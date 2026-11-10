"""Compare original and SWAP5 candidate states on an identical first interval."""
import argparse
from hashlib import sha256
import json
from math import fsum
from pathlib import Path

from audit_grass_water_start import difference, record


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def audit(build, control, legacy, old_theta, initial_theta, widths, old_head):
    manifest = build / "BUILD.json"
    metadata = json.loads(manifest.read_text())
    assert metadata["native_returncode"] == 0
    event, = [i for i,e in enumerate(metadata["events"])
              if e["label"] == "native_original_initial_interval"]
    log = build / f"{event}.stdout"
    lines = log.read_text(errors="replace").splitlines()
    full = record(lines,"GRASS_FULL_TRIAL_THETA")
    half = record(lines,"GRASS_HALF_TRIAL_THETA")
    head = record(lines,"GRASS_FULL_TRIAL_HEAD")
    dt, water_in, water_out, pond = record(lines,"GRASS_FULL_TRIAL_BALANCE")
    assert dt == legacy[0] and pond == 0
    for name in ("state.csv","budget.csv","conductive_budget.csv","crop.csv"):
        assert (build/"original-interval"/name).read_bytes() == (control/name).read_bytes(),name
    residual = fsum([w*(v-x) for v,x,w in zip(full,initial_theta,widths,strict=True)]
                    + [pond,-water_in,water_out])
    assert abs(residual) < 1e-10
    trial = {
        "dt_day": dt, "full_vs_legacy_theta": difference(full,old_theta),
        "half_vs_legacy_theta": difference(half,old_theta),
        "full_vs_half_theta": difference(full,half),
        "full_vs_legacy_head_cm": difference(head,old_head),
        "full_water_in_cm": water_in, "full_water_out_cm": water_out,
        "full_independent_water_residual_cm": residual,
        "accepted_outputs_byte_equal_to_unobserved_control": True,
    }
    return {
        "compiler": metadata["compiler"], "build_sha256": digest(manifest),
        "executable_sha256": metadata["executable_sha256"], "log_sha256": digest(log),
        "backend_sha256": next(h for path,h in metadata["source_sha256"].items()
                              if Path(path).name == "mod_fmr_serialized_reference_backend.f90"),
        "input_sha256": metadata["original_inputs_sha256"],
        "values": trial,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("legacy","build-root","controls"):
        parser.add_argument("--"+name,type=Path,required=True)
    args = parser.parse_args()
    lines = (args.legacy/"stdout").read_text(errors="replace").splitlines()
    legacy = record(lines,"LEGACY_WATER_FIRST")
    old_head = record(lines,"LEGACY_WATER_HEAD_FIRST")
    start = next(i for i,line in enumerate(lines) if line.startswith("LEGACY_HEAT_CASE "))
    nodes = [list(map(float,line.split()[1:])) for line in lines[start+1:start+114]]
    widths, initial, end = ([row[i] for row in nodes] for i in (0,7,8))
    result = {opt: audit(args.build_root/f"s5-grass-full-trial-{opt}",args.controls/f"{opt}-water",
                        legacy,end,initial,widths,old_head) for opt in ("O0","O2")}
    assert result["O0"]["values"] == result["O2"]["values"]
    print(json.dumps({
        "canonical_base": "a57d7d532464ad89b7aca918263cf114b6b42185",
        "legacy_build": json.loads((args.legacy/"RESULT.json").read_text()),
        "original_full_step": {"dt_day":legacy[0], "net_rain_cm_day":legacy[1],
                               "qtop_upward_cm_day":legacy[2], "qbottom_upward_cm_day":legacy[3],
                               "matrix_storage_change_cm":legacy[4]},
        "runs": result,
    },indent=2))


if __name__ == "__main__":
    main()
