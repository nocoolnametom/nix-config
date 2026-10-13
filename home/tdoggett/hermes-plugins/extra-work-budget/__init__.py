"""extra-work-budget: let a coding worker dig past its fix, but only briefly.

The worker's run has three phases:

  fixing  No limit of its own. Ends when the worker calls the `fix_done` tool
          (every part of the task is done and checked).
  extra   After `fix_done`: further tool calls count against EXTRA_WORK_BUDGET
          (default 25), counted in calls rather than minutes so that waiting
          for the GPU is free. Every EXTRA_WORK_REMIND_EVERY calls (default 5)
          the tool result carries a reminder: the original task, the files
          changed for it, calls left. Edits to files the fix didn't touch are
          refused, so problems found (or caused) while checking go in the
          report instead of becoming more fixes.
  done    Budget spent: everything except reading is refused with "write
          your report now".

Fallback for a worker that never calls `fix_done`: the first successful Nix
check (`nix eval`, `nix build`, `nix flake check`) after an edit starts a
larger budget (EXTRA_WORK_FALLBACK_BUDGET, default 60) with the same
reminders but no edit blocking, since the plugin can't tell whether every
part of the task is done. Either way the run ends in a report.

State lives in this process, per session; nothing is written to disk.
"""

from __future__ import annotations

import json
import os
from typing import Any, Optional

EDIT_TOOLS = {"patch", "write_file"}
READ_ONLY_TOOLS = {"read_file", "search_files", "todo", "fix_done"}
NIX_CHECKS = ("nix eval", "nix build", "nix flake check", "nixos-rebuild build", "nixos-rebuild dry-build")
TASK_EXCERPT_CHARS = 600


def _int_env(name: str, default: int) -> int:
    try:
        return max(1, int(os.environ.get(name, default)))
    except ValueError:
        return default


BUDGET = _int_env("EXTRA_WORK_BUDGET", 25)
FALLBACK_BUDGET = _int_env("EXTRA_WORK_FALLBACK_BUDGET", 60)
REMIND_EVERY = _int_env("EXTRA_WORK_REMIND_EVERY", 5)

FIX_DONE_SCHEMA = {
    "name": "fix_done",
    "description": (
        "Call this once, when every part of the task is done and you have checked it "
        "(e.g. with nix eval). After this, a small budget of tool calls remains for extra "
        "checking; edits to files you haven't changed are refused, and you write your report."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "summary": {
                "type": "string",
                "description": "Each part of the task, what you changed for it, and how you checked it.",
            }
        },
        "required": ["summary"],
    },
}

# session_id -> state dict, see _state()
_sessions: dict[str, dict[str, Any]] = {}


def _state(session_id: str) -> dict[str, Any]:
    return _sessions.setdefault(
        session_id,
        {
            "task": "",
            "edited": [],
            "phase": "fixing",  # fixing | fallback | extra
            "budget": 0,
            "used": 0,
            "remind_due": False,
            "final_sent": False,
        },
    )


def _start_budget(state: dict[str, Any], phase: str, budget: int) -> None:
    state.update(phase=phase, budget=budget, used=0, remind_due=False, final_sent=False)


def _parse_result(result: Any) -> Optional[dict[str, Any]]:
    if isinstance(result, dict):
        return result
    if isinstance(result, str):
        try:
            parsed = json.loads(result)
        except ValueError:
            return None
        return parsed if isinstance(parsed, dict) else None
    return None


def _succeeded(tool_name: str, result: Any, status: str) -> bool:
    if status == "error":
        return False
    parsed = _parse_result(result)
    if parsed is None:
        return True
    if parsed.get("error"):
        return False
    if tool_name == "terminal":
        return parsed.get("exit_code") == 0
    return True


def _path_of(args: Any) -> str:
    path = str(args.get("path", "")) if isinstance(args, dict) else ""
    return os.path.normpath(path) if path else ""


def _summary(state: dict[str, Any]) -> str:
    task = state["task"].strip()
    if len(task) > TASK_EXCERPT_CHARS:
        task = task[:TASK_EXCERPT_CHARS] + " [...]"
    files = ", ".join(state["edited"]) or "(none)"
    return f"Original task: {task}\nFiles changed for it: {files}"


def _calls(count: int) -> str:
    return f"{count} tool call{'' if count == 1 else 's'}"


