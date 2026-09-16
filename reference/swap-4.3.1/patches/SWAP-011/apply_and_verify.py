#!/usr/bin/env python3
"""Byte-safe applicator/verifier for the ordered B1.10 -> B1.11 SWAP-011 admission transform."""
from __future__ import annotations

import argparse
import hashlib
import re
from pathlib import Path

PATCH_SHA256 = "1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238"
TARGETS = {
    "MOD_MvG_functions.f90": (
        "4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1",
        "6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104",
    ),
    "WC_K_models_04_11.f90": (
        "7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e",
        "d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126",
    ),
    "MOD_RIA.f90": (
        "a8695bbcb45ae4967686ae4dfbb7e365e91658a190165e86487ee9e5f1ffa9b3",
        "673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a",
    ),
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _source_newline(data: bytes) -> bytes:
    crlf = data.count(b"\r\n")
    lf = data.count(b"\n")
    if crlf and crlf == lf:
        return b"\r\n"
    if lf and not crlf:
        return b"\n"
    raise ValueError("target source has mixed/unsupported line endings")


def _payload(raw: bytes, newline: bytes) -> bytes:
    if raw.endswith(b"\r\n"):
        raw = raw[:-2]
    elif raw.endswith(b"\n"):
        raw = raw[:-1]
    return raw + newline


def parse_patch(patch: bytes) -> dict[str, list[list[bytes]]]:
    lines = patch.splitlines(keepends=True)
    result: dict[str, list[list[bytes]]] = {}
    current: str | None = None
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith(b"diff --git "):
            m = re.match(br"diff --git a/(.+) b/(.+)\r?\n?$", line)
            if not m or m.group(1) != m.group(2):
                raise ValueError("unsupported diff header")
            current = m.group(1).decode("ascii").split("/")[-1]
            result.setdefault(current, [])
            i += 1
            continue
        if line.startswith(b"@@ "):
            if current is None:
                raise ValueError("hunk before file header")
            hunk: list[bytes] = []
            i += 1
            while i < len(lines) and not lines[i].startswith((b"@@ ", b"diff --git ")):
                if lines[i].startswith((b" ", b"+", b"-")):
                    hunk.append(lines[i])
                elif lines[i].startswith(b"\\ No newline at end of file"):
                    hunk.append(lines[i])
                elif lines[i].startswith((b"index ", b"--- ", b"+++ ")):
                    pass
                else:
                    raise ValueError(f"unsupported patch line: {lines[i][:80]!r}")
                i += 1
            result[current].append(hunk)
            continue
        i += 1
    return result


def apply_file(data: bytes, hunks: list[list[bytes]]) -> bytes:
    newline = _source_newline(data)
    out = data
    for n, hunk in enumerate(hunks, 1):
        if any(x.startswith(b"\\ No newline") for x in hunk):
            raise ValueError("no-newline hunk marker unsupported by qualified contract")
        old = bytearray()
        new = bytearray()
        for line in hunk:
            tag, raw = line[:1], line[1:]
            p = _payload(raw, newline)
            if tag in (b" ", b"-"):
                old.extend(p)
            if tag in (b" ", b"+"):
                new.extend(p)
        old_b, new_b = bytes(old), bytes(new)
        count = out.count(old_b)
        if count != 1:
            raise ValueError(f"hunk {n}: expected unique preimage block, found {count}")
        out = out.replace(old_b, new_b, 1)
    return out


def apply_tree(source_root: Path, patch_path: Path | None = None) -> dict:
    if patch_path is None:
        patch_path = Path(__file__).with_name("fix.patch")
    patch = patch_path.read_bytes()
    if sha(patch) != PATCH_SHA256:
        raise ValueError(f"SWAP-011 stored patch SHA mismatch: {sha(patch)}")
    parsed = parse_patch(patch)
    if set(parsed) != set(TARGETS):
        raise ValueError(f"unexpected patch target set: {sorted(parsed)}")
    results = {}
    for name, (pre, post) in TARGETS.items():
        path = source_root / name
        raw = path.read_bytes()
        if sha(raw) != pre:
            raise ValueError(f"{name}: ordered B1.10 preimage SHA mismatch: {sha(raw)}")
        corrected = apply_file(raw, parsed[name])
        if sha(corrected) != post:
            raise ValueError(f"{name}: B1.11 postimage SHA mismatch: {sha(corrected)}")
        path.write_bytes(corrected)
        results[name] = {"preimage_sha256": pre, "postimage_sha256": post, "status": "PASS"}
    return results


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    parser.add_argument("--patch", type=Path, default=None)
    args = parser.parse_args()
    try:
        results = apply_tree(args.source_root, args.patch)
    except Exception as exc:
        print(f"SWAP-011 B1.10 admission verification FAILED: {exc}")
        return 2
    print(f"SWAP-011 B1.10 admission PASS patch={PATCH_SHA256}")
    for name, result in results.items():
        print(f"  {name}: {result['preimage_sha256']} -> {result['postimage_sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
