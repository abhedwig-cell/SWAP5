"""Compare Grassgrowth at startup, including the first original water endpoint."""
import argparse
import csv
from hashlib import sha256
import json
from math import fsum
from pathlib import Path
import shutil
import subprocess


def record(lines, tag):
    row, = [line.split()[1:] for line in lines if line.startswith(tag+" ")]
    return list(map(float, row))


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def difference(actual, expected):
    values = [a-b for a,b in zip(actual, expected, strict=True)]
    i = max(range(len(values)), key=lambda j: abs(values[j]))
    return {"node": i+1, "signed": values[i], "max_abs": abs(values[i])}


def run_common_clock(build, metadata, output, clock, thermal):
    output.mkdir()
    files = (*metadata["original_inputs_sha256"], "application.binding")
    for name in files:
        shutil.copyfile(build/"original-interval"/name, output/name)
    exe = build/metadata["executable"]
    assert digest(exe) == metadata["executable_sha256"]
    command = [str(exe), str(clock), "retain-step", "100000"]
    if thermal:
        command += ["", "thermal-control"]
    with (output/"stdout").open("wb") as out, (output/"stderr").open("wb") as err:
        subprocess.run(command,cwd=output,stdout=out,stderr=err,check=True,timeout=60)
    return command


def compare(build, output, clock, legacy_theta, legacy_end):
    metadata = json.loads((build/"BUILD.json").read_text())
    assert metadata["native_returncode"] == 0
    event, = [i for i,event in enumerate(metadata["events"])
              if event["label"] == "native_original_initial_interval"]
    daily_log = (build/f"{event}.stdout").read_text(errors="replace").splitlines()
    first = record(daily_log, "GRASS_WATER_FIRST")
    initial = record(daily_log, "GRASS_WATER_INITIAL_THETA")
    trial = next(line.split()[1:] for line in daily_log if "ORIGINAL_GRASS_TRIAL" in line)
    with (build/"original-interval/budget.csv").open() as stream:
        day1, = csv.DictReader(stream)
    thermal = metadata["grass_numerical_profile"] == "thermal-control-1e-5C"
    command = run_common_clock(build,metadata,output,clock,thermal)
    with (output/"state.csv").open() as stream:
        end = [float(row["water_content"]) for row in csv.DictReader(stream)]
    with (output/"budget.csv").open() as stream:
        budget, = csv.DictReader(stream)
    assert float(budget["t1"]) == clock
    assert abs(float(budget["residual_cm"])) < 1e-10
    log = (output/"stdout").read_text(errors="replace").splitlines()
    leaves = [line.split() for line in log if line.startswith("GRASS_HEAT_ACCEPTED ")]
    assert float(leaves[0][2]) == 0 and float(leaves[-1][3]) == clock
    assert all(float(a[3]) == float(b[2]) for a,b in zip(leaves,leaves[1:]))
    return {
        "compiler": metadata["compiler"], "executable_sha256": metadata["executable_sha256"],
        "original_inputs_sha256": metadata["original_inputs_sha256"],
        "profile": metadata["grass_numerical_profile"],
        "initial_theta_vs_legacy": difference(initial,legacy_theta),
        "daily_first_leaf": dict(zip(("dt_days","gross_rain_cm_day","qtop_upward_cm_day",
            "qbottom_upward_cm_day","soil_storage_change_cm","air_temperature_c","net_rain_cm_day"),first,strict=True)),
        "daily_first_forcing_window_end": float(trial[2]),
        "daily_first_forcing_window_temporal_rejections": int(trial[-2]),
        "day1_adaptive_intervals": int(day1["accepted_steps"]),
        "common_clock": {"command": command, "thermal_leaves":len(leaves),
            "theta_vs_legacy":difference(end,legacy_end), "water_residual_cm":float(budget["residual_cm"]),
            "net_top_in_cm":fsum(float(row[11]) for row in leaves),
            "conductive_storage_j_cm2":fsum(float(row[7]) for row in leaves)},
    }


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--legacy",type=Path,required=True)
    parser.add_argument("--build-root",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    args.output.mkdir()
    lines=(args.legacy/"stdout").read_text(errors="replace").splitlines()
    legacy=record(lines,"LEGACY_WATER_FIRST")
    start=next(i for i,line in enumerate(lines) if line.startswith("LEGACY_HEAT_CASE "))
    first_case=[list(map(float,line.split()[1:])) for line in lines[start+1:start+114]]
    assert len(first_case)==113 and all(len(row)==13 for row in first_case)
    initial,end=([row[index] for row in first_case] for index in (7,8))
    runs={}
    for opt in ("O0","O2"):
        for profile in ("thermal","water"):
            tag=f"{opt}-{profile}"
            build=args.build_root / f"s5-grass-water-start-{tag}"
            runs[tag]=compare(build.resolve(),(args.output/tag).resolve(),legacy[0],initial,end)
    for profile in ("thermal","water"):
        a,b=(runs[f"{opt}-{profile}"] for opt in ("O0","O2"))
        for key in ("initial_theta_vs_legacy","daily_first_leaf","day1_adaptive_intervals"):
            assert a[key]==b[key],(profile,key)
        assert {k:v for k,v in a["common_clock"].items() if k!="command"} == {
            k:v for k,v in b["common_clock"].items() if k!="command"}
    print(json.dumps({"canonical_base":"a57d7d532464ad89b7aca918263cf114b6b42185",
        "legacy_build":json.loads((args.legacy/"RESULT.json").read_text()),
        "legacy_first":dict(zip(("dt_days","net_rain_cm_day","qtop_upward_cm_day",
            "qbottom_upward_cm_day","soil_storage_change_cm"),legacy,strict=True)), "runs":runs},indent=2))


if __name__=="__main__":
    main()
