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
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "app/hybrid_water"))
import daily_host as host_module
from daily_host import APPLICATION_MODEL, ANDELST, GRASSGROWTH, HUPSEL, SALTFARM, PROJECTS, build, checkpoint_identity, prepare_reference, run, sha, verify_checkpoint

GRASS_MODEL = "NATIVE_GRASSGROWTH_WATER"
HUPSEL_MODEL = "NATIVE_HUPSEL_ROTATION"


def require_no_macro_input(reference, project):
    """Refuse active/ambiguous actual SWP input before output or compilation."""
    path = Path(reference) / 'distribution/SWAP_4.3.1/cases' / project.case / 'swap.swp'
    values = re.findall(r'(?mi)^\s*SWMACRO\s*=\s*([^\s!]+)', path.read_text(encoding='cp1252'))
    if len(values) != 1 or not re.fullmatch(r'[+-]?\d+', values[0]) or int(values[0]) != 0:
        raise ValueError('No-macro release requires one explicit SWMACRO=0 in the actual original input; no input is changed')

GRASS_INPUTS = {"input.swp": "swap.swp", "grass.crp": "grass.crp", "input.met": "260.met",
                "swap.bbc": "swap.bbc", "swap.dra": "swap.dra"}


def run_grass(args):
    bundle = args.grass_build.resolve()
    metadata = json.loads((bundle / "BUILD.json").read_text())
    executable = bundle / ("swap5_grass_startup.exe" if os.name == "nt" else "swap5_grass_startup")
    if (metadata["status"] != "ORIGINAL_INTERVAL_COMPLETED"
            or metadata["grass_numerical_profile"] not in (
                "thermal-control-1e-5C", "thermal-subcycle4-1e-5C", "thermal-subcycle16-1e-5C")
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
    selector = {"thermal-subcycle4-1e-5C": "thermal-control-4",
                "thermal-subcycle16-1e-5C": "thermal-control-16"}.get(
                    metadata["grass_numerical_profile"], "thermal-control")
    command = [str(executable), str(args.days), "retain-step", "100000",
               str(origin) if origin is not None else "", selector, args.model]
    with (output / "stdout").open("wb") as stdout, (output / "stderr").open("wb") as stderr:
        completed = subprocess.run(command, cwd=output, stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr,
                                   timeout=args.timeout_seconds or (60 if args.no_macro_release else None))
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
        completed = subprocess.run(command, cwd=output, env=env, stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr,
                                   timeout=args.timeout_seconds or (60 if args.no_macro_release else None))
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
    from experimental_project import MODEL as experimental_model
    parser.add_argument("--model", choices=[GRASS_MODEL,HUPSEL_MODEL,experimental_model]+[p.model for p in PROJECTS])
    parser.add_argument('--experimental-project', type=Path,
                        help='Explicit experimental original project directory; no production/science claim')
    parser.add_argument('--experimental-solute-step-policy',choices=host_module.SOLUTE_STEP_POLICIES,
                        help='Explicit experimental chemical execution policy; no automatic fallback')
    parser.add_argument('--experimental-time-step-policy',choices=host_module.TIME_POLICIES,
                        help='Explicit experimental numerical policy; defaults to original adaptive daily seed, new policy is not qualified for all option mixes')
    parser.add_argument("--reference-work", type=Path, help="Original source provider prepared by --prepare-sources (or legacy Andelst archive)")
    parser.add_argument("--grass-build", type=Path, help="Verified Grassgrowth thermal-control build bundle")
    parser.add_argument("--hupsel-build", type=Path, help="Verified native Hupsel rotation build")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--prepare-archive", type=Path, help="Prepare the pinned original distribution for Andelst")
    parser.add_argument("--days", type=int, help="Last requested day, defaulting to the selected project's end")
    parser.add_argument("--checkpoint-at", type=int, help="Publish a checkpoint after this day is accepted")
    parser.add_argument("--restart", type=Path, help="Previously published checkpoint for the selected model")
    parser.add_argument("--restart-day", type=int)
    parser.add_argument("--kernel-opt", choices=["O0", "O2"])
    parser.add_argument('--donor-opt',choices=['O0','O2'],help='Experimental generated-donor units only; immutable original provider stays O2')
    parser.add_argument('--no-macro-release',action='store_true',help='Explicit macropore-free release; active macro input is rejected before build')
    parser.add_argument('--timeout-seconds',type=float,help='Hard model/controller wall cap; release default60seconds, compile time excluded')
    parser.add_argument('--prepare-sources', action='store_true', help='Build original source provider only; no model execution')
    parser.add_argument('--build-only', action='store_true', help='Compile the selected registered project without running it')
    parser.add_argument('--build-bundle', type=Path, help='Reuse an exact source/input/compiler-bound build')
    args = parser.parse_args()
    import user_prepare
    if args.prepare_sources:
        if (not args.no_macro_release or args.reference_work is None or args.model is not None
            or args.build_only or any(v is not None for v in (args.output,args.prepare_archive,args.build_bundle,
                args.grass_build,args.hupsel_build,args.days,args.checkpoint_at,args.restart,args.restart_day,args.kernel_opt,args.experimental_project,args.experimental_time_step_policy,args.experimental_solute_step_policy,args.donor_opt))):
            parser.error('--prepare-sources requires only --no-macro-release and a new --reference-work')
        try:
            prepared=user_prepare.prepare(args.reference_work)
        except (OSError,ValueError,subprocess.SubprocessError) as error:
            parser.error(str(error))
        print(json.dumps({'status':prepared['status'],'compile_seconds':prepared['compile_seconds']}))
        return 0
    if args.model is None:
        parser.error('--model is required for a build or run')
    experimental = args.experimental_project is not None
    if args.experimental_solute_step_policy is not None and not experimental:
        parser.error('--experimental-solute-step-policy requires --experimental-project')
    if args.experimental_time_step_policy is not None and not experimental:
        parser.error("--experimental-time-step-policy requires --experimental-project")
    if args.donor_opt is not None and not experimental:
        parser.error('--donor-opt is limited to explicit experimental project qualification')
    if (args.model == experimental_model) != experimental or (experimental and args.no_macro_release):
        parser.error('HYBRID_NOMACRO_WATER requires --experimental-project and cannot claim --no-macro-release')
    if args.no_macro_release and args.model not in (GRASSGROWTH.model,HUPSEL.model,SALTFARM.model):
        parser.error('Release selection is limited to the three registered no-macro hybrid projects; active macropores are excluded')
    if (args.build_only or args.build_bundle is not None) and not (args.no_macro_release or experimental):
        parser.error('--build-only/--build-bundle require --no-macro-release or --experimental-project')
    if args.build_only and (args.build_bundle is not None or any(v is not None for v in (args.days,args.restart,args.restart_day,args.checkpoint_at))):
        parser.error('--build-only does not run or resume a model')
    if args.no_macro_release and args.model==ANDELST.model:
        parser.error('Active macropores are outside SWAP5-NOMACRO-CLOSURE01; original Andelst is not silently changed')
    if args.timeout_seconds is not None and not 0<args.timeout_seconds<=300:
        parser.error('Model wall cap must be positive and at most300seconds')
    if args.prepare_archive is not None:
        if (args.model != APPLICATION_MODEL or args.reference_work is None
                or any(value is not None for value in (args.output, args.grass_build, args.hupsel_build,
                                                        args.days, args.restart, args.restart_day,
                                                        args.checkpoint_at, args.kernel_opt))):
            parser.error("Preparing Andelst requires only --model, --reference-work and --prepare-archive")
        prepare_reference(args.prepare_archive.resolve(), args.reference_work.resolve())
        return 0
    if args.output is None:
        parser.error("--output is required for a model run")
    if (args.no_macro_release or experimental) and args.output.exists():
        parser.error('Release output directory must be new')
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
    try:
        if experimental:
            from experimental_project import load
            project = load(args.experimental_project,time_step_policy=args.experimental_time_step_policy,solute_step_policy=args.experimental_solute_step_policy)
        else:
            project={p.model:p for p in PROJECTS}[args.model]
    except (OSError, ValueError) as error:
        parser.error(str(error))
    last_day=project.last_day
    args.days = last_day if args.days is None else args.days
    if (args.restart is None) != (args.restart_day is None):
        parser.error("--restart and --restart-day must be supplied together")
    first = args.restart_day if args.restart is not None else 0
    if not 0 <= first < args.days <= last_day or (args.restart is not None and first == 0):
        parser.error(f"The last day must follow the origin and be within the admitted {last_day}-day period")
    if args.checkpoint_at is not None and not first < args.checkpoint_at <= args.days:
        parser.error("The checkpoint day must belong to the requested run")

    if args.no_macro_release or experimental:
        try:
            prepared_provider=user_prepare.validate(args.reference_work)
            if not experimental:
                user_prepare.check_inputs(args.reference_work, project)
                require_no_macro_input(args.reference_work, project)
        except (OSError, ValueError) as error:
            parser.error(str(error))

    output = args.output.resolve()
    profile = dict(budget_retry=project.macro or project.solute, shared_pond_transfer=project.macro, refresh_macro_final=project.macro)
    if experimental:
        from experimental_project import inspect
        # Existing explicit-flux certificate is independent of chemical mode.
        # Reconstructed1/5 water-only cases retain the independent daily guard.
        profile['budget_retry']=inspect(project.input_directory)['boundary']['SWBOTB'] not in (1,5)
    project_meta=dict(case=project.case,model=project.model,start_date=project.start_date,nodes=project.nodes,water_tolerance=project.water_tolerance)
    if args.build_bundle is not None:
        from daily_coupling import validate_bundle
        try:
            bundle=args.build_bundle.resolve()
            meta,case=validate_bundle(bundle,args.reference_work.resolve(),project)
            inputs,build_id=meta['inputs'],meta['identity']
            user_prepare.validate_build(args.reference_work,build_id,validated_toolchain=prepared_provider['toolchain'])
            binding=checkpoint_identity(inputs,build_id,project=project,**profile)
            if meta['binding'] != binding:
                raise ValueError('Build checkpoint binding differs')
            actual_opt=next(v[1:] for v in build_id['kernel_flags'] if v in ('-O0','-O2'))
            donor_opt=next(v[1:] for v in build_id['donor_flags'] if v in ('-O0','-O2'))
            if args.donor_opt is not None and args.donor_opt != donor_opt:
                raise ValueError('Requested generated-donor optimization differs from build')
            args.donor_opt=donor_opt
            if args.kernel_opt is not None and args.kernel_opt != actual_opt:
                raise ValueError('Requested kernel optimization differs from build')
            args.kernel_opt=actual_opt
            donor=host_module.executable(bundle,'day_donor');kernel=host_module.executable(bundle,'day_kernel')
        except (OSError,ValueError,KeyError,StopIteration) as error:
            parser.error(str(error))
        output.mkdir(parents=True)
    else:
        args.kernel_opt=args.kernel_opt or 'O2'
        args.donor_opt=args.donor_opt or 'O2'
        output.mkdir(parents=True)
        donor,kernel,case,inputs,build_id=build(args.reference_work.resolve(),output,**profile,
            runtime_checkpoint=True,kernel_opt=args.kernel_opt,project=project,donor_opt=args.donor_opt)
        binding=checkpoint_identity(inputs,build_id,project=project,**profile)
    origin=None;receipt=None
    if args.restart is not None:
        origin=output/'verified-origin'
        receipt=verify_checkpoint(args.restart.resolve(),first,binding,origin)
    (output/'BUILD.json').write_text(json.dumps(dict(project=project_meta,inputs=inputs,identity=build_id,binding=binding,
        executable_sha256={'donor':sha(donor),'kernel':sha(kernel)}),indent=2)+'\n')
    if args.build_only:
        print(json.dumps({'status':'BUILT_NO_MODEL_EXECUTED','model':project.model,'kernel_optimization':args.kernel_opt}))
        return 0
    workers=[];expired=threading.Event();actual_start=host_module.start_process
    def track(*arguments,**keywords):
        process,log=actual_start(*arguments,**keywords);workers.append(process);return process,log
    def stop():
        expired.set()
        for process in workers:
            if process.poll() is None:process.kill()
    seconds=args.timeout_seconds or (60 if args.no_macro_release or experimental else None)
    timer=threading.Timer(seconds,stop) if seconds else None
    started=time.perf_counter();host_module.start_process=track
    if timer:timer.start()
    try:
        result = run(donor, kernel, case, output, args.days, checkpoint_day=first, origin=origin,
                     origin_receipt=receipt, runtime=True, publish_day=args.checkpoint_at,
                     checkpoint_binding=binding if args.checkpoint_at is not None else None, model=args.model, project=project)
    except Exception:
        if not expired.is_set():raise
        (output/'RESULT.json').write_text(json.dumps({'status':'MODEL_WALL_CAP_REACHED','seconds':time.perf_counter()-started,
            'cap_seconds':seconds,'model':args.model,'journal':'daily.jsonl; accepted records retained, no completion claim'},indent=2)+'\n')
        return 124
    finally:
        if timer:timer.cancel()
        host_module.start_process=actual_start
        for process in workers:
            if process.poll() is None:process.kill()
            process.wait(timeout=5)
    result['model_and_controller_seconds']=time.perf_counter()-started
    result['no_macro_release']=args.no_macro_release
    if experimental:
        result['execution_mode']='EXPERIMENTAL_NOT_PRODUCTION_QUALIFIED'
        result['scientific_equivalence']='NOT_QUALIFIED'
    report = {
        "model": args.model, "kernel_optimization": args.kernel_opt,
        "generated_donor_optimization":args.donor_opt,
        "input_sha256": inputs, "source_sha256": {"SWAP.ZIP": binding["swap_source"], "TTUTIL.ZIP": binding["ttutil_source"]},
        "donor_executable_sha256": sha(donor), "kernel_executable_sha256": sha(kernel),
        "origin_day": args.restart_day, "requested_days": args.days, **result,
    }
    (output / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n")
    return int(result["first_refusal"] is not None)


if __name__ == "__main__":
    raise SystemExit(main())
