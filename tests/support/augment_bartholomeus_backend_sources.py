#!/usr/bin/env python3
"""Complete backend compile dependencies without changing gate assertions or flags."""
import pathlib, re, sys

# Strict opt-in analysis API. The incumbent CLI below retains its provider
# override semantics; local modular tests never silently override providers.
MODULE_RE = re.compile(r"^\s*module\s+(?!procedure\b|function\b|subroutine\b)([a-z]\w*)", re.I | re.M)
USE_RE = re.compile(r"^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?([a-z]\w*)", re.I | re.M)
INTRINSICS = {"iso_fortran_env", "iso_c_binding", "ieee_arithmetic", "ieee_exceptions", "ieee_features", "omp_lib"}

def strict_closure(root, targets, extra_sources=()):
    """Ordered file-level module closure, not evidence-inheritance authority.

    Include/preprocessor/submodule inputs require a separate explicit build
    authority. Reject them rather than guessing. External procedures still
    require declared sources and an actual successful link.
    """
    root = pathlib.Path(root).resolve()
    candidates = sorted(set((root / "src").rglob("*.f90")) | set((root / "src").rglob("*.F90")))
    candidates += [root / p for p in extra_sources]
    providers, imports = {}, {}
    for path in candidates:
        source = path.read_text()
        imports[path] = set(x.lower() for x in USE_RE.findall(source)) - INTRINSICS
        for name in MODULE_RE.findall(source):
            name = name.lower()
            if name in providers and providers[name] != path:
                raise ValueError(f"duplicate module provider {name}")
            providers[name] = path
    order, seen, active, direct = [], set(), set(), {}
    def visit(path):
        if path in seen: return
        if path in active: raise ValueError(f"module cycle at {path}")
        source = path.read_text()
        if re.search(r"^\s*(?:#|include\b|submodule\b)", source, re.I | re.M):
            raise ValueError(f"explicit include/preprocessor/submodule authority required: {path}")
        active.add(path)
        children = set()
        for name in imports.get(path, set(x.lower() for x in USE_RE.findall(source)) - INTRINSICS):
            if name not in providers: raise ValueError(f"unresolved module {name} in {path}")
            if providers[name] != path: children.add(providers[name])
        direct[str(path.relative_to(root))] = sorted(str(x.relative_to(root)) for x in children)
        for child in sorted(children): visit(child)
        active.remove(path); seen.add(path); order.append(path)
    for target in targets: visit(root / target)
    return order, direct

def main():
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
        if complete or pathlib.Path(source).name in {
            "mod_fmr_serialized_reference_backend.f90",
            "mod_fmr_production_application_bootstrap.f90",
        }:
            visit(source)
        elif source not in seen:
            seen.add(source)
            ordered.append(source)
    print("\n".join(ordered))


if __name__ == "__main__":
    main()
