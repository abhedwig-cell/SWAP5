#!/usr/bin/env python3
"""Verify a published SWAP documentation site end to end.

The script intentionally uses only the Python standard library so it can be run
from a clean workstation after GitHub Pages deployment.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from html import unescape
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin, urlsplit
from urllib.request import Request, urlopen

USER_AGENT = "SWAP-docs-publication-verifier/1.0"


@dataclass(frozen=True)
class PageCheck:
    path: str
    required_text: tuple[str, ...]


CHECKS = (
    PageCheck("", ("SWAP technical documentation",)),
    PageCheck("architecture/overview/", ("Target architecture overview", "SWAP kernel")),
    PageCheck("architecture/invariants/", ("Core architecture invariants", "Mass conservation is absolute")),
    PageCheck("development/publication/", ("Online publication", "mkdocs build --strict")),
)


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def normalize_base_url(value: str) -> str:
    split = urlsplit(value)
    if split.scheme not in {"http", "https"} or not split.netloc:
        fail("base URL must be an absolute http(s) URL")
    return value.rstrip("/") + "/"


def fetch_text(url: str, timeout: float) -> str:
    request = Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urlopen(request, timeout=timeout) as response:
            status = getattr(response, "status", 200)
            if status != 200:
                fail(f"{url} returned HTTP {status}")
            content_type = response.headers.get_content_type()
            if content_type not in {"text/html", "application/xhtml+xml"}:
                fail(f"{url} returned unexpected content type {content_type!r}")
            charset = response.headers.get_content_charset() or "utf-8"
            return response.read().decode(charset, errors="replace")
    except HTTPError as exc:
        fail(f"{url} returned HTTP {exc.code}")
    except URLError as exc:
        fail(f"cannot reach {url}: {exc.reason}")
    except TimeoutError:
        fail(f"timeout while fetching {url}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Verify the published SWAP MkDocs site after deployment.")
    parser.add_argument("base_url", help="Published site URL, including repository path if used")
    parser.add_argument("--timeout", type=float, default=15.0, help="HTTP timeout in seconds")
    args = parser.parse_args()
    base_url = normalize_base_url(args.base_url)
    for check in CHECKS:
        url = urljoin(base_url, check.path)
        html = unescape(fetch_text(url, args.timeout))
        missing = [token for token in check.required_text if token not in html]
        if missing:
            fail(f"{url} is reachable but misses expected text: {missing}")
        print(f"OK: {url}")
    print(f"Published documentation verification passed: {base_url}")


if __name__ == "__main__":
    main()
