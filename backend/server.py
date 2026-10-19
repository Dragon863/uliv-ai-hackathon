#!/usr/bin/env python3
"""Small JSON-file API for Meadow House Repairs."""

from __future__ import annotations

import hmac
import json
import os
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


EMPTY_STATE: dict[str, Any] = {"jobs": [], "nextSequence": 1}
MAX_BODY_BYTES = 4 * 1024 * 1024


class JsonStore:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.lock = threading.RLock()

    def read(self) -> dict[str, Any]:
        with self.lock:
            if not self.path.exists():
                return dict(EMPTY_STATE)
            with self.path.open("r", encoding="utf-8") as data_file:
                state = json.load(data_file)
            validate_state(state)
            return state

    def write(self, state: dict[str, Any]) -> None:
        validate_state(state)
        with self.lock:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            temp_name: str | None = None
            try:
                with tempfile.NamedTemporaryFile(
                    "w",
                    encoding="utf-8",
                    dir=self.path.parent,
                    prefix=f".{self.path.name}.",
                    suffix=".tmp",
                    delete=False,
                ) as temp_file:
                    temp_name = temp_file.name
                    json.dump(state, temp_file, ensure_ascii=False, separators=(",", ":"))
                    temp_file.flush()
                    os.fsync(temp_file.fileno())
                os.replace(temp_name, self.path)
            finally:
                if temp_name and os.path.exists(temp_name):
                    os.unlink(temp_name)


def validate_state(state: Any) -> None:
    if not isinstance(state, dict):
        raise ValueError("Request body must be a JSON object")
    jobs = state.get("jobs")
    sequence = state.get("nextSequence")
    if not isinstance(jobs, list):
        raise ValueError("'jobs' must be a list")
    if isinstance(sequence, bool) or not isinstance(sequence, int) or sequence < 1:
        raise ValueError("'nextSequence' must be a positive integer")
    for index, job in enumerate(jobs):
        if not isinstance(job, dict):
            raise ValueError(f"jobs[{index}] must be an object")
        required = ("id", "description", "reporter", "priority", "status", "createdAt", "history")
        if any(key not in job for key in required):
            raise ValueError(f"jobs[{index}] is missing a required field")
        if not isinstance(job["id"], str) or not isinstance(job["history"], list):
            raise ValueError(f"jobs[{index}] has invalid id or history fields")


class MeadowRequestHandler(BaseHTTPRequestHandler):
    store: JsonStore
    api_token: str

    def _send_json(self, status: int, data: dict[str, Any]) -> None:
        encoded = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, PUT, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type, Accept")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(encoded)

    def _authorized(self) -> bool:
        if not self.api_token:
            return True
        supplied = self.headers.get("Authorization", "")
        expected = f"Bearer {self.api_token}"
        return hmac.compare_digest(supplied.encode(), expected.encode())

    def _require_auth(self) -> bool:
        if self._authorized():
            return True
        self._send_json(401, {"error": "Unauthorized. Check MEADOW_API_TOKEN."})
        return False

    def do_OPTIONS(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, PUT, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type, Accept")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        if self.path == "/health":
            self._send_json(200, {"status": "ok"})
            return
        if self.path != "/api/jobs":
            self._send_json(404, {"error": "Not found"})
            return
        if not self._require_auth():
            return
        try:
            self._send_json(200, self.store.read())
        except (OSError, ValueError, json.JSONDecodeError) as error:
            self._send_json(500, {"error": f"Could not read jobs data: {error}"})

    def do_PUT(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        if self.path != "/api/jobs":
            self._send_json(404, {"error": "Not found"})
            return
        if not self._require_auth():
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if size < 1 or size > MAX_BODY_BYTES:
                raise ValueError("Request body must be between 1 byte and 4 MiB")
            state = json.loads(self.rfile.read(size))
            validate_state(state)
            self.store.write(state)
            self._send_json(200, {"status": "saved"})
        except (OSError, ValueError, json.JSONDecodeError) as error:
            self._send_json(400, {"error": str(error)})

    def log_message(self, format: str, *args: Any) -> None:
        print(f"{self.address_string()} - {format % args}")


def make_server(
    host: str = "0.0.0.0",
    port: int = 8000,
    data_file: Path | None = None,
    api_token: str | None = None,
) -> ThreadingHTTPServer:
    store = JsonStore(data_file or Path(__file__).parent / "data" / "jobs.json")
    handler = type(
        "ConfiguredMeadowRequestHandler",
        (MeadowRequestHandler,),
        {"store": store, "api_token": api_token if api_token is not None else os.environ.get("MEADOW_API_TOKEN", "")},
    )
    return ThreadingHTTPServer((host, port), handler)


def main() -> None:
    port = int(os.environ.get("PORT", "8001"))
    server = make_server(port=port)
    print(f"Meadow House API listening at http://0.0.0.0:{port}")
    if not server.RequestHandlerClass.api_token:
        print("MEADOW_API_TOKEN is unset; API writes are unauthenticated.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Stopping Meadow House API")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
