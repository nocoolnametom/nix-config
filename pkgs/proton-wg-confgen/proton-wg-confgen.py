"""Generate a WireGuard configuration for a Proton VPN server, headlessly.

Proton no longer offers WireGuard config downloads for every account, and its
official Linux clients expect a desktop session (NetworkManager, a keyring and
an interactive login). This tool drives the same library those clients use,
proton-vpn-api-core, without any of that:

  1. Signs in with a username/password (and an optional TOTP secret), or
     resumes the session saved by a previous run.
  2. Registers this machine's WireGuard key with Proton. The key is created on
     the first run and then kept in the state file, so it never changes; only
     its certificate (valid for about 7 days) is renewed on each run.
  3. Fetches the live server list and picks an enabled server that matches the
     requested country/features, skipping any the caller has marked bad.
  4. Writes a `wg setconf` configuration plus a JSON description of the chosen
     server.

Exit codes: 0 success, 1 generic failure, 2 sign-in needs human attention
(wrong password, CAPTCHA, unexpected 2FA), 3 no matching server.
"""

import argparse
import asyncio
import json
import os
import random
import sys
import tempfile
import time
from pathlib import Path
from types import SimpleNamespace

from proton.session.exceptions import (
    ProtonAPIAuthenticationNeeded,
    ProtonAPIError,
    ProtonAPIHumanVerificationNeeded,
)
from proton.vpn.core.session_holder import ClientTypeMetadata, SessionHolder
from proton.vpn.session import VPNSession
from proton.vpn.session.servers.types import ServerFeatureEnum

EXIT_NEEDS_HUMAN = 2
EXIT_NO_SERVER = 3


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def read_secret(path: str) -> str:
    return Path(path).read_text(encoding="utf-8").strip()


