#!/usr/bin/env python3

"""
RCON client — sends commands to Quake-based game servers.
"""

import sys
import os
import argparse
from lib import load_env_file, send_rcon_command, DEFAULT_PORT


def main():
    load_env_file()

    parser = argparse.ArgumentParser(
        description="Send RCON commands to Quake-based game servers",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    %(prog)s -s 192.168.1.100 status
    %(prog)s -s 192.168.1.100 -p mypassword -P 27015 "say Hello World"
    %(prog)s -s 127.0.0.1 --password secret players
        """,
    )

    parser.add_argument(
        "-s",
        "--server",
        default=os.environ.get("RCON_SERVER"),
        help="Server IP address or hostname (default: from .env)",
    )
    parser.add_argument("command", help="RCON command to execute")
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

    print(f"Sending RCON command to {args.server}:{args.port}...")
    print(f"Command: {args.command}")
    print("Response:")
    print("-" * 40)

    response = send_rcon_command(
        args.server, args.port, args.password, args.command, args.timeout
    )

    if not response:
        print("No response received")
        sys.exit(1)

    print(response)
    print("-" * 40)

    # send_rcon_command reports failures as text; scripts need a non-zero exit.
    if response.startswith(("Error:", "No valid response")) or (
        "Bad rconpassword" in response
    ):
        print("Command failed")
        sys.exit(1)

    print("Command completed")


if __name__ == "__main__":
    main()
