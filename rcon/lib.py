#!/usr/bin/env python3

"""
Shared RCON library for OpenMoHAA server management.
Provides UDP-based RCON communication using the Quake protocol.
"""

import socket
import os
from pathlib import Path


def load_env_file():
    """Load environment variables from .env file if it exists."""
    env_file = Path(__file__).parent / ".env"
    if env_file.exists():
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    os.environ.setdefault(key.strip(), value.strip())


def send_rcon_command(server, port, password, command, timeout=5):
    """
    Send an RCON command to a Quake-based game server.

    Args:
        server: Server IP address or hostname
        port: Server port
        password: RCON password
        command: Command to execute
        timeout: Socket timeout in seconds

    Returns:
        str: Server response or error message
    """
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)

        rcon_cmd = f"rcon {password} {command}"
        packet = b"\xff\xff\xff\xff\x02" + rcon_cmd.encode("utf-8")

        sock.sendto(packet, (server, port))
        response, addr = sock.recvfrom(65000)

        if len(response) > 4:
            return response[4:].decode("utf-8", errors="ignore").rstrip("\x00")
        else:
            return "No valid response received"

    except socket.timeout:
        return "Error: Connection timed out"
    except socket.gaierror:
        return "Error: Could not resolve hostname"
    except ConnectionRefusedError:
        return "Error: Connection refused"
    except socket.error as e:
        return f"Error: Socket error - {str(e)}"
    except Exception as e:
        return f"Error: {str(e)}"
    finally:
        if "sock" in locals():
            sock.close()


def send_status_query(server, port, timeout=5):
    """
    Send a getstatus query to a game server (no password needed).

    Args:
        server: Server IP address or hostname
        port: Server port
        timeout: Socket timeout in seconds

    Returns:
        bytes: Raw response data

    Raises:
        Exception: If the query fails
    """
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)
        message = b"\xff\xff\xff\xff\x02getstatus"
        sock.sendto(message, (server, port))
        received, addr = sock.recvfrom(4096)
        return received
    except socket.timeout:
        raise ConnectionError("Connection timed out")
    except socket.gaierror:
        raise ConnectionError("Could not resolve hostname")
    except ConnectionRefusedError:
        raise ConnectionError("Connection refused")
    except socket.error as e:
        raise ConnectionError(f"Socket error - {str(e)}")
    finally:
        if "sock" in locals():
            sock.close()


def validate_address(address):
    """Validate if the address is a valid IP or resolvable hostname."""
    try:
        socket.inet_aton(address)
        return True, "IP address"
    except socket.error:
        pass
    try:
        socket.gethostbyname(address)
        return True, "hostname"
    except socket.error:
        return False, "unknown"


def parse_server_response(data):
    """Parse a MOHAA server status response into structured data.

    Args:
        data: Raw bytes from server response

    Returns:
        tuple: (server_info dict, players list of dicts with 'name' and 'score')
    """
    response = data.decode("utf-8", errors="ignore")

    if "\x01statusResponse\n" in response:
        response = response.split("\x01statusResponse\n", 1)[1]

    lines = response.split("\n")
    server_info_line = lines[0] if lines else ""
    player_lines = lines[1:] if len(lines) > 1 else []

    server_info = {}
    if server_info_line.startswith("\\"):
        parts = server_info_line[1:].split("\\")
        for i in range(0, len(parts) - 1, 2):
            if i + 1 < len(parts):
                server_info[parts[i]] = parts[i + 1]

    players = []
    for line in player_lines:
        line = line.strip()
        if line and '"' in line:
            parts = line.split('"')
            if len(parts) >= 2:
                players.append({"name": parts[1], "score": parts[0].strip()})

    return server_info, players


DEFAULT_PORT = 12203
