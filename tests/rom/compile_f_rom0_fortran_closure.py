#!/usr/bin/env python3
"""Compile a Fortran test and the transitive SWAP5 module closure.

This is research/test build plumbing only. It discovers module dependencies from
checked-out source text so ROM-0 does not maintain a second hand-curated copy of
the rapidly evolving serialized-runtime compile list.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys

MODULE_RE = re.compile(r"^\s*module\s+(?!procedure\b|subroutine\b|function\b)([a-zA-Z_]\w*)", re.I)
USE_RE = re.compile(r"^\s*use(?:\s*,\s*(?:non_)?intrinsic\s*::)?\s*(?:::)?\s*([a-zA-Z_]\w*)", re.I)

def source_modules(path: pathlib.Path) -> set[str]:
    out=set()
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        m=MODULE_RE.match(line)
        if m:
            out.add(m.group(1).lower())
    return out

def used_modules(path: pathlib.Path) -> set[str]:
    out=set()
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        m=USE_RE.match(line)
        if m:
            name=m.group(1).lower()
            if not name.startswith(("iso_", "ieee_")):
                out.add(name)
    return out

def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)

def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--stub", required=True)
    ap.add_argument("--target", required=True)
    ap.add_argument("--external-source", action="append", default=[])
    ap.add_argument("--build", required=True)
    ap.add_argument("--opt", default="2")
    args=ap.parse_args()

    root=pathlib.Path(args.root).resolve()
    stub=(root/args.stub).resolve()
    target=(root/args.target).resolve()
    external_sources=[(root/p).resolve() for p in args.external_source]
    build=pathlib.Path(args.build).resolve()
    build.mkdir(parents=True, exist_ok=True)

    candidates=sorted(list((root/"src").rglob("*.f90")) + list((root/"src").rglob("*.F90")))
    providers: dict[str,pathlib.Path]={}
    file_modules: dict[pathlib.Path,set[str]]={}
    for path in candidates:
        mods=source_modules(path)
        if not mods:
            continue
        file_modules[path]=mods
        for mod in mods:
            if mod in providers and providers[mod] != path:
                raise SystemExit(f"duplicate module provider {mod}: {providers[mod]} vs {path}")
            providers[mod]=path

    stub_mods=source_modules(stub)
    required_files:set[pathlib.Path]=set()
    visiting:set[pathlib.Path]=set()
    visited:set[pathlib.Path]=set()
    unresolved:set[str]=set()

    def add_file(path:pathlib.Path) -> None:
        if path in visited:
            return
        if path in visiting:
            raise SystemExit(f"Fortran module dependency cycle at {path}")
        visiting.add(path)
        for mod in used_modules(path):
            if mod in stub_mods:
                continue
            provider=providers.get(mod)
            if provider is None:
                unresolved.add(mod)
                continue
            add_file(provider)
        visiting.remove(path)
        visited.add(path)
        required_files.add(path)
        order.append(path)

    order:list[pathlib.Path]=[]
    # External procedures such as the legacy HeadCalc entry point are not
    # discoverable from USE statements. Seed those sources explicitly, while
    # still resolving all of their module dependencies transitively.
    for path in external_sources:
        if not path.is_file():
            raise SystemExit(f"missing external source: {path}")
        add_file(path)

    # Resolve dependencies needed by the test itself.
    for mod in used_modules(target):
        if mod in stub_mods:
            continue
        provider=providers.get(mod)
        if provider is None:
            unresolved.add(mod)
        else:
            add_file(provider)

    if unresolved:
        raise SystemExit("unresolved non-intrinsic modules: " + ", ".join(sorted(unresolved)))

    common=[
        "gfortran","-std=f2008","-ffree-line-length-none","-Wall","-Wextra",
        "-fcheck=all","-fbacktrace","-fopenmp","-ffpe-trap=invalid,zero,overflow",
        f"-O{args.opt}","-J",str(build),"-I",str(build)
    ]

    objects:list[pathlib.Path]=[]
    stub_obj=build/"rom0_stubs.o"
    run(common+["-c",str(stub),"-o",str(stub_obj)])
    objects.append(stub_obj)

    for idx,path in enumerate(order):
        obj=build/f"m_{idx:04d}_{path.stem}.o"
        run(common+["-c",str(path),"-o",str(obj)])
        objects.append(obj)

    target_obj=build/"rom0_test.o"
    run(common+["-c",str(target),"-o",str(target_obj)])
    objects.append(target_obj)

    exe=build/"rom0_test"
    run(["gfortran","-fopenmp",f"-O{args.opt}",*[str(x) for x in objects],"-o",str(exe)])

    print(f"F_ROM0_BUILD_SOURCE_COUNT={len(order)}")
    print(f"F_ROM0_BUILD_EXECUTABLE={exe}")
    return 0

if __name__=="__main__":
    raise SystemExit(main())