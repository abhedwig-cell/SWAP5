#!/usr/bin/env python3
"""Measure a bounded many-column serialized Richards worker workload on Windows."""
from __future__ import annotations

import ctypes
from ctypes import wintypes
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_m7_standalone_profile_examples import module_sources  # noqa: E402


NCOLUMN = 256
NNODE = 32
FLAGS = [
    "-std=f2008", "-ffree-line-length-none", "-Wall", "-Wextra", "-fopenmp",
    "-fcheck=all", "-fbacktrace", "-ffpe-trap=invalid,zero,overflow", "-O2",
]
MARKERS = [
    f"M7_LARGE_BATCH_COLUMNS {NCOLUMN}",
    f"M7_LARGE_BATCH_ACTIVE_NODES {NNODE}",
    "M7_LARGE_BATCH_ALL_COLUMNS_COMMITTED_HARD_MASS=PASS",
    "M7_SERIALIZED_WORKER_SCRATCH_REUSE_CROSS_COLUMN=PASS",
]


class ProcessMemoryCountersEx(ctypes.Structure):
    _fields_ = [
        ("cb", wintypes.DWORD),
        ("page_fault_count", wintypes.DWORD),
        ("peak_working_set_size", ctypes.c_size_t),
        ("working_set_size", ctypes.c_size_t),
        ("quota_peak_paged_pool_usage", ctypes.c_size_t),
        ("quota_paged_pool_usage", ctypes.c_size_t),
        ("quota_peak_non_paged_pool_usage", ctypes.c_size_t),
        ("quota_non_paged_pool_usage", ctypes.c_size_t),
        ("pagefile_usage", ctypes.c_size_t),
        ("peak_pagefile_usage", ctypes.c_size_t),
        ("private_usage", ctypes.c_size_t),
    ]


def query_peak_memory(pid: int) -> tuple[int, int]:
    if os.name != "nt":
        raise RuntimeError("this probe currently requires Windows process memory counters")
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    psapi = ctypes.WinDLL("psapi", use_last_error=True)
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    psapi.GetProcessMemoryInfo.argtypes = [
        wintypes.HANDLE, ctypes.POINTER(ProcessMemoryCountersEx), wintypes.DWORD,
    ]
    psapi.GetProcessMemoryInfo.restype = wintypes.BOOL
    handle = kernel.OpenProcess(0x0400 | 0x0010, False, pid)  # QUERY_INFORMATION | VM_READ
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        counters = ProcessMemoryCountersEx()
        counters.cb = ctypes.sizeof(counters)
        if not psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb):
            raise ctypes.WinError(ctypes.get_last_error())
        return int(counters.peak_working_set_size), int(counters.private_usage)
    finally:
        kernel.CloseHandle(handle)


