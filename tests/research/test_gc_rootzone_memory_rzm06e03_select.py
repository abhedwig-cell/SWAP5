from __future__ import annotations
import argparse
import json
import math
from pathlib import Path

NODES = 16
DZ_CM = 10.0
Z_CM = [-5.0 - 10.0 * i for i in range(NODES)]
W_TOL_CM = 1e-4
ROOT30_TOL_CM = 1e-4
M1_MIN_CM = 1e-2

STATE_ALLOWED = {"FAMILY", "PHASE", "STEP", "PHASE_STEP", "T"}
NODE_ALLOWED = {"FAMILY", "PHASE", "STEP", "NODE", "H", "THETA"}


def extract(line: str, allowed: set[str]) -> dict[str, str]:
    out: dict[str, str] = {}
    for token in line.rstrip("\n").split("|")[1:]:
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        if key in allowed:
            out[key] = value
    return out


def observables(theta: list[float]) -> tuple[float, float, float]:
    profile = math.fsum(v * DZ_CM for v in theta)
    root30 = math.fsum(theta[i] * DZ_CM for i in range(3))
    moment = math.fsum(theta[i] * DZ_CM * Z_CM[i] for i in range(NODES)) / profile
    return profile, root30, moment


def parse(path: Path):
    raw = path.read_bytes()
    states: dict[tuple[str, int], dict] = {}
    nodes: dict[tuple[str, int], dict[int, tuple[float, float]]] = {}
    stops: list[str] = []

    for line in raw.decode("utf-8").splitlines():
        if line.startswith("RZM06E03_STATE|"):
            fields = extract(line, STATE_ALLOWED)
            assert set(fields) == STATE_ALLOWED, fields
            key = (fields["FAMILY"], int(fields["STEP"]))
            assert key not in states, key
            states[key] = {
                "family": fields["FAMILY"],
                "phase": fields["PHASE"],
                "step": int(fields["STEP"]),
                "phase_step": int(fields["PHASE_STEP"]),
                "time_day": float(fields["T"]),
            }
        elif line.startswith("RZM06E03_NODE|"):
            fields = extract(line, NODE_ALLOWED)
            assert set(fields) == NODE_ALLOWED, fields
            key = (fields["FAMILY"], int(fields["STEP"]))
            node = int(fields["NODE"])
            assert 1 <= node <= NODES
            nodes.setdefault(key, {})[node] = (float(fields["H"]), float(fields["THETA"]))
        elif line.startswith("RZM06E03_STOP|"):
            stops.append(line)

    records = []
    for key, meta in states.items():
        ns = nodes.get(key, {})
        assert len(ns) == NODES, (key, len(ns))
        h = [ns[i][0] for i in range(1, NODES + 1)]
        theta = [ns[i][1] for i in range(1, NODES + 1)]
        assert all(math.isfinite(x) for x in h + theta)
        profile, root30, moment = observables(theta)
        records.append(
            {
                **meta,
                "pressure_head_cm": h,
                "water_content": theta,
                "profile_water_cm": profile,
                "root30_water_cm": root30,
                "distribution_moment_cm": moment,
            }
        )
    records.sort(key=lambda r: (r["family"], r["step"]))
    return raw, records, stops


def pair_metrics(a: dict, b: dict) -> dict:
    return {
        "abs_delta_profile_water_cm": abs(b["profile_water_cm"] - a["profile_water_cm"]),
        "abs_delta_root30_water_cm": abs(b["root30_water_cm"] - a["root30_water_cm"]),
        "abs_delta_distribution_moment_cm": abs(
            b["distribution_moment_cm"] - a["distribution_moment_cm"]
        ),
    }


