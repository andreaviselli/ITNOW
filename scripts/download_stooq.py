#!/usr/bin/env python3
"""Download STOOQ CSV files, including the lightweight JS verification flow."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import urllib.parse
import urllib.request
from http.cookiejar import CookieJar
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--timeout", type=float, default=60.0)
    return parser.parse_args()


def is_html_challenge(body: bytes) -> bool:
    text = body[:2000].decode("utf-8", errors="ignore")
    return "__verify" in text and "crypto.subtle.digest" in text


def solve_challenge(body: bytes) -> tuple[str, int]:
    text = body.decode("utf-8", errors="ignore")
    c_match = re.search(r'const c="([^"]+)"', text)
    d_match = re.search(r"d=(\d+)", text)
    if not c_match or not d_match:
        raise RuntimeError("Could not parse STOOQ verification challenge.")

    challenge = c_match.group(1)
    difficulty = int(d_match.group(1))
    prefix = "0" * difficulty
    nonce = 0
    while True:
        digest = hashlib.sha256(f"{challenge}{nonce}".encode("utf-8")).hexdigest()
        if digest.startswith(prefix):
            return challenge, nonce
        nonce += 1


def fetch(opener: urllib.request.OpenerDirector, url: str, timeout: float) -> bytes:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125 Safari/537.36"
            ),
            "Accept": "text/csv,text/plain,*/*",
            "Accept-Language": "en-US,en;q=0.9",
        },
    )
    with opener.open(request, timeout=timeout) as response:
        return response.read()


def post_verify(
    opener: urllib.request.OpenerDirector, source_url: str, challenge: str, nonce: int, timeout: float
) -> None:
    parsed = urllib.parse.urlparse(source_url)
    verify_url = urllib.parse.urlunparse((parsed.scheme, parsed.netloc, "/__verify", "", "", ""))
    body = urllib.parse.urlencode({"c": challenge, "n": str(nonce)}).encode("utf-8")
    request = urllib.request.Request(
        verify_url,
        data=body,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Origin": f"{parsed.scheme}://{parsed.netloc}",
            "Referer": source_url,
            "Accept": "*/*",
            "Accept-Language": "en-US,en;q=0.9",
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125 Safari/537.36"
            ),
        },
        method="POST",
    )
    with opener.open(request, timeout=timeout) as response:
        if response.status >= 400:
            raise RuntimeError(f"STOOQ verification failed with HTTP {response.status}.")


def main() -> int:
    args = parse_args()
    cookie_jar = CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cookie_jar))

    body = fetch(opener, args.url, args.timeout)
    if is_html_challenge(body):
        challenge, nonce = solve_challenge(body)
        post_verify(opener, args.url, challenge, nonce, args.timeout)
        body = fetch(opener, args.url, args.timeout)

    preview = body[:1000].decode("utf-8", errors="ignore").strip().lower()
    if (
        body.lstrip().lower().startswith(b"<!doctype html")
        or b"<html" in body[:500].lower()
        or preview.startswith("access denied")
    ):
        sys.stderr.write("STOOQ returned an access-control response instead of CSV.\n")
        return 1

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
