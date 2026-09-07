#!/usr/bin/env python3
"""Materialize the exact legacy physical source needed by the F-VQ09 probe.

The chain is B0 -> B1.10 -> F-CI06 -> F-CI11, followed only by the qualified
F-CI13 canonical-trial terminal-status guard in swap.f90. Adapter/runtime source
is required to remain byte-identical to the qualified F-CI14 production-source
head; it is not copied into the legacy tree.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

try:
    from .fvq09_asset_bundle import directory_manifest
except ImportError:
    from fvq09_asset_bundle import directory_manifest

ROOT = Path(__file__).resolve().parents[2]
QUALIFIED_PRODUCTION_SOURCE_HEAD = "da5026d8b87ad2f3c7912360891839a120ecccb6"
FCI13_PORT = ROOT / "src/legacy/b1_10_fci13_port"

FCI13_INSERT = """
!        F-CI13: a canonical trial must not continue from the legacy terminal
!        non-converged minimum-dt route. HeadCalc records that route by
!        incrementing worker%history%iwarn. Standalone execution has no worker
!        and therefore retains the qualified legacy continuation behaviour.
         if (present(worker)) then
            if (worker%history%iwarn > 0) then
               call SoilWaterStateVar(2)
               return
            end if
         end if
"""


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=ROOT, check=True, text=True, capture_output=True, **kwargs)


def normalized_lf(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")


def legacy_crlf(data: bytes) -> bytes:
    return normalized_lf(data).replace(b"\n", b"\r\n")


def ensure_qualified_src_identity() -> None:
    proc = subprocess.run(
        ["git", "diff", "--quiet", QUALIFIED_PRODUCTION_SOURCE_HEAD, "--", "src"],
        cwd=ROOT,
    )
    if proc.returncode != 0:
        raise ValueError("current src tree differs from qualified F-CI14 production-source head")


def assemble_fci13_swap(fci11_source: Path) -> bytes:
    run([sys.executable, "tools/fci/fci13_recoverable_status_gate.py"])
    parts = [FCI13_PORT / f"swap_part0{i}.inc" for i in range(1, 9)]
    if not all(path.is_file() for path in parts):
        raise ValueError("F-CI13 swap part missing")
    post_lf = normalized_lf(b"".join(path.read_bytes() for path in parts))
    pre_lf = normalized_lf((fci11_source / "swap.f90").read_bytes())
    insert = FCI13_INSERT.encode("utf-8")
    if post_lf.count(insert) != 1:
        raise ValueError("F-CI13 terminal-status guard count is not exactly one")
    if post_lf.replace(insert, b"", 1) != pre_lf:
        raise ValueError("F-CI13 legacy source differs from F-CI11 beyond admitted terminal-status guard")
    return legacy_crlf(post_lf)


def materialize(b0_archive: Path, output: Path) -> dict:
    ensure_qualified_src_identity()
    work = output.parent / f".{output.name}.work"
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    b1 = work / "b1_10"
    fci06 = work / "fci06"
    fci11 = work / "fci11"
    try:
        b1_result = run([sys.executable, "tools/vq/b1_10_reconstruct.py", "--archive", str(b0_archive), "--output-dir", str(b1)])
        fci06_result = run([sys.executable, "tools/fci/fci06_apply_controlled_source_port.py", "--source", str(b1), "--output", str(fci06)])
        fci11_result = run([sys.executable, "tools/fci/fci11_apply_controlled_interval_mass_port.py", "--source", str(fci06), "--output", str(fci11)])
        (fci11 / "swap.f90").write_bytes(assemble_fci13_swap(fci11))
        if output.exists():
            shutil.rmtree(output)
        shutil.copytree(fci11, output)
        manifest = directory_manifest(output)
        result = {
            "work_unit": "F-VQ09",
            "status": "PASS_MATERIALIZED_QUALIFIED_PHYSICAL_SOURCE",
            "qualified_production_source_head": QUALIFIED_PRODUCTION_SOURCE_HEAD,
            "legacy_chain": ["B1.10", "F-CI06", "F-CI11", "F-CI13_TERMINAL_STATUS_GUARD"],
            "materialized_source_manifest_sha256": manifest["manifest_sha256"],
            "materialized_source_file_count": manifest["file_count"],
            "b1_10_materializer_output": json.loads(b1_result.stdout),
            "fci06_materializer_output": json.loads(fci06_result.stdout),
            "fci11_materializer_output": json.loads(fci11_result.stdout),
        }
        return result
    finally:
        if work.exists():
            shutil.rmtree(work)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--b0", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = materialize(args.b0, args.output)
    except Exception as exc:
        print(json.dumps({"work_unit": "F-VQ09", "status": "FAIL_MATERIALIZATION", "failure": str(exc)}, indent=2))
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
