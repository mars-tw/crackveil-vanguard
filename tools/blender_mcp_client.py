"""Small newline-delimited JSON client for the local Blender MCP add-on.

Each request uses a fresh TCP connection, as required by the add-on.  Refused
connections are retried because Blender may be temporarily serving another MCP
client.  The module is both importable by the R21 batch builder and usable as a
command-line diagnostic:

    python tools/blender_mcp_client.py get_scene_info
    python tools/blender_mcp_client.py execute_code --params '{"code":"print(1)"}'
"""

from __future__ import annotations

import argparse
import json
import socket
import time
from pathlib import Path
from typing import Any


HOST = "127.0.0.1"
PORT = 9876


def send_command(
    command_type: str,
    params: dict[str, Any] | None = None,
    *,
    retry_seconds: float = 180.0,
    retry_interval: float = 2.0,
    response_timeout: float = 900.0,
) -> dict[str, Any]:
    """Send one command over one connection and decode its JSON response."""
    payload = json.dumps(
        {"type": command_type, "params": params or {}},
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8") + b"\n"
    deadline = time.monotonic() + retry_seconds
    last_error: OSError | None = None
    while time.monotonic() < deadline:
        try:
            with socket.create_connection((HOST, PORT), timeout=15.0) as connection:
                connection.settimeout(response_timeout)
                connection.sendall(payload)
                # The add-on currently sends one complete response but keeps
                # the accepted socket alive briefly.  One large recv avoids
                # waiting for EOF or a response-side newline that may not be
                # present.
                raw = connection.recv(16 * 1024 * 1024).split(b"\n", 1)[0]
            if not raw:
                raise RuntimeError(f"Blender MCP returned no data for {command_type}")
            response = json.loads(raw.decode("utf-8"))
            if not isinstance(response, dict):
                raise RuntimeError(f"Unexpected Blender MCP response: {response!r}")
            return response
        except (ConnectionRefusedError, ConnectionResetError, TimeoutError, socket.timeout, OSError) as error:
            last_error = error
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            time.sleep(min(retry_interval, remaining))
    raise RuntimeError(
        f"Unable to reach Blender MCP at {HOST}:{PORT} for {retry_seconds:.0f}s"
    ) from last_error


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command")
    parser.add_argument("--params", default="{}", help="JSON object")
    parser.add_argument("--params-file", type=Path, help="JSON object file")
    parser.add_argument("--code-file", type=Path, help="execute_code source file")
    parser.add_argument("--code-call", help="statement appended to --code-file")
    parser.add_argument("--retry-seconds", type=float, default=180.0)
    parser.add_argument("--response-timeout", type=float, default=900.0)
    args = parser.parse_args()
    params_text = args.params_file.read_text(encoding="utf-8") if args.params_file else args.params
    params = json.loads(params_text)
    if not isinstance(params, dict):
        parser.error("--params must decode to a JSON object")
    if args.code_file:
        if args.command != "execute_code":
            parser.error("--code-file is only valid with execute_code")
        source_path = str(args.code_file.resolve()).replace("\\", "/")
        code = (
            "_r21_ns = {'bpy': bpy, '__name__': 'blender_mcp_exec'}\n"
            f"exec(compile(open({source_path!r}, encoding='utf-8').read(), {source_path!r}, 'exec'), _r21_ns)\n"
        )
        if args.code_call:
            code += f"exec({args.code_call!r}, _r21_ns)\n"
        params = {"code": code}
    response = send_command(
        args.command,
        params,
        retry_seconds=args.retry_seconds,
        response_timeout=args.response_timeout,
    )
    print(json.dumps(response, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
