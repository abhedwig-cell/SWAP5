#!/usr/bin/env python3
"""Replay the pinned F-MR39 runtime fixture with temporary M7 telemetry output."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import re
import subprocess
import tempfile

import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_m7_standalone_profile_examples import source_modules  # noqa: E402


ROOT = Path(__file__).resolve().parents[2]
DONOR = "87b553094b66980006b69f5ba8b53d70ccd0a8e0"
TEST_PATH = "tests/fmr/test_fmr39_soil_temperature_runtime_composition.f90"
EXPECTED_TEST_BLOB = "00a0d30fd4f1f3ef3888dbc03cf71d41770c4fab"
SOURCE_RUNNER = ROOT / "tests/fci/run_fci45_fmr39_soil_temperature_runtime_canonical_admission.sh"
FLAGS = [
    "-std=f2008",
    "-ffree-line-length-none",
    "-Wall",
    "-Wextra",
    "-fcheck=all",
    "-fbacktrace",
    "-ffpe-trap=invalid,zero,overflow",
]
MARKERS = [
    "M7_RESOURCE_SOIL_TEMP",
    "FMR39_ENABLED_WATER_THERMAL_ATOMIC_COMMIT=PASS",
    "FMR39_INACTIVE_COLUMN_NO_THERMAL_PHYSICAL_STATE=PASS",
    "FMR39_RESTRICTED_SOIL_TEMPERATURE_RUNTIME_TEST PASS",
]


def ordered_sources() -> list[Path]:
    text = SOURCE_RUNNER.read_text(encoding="utf-8")
    match = re.search(r"MODULE_SRC=\(\s*(.*?)\s*\)", text, re.S)
    if not match:
        raise RuntimeError(f"could not find the pinned F-MR39 module list in {SOURCE_RUNNER}")
    names = re.findall(r"(?m)^\s*([^\s]+\.f90)\s*$", match.group(1))
    paths = [ROOT / name for name in names]
    if len(paths) != 32 or any(not path.is_file() for path in paths):
        raise RuntimeError("F-MR39 canonical runtime module source surface changed")
    available: dict[str, list[Path]] = {}
    for path in (ROOT / "src").rglob("*.f90"):
        provided, _ = source_modules(path)
        for name in provided:
            available.setdefault(name, []).append(path)
    included = {path.resolve() for path in paths}
    while True:
        provided_now = {name for path in paths for name in source_modules(path)[0]}
        additions: list[Path] = []
        for path in paths:
            _, used = source_modules(path)
            for name in used - provided_now:
                candidates = [p for p in available.get(name, []) if p.resolve() not in included]
                if len(candidates) > 1:
                    raise RuntimeError(f"ambiguous source providers for {name}: {candidates}")
                if candidates:
                    additions.append(candidates[0])
        if not additions:
            break
        for path in additions:
            if path.resolve() not in included:
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
        index: {providers[name] for name in used if name in providers and providers[name] != index}
        for index, used in enumerate(used_by_source)
    }
    ordered: list[Path] = []
    pending = set(dependencies)
    while pending:
        ready = sorted(index for index in pending if not (dependencies[index] & pending))
        if not ready:
            raise RuntimeError("cyclic F-MR39 Fortran module dependency")
        for index in ready:
            ordered.append(paths[index])
            pending.remove(index)
    return ordered


def instrumented_source() -> str:
    source = subprocess.run(
        ["git", "show", f"{DONOR}:{TEST_PATH}"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    blob = hashlib.sha1(f"blob {len(source.encode('utf-8'))}\0".encode() + source.encode("utf-8")).hexdigest()
    if blob != EXPECTED_TEST_BLOB:
        raise RuntimeError(f"F-MR39 runtime fixture blob mismatch: {blob}")
    source, uses = source.replace(
        "fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK",
        "fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK, &\n       fmr_serialized_batch_diagnostics_t",
        1,
    ), 1
    if uses != 1:
        raise RuntimeError("could not add batch telemetry type to the temporary F-MR39 fixture")
    source, declarations = source.replace(
        "type(fmr_aggregate_diagnostics_t) :: aggregate, ref_aggregate",
        "type(fmr_aggregate_diagnostics_t) :: aggregate, ref_aggregate\n"
        "    type(fmr_serialized_batch_diagnostics_t) :: m7_resource_telemetry",
        1,
    ), 1
    if declarations != 1:
        raise RuntimeError("could not declare temporary M7 batch telemetry")
    call = (
        "call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top_provider, &\n"
        "         t0, tm, 1, results, diagnostics, aggregate, status)\n"
        "    call require(status == FMR_SERIAL_DISPATCH_OK, 'enabled dispatch status')"
    )
    replacement = (
        "call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top_provider, &\n"
        "         t0, tm, 1, results, diagnostics, aggregate, status, m7_resource_telemetry)\n"
        "    call require(status == FMR_SERIAL_DISPATCH_OK, 'enabled dispatch status')\n"
        "    call require(m7_resource_telemetry%soil_temperature_evaluation_calls > 0, &\n"
        "         'active soil-temperature process calls measured')\n"
        "    call require(m7_resource_telemetry%max_common_work_payload_bytes > 0_int64, &\n"
        "         'active common workspace payload measured')\n"
        "    call require(m7_resource_telemetry%max_soil_temperature_optional_payload_bytes > 0_int64, &\n"
        "         'active soil-temperature parameter and workspace payload measured')\n"
        "    write(*,'(a,1x,i0,1x,a,1x,i0,1x,a,1x,i0)') 'M7_RESOURCE_SOIL_TEMP', &\n"
        "         m7_resource_telemetry%soil_temperature_evaluation_calls, 'COMMON_WORK_BYTES', &\n"
        "         m7_resource_telemetry%max_common_work_payload_bytes, 'SOIL_TEMP_OPTIONAL_BYTES', &\n"
        "         m7_resource_telemetry%max_soil_temperature_optional_payload_bytes"
    )
    source, calls = source.replace(call, replacement, 1), 1
    if calls != 1:
        raise RuntimeError("could not instrument the accepted F-MR39 runtime interval")
    return source


def run_profile(temp: Path, compiler: str, source_files: list[Path], test_text: str, opt: str) -> str:
    out = temp / f"o{opt}"
    out.mkdir()
    generated_test = temp / f"test_fmr39_m7_o{opt}.f90"
    generated_test.write_text(test_text, encoding="utf-8")
    objects: list[Path] = []
    for index, source in enumerate(source_files):
        obj = out / f"module_{index:02d}.o"
        cmd = [compiler, *FLAGS, f"-O{opt}", "-J", str(out), "-I", str(out), "-c", str(source), "-o", str(obj)]
        built = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
        if built.returncode:
            raise RuntimeError(f"F-MR39 O{opt} compile failed for {source}\n{built.stdout}{built.stderr}")
        objects.append(obj)
    test_object = out / "m7_instrumented_test.o"
    cmd = [compiler, *FLAGS, f"-O{opt}", "-J", str(out), "-I", str(out), "-c", str(generated_test), "-o", str(test_object)]
    built = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    if built.returncode:
        raise RuntimeError(f"instrumented F-MR39 O{opt} test compile failed\n{built.stdout}{built.stderr}")
    exe = out / "fmr39_m7.exe"
    linked = subprocess.run([compiler, f"-O{opt}", *(str(obj) for obj in objects), str(test_object), "-o", str(exe)],
                            cwd=ROOT, text=True, capture_output=True)
    if linked.returncode:
        raise RuntimeError(f"F-MR39 O{opt} link failed\n{linked.stdout}{linked.stderr}")
    first = subprocess.run([str(exe)], cwd=ROOT, text=True, capture_output=True)
    second = subprocess.run([str(exe)], cwd=ROOT, text=True, capture_output=True)
    transcript = first.stdout + first.stderr
    if first.returncode or second.returncode or transcript != second.stdout + second.stderr:
        raise RuntimeError(f"F-MR39 O{opt} runtime failure/nondeterminism\n{transcript}{second.stdout}{second.stderr}")
    for marker in MARKERS:
        if marker not in transcript:
            raise RuntimeError(f"F-MR39 O{opt} transcript missing {marker}\n{transcript}")
    return transcript


def main() -> int:
    compiler = os.environ.get("FC", "gfortran")
    temp_root = os.environ.get("SWAP5_M7_TEMP_ROOT")
    files = ordered_sources()
    test = instrumented_source()
    with tempfile.TemporaryDirectory(prefix="swap5-m7-soil-temp-", dir=temp_root) as raw_temp:
        temp = Path(raw_temp)
        outputs = [run_profile(temp, compiler, files, test, opt) for opt in ("0", "2")]
        if outputs[0] != outputs[1]:
            raise RuntimeError("F-MR39 M7 O0/O2 telemetry transcript mismatch")
        print(outputs[0], end="")
    print("M7_RESOURCE_SOIL_TEMPERATURE_O0_O2=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
