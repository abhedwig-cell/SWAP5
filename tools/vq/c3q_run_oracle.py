#!/usr/bin/env python3
"""Run the exact reconstructed B1.5p1 grass case with reversible C3Q oxygen tracing."""
from __future__ import annotations

import argparse, hashlib, json, shutil, subprocess
from pathlib import Path

from b0_source_runner import build_gfortran, run
from b1_reconstruct import reconstruct
from c3q_instrument_oxygen import instrument, strip_trace, SOURCE_SHA256


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--archive", required=True, type=Path)
    ap.add_argument("--work-dir", required=True, type=Path)
    ap.add_argument("--case", default="2.grassgrowth")
    args = ap.parse_args()

    if args.work_dir.exists():
        shutil.rmtree(args.work_dir)
    args.work_dir.mkdir(parents=True)

    source = args.work_dir / "b1-source" / "SWAP"
    source.parent.mkdir(parents=True)
    recon = reconstruct(args.archive, source)
    oxygen = source / "oxygenstress.f90"
    original = oxygen.read_bytes()
    if hashlib.sha256(original).hexdigest() != SOURCE_SHA256:
        raise RuntimeError("unexpected reconstructed oxygenstress identity")
    traced = instrument(original)
    if strip_trace(traced) != original:
        raise RuntimeError("instrumentation reversibility failure")
    oxygen.write_bytes(traced)

    # Reuse the qualified VQ build implementation by constructing the directory layout it expects.
    dist = args.work_dir / "distribution" / "SWAP_4.3.1"
    with __import__("zipfile").ZipFile(args.archive) as z:
        z.extractall(args.work_dir / "distribution")
    srcdir = dist / "tools" / "SWAP" / "source"
    traced_zip = args.work_dir / "SWAP.ZIP"
    with __import__("zipfile").ZipFile(traced_zip, "w", __import__("zipfile").ZIP_DEFLATED) as z:
        for p in sorted(source.iterdir()):
            if p.is_file():
                z.write(p, "SWAP/" + p.name)
    shutil.copy2(traced_zip, srcdir / "SWAP.ZIP")

    exe, _ = build_gfortran(dist, args.work_dir / "build")
    case_src = dist / "cases" / args.case
    case_run = args.work_dir / "run" / args.case
    shutil.copytree(case_src, case_run)
    completed = run([str(exe), "./swap.swp"], case_run)

    trace = case_run / "c3q_oxygen_trace.csv"
    err = (case_run / "swap.err").read_text(errors="replace") if (case_run / "swap.err").exists() else ""
    ok = completed.returncode == 100 and (case_run / "swap.ok").is_file() and not err.strip() and trace.is_file()

    result = {
        "schema_version": 1,
        "slice": "PPA-WU05-C3Q",
        "oracle": "B1.5p1",
        "qualified_reconstruction": recon["qualified_reconstruction"],
        "b1_source_manifest_sha256": recon["source_tree"]["manifest_sha256"],
        "oxygen_original_sha256": hashlib.sha256(original).hexdigest(),
        "oxygen_instrumented_sha256": hashlib.sha256(traced).hexdigest(),
        "instrumentation_strip_restores_original": strip_trace(traced) == original,
        "executable_sha256": sha(exe),
        "case": args.case,
        "returncode": completed.returncode,
        "swap_ok": (case_run / "swap.ok").is_file(),
        "swap_err_empty": not err.strip(),
        "trace_present": trace.is_file(),
        "trace_sha256": sha(trace) if trace.is_file() else None,
        "trace_bytes": trace.stat().st_size if trace.is_file() else 0,
        "accepted": ok,
    }
    out = args.work_dir / "c3q_oracle_result.json"
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if ok else 4


if __name__ == "__main__":
    raise SystemExit(main())