def write_private(path: Path, content: str) -> None:
    """Atomically write a root-only file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(content)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def new_session() -> VPNSession:
    # Identify as the official CLI built on the same library version, so the
    # API applies the same rules it applies to that client.
    metadata = ClientTypeMetadata(type="cli")
    # pylint: disable=protected-access
    appversion = SessionHolder._get_app_version_header_value(metadata)
    return VPNSession(
        appversion=appversion,
        user_agent=f"ProtonVPN/{metadata.version} (Linux; nixos)",
    )


def load_session(state_file: Path) -> VPNSession:
    session = new_session()
    if state_file.exists():
        try:
            session.__setstate__(json.loads(state_file.read_text(encoding="utf-8")))
        except (ValueError, KeyError) as error:
            log(f"Ignoring unreadable session state ({error}); signing in again")
            session = new_session()
    return session


def save_session(session: VPNSession, state_file: Path) -> None:
    # Includes the refresh token and the ed25519 key the WireGuard key derives from.
    write_private(state_file, json.dumps(session.__getstate__()))


async def sign_in(session: VPNSession, args) -> None:
    username = read_secret(args.username_file)
    password = read_secret(args.password_file)
    log(f"Signing in to Proton as {username}")
    result = await session.login(username, password)
    if result.twofa_required:
        if not args.totp_secret_file:
            log("Account requires 2FA but no TOTP secret file was given")
            sys.exit(EXIT_NEEDS_HUMAN)
        import pyotp  # pylint: disable=import-outside-toplevel

        code = pyotp.TOTP(read_secret(args.totp_secret_file)).now()
        result = await session.provide_2fa_code(code)
    if not result.success:
        log("Proton rejected the sign-in (check the username, password and TOTP secret)")
        sys.exit(EXIT_NEEDS_HUMAN)


def certificate_features(args) -> SimpleNamespace:
    # Features are baked into the certificate the server sees, so they are
    # requested here rather than toggled after connecting.
    return SimpleNamespace(
        moderate_nat=args.moderate_nat,
        vpn_accelerator=True,
        port_forwarding=args.port_forwarding,
        netshield=0,
    )


async def refresh(session: VPNSession, args, state_file: Path) -> VPNSession:
    """Make sure the session is signed in and its VPN data/certificate are fresh."""
    for attempt in (1, 2):
        try:
            if not session.logged_in:
                await sign_in(session, args)
                save_session(session, state_file)
            await session.fetch_session_data(features=certificate_features(args))
            save_session(session, state_file)
            return session
        except ProtonAPIHumanVerificationNeeded:
            log("Proton wants a CAPTCHA/human verification for this sign-in; sign in once "
                "with an official app from this network, then retry")
            sys.exit(EXIT_NEEDS_HUMAN)
        except (ProtonAPIAuthenticationNeeded, ProtonAPIError) as error:
            http_code = getattr(error, "http_code", None)
            if attempt == 2 or not (
                isinstance(error, ProtonAPIAuthenticationNeeded) or http_code in (401, 403)
            ):
                raise
            # The saved session expired or was revoked: start over with the password.
            log(f"Saved Proton session no longer valid ({error}); signing in again")
            state_file.unlink(missing_ok=True)
            session = new_session()
    raise RuntimeError("unreachable")


def read_excluded(path) -> set:
    """Server names or entry IPs the caller marked bad, as `<name-or-ip> <epoch>` lines.

    Only entries from the last 24 hours count, so a server that was down for a
    while becomes eligible again. Several logical servers can share one entry
    IP, which is why callers should list the IP as well as the name.
    """
    if not path or not os.path.exists(path):
        return set()
    cutoff = time.time() - 24 * 3600
    excluded = set()
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[1].isdigit() and int(parts[1]) >= cutoff:
            excluded.add(parts[0])
        elif len(parts) == 1:
            excluded.add(parts[0])
    return excluded


def pick_server(session: VPNSession, args):
    tier = session.vpn_account.max_tier
    required = ServerFeatureEnum.P2P if args.p2p else 0
    forbidden = ServerFeatureEnum.SECURE_CORE | ServerFeatureEnum.TOR
    excluded = read_excluded(args.exclude_file)

    def usable_physicals(server, skip):
        return [
            p for p in server.physical_servers
            if p.enabled and p.x25519_pk and p.entry_ip and p.entry_ip not in skip
        ]

    def candidates_for(skip):
        def matches(server) -> bool:
            flags = 0
            for feature in server.features:
                flags |= feature
            return (
                server.enabled
                and server.tier <= tier
                and server.exit_country.upper() == args.country.upper()
                and (not args.city or (server.city or "").lower() == args.city.lower())
                and flags & required == required
                and flags & forbidden == 0
                and server.name not in skip
                and bool(usable_physicals(server, skip))
            )

        return sorted(filter(matches, session.server_list), key=lambda s: s.score)

    candidates = candidates_for(excluded)
    if not candidates and excluded:
        # Everything we'd use has been marked bad, which usually means the
        # problem is on our side (e.g. the uplink was down), not Proton's.
        # Retrying known servers beats giving up.
        log(f"All matching servers are excluded ({len(excluded)} entries); ignoring exclusions")
        excluded = set()
        candidates = candidates_for(excluded)
    if not candidates:
        log(f"No enabled server matches country={args.country} city={args.city} "
            f"p2p={args.p2p} (tier {tier})")
        sys.exit(EXIT_NO_SERVER)

    # Stay on the current server while it is still healthy, so a routine
    # certificate renewal doesn't drop every peer connection.
    chosen = next((s for s in candidates if s.name == args.prefer), None)
    if chosen is None:
        chosen = random.choice(candidates[: args.top])
    physical = random.choice(usable_physicals(chosen, excluded))
    return chosen, physical


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--state-dir", required=True,
                        help="Directory for the saved session (keep it private and persistent)")
    parser.add_argument("--username-file", required=True)
    parser.add_argument("--password-file", required=True)
    parser.add_argument("--totp-secret-file", help="Base32 TOTP secret, if the account uses 2FA")
    parser.add_argument("--country", default="US", help="Two-letter exit country code")
    parser.add_argument("--city", help="Optional exit city")
    parser.add_argument("--p2p", action="store_true", help="Only servers that allow P2P")
    parser.add_argument("--port-forwarding", action="store_true",
                        help="Request NAT-PMP port forwarding in the certificate")
    parser.add_argument("--moderate-nat", action="store_true",
                        help="Request moderate (less strict) NAT in the certificate")
    parser.add_argument("--exclude-file", help="File of `<server-name> <epoch>` lines to skip")
    parser.add_argument("--prefer", help="Keep this server if it still qualifies")
    parser.add_argument("--top", type=int, default=5,
                        help="Choose randomly among this many best-scored servers")
    parser.add_argument("--endpoint-port", type=int, default=51820)
    parser.add_argument("--output", required=True, help="Where to write the `wg setconf` file")
    parser.add_argument("--info", help="Where to write JSON describing the chosen server")
    args = parser.parse_args()

    state_file = Path(args.state_dir) / "session.json"
    session = asyncio.run(refresh(load_session(state_file), args, state_file))
    server, physical = pick_server(session, args)
    credentials = session.vpn_account.vpn_credentials.pubkey_credentials

    write_private(
        Path(args.output),
        "[Interface]\n"
        f"PrivateKey = {credentials.wg_private_key}\n"
        "\n[Peer]\n"
        f"PublicKey = {physical.x25519_pk}\n"
        "AllowedIPs = 0.0.0.0/0\n"
        f"Endpoint = {physical.entry_ip}:{args.endpoint_port}\n"
        "PersistentKeepalive = 25\n",
    )
    info = {
        "server": server.name,
        "city": server.city,
        "entry_ip": physical.entry_ip,
        "load": server.load,
        "certificate_valid_seconds": credentials.certificate_validity_remaining,
        "generated_at": int(time.time()),
    }
    if args.info:
        write_private(Path(args.info), json.dumps(info) + "\n")
    log(f"Selected {server.name} ({server.city}) via {physical.entry_ip}, load {server.load}%")


if __name__ == "__main__":
    main()
