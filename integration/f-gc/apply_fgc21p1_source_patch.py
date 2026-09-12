#!/usr/bin/env python3
"""Fail-closed exact-context applier for the preregistered F-GC21P1 staged source patch.

The original staged artifact intentionally records hunks without source line numbers.
This helper applies those hunks only when every old-context block occurs exactly once
in the pinned current-canonical source. It never guesses offsets or fuzz-matches.
"""
from pathlib import Path
import subprocess
import sys

PATCH = Path("integration/f-gc/F-GC21P1_SOURCE.patch")
EXPECTED = {
    "src/transaction/mod_transaction_reference.f90",
    "src/runtime/mod_canonical_contracts.f90",
    "src/runtime/mod_canonical_interval_runtime.f90",
    "src/kernel/mod_kernel_transactions.f90",
    "src/runtime/mod_fmr_serialized_reference_backend.f90",
}


def fail(message: str) -> None:
    print(f"FGC21P1_APPLY_FAIL {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_patch(text: str):
    lines = text.splitlines(keepends=True)
    i = 0
    files = []
    while i < len(lines):
        line = lines[i]
        if not line.startswith("diff --git a/"):
            i += 1
            continue
        parts = line.rstrip("\n").split()
        if len(parts) != 4 or not parts[2].startswith("a/") or not parts[3].startswith("b/"):
            fail(f"bad diff header: {line.rstrip()}")
        a_path = parts[2][2:]
        b_path = parts[3][2:]
        if a_path != b_path:
            fail(f"rename not allowed: {a_path} -> {b_path}")
        path = b_path
        i += 1
        if i >= len(lines) or not lines[i].startswith("--- a/"):
            fail(f"missing --- header for {path}")
        i += 1
        if i >= len(lines) or not lines[i].startswith("+++ b/"):
            fail(f"missing +++ header for {path}")
        i += 1
        hunks = []
        while i < len(lines) and not lines[i].startswith("diff --git a/"):
            if not lines[i].startswith("@@"):
                if lines[i].strip():
                    fail(f"unexpected line outside hunk for {path}: {lines[i].rstrip()}")
                i += 1
                continue
            i += 1
            old = []
            new = []
            saw = False
            while i < len(lines) and not lines[i].startswith("@@") and not lines[i].startswith("diff --git a/"):
                h = lines[i]
                if h.startswith(" "):
                    old.append(h[1:])
                    new.append(h[1:])
                    saw = True
                elif h.startswith("-"):
                    old.append(h[1:])
                    saw = True
                elif h.startswith("+"):
                    new.append(h[1:])
                    saw = True
                elif h.startswith("\\ No newline at end of file"):
                    pass
                else:
                    fail(f"malformed hunk line for {path}: {h.rstrip()}")
                i += 1
            if not saw:
                fail(f"empty hunk for {path}")
            hunks.append(("".join(old), "".join(new)))
        files.append((path, hunks))
    return files


def main() -> None:
    if not PATCH.is_file():
        fail("staged patch missing")
    parsed = parse_patch(PATCH.read_text())
    paths = {path for path, _ in parsed}
    if paths != EXPECTED or len(parsed) != len(EXPECTED):
        fail(f"unexpected source set: {sorted(paths)}")

    for path, hunks in parsed:
        target = Path(path)
        if not target.is_file():
            fail(f"target missing: {path}")
        text = target.read_text()
        for index, (old, new) in enumerate(hunks, start=1):
            count = text.count(old)
            if count != 1:
                fail(f"{path} hunk {index} old-context count={count}, expected=1")
            text = text.replace(old, new, 1)
        target.write_text(text)

    changed = subprocess.check_output(
        ["git", "diff", "--name-only", "--", "src"], text=True
    ).splitlines()
    if set(changed) != EXPECTED or len(changed) != len(EXPECTED):
        fail(f"post-apply source delta mismatch: {changed}")

    subprocess.run(["git", "diff", "--check"], check=True)
    print("FGC21P1_EXACT_CONTEXT_SOURCE_APPLY=PASS")
    for path in sorted(changed):
        print(f"FGC21P1_APPLIED_SOURCE {path}")


if __name__ == "__main__":
    main()
