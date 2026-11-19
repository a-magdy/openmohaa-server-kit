#!/usr/bin/env python3

"""
Server status query — displays detailed MOHAA server information.
"""

import sys
import os
from lib import (
    load_env_file,
    send_status_query,
    validate_address,
    parse_server_response,
    DEFAULT_PORT,
)


def format_server_info(server_info, players):
    """Format server information in a human-readable way."""
    print("=" * 60)
    print("MOHAA SERVER STATUS")
    print("=" * 60)

    print(f"Server Name: {server_info.get('sv_hostname', 'Unknown')}")
    print(f"Map: {server_info.get('mapname', 'Unknown')}")
    print(f"Game Type: {server_info.get('g_gametypestring', 'Unknown')}")
    print(f"Version: {server_info.get('shortversion', 'Unknown')}")
    print(f"Players: {len(players)}/{server_info.get('sv_maxclients', '?')}")

    print("\n" + "-" * 30)
    print("GAME SETTINGS")
    print("-" * 30)
    print(f"Frag Limit: {server_info.get('fraglimit', 'N/A')}")
    print(f"Time Limit: {server_info.get('timelimit', 'N/A')} minutes")
    print(f"Round Limit: {server_info.get('roundlimit', 'N/A')}")
    print(f"Skill Level: {server_info.get('skill', 'N/A')}")
    print(f"Cheats: {'Enabled' if server_info.get('cheats') == '1' else 'Disabled'}")
    print(f"Allow Vote: {'Yes' if server_info.get('g_allowvote') == '1' else 'No'}")

    print("\n" + "-" * 30)
    print("SERVER SETTINGS")
    print("-" * 30)
    print(f"FPS: {server_info.get('sv_fps', 'N/A')}")
    print(f"Min Ping: {server_info.get('sv_minPing', 'N/A')}")
    print(f"Max Ping: {server_info.get('sv_maxPing', 'N/A')}")
    print(
        f"Allow Download: {'Yes' if server_info.get('sv_allowDownload') == '1' else 'No'}"
    )
    print(
        f"Flood Protect: {'Yes' if server_info.get('sv_floodProtect') == '1' else 'No'}"
    )

    if "sv_maplist" in server_info:
        maps = server_info["sv_maplist"].split(" ")
        print(f"\nMap Rotation: {', '.join(maps)}")

    if players:
        print("\n" + "-" * 30)
        print("PLAYERS")
        print("-" * 30)
        for i, player in enumerate(players, 1):
            print(f"{i}. {player['name']} (Score: {player['score']})")
    else:
        print("\nNo players currently on the server.")

    print("=" * 60)


def main():
    load_env_file()

    port = int(os.environ.get("RCON_PORT", str(DEFAULT_PORT)))

    if len(sys.argv) > 1:
        server = sys.argv[1]
        print(f"Using provided address: {server}")
    elif os.environ.get("RCON_SERVER"):
        server = os.environ.get("RCON_SERVER")
        print(f"Using server from .env file: {server}")
    else:
        print(
            "Error: No server specified. Provide as argument or set RCON_SERVER in .env"
        )
        sys.exit(1)

    is_valid, addr_type = validate_address(server)
    if not is_valid:
        print(f"Error: Invalid IP address or hostname '{server}'")
        sys.exit(1)

    print(f"Connecting to {server}:{port} ({addr_type})...")
    print()

    try:
        received = send_status_query(server, port)
        server_info, players = parse_server_response(received)
        format_server_info(server_info, players)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
