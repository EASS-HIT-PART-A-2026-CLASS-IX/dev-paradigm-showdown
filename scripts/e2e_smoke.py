#!/usr/bin/env python3

import json
import os
import re
import subprocess
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def run(cmd: list[str]) -> str:
    result = subprocess.run(cmd, check=True, text=True, capture_output=True)
    return result.stdout.strip()


def fetch(url: str, method: str = "GET") -> tuple[int, str]:
    request = Request(
        url,
        method=method,
        headers={
            "Accept": "application/json, text/html;q=0.9, */*;q=0.8",
            "User-Agent": "Mozilla/5.0 (compatible; DevParadigmShowdownSmoke/1.0)",
        },
    )
    with urlopen(request, timeout=10) as response:
        status = response.getcode()
        body = response.read().decode("utf-8")
        return status, body


def resolve_base_url() -> str:
    configured = os.getenv("E2E_BASE_URL")
    if configured:
        return configured.rstrip("/")

    port_output = run(["docker", "compose", "port", "frontend", "80"])
    host_port = port_output.rsplit(":", 1)[-1]
    return f"http://127.0.0.1:{host_port}"


def resolve_api_base_url(frontend_base_url: str) -> str:
    override = os.getenv("E2E_API_BASE_URL")
    if override:
        return override.rstrip("/")

    try:
        _, config_js = fetch(f"{frontend_base_url}/config.js")
    except (HTTPError, URLError):
        return frontend_base_url

    match = re.search(r"apiBaseUrl:\s*['\"]([^'\"]*)['\"]", config_js)
    if not match or not match.group(1):
        return frontend_base_url

    return match.group(1).rstrip("/")


def main() -> int:
    frontend_base_url = resolve_base_url()
    api_base_url = resolve_api_base_url(frontend_base_url)

    print(f"Frontend URL: {frontend_base_url}")
    print(f"API base URL: {api_base_url}")

    try:
        status, html = fetch(f"{frontend_base_url}/")
        assert status == 200, f"unexpected frontend status {status}"
        assert "Dev Paradigm Showdown" in html, "frontend title not found"
        assert 'id="paradigm-list"' in html, "frontend list container not found"
        print("UI check: ok")

        status, body = fetch(f"{api_base_url}/api/paradigms")
        assert status == 200, f"unexpected API list status {status}"
        paradigms = json.loads(body)
        assert len(paradigms) >= 3, f"expected at least 3 paradigms, got {len(paradigms)}"
        print(f"API list check: ok ({len(paradigms)} paradigms)")

        target = paradigms[0]
        before_votes = target["votes"]
        target_id = target["id"]

        status, body = fetch(f"{api_base_url}/api/paradigms/{target_id}/vote", method="POST")
        assert status == 200, f"unexpected vote status {status}"
        voted = json.loads(body)
        expected_votes = before_votes + 1
        assert voted["votes"] == expected_votes, (
            f"vote response mismatch for id {target_id}: expected {expected_votes}, got {voted['votes']}"
        )
        print(f"Vote mutation check: ok ({target['name']} {before_votes} -> {voted['votes']})")

        time.sleep(0.5)
        status, body = fetch(f"{api_base_url}/api/paradigms")
        assert status == 200, f"unexpected API re-fetch status {status}"
        after = json.loads(body)
        updated = next(item for item in after if item["id"] == target_id)
        assert updated["votes"] == expected_votes, (
            "follow-up fetch mismatch for "
            f"id {target_id}: expected {expected_votes}, got {updated['votes']}. "
            "This usually means the deployed backend is not using shared persistent storage."
        )
        print("End-to-end re-fetch check: ok")

        return 0
    except (AssertionError, HTTPError, URLError, subprocess.CalledProcessError) as exc:
        print(f"Smoke test failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
