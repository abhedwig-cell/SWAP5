#!/usr/bin/env python3
"""Replay existing bounded standalone-application profile tests on O0/O2.

The repository's Bash wrappers cannot run in this local Git Bash environment.
This runner reads their ordered module-source lists and invokes the same GNU
Fortran compiler flags directly. It is not a replacement for the official CI
gates and does not qualify profiles beyond the listed tests.
"""
from __future__ import annotations

import os
from pathlib import Path
import re
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
FLAGS = [
    "-std=f2008",
    "-ffree-line-length-none",
    "-Wall",
    "-Wextra",
    "-fopenmp",
    "-fcheck=all",
    "-fbacktrace",
    "-ffpe-trap=invalid,zero,overflow",
]
PROFILES = {
    "prescribed_qbot": {
        "runner": "tests/fapp/run_ppa_wu02_prescribed_qbot_application_admission.sh",
        "test": "tests/fapp/test_ppa_wu02_prescribed_qbot_application_admission.f90",
        "markers": [
            "PPA_WU02_STANDALONE_REFERENCE_RICHARDS_RUNTIME=PASS",
            "PPA_WU02_STANDALONE_HARD_MASS=PASS",
            "PPA-WU02 PRODUCTION APPLICATION BOOTSTRAP GATE PASS",
        ],
    },
    "black_evaporation": {
        "runner": "tests/fapp/run_ppa_wu04a_black_evaporation.sh",
        "test": "tests/fapp/test_ppa_wu04a_black_runtime.f90",
        "markers": [
            "PPA_WU04A_PRODUCTION_APPLICATION_REACHABLE=PASS",
            "PPA_WU04A_HARD_MASS=PASS",
            "PPA-WU04-A BLACK RUNTIME TEST PASS",
        ],
    },
    "boesten_evaporation": {
        "runner": "tests/fapp/run_ppa_wu04b_boesten_evaporation.sh",
        "test": "tests/fapp/test_ppa_wu04b_boesten_runtime.f90",
        "markers": [
            "PPA_WU04B_PRODUCTION_APPLICATION_REACHABLE=PASS",
            "PPA_WU04B_HARD_MASS=PASS",
            "PPA-WU04-B BOESTEN RUNTIME TEST PASS",
        ],
    },
}


def source_modules(path: Path) -> tuple[set[str], set[str]]:
    source = path.read_text(encoding="utf-8").lower()
    provided = set(re.findall(r"(?m)^\s*module\s+(?!procedure\b)([a-z_]\w*)", source))
    used = set(re.findall(r"(?m)^\s*use(?:\s*,\s*non_intrinsic\s*)?(?:\s*::\s*|\s+)([a-z_]\w*)", source))
    return provided, used


def module_sources(runner: Path) -> list[Path]:
    text = runner.read_text(encoding="utf-8")
    match = re.search(r"MODULE_SRC=\(\s*(.*?)\s*\)", text, re.S)
    if not match:
        raise RuntimeError(f"could not locate MODULE_SRC array in {runner}")
    names = re.findall(r"(?m)^\s*([^\s]+\.f90)\s*$", match.group(1))
    if len(names) < 60:
        raise RuntimeError(f"unexpectedly short source list: {len(names)}")
    paths = [ROOT / name for name in names]
    missing = [path for path in paths if not path.is_file()]
    if missing:
        raise RuntimeError(f"missing module source: {missing[0]}")

    # Some legacy runners rely on .mod files already present in the checkout.
    # Complete their source list from the tracked production tree so this replay
    # is independent of ignored compiler artefacts and the current directory.
    available: dict[str, list[Path]] = {}
    for path in (ROOT / "src").rglob("*.f90"):
        provided, _ = source_modules(path)
        for name in provided:
            available.setdefault(name, []).append(path)
    included = {path.resolve() for path in paths}
    while True:
        provided_now = {
            name
            for path in paths
            for name in source_modules(path)[0]
        }
        additions: list[Path] = []
        for path in paths:
            _, used = source_modules(path)
            for name in used - provided_now:
                candidates = [candidate for candidate in available.get(name, []) if candidate.resolve() not in included]
                if len(candidates) > 1:
                    raise RuntimeError(f"ambiguous source providers for omitted module {name}: {candidates}")
                if candidates:
                    additions.append(candidates[0])
        if not additions:
            break
        for path in additions:
            if path.resolve() not in included:
                print(f"M7_PROFILE_ADDED_SOURCE_DEPENDENCY={path.relative_to(ROOT).as_posix()}")
                paths.append(path)
                included.add(path.resolve())

    providers: dict[str, int] = {}
    used_by_source: list[set[str]] = []
    for index, path in enumerate(paths):
        provided, used = source_modules(path)
        for name in provided:
            if name in providers:
                raise RuntimeError(f"duplicate module provider {name}: {paths[providers[name]]} and {path}")
            providers[name] = index
        used_by_source.append(used)

    dependencies = {
        index: {providers[name] for name in used_by_source[index] if name in providers and providers[name] != index}
        for index in range(len(paths))
    }
    ordered: list[Path] = []
    pending = set(dependencies)
    while pending:
        ready = sorted(index for index in pending if not (dependencies[index] & pending))
        if not ready:
            blocked = ", ".join(paths[index].name for index in sorted(pending))
            raise RuntimeError(f"cyclic Fortran module dependency in {runner}: {blocked}")
        for index in ready:
            ordered.append(paths[index])
            pending.remove(index)
    if ordered != paths:
        print(f"M7_PROFILE_MODULE_ORDERED_BY_USE_DEPENDENCIES={runner.name}")
    return ordered


