#!/usr/bin/env python3
"""
Test runner for ResizeAlign plugin.

Builds the main plugin and test runner plugin, starts a WebSocket server,
waits for Roblox Studio to connect, then streams test results to stdout.

Usage:
    python runtests.py [filter]

    filter: "all" (default) or a substring to match test names against.

Requires: pip install websockets
"""

import asyncio
import json
import subprocess
import sys

import websockets
import websockets.asyncio.server

PORT = 38741
CONNECT_TIMEOUT = 30


def build(description: str, args: list[str]):
    """Run a rojo build command and print status."""
    print(f"{description}...")
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode != 0:
        print("  Build failed!")
        print(result.stderr)
        sys.exit(1)
    print("  Done.")


async def run_tests(filter_str: str):
    # Step 1: Start WebSocket server and wait for connection
    connected: asyncio.Future[websockets.asyncio.server.ServerConnection] = \
        asyncio.get_event_loop().create_future()

    async def handler(websocket: websockets.asyncio.server.ServerConnection):
        if not connected.done():
            connected.set_result(websocket)
        # Keep the handler alive until the connection closes
        try:
            await websocket.wait_closed()
        except Exception:
            pass

    server = await websockets.asyncio.server.serve(handler, "localhost", PORT)

    # Step 2: Build the test runner plugin (triggers Studio auto-reload)
    build(
        "Building test runner",
        ["rojo", "build", "runtests.project.json", "-p",
         "RunTests.rbxmx"],
    )

    print(f"Waiting for Studio connection on port {PORT}...")

    # Step 3: Wait for Studio to connect
    try:
        ws = await asyncio.wait_for(connected, timeout=CONNECT_TIMEOUT)
    except asyncio.TimeoutError:
        print(f"Timed out waiting for Studio after {CONNECT_TIMEOUT}s.")
        server.close()
        sys.exit(1)

    # Wait for "ready" message
    try:
        raw = await asyncio.wait_for(ws.recv(), timeout=10)
        msg = json.loads(raw)
        if msg.get("type") != "ready":
            print(f"Unexpected first message: {msg}")
            server.close()
            sys.exit(1)
    except asyncio.TimeoutError:
        print("Timed out waiting for ready message.")
        server.close()
        sys.exit(1)

    print("Connected!\n")

    # Step 4: Send run command
    await ws.send(json.dumps({"type": "run", "filter": filter_str}))

    # Step 5: Process results
    passed = 0
    failed = 0
    total = 0
    exit_code = 0

    print("Running tests...")
    try:
        async for raw_msg in ws:
            msg = json.loads(raw_msg)
            msg_type = msg.get("type")

            if msg_type == "output":
                print(f"  {msg.get('message', '')}")

            elif msg_type == "result":
                name = msg.get("name", "?")
                status = msg.get("status", "?")
                duration = msg.get("duration", 0)
                error_msg = msg.get("error")

                if status == "pass":
                    print(f"  \033[32mPASS\033[0m  {name} ({duration}ms)")
                else:
                    print(f"  \033[31mFAIL\033[0m  {name}")
                    if error_msg:
                        print(f"        {error_msg}")

            elif msg_type == "done":
                passed = msg.get("passed", 0)
                failed = msg.get("failed", 0)
                total = msg.get("total", 0)
                break

    except websockets.exceptions.ConnectionClosed:
        print("\nConnection to Studio lost.")
        exit_code = 1

    # Step 6: Print summary
    print()
    if failed > 0:
        print(
            f"Results: \033[32m{passed} passed\033[0m, "
            f"\033[31m{failed} failed\033[0m, {total} total"
        )
        exit_code = 1
    else:
        print(f"Results: \033[32m{passed} passed\033[0m, {total} total")

    # Cleanup
    server.close()
    await server.wait_closed()
    sys.exit(exit_code)


def main():
    filter_str = sys.argv[1] if len(sys.argv) > 1 else "all"
    asyncio.run(run_tests(filter_str))


if __name__ == "__main__":
    main()