def _handle_fix_done(args: dict, session_id: str = "", **_: Any) -> str:
    state = _state(session_id)
    if state["phase"] == "extra":
        return json.dumps({"result": "fix_done was already called; carry on with your report."})
    # From the fallback, only what is left of it: in T7 (2026-10-13) a worker
    # that had used up its fallback budget called fix_done and got 25 more.
    budget = BUDGET if state["phase"] == "fixing" else min(BUDGET, state["budget"] - state["used"])
    _start_budget(state, "extra", budget)
    if budget <= 0:
        state["final_sent"] = True
        return json.dumps(
            {"result": "[extra-work budget] Noted, but the budget is already used up. Write your report now.\n" + _summary(state)}
        )
    return json.dumps(
        {
            "result": (
                f"[extra-work budget] Noted. You have {_calls(budget)} for any extra checking that "
                "would change your confidence in the fix; edits to files you haven't changed are now "
                "refused. If nothing more is needed, write your report now.\n" + _summary(state)
            )
        }
    )


def _on_pre_llm_call(session_id: str = "", user_message: Any = None, **_: Any) -> None:
    state = _state(session_id)
    if not state["task"] and isinstance(user_message, str):
        state["task"] = user_message


def _on_pre_tool_call(tool_name: str = "", args: Any = None, session_id: str = "", **_: Any) -> Optional[dict[str, str]]:
    state = _state(session_id)
    if state["phase"] == "fixing" or tool_name == "fix_done":
        return None

    if state["used"] >= state["budget"]:
        if tool_name in READ_ONLY_TOOLS:
            return None
        return {
            "action": "block",
            "message": (
                "Not run: the budget for work after the fix is used up. "
                "Write your report now. Include what you were checking when the budget ran out "
                "and why it is unfinished.\n\n" + _summary(state)
            ),
        }

    state["used"] += 1
    if state["used"] % REMIND_EVERY == 0 or state["used"] == state["budget"]:
        state["remind_due"] = True

    if state["phase"] == "extra" and tool_name in EDIT_TOOLS and _path_of(args) not in state["edited"]:
        return {
            "action": "block",
            "message": (
                f"Not run: you called fix_done, and {_path_of(args) or 'this file'} is not part of the "
                "fix. Don't fix other problems now, including ones your checking turned up. Describe "
                "this one in your report instead. If the original fix really needs this file, say so "
                "in the report.\n\n" + _summary(state)
            ),
        }
    return None


def _on_transform_tool_result(
    tool_name: str = "", args: Any = None, result: Any = None, session_id: str = "", status: str = "", **_: Any
) -> Optional[str]:
    state = _state(session_id)
    if tool_name == "fix_done":
        return None
    succeeded = _succeeded(tool_name, result, status)

    if tool_name in EDIT_TOOLS and succeeded:
        path = _path_of(args)
        if path and path not in state["edited"]:
            state["edited"].append(path)

    note = ""
    if state["phase"] == "fixing" and state["edited"] and tool_name == "terminal" and succeeded:
        command = str(args.get("command", "")) if isinstance(args, dict) else ""
        if any(check in command for check in NIX_CHECKS):
            _start_budget(state, "fallback", FALLBACK_BUDGET)
            note = (
                "[extra-work budget] That check passed. If every part of the task is now done and "
                "checked, call fix_done. If parts remain, carry on with them. From here, the rest of "
                f"this run has {_calls(FALLBACK_BUDGET)}.\n" + _summary(state)
            )
    elif state["phase"] != "fixing" and state["remind_due"]:
        state["remind_due"] = False
        left = state["budget"] - state["used"]
        if left <= 0 and not state["final_sent"]:
            state["final_sent"] = True
            note = "[extra-work budget] Used up. Write your report now.\n" + _summary(state)
        elif left > 0:
            unfinished = "" if state["phase"] == "extra" else " If every part of the task is done, call fix_done."
            note = (
                f"[extra-work budget] {_calls(left)} left. Is this still about the original task? If the "
                "last few calls haven't changed your confidence in the fix, stop and write your report."
                + unfinished + "\n" + _summary(state)
            )

    if not note or not isinstance(result, str):
        return None
    return result + "\n\n" + note


def register(ctx) -> None:
    ctx.register_tool(
        name="fix_done",
        toolset="extra_work_budget",
        schema=FIX_DONE_SCHEMA,
        handler=_handle_fix_done,
        description=FIX_DONE_SCHEMA["description"],
        emoji="🏁",
    )
    ctx.register_hook("pre_llm_call", _on_pre_llm_call)
    ctx.register_hook("pre_tool_call", _on_pre_tool_call)
    ctx.register_hook("transform_tool_result", _on_transform_tool_result)