def compile_run(name: str, spec: dict[str, object], opt: str, temp: Path, compiler: str) -> str:
    out = temp / name / f"o{opt}"
    out.mkdir(parents=True)
    sources = module_sources(ROOT / str(spec["runner"]))
    objects: list[Path] = []
    for index, source in enumerate(sources):
        obj = out / f"module_{index:03d}.o"
        command = [
            compiler,
            *FLAGS,
            f"-O{opt}",
            "-J",
            str(out),
            "-I",
            str(out),
            "-c",
            str(source),
            "-o",
            str(obj),
        ]
        built = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
        if built.returncode:
            print(f"{name} O{opt} failed compiling {source}")
            print(built.stdout, end="")
            print(built.stderr, end="")
            raise subprocess.CalledProcessError(built.returncode, command)
        objects.append(obj)

    test_source = ROOT / str(spec["test"])
    test_object = out / "test.o"
    built = subprocess.run(
        [compiler, *FLAGS, f"-O{opt}", "-J", str(out), "-I", str(out), "-c", str(test_source), "-o", str(test_object)],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    if built.returncode:
        print(built.stdout, end="")
        print(built.stderr, end="")
        raise subprocess.CalledProcessError(built.returncode, built.args)

    executable = out / f"{name}.exe"
    linked = subprocess.run(
        [compiler, "-fopenmp", f"-O{opt}", *(str(obj) for obj in objects), str(test_object), "-o", str(executable)],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    if linked.returncode:
        print(linked.stdout, end="")
        print(linked.stderr, end="")
        raise subprocess.CalledProcessError(linked.returncode, linked.args)

    run = subprocess.run([str(executable)], cwd=ROOT, text=True, capture_output=True)
    transcript = run.stdout + run.stderr
    if run.returncode:
        print(transcript, end="")
        raise subprocess.CalledProcessError(run.returncode, run.args)
    for marker in spec["markers"]:
        if marker not in transcript:
            print(transcript, end="")
            raise RuntimeError(f"{name} O{opt} transcript missing {marker}")
    return transcript


def main() -> int:
    compiler = os.environ.get("FC", "gfortran")
    temp_root = os.environ.get("SWAP5_M7_TEMP_ROOT")
    with tempfile.TemporaryDirectory(prefix="swap5-m7-standalone-profiles-", dir=temp_root) as raw_temp:
        temp = Path(raw_temp)
        for name, spec in PROFILES.items():
            outputs = [compile_run(name, spec, opt, temp, compiler) for opt in ("0", "2")]
            if outputs[0] != outputs[1]:
                raise RuntimeError(f"{name} O0/O2 runtime transcript mismatch")
            print(f"M7_STANDALONE_PROFILE_{name.upper()}_O0_O2=PASS")
            print(outputs[0], end="")
    print("M7_STANDALONE_PROFILE_EXAMPLES=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
