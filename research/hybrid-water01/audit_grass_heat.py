"""Audit the observed accepted Grassgrowth steps against their published budgets."""
import argparse
import csv
from hashlib import sha256
import json
from math import fsum, isfinite
from pathlib import Path

FIELDS = (
    "t0", "t1", "water_storage_cm", "water_residual_cm", "conductive_storage",
    "conductive_input", "mixture_storage", "water_capacity", "air_capacity",
    "top_water_in", "bottom_water_in", "source_water_in",
    "top_out_heat_at_end_temperature", "bottom_out_heat_at_end_temperature",
    "nodal_out_heat_at_end_temperature",
)


def read_rows(path):
    with path.open(newline="") as stream:
        return list(csv.DictReader(stream))


def audit(logs, cases):
    observations = {}
    for log in logs:
        for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
            if not line.startswith("GRASS_HEAT_ACCEPTED "):
                continue
            _, day, *values = line.split()
            row = dict(zip(FIELDS, map(float, values), strict=True))
            assert all(map(isfinite, row.values()))
            observations.setdefault(int(day), []).append(row)

    budgets = [row for case in cases for row in read_rows(case / "conductive_budget.csv")]
    assert list(observations) == [int(row["day"]) for row in budgets] and budgets
    result = []
    for budget in budgets:
        day = int(budget["day"])
        steps = observations[day]
        accepted_intervals = int(budget["accepted_steps"])
        assert accepted_intervals <= len(steps) <= 2 * accepted_intervals
        assert steps[0]["t0"] == day - 1 and steps[-1]["t1"] == float(budget["t1"])
        assert all(a["t1"] == b["t0"] for a, b in zip(steps, steps[1:]))
        assert all(step["t1"] > step["t0"] for step in steps)
        total = lambda key: fsum(step[key] for step in steps)
        water_residual = max(abs(step["water_residual_cm"]) for step in steps)
        assert water_residual < 1e-10
        conductive = total("conductive_input")
        assert abs(conductive - (float(budget["top_in_j_cm2"]) + float(budget["bottom_in_j_cm2"]))) < 1e-8
        storage = total("conductive_storage")
        assert abs(storage - float(budget["storage_change_j_cm2"])) < 1e-8
        split_error = max(abs(fsum((step["mixture_storage"], -step["conductive_storage"],
                                   -step["water_capacity"], -step["air_capacity"]))) for step in steps)
        assert split_error < 1e-8
        inflow_keys = ("top_water_in", "bottom_water_in", "source_water_in")
        positive_inflow = {key: fsum(max(0.0, step[key]) for step in steps) for key in inflow_keys}
        first_missing_donor = next((step["t0"] for step in steps
                                    if any(step[key] > 0 for key in inflow_keys)), None)
        result.append({
            "day": day,
            "accepted_adaptive_intervals": accepted_intervals,
            "accepted_thermal_leaves": len(steps),
            "max_step_water_residual_cm": water_residual,
            "max_step_mixture_split_error_j_cm2": split_error,
            "conductive_input_j_cm2": conductive,
            "conductive_storage_j_cm2": storage,
            "mixture_storage_j_cm2": total("mixture_storage"),
            "water_capacity_term_j_cm2": total("water_capacity"),
            "air_capacity_term_j_cm2": total("air_capacity"),
            "inflow_with_unobserved_donor_temperature_cm": positive_inflow,
            "first_inflow_missing_donor_t0_day": first_missing_donor,
            "unobserved_inflow_energy_per_kelvin_j_cm2": 4.18 * fsum(positive_inflow.values()),
            "outflow_heat_at_end_temperature_j_cm2": {
                key: total(key) for key in FIELDS[-3:]
            },
        })
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--resume", type=Path)
    args = parser.parse_args()
    build = json.loads((args.build / "BUILD.json").read_text())
    assert build["native_returncode"] == 0
    event, = [i for i, event in enumerate(build["events"]) if event["label"] == "native_original_initial_interval"]
    logs = [args.build / f"{event}.stdout"]
    cases = [args.build / "original-interval"]
    if args.resume:
        logs.append(args.resume / "stdout")
        cases.append(args.resume)
    print(json.dumps({
        "executable_sha256": build["executable_sha256"],
        "compiler": build["compiler"],
        "input_sha256": build["original_inputs_sha256"],
        "observer_source_sha256": next(digest for name, digest in build["source_sha256"].items()
                                        if Path(name).name == "initial_interval.f90"),
        "observation_log_sha256": [sha256(log.read_bytes()).hexdigest() for log in logs],
        "days": audit(logs, cases),
    }, indent=2))


if __name__ == "__main__":
    main()
