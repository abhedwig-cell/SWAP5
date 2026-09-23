from __future__ import annotations

from dataclasses import asdict
import json

from q2a_policy import (
    AcceptedHydraulicView,
    AcceptedPolicyState,
    AutomaticManagementConfig,
    commit_policy_trial,
    evaluate_policy_trial,
)

TOL = 1.0e-12

CFG = AutomaticManagementConfig(
    wlsman_cm=(-60.0, -40.0, -20.0),
    gwlcrit_cm=(0.0, -50.0, -100.0),
    vcrit_cm=(0.0, 20.0, 40.0),
    hcrit_cm=(0.0, -50.0, -100.0),
    dropr_cm_per_day=5.0,
)

CASES = [
    dict(id="P0_HIGH_PHASE", event=True, gwl=-150.0, vair=50.0, h=-150.0, accepted=-20.0, dt=1.0, phase=3, requested=-20.0, target=-20.0),
    dict(id="P1_GWL_TO_PHASE2", event=True, gwl=-80.0, vair=50.0, h=-150.0, accepted=-20.0, dt=1.0, phase=2, requested=-40.0, target=-25.0),
    dict(id="P2_AIR_TO_PHASE2", event=True, gwl=-150.0, vair=30.0, h=-150.0, accepted=-20.0, dt=1.0, phase=2, requested=-40.0, target=-25.0),
    dict(id="P3_HEAD_TO_PHASE2", event=True, gwl=-150.0, vair=50.0, h=-80.0, accepted=-20.0, dt=1.0, phase=2, requested=-40.0, target=-25.0),
    dict(id="P4_COMBINED_TO_PHASE1", event=True, gwl=-80.0, vair=10.0, h=10.0, accepted=-20.0, dt=2.0, phase=1, requested=-60.0, target=-30.0),
    dict(id="P5_EQUALITY_SEAMS_STAY_PHASE3", event=True, gwl=-100.0, vair=40.0, h=-100.0, accepted=-20.0, dt=1.0, phase=3, requested=-20.0, target=-20.0),
    dict(id="P6_BETWEEN_EVENT_MEMORY", event=False, gwl=10.0, vair=-1.0, h=10.0, accepted=-35.0, dt=9.0, phase=None, requested=-35.0, target=-35.0),
    dict(id="P7_UPWARD_IMMEDIATE", event=True, gwl=-150.0, vair=50.0, h=-150.0, accepted=-60.0, dt=0.25, phase=3, requested=-20.0, target=-20.0),
]


def close(a: float, b: float) -> bool:
    return abs(a - b) <= TOL


def run_frozen_cases() -> list[dict]:
    evidence = []
    for case in CASES:
        accepted = AcceptedPolicyState(wlstar_cm=case["accepted"])
        view = AcceptedHydraulicView(
            groundwater_level_cm=case["gwl"],
            total_air_volume_cm=case["vair"],
            selected_pressure_head_cm=case["h"],
        )
        trial = evaluate_policy_trial(
            CFG,
            accepted,
            view,
            adjustment_event=case["event"],
            dt_day=case["dt"],
        )
        assert accepted.wlstar_cm == case["accepted"], f"{case['id']} mutated accepted state"
        assert trial.selected_phase == case["phase"], (case["id"], trial.selected_phase)
        assert close(trial.requested_target_cm, case["requested"]), (case["id"], trial.requested_target_cm)
        assert close(trial.candidate_wlstar_cm, case["target"]), (case["id"], trial.candidate_wlstar_cm)
        evidence.append({"id": case["id"], **asdict(trial)})
        print(
            f"SW_RIB_SWM01_Q2A_CASE_PASS={case['id']} "
            f"phase={trial.selected_phase} requested_cm={trial.requested_target_cm:.12g} "
            f"candidate_cm={trial.candidate_wlstar_cm:.12g}"
        )
    return evidence


def run_transaction_cases() -> dict:
    origin = AcceptedPolicyState(wlstar_cm=-20.0)
    view = AcceptedHydraulicView(
        groundwater_level_cm=-80.0,
        total_air_volume_cm=10.0,
        selected_pressure_head_cm=10.0,
    )

    rejected = evaluate_policy_trial(
        CFG, origin, view, adjustment_event=True, dt_day=2.0
    )
    assert close(rejected.candidate_wlstar_cm, -30.0)
    assert close(origin.wlstar_cm, -20.0)

    replay = evaluate_policy_trial(
        CFG, origin, view, adjustment_event=True, dt_day=2.0
    )
    assert replay == rejected

    committed = commit_policy_trial(origin, replay)
    assert close(committed.wlstar_cm, -30.0)

    retry_from_same_origin = evaluate_policy_trial(
        CFG, origin, view, adjustment_event=True, dt_day=1.0
    )
    assert close(retry_from_same_origin.candidate_wlstar_cm, -25.0)
    assert close(origin.wlstar_cm, -20.0)

    try:
        commit_policy_trial(committed, replay)
    except ValueError:
        stale_commit_fail_closed = True
    else:
        stale_commit_fail_closed = False
    assert stale_commit_fail_closed

    print("SW_RIB_SWM01_Q2A_ROLLBACK=PASS")
    print("SW_RIB_SWM01_Q2A_REPLAY=PASS")
    print("SW_RIB_SWM01_Q2A_EXPLICIT_COMMIT=PASS")
    print("SW_RIB_SWM01_Q2A_STALE_COMMIT_FAIL_CLOSED=PASS")

    return {
        "rejected": asdict(rejected),
        "replay_identical": replay == rejected,
        "committed": asdict(committed),
        "retry_from_same_origin": asdict(retry_from_same_origin),
        "stale_commit_fail_closed": stale_commit_fail_closed,
    }


def run_dropr_threshold_case() -> dict:
    cfg = AutomaticManagementConfig(
        wlsman_cm=(-60.0, -40.0, -20.0),
        gwlcrit_cm=(0.0, -50.0, -100.0),
        vcrit_cm=(0.0, 20.0, 40.0),
        hcrit_cm=(0.0, -50.0, -100.0),
        dropr_cm_per_day=0.001,
    )
    accepted = AcceptedPolicyState(wlstar_cm=-20.0)
    view = AcceptedHydraulicView(
        groundwater_level_cm=10.0,
        total_air_volume_cm=-1.0,
        selected_pressure_head_cm=10.0,
    )
    trial = evaluate_policy_trial(
        cfg, accepted, view, adjustment_event=True, dt_day=1.0
    )
    assert trial.selected_phase == 1
    assert close(trial.requested_target_cm, -60.0)
    assert close(trial.candidate_wlstar_cm, -60.0)
    print("SW_RIB_SWM01_Q2A_DROPR_EQUALITY_SEAM=PASS")
    return asdict(trial)


def main() -> None:
    result = {
        "frozen_cases": run_frozen_cases(),
        "transaction": run_transaction_cases(),
        "dropr_threshold": run_dropr_threshold_case(),
    }
    print("SW_RIB_SWM01_Q2A_RESULT_JSON=" + json.dumps(result, sort_keys=True))
    print("SW_RIB_SWM01_Q2A_ACCEPTED_STATE_POLICY=PASS")


if __name__ == "__main__":
    main()
