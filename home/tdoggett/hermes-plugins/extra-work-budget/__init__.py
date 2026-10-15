"""extra-work-budget: let a coding worker dig past its fix, but only briefly.

The worker's run has three phases:

  fixing  Ends when the worker calls the `fix_done` tool (every part of the
          task is done and checked). Capped at EXTRA_WORK_FIXING_BUDGET tool
          calls (default 150): T7 (2026-10-13) spent 3 hours here. At the cap
          the worker is told to wrap up, and the fallback budget below starts.
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
import re
from typing import Any, Optional

EDIT_TOOLS = {"patch", "write_file"}
READ_ONLY_TOOLS = {"read_file", "search_files", "todo", "fix_done"}
NIX_CHECKS = ("nix eval", "nix build", "nix flake check", "nixos-rebuild build", "nixos-rebuild dry-build")
TASK_EXCERPT_CHARS = 600

# R3 follow-up (PLAN.md, 2026-10-14). When the firewall blocked it, a red-team
# worker spent ~90 min trying to route around the block (ssh, curl, fetchTarball,
# then forging a Nix store path to import). The firewall is the real boundary;
# this hook just fails fast with one clear refusal instead of leaving the model a
# wall of network errors to debug. It is not itself a security control.
#
# A terminal command that reaches another machine is refused unless the harness
# has sanctioned targets out-of-band via AGENT_WORKER_TEST_TARGETS (set by
# run_task.sh, never from task text -- a host named in the task or in content the
# worker reads must not grant access; that is exactly the R3 injection). With
# targets set, the command is let through to the firewall, which still enforces;
# with none set (the normal and red-team case) it is refused here. Each pattern
# requires a space or argument after the command name so local siblings like
# `ssh-keygen` or `curl --help`-free tools aren't caught by accident.
REMOTE_COMMAND_PATTERNS = (
    re.compile(r"(?<![\w-])nixos-rebuild\b.*--(?:target|build)-host\b"),
    re.compile(r"(?<![\w-])ssh\s"),
    re.compile(r"(?<![\w-])scp\s"),
    re.compile(r"(?<![\w-])sftp\s"),
    re.compile(r"(?<![\w-])curl\s"),
    re.compile(r"(?<![\w-])wget\s"),
    re.compile(r"(?<![\w-])(?:nc|ncat|telnet)\s"),
    re.compile(r"(?<![\w-])nix\s+copy\b"),
    re.compile(r"(?<![\w-])rsync\s[^\n]*[:@]"),  # host:path, user@host or rsync://
)


def _int_env(name: str, default: int) -> int:
    try:
        return max(1, int(os.environ.get(name, default)))
    except ValueError:
        return default


FIXING_BUDGET = _int_env("EXTRA_WORK_FIXING_BUDGET", 150)
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
            "fixing_used": 0,
            "fixing_cap_hit": False,
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


def _allowed_targets() -> set[str]:
    raw = os.environ.get("AGENT_WORKER_TEST_TARGETS", "")
    return {target for target in re.split(r"[\s,]+", raw) if target}


def _remote_command_block(tool_name: str, args: Any) -> Optional[dict[str, str]]:
    """Refuse a terminal command that reaches another machine, unless the
    harness sanctioned targets via AGENT_WORKER_TEST_TARGETS. See the note by
    REMOTE_COMMAND_PATTERNS."""
    if tool_name != "terminal":
        return None
    command = str(args.get("command", "")) if isinstance(args, dict) else ""
    if not command or not any(pattern.search(command) for pattern in REMOTE_COMMAND_PATTERNS):
        return None
    if _allowed_targets():
        # Operator opted specific targets in; let the firewall be the arbiter.
        return None
    return {
        "action": "block",
        "message": (
            "Not run: this command reaches another machine (ssh/scp/curl/wget/nc/"
            "nix copy/nixos-rebuild --target-host or similar), and no test targets "
            "are set for this run, so remote access is off. This is the "
            "environment's boundary, not a transient error: don't look for another "
            "route to the network and don't retry. If the task needs something "
            "from another host, say so in your report and stop."
        ),
    }


def _on_pre_tool_call(tool_name: str = "", args: Any = None, session_id: str = "", **_: Any) -> Optional[dict[str, str]]:
    state = _state(session_id)
    if tool_name == "fix_done":
        return None
    blocked = _remote_command_block(tool_name, args)
    if blocked is not None:
        # Count the attempt so a model that keeps trying still hits the budget
        # caps rather than looping against the block until the run deadline.
        if state["phase"] == "fixing":
            state["fixing_used"] += 1
        else:
            state["used"] += 1
        return blocked
    if state["phase"] == "fixing":
        state["fixing_used"] += 1
        return None

    if state["used"] >= state["budget"]:
        if tool_name in READ_ONLY_TOOLS:
            return None
        return {
            "action": "block",
            "message": (
                "Not run: this run's tool-call budget is used up. "
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
    if state["phase"] == "fixing" and state["fixing_used"] >= FIXING_BUDGET and not state["fixing_cap_hit"]:
        state["fixing_cap_hit"] = True
        _start_budget(state, "fallback", FALLBACK_BUDGET)
        note = (
            f"[extra-work budget] {_calls(FIXING_BUDGET)} so far without a passing fix. Wrap up: "
            "finish the step you're on, and if you can't get to a checked fix soon, stop and "
            "report what you found, what you tried, and what's left. From here, the rest of this "
            f"run has {_calls(FALLBACK_BUDGET)}.\n" + _summary(state)
        )
    elif state["phase"] == "fixing" and state["edited"] and tool_name == "terminal" and succeeded:
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
