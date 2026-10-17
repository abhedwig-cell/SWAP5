#!/usr/bin/env python3
"""Resolve a deterministic, fail-closed Fortran module dependency closure.

Usage: python resolve_fortran_module_closure.py source1.f90 source2.f90 ...
Outputs ordered source paths, one per line. Errors go to stderr.
"""
import pathlib
import re
import sys

DEFINES = re.compile(
    r"^\s*module\s+(?!procedure\b|subroutine\b|function\b|pure\b|impure\b)([a-z][a-z0-9_]*)\b",
    re.IGNORECASE | re.MULTILINE,
)
USES = re.compile(
    r"^\s*use\s*(?:,\s*(?:non_intrinsic|intrinsic)\s*::\s*|::\s*)?([a-z][a-z0-9_]*)\b",
    re.IGNORECASE | re.MULTILINE,
)
INTRINSIC = {"iso_fortran_env", "ieee_arithmetic", "iso_c_binding", "omp_lib", "ieee_exceptions", "ieee_features"}


def main():
    root = pathlib.Path(__file__).resolve().parents[2]
    if not sys.argv[1:]:
        raise ValueError("no source roots supplied")
    initial = [pathlib.Path(p) for p in sys.argv[1:]]
    if len(set(initial)) != len(initial):
        raise ValueError("duplicate selected source")
    for path in initial:
        if not (root / path).is_file():
            raise ValueError(f"missing selected source: {path}")

    source_files = set(initial)
    for folder in ("src", "reference"):
        location = root / folder
        if location.is_dir():
            source_files.update(p.relative_to(root) for p in location.rglob("*.f90"))

    text_cache = {}
    definitions = {}
    for path in sorted(source_files):
        text = (root / path).read_text(encoding="utf-8", errors="replace")
        text_cache[path] = text
        for name in DEFINES.findall(text):
            definitions.setdefault(name.lower(), []).append(path)

    # Explicitly selected fixture and source owners take precedence.
    chosen = {}
    for path in initial:
        for name in DEFINES.findall(text_cache[path]):
            key = name.lower()
            if key in chosen and chosen[key] != path:
                raise ValueError(f"duplicate selected provider for {key}: {chosen[key]} / {path}")
            chosen[key] = path

    ambiguous = {}
    for name, choices in definitions.items():
        if name in chosen:
            continue
        if len(choices) == 1:
            chosen[name] = choices[0]
        else:
            # Unrelated duplicate historical modules may exist in the tree.
            # Fail only when the selected dependency graph actually needs one.
            ambiguous[name] = choices

    seen = set()
    active = set()
    ordered = []

    def visit(path):
        if path in seen:
            return
        if path in active:
            raise ValueError(f"Fortran module dependency cycle through {path}")
        active.add(path)
        for name in USES.findall(text_cache[path]):
            key = name.lower()
            if key in INTRINSIC:
                continue
            provider = chosen.get(key)
            if provider is None:
                if key in ambiguous:
                    raise ValueError(f"{path} requires ambiguous Fortran module {key}: {ambiguous[key]}")
                raise ValueError(f"{path} requires missing Fortran module {key}")
            visit(provider)
        active.remove(path)
        seen.add(path)
        ordered.append(path)

    for path in initial:
        visit(path)
    print("\n".join(str(p) for p in ordered), end="\n", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as exc:
        print(f"FORTRAN_MODULE_CLOSURE_FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
