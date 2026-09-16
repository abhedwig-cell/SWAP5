#!/usr/bin/env python3
"""Resolve the current Fortran module closure for immutable qualification tests.

This is qualification harness only. It never rewrites production or test semantics.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

MODULE_RE = re.compile(r"^\s*module\s+(?!procedure\b)([a-zA-Z_]\w*)", re.I | re.M)
USE_RE = re.compile(
    r"^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*)?(?:::)?\s*([a-zA-Z_]\w*)",
    re.I | re.M,
)
INTRINSIC = {
    "iso_fortran_env",
    "iso_c_binding",
    "ieee_arithmetic",
    "ieee_exceptions",
    "ieee_features",
    "omp_lib",
    "omp_lib_kinds",
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--test", action="append", default=[])
    ap.add_argument("--support", action="append", default=[])
    ap.add_argument("--force", action="append", default=[])
    ns = ap.parse_args()

    tests = [Path(x) for x in ns.test]
    supports = [Path(x) for x in ns.support]
    forced = [Path(x) for x in ns.force]
    production = sorted(Path("src").rglob("*.f90"), key=lambda p: str(p))
    candidates = production + supports + forced + tests

    for p in candidates:
        if not p.exists():
            raise SystemExit(f"missing Fortran source: {p}")

    text: dict[Path, str] = {}
    module_file: dict[str, Path] = {}
    for p in candidates:
        if p in text:
            continue
        t = p.read_text(encoding="utf-8", errors="ignore")
        text[p] = t
        for mod in MODULE_RE.findall(t):
            key = mod.lower()
            old = module_file.get(key)
            if old is not None and old != p:
                raise SystemExit(f"duplicate module {mod}: {old} and {p}")
            module_file[key] = p

    test_set = set(tests)

    def deps(p: Path) -> set[Path]:
        out: set[Path] = set()
        for mod in USE_RE.findall(text[p]):
            key = mod.lower()
            if key in INTRINSIC:
                continue
            provider = module_file.get(key)
            if provider is None:
                raise SystemExit(f"unresolved module {mod} required by {p}")
            if provider == p:
                continue
            if provider in test_set:
                raise SystemExit(
                    f"cross-test module dependency {mod}: {p} requires test source {provider}"
                )
            out.add(provider)
        return out

    selected: set[Path] = set(forced)
    stack: list[Path] = []
    for test in tests:
        stack.extend(deps(test))
    for p in forced:
        stack.extend(deps(p))

    while stack:
        p = stack.pop()
        if p in selected:
            continue
        if p in test_set:
            continue
        selected.add(p)
        stack.extend(deps(p))

    state: dict[Path, int] = {}
    order: list[Path] = []

    def visit(p: Path) -> None:
        mark = state.get(p, 0)
        if mark == 1:
            raise SystemExit(f"module dependency cycle involving {p}")
        if mark == 2:
            return
        state[p] = 1
        for q in sorted(deps(p), key=lambda x: str(x)):
            if q in selected:
                visit(q)
        state[p] = 2
        order.append(p)

    for p in sorted(selected, key=lambda x: str(x)):
        visit(p)

    Path(ns.out).write_text("\n".join(str(p) for p in order) + "\n", encoding="utf-8")
    print(f"STATUS_A_DEPENDENCY_CLOSURE_FILES={len(order)}")


if __name__ == "__main__":
    main()
