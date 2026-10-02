#!/usr/bin/env python3
"""Emit the current-canonical Fortran module closure needed by PUB-ME G1 D2 replication.

This is build tooling only. It does not rewrite sources. Two test-owned module
providers are intentional:
- tests/fsi/fsi04_real_headcalc_stubs.f90 supplies the established legacy
  runtime globals used by the real HeadCalc qualification route.
- pub_me_d2_directional_service_stub.f90 replaces one non-requested optional
  directional service. The stub hard-fails if that route is ever requested.
"""
from __future__ import annotations
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
TEST = ROOT / "tests/publication/test_pub_me_g1_d2_reverse_flow_replication.f90"
HEADCALC = ROOT / "src/legacy/b1_10_port/headcalc.f90"
LEGACY_STUBS = ROOT / "tests/fsi/fsi04_real_headcalc_stubs.f90"
DIRECTION_STUB = ROOT / "tests/publication/pub_me_d2_directional_service_stub.f90"
REAL_DIRECTION = ROOT / "src/adapter/mod_reference_richards_accepted_step_directional_service.f90"

module_re = re.compile(r"^\s*module\s+(?!procedure\b|subroutine\b|function\b)([a-zA-Z]\w*)", re.I)
use_re = re.compile(r"^\s*use(?:\s*,\s*[^:]*)?\s*(?:::\s*)?([a-zA-Z]\w*)", re.I)
intrinsic = {"iso_fortran_env", "ieee_arithmetic", "omp_lib", "iso_c_binding"}

def text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8", errors="strict")

def defined(path: pathlib.Path) -> set[str]:
    out=set()
    for line in text(path).splitlines():
        m=module_re.match(line)
        if m and not line.lstrip().lower().startswith("end module"):
            out.add(m.group(1).lower())
    return out

def used(path: pathlib.Path) -> set[str]:
    out=set()
    for line in text(path).splitlines():
        m=use_re.match(line)
        if m:
            name=m.group(1).lower()
            if name not in intrinsic:
                out.add(name)
    return out

src_files=sorted((ROOT/"src").rglob("*.f90"))
module_map: dict[str,pathlib.Path] = {}
duplicates: dict[str,list[pathlib.Path]] = {}
for p in src_files:
    for m in defined(p):
        if m in module_map and module_map[m] != p:
            duplicates.setdefault(m,[module_map[m]]).append(p)
        else:
            module_map[m]=p

# Test-owned providers intentionally override production/legacy providers only
# for this qualification build.
for override in (LEGACY_STUBS, DIRECTION_STUB):
    for m in defined(override):
        module_map[m]=override

# Duplicate production module names are unsafe unless an explicit test override
# resolved them.
unresolved_dups={m:ps for m,ps in duplicates.items() if module_map.get(m) not in (LEGACY_STUBS,DIRECTION_STUB)}
if unresolved_dups:
    for m,ps in sorted(unresolved_dups.items()):
        print("PUB_ME_G1_D2_BUILD_DUPLICATE_MODULE",m,*(str(p.relative_to(ROOT)) for p in ps),file=sys.stderr)
    raise SystemExit(31)

file_deps: dict[pathlib.Path,set[pathlib.Path]] = {}
visiting:set[pathlib.Path]=set()
visited:set[pathlib.Path]=set()
order:list[pathlib.Path]=[]

def visit_file(path:pathlib.Path) -> None:
    if path in visited:
        return
    if path in visiting:
        raise RuntimeError(f"Fortran module dependency cycle at {path.relative_to(ROOT)}")
    visiting.add(path)
    deps=set()
    for mod in used(path):
        provider=module_map.get(mod)
        if provider is None:
            raise RuntimeError(f"unresolved module {mod} used by {path.relative_to(ROOT)}")
        if provider != path:
            deps.add(provider)
    file_deps[path]=deps
    for dep in sorted(deps,key=lambda p:str(p)):
        visit_file(dep)
    visiting.remove(path)
    visited.add(path)
    order.append(path)

# Root module dependencies come from the D2 program plus the real legacy
# HeadCalc external routine. HeadCalc itself is linked separately after all
# modules are compiled.
for mod in sorted(used(TEST) | used(HEADCALC)):
    provider=module_map.get(mod)
    if provider is None:
        raise RuntimeError(f"unresolved root module {mod}")
    visit_file(provider)

if REAL_DIRECTION in visited:
    raise RuntimeError("real optional directional service entered G1 D2 replication closure")
if DIRECTION_STUB not in visited:
    raise RuntimeError("G1 D2 directional stub not selected by backend closure")
if LEGACY_STUBS not in visited:
    raise RuntimeError("real HeadCalc legacy stubs not selected")

for p in order:
    print(p.relative_to(ROOT))
