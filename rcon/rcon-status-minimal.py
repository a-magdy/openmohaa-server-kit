#!/usr/bin/env python3

"""
Minimal server status query — compact MOHAA server information.
"""

import sys
import os
from lib import load_env_file, send_status_query, parse_server_response, DEFAULT_PORT


def main():
    load_env_file()

    server = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("RCON_SERVER")
    port = int(os.environ.get("RCON_PORT", str(DEFAULT_PORT)))

    if not server:
        print("No server specified")
        sys.exit(1)

    try:
        received = send_status_query(server, port)
        server_info, players = parse_server_response(received)

        print(f"{server_info.get('sv_hostname', 'Unknown')}")
        print(f"Map: {server_info.get('mapname', 'Unknown')}")
        print(f"Players: {len(players)}/{server_info.get('sv_maxclients', '?')}")

        for player in players:
            print(f"  {player['name']} ({player['score']})")

    except Exception as e:
        print(f"Failed to get server status: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
