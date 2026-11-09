#!/usr/bin/env python3
"""Run an explicitly selected SWAP5 water project."""

import argparse
import csv
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "app/hybrid_water"))
from daily_host import APPLICATION_MODEL, build, checkpoint_identity, run, sha, verify_checkpoint

GRASS_MODEL = "NATIVE_GRASSGROWTH_WATER"
HUPSEL_MODEL = "NATIVE_HUPSEL_ROTATION"
GRASS_INPUTS = {"input.swp": "swap.swp", "grass.crp": "grass.crp", "input.met": "260.met",
                "swap.bbc": "swap.bbc", "swap.dra": "swap.dra"}


def run_grass(args):
    bundle = args.grass_build.resolve()
    metadata = json.loads((bundle / "BUILD.json").read_text())
    executable = bundle / ("swap5_grass_startup.exe" if os.name == "nt" else "swap5_grass_startup")
    if (metadata["status"] != "ORIGINAL_INTERVAL_COMPLETED"
            or metadata["grass_numerical_profile"] != "thermal-control-1e-5C"
            or sha(executable) != metadata["executable_sha256"]):
        raise ValueError("Grassgrowth requires a verified thermal-control application build")
    if any(sha(Path(name)) != digest for name, digest in metadata["source_sha256"].items()):
        raise ValueError("Grassgrowth build source differs")
    inputs = bundle / "original-interval"
    project = ROOT / "reference/swap-4.3.1/projects/2.grassgrowth"
    original = {name: sha(project / source) for name, source in GRASS_INPUTS.items()}
    pinned = {**original, "application.binding": metadata["application_binding_sha256"]}
    staged = {name: (inputs / name).read_bytes() for name in pinned}
    if (metadata["original_inputs_sha256"] != original
            or any(sha256(data).hexdigest() != pinned[name] for name, data in staged.items())):
        raise ValueError("Grassgrowth input or build binding differs")
    binding = json.loads(staged["application.binding"])
    if any(binding[key] != metadata[key] for key in (
            "executable_sha256", "compiler", "source_sha256", "grass_numerical_profile")):
        raise ValueError("Grassgrowth application binding does not describe the verified build")
    origin = args.restart.resolve() if args.restart is not None else None
    output = args.output.resolve()
    output.mkdir(parents=True)
    for name, data in staged.items():
        (output / name).write_bytes(data)
    command = [str(executable), str(args.days), "retain-step", "100000",
               str(origin) if origin is not None else "", "thermal-control", args.model]
    with (output / "stdout").open("wb") as stdout, (output / "stderr").open("wb") as stderr:
        completed = subprocess.run(command, cwd=output, stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr)
    if completed.returncode:
        return completed.returncode
    with (output / "stdout").open("rb") as stdout:
        if stdout.readline().strip() != f"DAILY_MODEL {args.model}".encode("ascii"):
            raise ValueError("Grassgrowth did not acknowledge the selected application model")
    with (output / "budget.csv").open(newline="") as stream:
        rows = list(csv.DictReader(stream))
    if not rows or int(rows[-1]["day"]) != args.days:
        raise ValueError("Grassgrowth did not complete the requested days")
    report = {
        "model": args.model, "requested_days": args.days,
        "first_completed_day": int(rows[0]["day"]), "last_completed_day": int(rows[-1]["day"]),
        "input_sha256": original, "executable_sha256": sha(executable),
        "checkpoint_sha256": sha(output / "checkpoint.bin"),
        "maximum_water_residual_cm": max(abs(float(row["residual_cm"])) for row in rows),
        "maximum_heat_residual_j_cm2": max(abs(float(row["heat_residual_j_cm2"])) for row in rows),
    }
    (output / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n")
    return 0


def hupsel_inputs():
    authority = ROOT / "integration/dataqual15_hupsel/PRESSURE_DIAGNOSTIC_INPUTS_20261104"
    pins = json.loads(authority.with_suffix(".json").read_text())
    archive = authority.with_suffix(".tar.xz")
    if sha(archive) != pins["archive_sha256"]:
        raise ValueError("Hupsel prepared input archive differs")
    with tarfile.open(archive) as stream:
        members = stream.getmembers()
        if (len(members) != len(pins["files_sha256"])
                or {m.name for m in members} != set(pins["files_sha256"])
                or any(not m.isfile() or Path(m.name).name != m.name for m in members)):
            raise ValueError("Unexpected Hupsel prepared input inventory")
        files = {m.name: stream.extractfile(m).read() for m in members}
    project = ROOT / "reference/swap-4.3.1/projects/1.hupselbrook"
    for name, data in files.items():
        if sha256(data).hexdigest() != pins["files_sha256"][name]:
            raise ValueError(f"Hupsel prepared input differs: {name}")
        if name != "input.nml":
            original = (project / name).read_bytes().replace(b"\r\n", b"\n")
            if name == "swap.swp":
                # The sealed pressure-film preparation uses a 0.01-day numerical ceiling.
                original = original.replace(b"DTMAX = 0.04 ", b"DTMAX = 0.01 ", 1)
            if data.replace(b"\r\n", b"\n") != original:
                raise ValueError(f"Hupsel original project input differs: {name}")
    files["swap.swp"] += (b"\n! Explicit SWAP5 numerical profile; original physical input above is unchanged.\n"
                         b"SWAP5_ROOT_ACCURACY = 1\n")
    return files


def run_hupsel(args):
    bundle = args.hupsel_build.resolve()
    metadata = json.loads((bundle / "BUILD.json").read_text())
    executable = bundle / ("swap5_hupsel_germination.exe" if os.name == "nt" else "swap5_hupsel_germination")
    if (metadata["status"] != "BUILT" or sha(executable) != metadata["executable_sha256"]
            or not any(Path(name).resolve() == ROOT / "app/solute_project/main.f90"
                       for name in metadata["source_sha256"])
            or any(sha(Path(name)) != digest for name, digest in metadata["source_sha256"].items())):
        raise ValueError("Hupsel executable or build source differs")
    files = hupsel_inputs()
    input_hashes = {name: sha256(data).hexdigest() for name, data in files.items()}
    binding = {"model": args.model, "input_sha256": input_hashes, "executable_sha256": sha(executable)}
    origin = args.restart.resolve() if args.restart is not None else None
    origin_data = None
    if origin is not None:
        receipt = json.loads((origin.parent / "RESULT.json").read_text())
        origin_data = origin.read_bytes()
        if (any(receipt[key] != value for key, value in binding.items())
                or receipt["checkpoint_sha256"] != sha256(origin_data).hexdigest()
                or not 0 < receipt["last_completed_day"] < args.days):
            raise ValueError("Hupsel checkpoint build, input, content or day differs")
    ends = re.search(rb"^ends_day=(.*)$", files["input.nml"], re.M)
    stop = next(index for index, token in enumerate(ends[1].split(b","), 1)
                if token.strip() and float(token) == args.days)
    output = args.output.resolve()
    output.mkdir(parents=True)
    for name, data in files.items():
        (output / name).write_bytes(data)
    if origin_data is not None:
        (output / "restart-origin.bin").write_bytes(origin_data)
    command = [str(executable), "input.nml", "restart-origin.bin" if origin_data is not None else "-",
               str(stop), "swap.swp", "maize.crp", args.model]
    env = dict(os.environ, OMP_NUM_THREADS="1")
    env.pop("SWAP5_DIAG_PREDECESSOR", None)
    with (output / "stdout").open("wb") as stdout, (output / "stderr").open("wb") as stderr:
        completed = subprocess.run(command, cwd=output, env=env, stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr)
    if completed.returncode:
        return completed.returncode
    markers = (output / "stdout").read_bytes().splitlines()
    if (f"DAILY_MODEL {args.model}".encode("ascii") not in markers
            or b"HUPSEL_ROOT_NUMERICAL_PROFILE=PRESSURE_FILM_REFINED" not in markers):
        raise ValueError("Hupsel did not acknowledge the selected rotation and numerical profile")
    with (output / "budget.csv").open(newline="") as stream:
        rows = list(csv.DictReader(stream))
    checkpoint = (output / "checkpoint.bin").read_bytes()
    if (not rows or float(rows[-1]["t1_day"]) != args.days or checkpoint[:8] != b"S5HR0004"
            or struct.unpack_from("=d", checkpoint, 8)[0] != args.days):
        raise ValueError("Hupsel did not commit the requested terminal day")
    report = {
        **binding, "requested_days": args.days, "last_completed_day": args.days,
        "origin_day": receipt["last_completed_day"] if origin is not None else None,
        "checkpoint_sha256": sha256(checkpoint).hexdigest(),
        "maximum_water_residual_cm": max(abs(float(row["water_residual_cm"])) for row in rows),
        "maximum_solute_residual_mg_cm2": max(abs(float(row["solute_residual_mg_cm2"])) for row in rows),
        "maximum_heat_residual_j_cm2": max(abs(float(row["observed_heat_residual_j_cm2"])) for row in rows),
    }
    (output / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", required=True, choices=[APPLICATION_MODEL, GRASS_MODEL, HUPSEL_MODEL])
    parser.add_argument("--reference-work", type=Path, help="Prepared original SWAP 4.3.1 distribution for Andelst")
    parser.add_argument("--grass-build", type=Path, help="Verified Grassgrowth thermal-control build bundle")
    parser.add_argument("--hupsel-build", type=Path, help="Verified native Hupsel rotation build")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--days", type=int, help="Last requested day, defaulting to the selected project's end")
    parser.add_argument("--checkpoint-at", type=int, help="Publish a checkpoint after this day is accepted")
    parser.add_argument("--restart", type=Path, help="Previously published checkpoint for the selected model")
    parser.add_argument("--restart-day", type=int)
    parser.add_argument("--kernel-opt", choices=["O0", "O2"])
    args = parser.parse_args()
    if args.model == HUPSEL_MODEL:
        if (args.hupsel_build is None or args.grass_build is not None or args.reference_work is not None
                or args.kernel_opt is not None or args.restart_day is not None or args.checkpoint_at is not None):
            parser.error("Hupsel requires --hupsel-build and publishes its native checkpoint on accepted days")
        args.days = 1096 if args.days is None else args.days
        if not 1 <= args.days <= 1096:
            parser.error("Hupsel day must be in 1..1096")
        return run_hupsel(args)
    if args.model == GRASS_MODEL:
        if (args.grass_build is None or args.hupsel_build is not None or args.reference_work is not None or args.kernel_opt is not None
                or args.restart_day is not None or args.checkpoint_at is not None):
            parser.error("Grassgrowth requires --grass-build and publishes its native checkpoint on each accepted day")
        args.days = 1827 if args.days is None else args.days
        if not 1 <= args.days <= 1827:
            parser.error("Grassgrowth day must be in 1..1827")
        return run_grass(args)
    if args.reference_work is None or args.grass_build is not None or args.hupsel_build is not None:
        parser.error("Andelst requires --reference-work")
    args.days = 481 if args.days is None else args.days
    args.kernel_opt = args.kernel_opt or "O2"
    if (args.restart is None) != (args.restart_day is None):
        parser.error("--restart and --restart-day must be supplied together")
    first = args.restart_day if args.restart is not None else 0
    if not 0 <= first < args.days <= 481 or (args.restart is not None and first == 0):
        parser.error("The last day must follow the origin and be within the original 481-day period")
    if args.checkpoint_at is not None and not first < args.checkpoint_at <= args.days:
        parser.error("The checkpoint day must belong to the requested run")

    output = args.output.resolve()
    output.mkdir(parents=True)
    profile = dict(budget_retry=True, shared_pond_transfer=True, refresh_macro_final=True)
    donor, kernel, case, inputs, build_id = build(
        args.reference_work.resolve(), output, **profile, runtime_checkpoint=True, kernel_opt=args.kernel_opt,
    )
    binding = checkpoint_identity(inputs, build_id, **profile)
    origin = None
    receipt = None
    if args.restart is not None:
        origin = output / "verified-origin"
        receipt = verify_checkpoint(args.restart.resolve(), first, binding, origin)
    result = run(donor, kernel, case, output, args.days, checkpoint_day=first, origin=origin,
                 origin_receipt=receipt, runtime=True, publish_day=args.checkpoint_at,
                 checkpoint_binding=binding if args.checkpoint_at is not None else None, model=args.model)
    report = {
        "model": args.model, "kernel_optimization": args.kernel_opt,
        "input_sha256": inputs, "source_sha256": {"SWAP.ZIP": binding["swap_source"], "TTUTIL.ZIP": binding["ttutil_source"]},
        "donor_executable_sha256": sha(donor), "kernel_executable_sha256": sha(kernel),
        "origin_day": args.restart_day, "requested_days": args.days, **result,
    }
    (output / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n")
    return int(result["first_refusal"] is not None)


if __name__ == "__main__":
    raise SystemExit(main())
