import json
import tempfile
import threading
import unittest
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from server import make_server


class ApiTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.path = Path(self.temp_dir.name) / "jobs.json"
        self.server = make_server("127.0.0.1", 0, self.path, api_token="test-secret")
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.origin = f"http://127.0.0.1:{self.server.server_port}"

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.temp_dir.cleanup()

    def request(self, method, path="/api/jobs", body=None, token="test-secret"):
        headers = {"Accept": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        data = None
        if body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
        request = Request(f"{self.origin}{path}", data=data, headers=headers, method=method)
        with urlopen(request, timeout=2) as response:
            return response.status, json.loads(response.read())

    def test_health_and_empty_state(self):
        self.assertEqual(self.request("GET", "/health"), (200, {"status": "ok"}))
        self.assertEqual(self.request("GET")[1], {"jobs": [], "nextSequence": 1})

    def test_put_persists_and_get_reads_state(self):
        state = {"jobs": [{"id": "MH-0001", "description": "Tap", "reporter": "Sam", "priority": "normal", "status": "newJob", "createdAt": "2026-10-19T12:00:00Z", "history": []}], "nextSequence": 2}
        self.assertEqual(self.request("PUT", body=state), (200, {"status": "saved"}))
        self.assertEqual(self.request("GET")[1], state)
        self.assertTrue(self.path.exists())

    def test_requires_token_when_configured(self):
        with self.assertRaises(HTTPError) as error:
            self.request("GET", token="wrong")
        self.assertEqual(error.exception.code, 401)

    def test_rejects_invalid_state(self):
        with self.assertRaises(HTTPError) as error:
            self.request("PUT", body={"jobs": "not-a-list", "nextSequence": 1})
        self.assertEqual(error.exception.code, 400)


if __name__ == "__main__":
    unittest.main()
