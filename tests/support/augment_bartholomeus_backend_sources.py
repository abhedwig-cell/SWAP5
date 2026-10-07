#!/usr/bin/env python3
"""Complete backend compile dependencies without changing gate assertions or flags."""
import pathlib, re, sys
root = pathlib.Path(__file__).resolve().parents[2]
modules = {}
paths = sorted((root / "src").rglob("*.f90"))
paths += [root / "tests/fsi/fsi04_real_headcalc_stubs.f90"]
for path in paths:
    for name in re.findall(r"^\s*module\s+(\w+)\s*$", path.read_text(), re.M | re.I):
        modules[name.lower()] = str(path.relative_to(root))
ordered, seen, visiting = [], set(), set()
def visit(source):
    if source in seen:
        return
    if source in visiting:
        raise RuntimeError("module dependency cycle: " + source)
    visiting.add(source)
    for name in re.findall(r"^\s*use\s+(?:,\s*non_intrinsic\s*::\s*)?(\w+)",
                           (root / source).read_text(), re.M | re.I):
        dependency = modules.get(name.lower())
        if dependency and dependency != source:
            visit(dependency)
    visiting.remove(source)
    seen.add(source)
    ordered.append(source)
arguments = sys.argv[1:]
complete = "--all" in arguments
# A runner's explicit module provider (including its legacy test stubs) wins.
if complete:
    for source in (arg for arg in arguments if arg != "--all"):
        for name in re.findall(r"^\s*module\s+(\w+)\s*$", (root / source).read_text(), re.M | re.I):
            modules[name.lower()] = source
for source in (arg for arg in arguments if arg != "--all"):
    if complete or pathlib.Path(source).name == "mod_fmr_serialized_reference_backend.f90":
        visit(source)
    elif source not in seen:
        seen.add(source)
        ordered.append(source)
print("\n".join(ordered))
