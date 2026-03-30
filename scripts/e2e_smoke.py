#!/usr/bin/env python3

import json
import subprocess
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def run(cmd: list[str]) -> str:
    result = subprocess.run(cmd, check=True, text=True, capture_output=True)
    return result.stdout.strip()


def fetch(url: str, method: str = "GET") -> tuple[int, str]:
    request = Request(url, method=method)
    with urlopen(request, timeout=10) as response:
        status = response.getcode()
        body = response.read().decode("utf-8")
        return status, body


def main() -> int:
    port_output = run(["docker", "compose", "port", "frontend", "80"])
    host_port = port_output.rsplit(":", 1)[-1]
    base_url = f"http://127.0.0.1:{host_port}"

    print(f"Frontend URL: {base_url}")

    try:
        status, html = fetch(f"{base_url}/")
        assert status == 200
        assert "Dev Paradigm Showdown" in html
        assert 'id="paradigm-list"' in html
        print("UI check: ok")

        status, body = fetch(f"{base_url}/api/paradigms")
        assert status == 200
        paradigms = json.loads(body)
        assert len(paradigms) >= 3
        print(f"API list check: ok ({len(paradigms)} paradigms)")

        target = paradigms[0]
        before_votes = target["votes"]
        target_id = target["id"]

        status, body = fetch(f"{base_url}/api/paradigms/{target_id}/vote", method="POST")
        assert status == 200
        voted = json.loads(body)
        assert voted["votes"] == before_votes + 1
        print(f"Vote mutation check: ok ({target['name']} {before_votes} -> {voted['votes']})")

        time.sleep(0.5)
        status, body = fetch(f"{base_url}/api/paradigms")
        assert status == 200
        after = json.loads(body)
        updated = next(item for item in after if item["id"] == target_id)
        assert updated["votes"] == before_votes + 1
        print("End-to-end re-fetch check: ok")

        return 0
    except (AssertionError, HTTPError, URLError, subprocess.CalledProcessError) as exc:
        print(f"Smoke test failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