def compact_origin(r: dict) -> dict:
    return {
        "family": r["family"],
        "phase": r["phase"],
        "step": r["step"],
        "phase_step": r["phase_step"],
        "time_day": r["time_day"],
        "profile_water_cm": r["profile_water_cm"],
        "root30_water_cm": r["root30_water_cm"],
        "distribution_moment_cm": r["distribution_moment_cm"],
        "pressure_head_cm": r["pressure_head_cm"],
        "water_content": r["water_content"],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--o0", required=True)
    parser.add_argument("--o2", required=True)
    args = parser.parse_args()

    raw0, records0, stops0 = parse(Path(args.o0))
    raw2, records2, stops2 = parse(Path(args.o2))
    assert raw0 == raw2, "E03 O0/O2 output drift"
    assert records0 == records2
    assert stops0 == stops2

    base = [r for r in records0 if r["family"] == "BASE_EQ" and r["phase"] == "CONTROL"]
    assert len(base) == 1, len(base)
    base = base[0]
    recover = [r for r in records0 if r["phase"] == "RECOVER"]

    eligible: list[tuple[dict, dict]] = [(base, r) for r in recover]
    dry = [r for r in recover if r["family"] == "DRY_RECOVER"]
    wet = [r for r in recover if r["family"] == "WET_RECOVER"]
    eligible.extend((a, b) for a in dry for b in wet)

    qualifying = []
    water_root_matched = []
    best_m1_any = None
    closest_root = None

    for a, b in eligible:
        metrics = pair_metrics(a, b)
        rec = {"A": a, "B": b, **metrics}
        if (
            best_m1_any is None
            or metrics["abs_delta_distribution_moment_cm"]
            > best_m1_any["abs_delta_distribution_moment_cm"]
        ):
            best_m1_any = rec
        if (
            metrics["abs_delta_profile_water_cm"] <= W_TOL_CM
            and (closest_root is None
                 or metrics["abs_delta_root30_water_cm"] < closest_root["abs_delta_root30_water_cm"])
        ):
            closest_root = rec
        if (
            metrics["abs_delta_profile_water_cm"] <= W_TOL_CM
            and metrics["abs_delta_root30_water_cm"] <= ROOT30_TOL_CM
        ):
            water_root_matched.append(rec)
            if metrics["abs_delta_distribution_moment_cm"] >= M1_MIN_CM:
                qualifying.append(rec)

    qualifying.sort(
        key=lambda r: (
            -r["abs_delta_distribution_moment_cm"],
            r["abs_delta_root30_water_cm"],
            r["abs_delta_profile_water_cm"],
            r["A"]["step"] + r["B"]["step"],
            r["A"]["family"],
            r["B"]["family"],
        )
    )

    selected = None
    disposition = "NO_MATCH"
    if qualifying:
        r = qualifying[0]
        selected = {
            "A": compact_origin(r["A"]),
            "B": compact_origin(r["B"]),
            "abs_delta_profile_water_cm": r["abs_delta_profile_water_cm"],
            "abs_delta_root30_water_cm": r["abs_delta_root30_water_cm"],
            "abs_delta_distribution_moment_cm": r["abs_delta_distribution_moment_cm"],
        }
        disposition = "SELECTED_RESPONSE_BLIND_ROOTMATCHED_DEEP_MEMORY_PAIR"

    def summarize_pair(r):
        if r is None:
            return None
        return {
            "A": {"family": r["A"]["family"], "phase": r["A"]["phase"], "step": r["A"]["step"]},
            "B": {"family": r["B"]["family"], "phase": r["B"]["phase"], "step": r["B"]["step"]},
            "abs_delta_profile_water_cm": r["abs_delta_profile_water_cm"],
            "abs_delta_root30_water_cm": r["abs_delta_root30_water_cm"],
            "abs_delta_distribution_moment_cm": r["abs_delta_distribution_moment_cm"],
            "fraction_of_M1_requirement": r["abs_delta_distribution_moment_cm"] / M1_MIN_CM,
        }

    evidence = {
        "schema": "swap5.gc_rootzone_memory.rzm06e03.rootmatched_deep_memory_selection.v1",
        "preregistration_commit": "e6543e57bed84ec22615ea68f14f66ec400362cd",
        "production_changes": False,
        "firewall": {
            "response_fields_parsed": False,
            "external_library_used": False,
            "state_fields": sorted(STATE_ALLOWED),
            "node_fields": sorted(NODE_ALLOWED),
        },
        "generation": {
            "accepted_state_count": len(records0),
            "recover_state_count": len(recover),
            "accepted_by_family": {
                family: sum(1 for r in records0 if r["family"] == family)
                for family in ("BASE_EQ", "DRY_RECOVER", "WET_RECOVER")
            },
            "stop_records": stops0,
        },
        "frozen_gate": {
            "max_abs_profile_water_difference_cm": W_TOL_CM,
            "max_abs_root30_water_difference_cm": ROOT30_TOL_CM,
            "min_abs_distribution_moment_difference_cm": M1_MIN_CM,
        },
        "census": {
            "eligible_pairs": len(eligible),
            "water_root_matched_pairs": len(water_root_matched),
            "qualifying_pairs": len(qualifying),
            "best_M1_any_pair": summarize_pair(best_m1_any),
            "closest_root_pair_with_profile_water_gate": summarize_pair(closest_root),
        },
        "selected_pair": selected,
        "disposition": disposition,
        "nonclaims": [
            "E03 performs no fixed-Hc response probe",
            "selection uses only committed pressure-head and water-content state",
            "selection alone does not establish response-memory causality",
        ],
    }

    print("RZM06E03_SELECTION_JSON", json.dumps(evidence, sort_keys=True, separators=(",", ":")))
    print("GC_RZM06E03_RESPONSE_BLIND_SELECTION=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
