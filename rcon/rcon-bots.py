#!/usr/bin/env python3

"""
Bot adder — adds named bots to MOHAA servers using RCON.
"""

import sys
import os
import time
import argparse
from lib import load_env_file, send_rcon_command, DEFAULT_PORT


def main():
    load_env_file()

    parser = argparse.ArgumentParser(
        description="Add bots to MOHAA servers using RCON",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s -s 192.168.1.100 Soldier1 Sniper2 Medic3
  %(prog)s -s 127.0.0.1 EliteBot1 EliteBot2
  %(prog)s -s 192.168.1.100 -p mypass Rookie1 Rookie2
        """,
    )

    parser.add_argument(
        "-s",
        "--server",
        default=os.environ.get("RCON_SERVER"),
        help="Server IP address or hostname (default: from .env)",
    )
    parser.add_argument(
        "-p",
        "--password",
        default=os.environ.get("RCON_PASSWORD"),
        help="RCON password (default: from .env)",
    )
    parser.add_argument(
        "-P",
        "--port",
        type=int,
        default=int(os.environ.get("RCON_PORT", str(DEFAULT_PORT))),
        help=f"Server port (default: from .env or {DEFAULT_PORT})",
    )
    parser.add_argument(
        "-t",
        "--timeout",
        type=int,
        default=5,
        help="Connection timeout in seconds (default: 5)",
    )
    parser.add_argument(
        "bot_names", nargs="+", help="Bot names to add (at least one required)"
    )

    args = parser.parse_args()

    if not args.server:
        print(
            "Error: Server address is required. Provide via -s/--server or set RCON_SERVER in .env"
        )
        sys.exit(1)

    if not args.password:
        print(
            "Error: RCON password is required. Provide via -p/--password or set RCON_PASSWORD in .env"
        )
        sys.exit(1)

    if not (1 <= args.port <= 65535):
        print(f"Error: Invalid port number: {args.port} (must be 1-65535)")
        sys.exit(1)

    print(f"Adding bots to {args.server}:{args.port}...")
    print("=" * 40)

    for i, bot_name in enumerate(args.bot_names, 1):
        command = f"addbot 1 {bot_name}"
        print(f"[{i}/{len(args.bot_names)}] Adding bot: {bot_name}")
        print(f"Command: {command}")
        print("Response:")

        response = send_rcon_command(
            args.server, args.port, args.password, command, args.timeout
        )

        if response:
            print(response)
        else:
            print("(No response or empty response)")

        print("-" * 40)

        if i < len(args.bot_names):
            time.sleep(0.5)

    print("All bots added successfully!")
    print(f"Added {len(args.bot_names)} bots")


if __name__ == "__main__":
    main()