def measured_run(executable: Path, output_path: Path) -> tuple[str, int, int]:
    peak_working_set = 0
    peak_private = 0
    with output_path.open("w", encoding="utf-8") as output_file:
        process = subprocess.Popen(
            [str(executable)], cwd=ROOT, stdout=output_file, stderr=subprocess.STDOUT,
            text=True, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        while process.poll() is None:
            working_set, private = query_peak_memory(process.pid)
            peak_working_set = max(peak_working_set, working_set)
            peak_private = max(peak_private, private)
            time.sleep(0.002)
        process.wait()
    output = output_path.read_text(encoding="utf-8")
    if process.returncode:
        raise RuntimeError(f"large-batch runtime failed ({process.returncode})\n{output}")
    return output, peak_working_set, peak_private


def generated_sources(temp: Path) -> tuple[list[Path], Path]:
    runner = ROOT / "tests/fapp/run_ppa_wu02_prescribed_qbot_application_admission.sh"
    sources = module_sources(runner)
    stub = sources[0]
    text = stub.read_text(encoding="utf-8")
    text, count = re.subn(r"integer, parameter :: numnod = 4\b", f"integer, parameter :: numnod = {NNODE}", text, count=1)
    if count != 1:
        raise RuntimeError("could not scale the generated legacy test stub grid")
    text = text.replace(
        f"integer, parameter :: numnod = {NNODE}\n",
        f"integer, parameter :: numnod = {NNODE}\n  integer :: grid_index\n",
        1,
    )
    text, count = re.subn(
        r"real\(8\), parameter :: z\(numnod\) = \[-0\.25d0, -0\.75d0, -1\.50d0, -2\.50d0\]",
        "real(8), parameter :: z(numnod) = [(-0.05d0*real(grid_index,8), grid_index=1,numnod)]",
        text, count=1,
    )
    if count != 1:
        raise RuntimeError("could not scale generated soil-node elevations")
    text, count = re.subn(
        r"real\(8\), parameter :: dz\(numnod\) = \[0\.50d0, 0\.50d0, 1\.00d0, 1\.00d0\]",
        "real(8), parameter :: dz(numnod) = 0.05d0",
        text, count=1,
    )
    if count != 1:
        raise RuntimeError("could not scale generated soil-node spacing")
    text, count = re.subn(
        r"real\(8\), parameter :: disnod\(numnod\+1\) = 1\.0d0",
        "real(8), parameter :: disnod(numnod+1) = 0.05d0",
        text, count=1,
    )
    if count != 1:
        raise RuntimeError("could not scale generated interface spacing")
    generated_stub = temp / "fsi04_real_headcalc_stubs_large_batch.f90"
    generated_stub.write_text(text, encoding="utf-8")
    sources[0] = generated_stub

    test_path = ROOT / "tests/fmr/test_m7_serialized_worker_scratch_reuse.f90"
    test = test_path.read_text(encoding="utf-8")
    test, count = re.subn(r"integer, parameter :: NCOLUMN = 3\b", f"integer, parameter :: NCOLUMN = {NCOLUMN}", test, count=1)
    if count != 1:
        raise RuntimeError("could not scale the generated worker count")
    test, count = re.subn(
        r"call require\(results\(i\)%completed \.and\. results\(i\)%committed, 'A-B-A column accepted and committed'\)",
        "call require(results(i)%completed .and. results(i)%committed, 'large-batch column accepted and committed')",
        test, count=1,
    )
    if count != 1:
        raise RuntimeError("could not label generated large-batch acceptance")
    final = "  print '(a)', 'M7_SERIALIZED_WORKER_SCRATCH_REUSE_CROSS_COLUMN=PASS'"
    replacement = (
        "  call require(all([(results(i)%completed .and. results(i)%committed .and. results(i)%mass%complete .and. &\n"
        "       abs(results(i)%mass%residual) <= HARD_MASS_GATE .and. states(i)%current_revision() == 1_int64, &\n"
        "       i=1,NCOLUMN)]), 'all large-batch columns committed under hard mass gate')\n"
        "  print '(a,1x,i0)', 'M7_LARGE_BATCH_COLUMNS', NCOLUMN\n"
        "  print '(a,1x,i0)', 'M7_LARGE_BATCH_ACTIVE_NODES', numnod\n"
        "  print '(a,1x,i0)', 'M7_LARGE_BATCH_COMMON_INPUT_ARRAY_BYTES', NCOLUMN * &\n"
        "       (common_parameter_payload_bytes(parameters(1)) + common_forcing_payload_bytes(forcings(1)) + &\n"
        "       common_state_payload_bytes(initial_state))\n"
        "  print '(a)', 'M7_LARGE_BATCH_ALL_COLUMNS_COMMITTED_HARD_MASS=PASS'\n" + final
    )
    test, count = test.replace(final, replacement, 1), 1
    if count != 1:
        raise RuntimeError("could not add large-batch measurement markers")
    generated_test = temp / "test_m7_large_batch_memory.f90"
    generated_test.write_text(test, encoding="utf-8")
    return sources, generated_test


def main() -> int:
    compiler = os.environ.get("FC", "gfortran")
    temp_root = os.environ.get("SWAP5_M7_TEMP_ROOT")
    with tempfile.TemporaryDirectory(prefix="swap5-m7-large-batch-", dir=temp_root) as raw_temp:
        temp = Path(raw_temp)
        sources, test = generated_sources(temp)
        out = temp / "o2"
        out.mkdir()
        objects: list[Path] = []
        for index, source in enumerate(sources):
            obj = out / f"module_{index:03d}.o"
            built = subprocess.run(
                [compiler, *FLAGS, "-J", str(out), "-I", str(out), "-c", str(source), "-o", str(obj)],
                cwd=ROOT, text=True, capture_output=True,
            )
            if built.returncode:
                raise RuntimeError(f"large-batch O2 compile failed for {source}\n{built.stdout}{built.stderr}")
            objects.append(obj)
        test_object = out / "test.o"
        built = subprocess.run(
            [compiler, *FLAGS, "-J", str(out), "-I", str(out), "-c", str(test), "-o", str(test_object)],
            cwd=ROOT, text=True, capture_output=True,
        )
        if built.returncode:
            raise RuntimeError(f"large-batch O2 test compile failed\n{built.stdout}{built.stderr}")
        exe = out / "m7_large_batch_memory.exe"
        linked = subprocess.run(
            [compiler, "-fopenmp", "-O2", *(str(obj) for obj in objects), str(test_object), "-o", str(exe)],
            cwd=ROOT, text=True, capture_output=True,
        )
        if linked.returncode:
            raise RuntimeError(f"large-batch O2 link failed\n{linked.stdout}{linked.stderr}")
        output, peak_working_set, peak_private = measured_run(exe, out / "runtime-output.txt")
        for marker in MARKERS:
            if marker not in output:
                raise RuntimeError(f"large-batch transcript missing {marker}\n{output[-6000:]}")
        print(f"M7_LARGE_BATCH_PEAK_WORKING_SET_BYTES {peak_working_set}")
        print(f"M7_LARGE_BATCH_MAX_SAMPLED_PRIVATE_BYTES {peak_private}")
        for line in output.splitlines():
            if line.startswith(("M7_LARGE_BATCH_", "M7_WORKER_SCRATCH_A_B_A_STATE_IDENTITY", "M7_WORKER_SCRATCH_A_B_A_MASS_IDENTITY", "M7_SERIALIZED_WORKER_SCRATCH_REUSE_CROSS_COLUMN")):
                print(line)
    print("M7_LARGE_BATCH_MEMORY_PROBE_O2=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
