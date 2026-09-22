from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "fgc" / "support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap


DURATIONS = (5.0e-5, 1.0e-4, 2.0e-4)
QBOTS = (5.0e-7, 1.0e-6, 2.0e-6)
EPS = sys.float_info.epsilon
MASS_TOL = 1.0e-12


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def fp_close(actual: float, expected: float, message: str) -> None:
    scale = max(1.0, abs(actual), abs(expected))
    tol = 256.0 * EPS * scale
    require(
        math.isclose(actual, expected, rel_tol=0.0, abs_tol=tol),
        f"{message}: {actual:.17g} != {expected:.17g} (tol={tol:.17g})",
    )


def main() -> None:
    bridge = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(bridge.is_file(), "missing F-GC44 bridge")
    swap = Fgc44RealSwap(bridge)

    rows: list[dict[str, object]] = []
    success_count = 0

    for duration in DURATIONS:
        for qbot in QBOTS:
            status, hcof, rhs, href = swap.try_initialize_configured(
                duration,
                qbot,
            )
            try:
                diag = swap.predictor_run_diagnostics()
            except RuntimeError:
                diag = {
                    "available": False,
                    "result_status": -999,
                    "completed": False,
                    "direction_available": False,
                    "transaction_calls": -1,
                    "accepted_substeps": -1,
                    "attempts": -1,
                    "retries": -1,
                    "trial_rollbacks": -1,
                    "solver_rejections": -1,
                    "temporal_rejections": -1,
                    "temporal_unavailable_rejections": -1,
                    "mass_rejections": -1,
                    "internal_retries": -1,
                    "max_temporal_indicator": float("nan"),
                    "min_accepted_substep_duration": float("nan"),
                    "max_accepted_substep_duration": float("nan"),
                }

            row: dict[str, object] = {
                "duration": duration,
                "qbot": qbot,
                "status": status,
                "hcof": hcof,
                "rhs": rhs,
                "href": href,
                "diag": diag,
            }

            tag = (
                f"D{duration:.0e}_Q{qbot:.0e}"
                .replace("-", "M")
                .replace("+", "P")
            )
            print(f"GC_DSW22D_{tag}_STATUS={status}")
            print(
                f"GC_DSW22D_{tag}_DIAG_AVAILABLE="
                f"{1 if bool(diag['available']) else 0}"
            )
            print(
                f"GC_DSW22D_{tag}_COMPLETED="
                f"{1 if bool(diag['completed']) else 0}"
            )
            print(
                f"GC_DSW22D_{tag}_DIRECTION_AVAILABLE="
                f"{1 if bool(diag['direction_available']) else 0}"
            )
            for key in (
                "result_status",
                "transaction_calls",
                "accepted_substeps",
                "attempts",
                "retries",
                "trial_rollbacks",
                "solver_rejections",
                "temporal_rejections",
                "temporal_unavailable_rejections",
                "mass_rejections",
                "internal_retries",
            ):
                print(f"GC_DSW22D_{tag}_{key.upper()}={int(diag[key])}")
            for key in (
                "max_temporal_indicator",
                "min_accepted_substep_duration",
                "max_accepted_substep_duration",
            ):
                value = float(diag[key])
                print(f"GC_DSW22D_{tag}_{key.upper()}={value:.17g}")

            if status == 0:
                success_count += 1
                e1 = swap.e1_diagnostics()
                row["e1"] = e1

                q_u_expected = (
                    float(e1["u"])
                    * (
                        float(e1["h_end_m"])
                        - float(e1["h_start_m"])
                    )
                    * 100.0
                    / duration
                    - float(e1["q_bot_predictor_cm_per_day"])
                )
                hcof_expected = float(e1["u"]) / duration
                rhs_expected = (
                    hcof_expected * href
                    - 0.01 * float(e1["q_u_cm_per_day"])
                )
                storage_from_mass = (
                    float(e1["total_in_native"])
                    - float(e1["total_out_native"])
                    + float(e1["mass_residual_native"])
                )

                print(f"GC_DSW22D_{tag}_U={float(e1['u']):.17g}")
                print(
                    f"GC_DSW22D_{tag}_Q_U_CM_PER_DAY="
                    f"{float(e1['q_u_cm_per_day']):.17g}"
                )
                print(
                    f"GC_DSW22D_{tag}_STORAGE_CHANGE_NATIVE="
                    f"{float(e1['storage_change_native']):.17g}"
                )
                print(
                    f"GC_DSW22D_{tag}_MASS_RESIDUAL_NATIVE="
                    f"{float(e1['mass_residual_native']):.17g}"
                )
                print(f"GC_DSW22D_{tag}_HCOF={hcof:.17g}")
                print(f"GC_DSW22D_{tag}_RHS={rhs:.17g}")
                print(f"GC_DSW22D_{tag}_HREF_M={href:.17g}")

                require(bool(e1["mass_complete"]), f"{tag} mass not complete")
                fp_close(
                    float(e1["q_bot_predictor_cm_per_day"]),
                    qbot,
                    f"{tag} configured qbot",
                )
                fp_close(
                    float(e1["q_u_cm_per_day"]),
                    q_u_expected,
                    f"{tag} q_u reconstruction",
                )
                fp_close(hcof, hcof_expected, f"{tag} HCOF=u/dt")
                fp_close(rhs, rhs_expected, f"{tag} RHS transform")
                require(
                    abs(
                        float(e1["storage_change_native"])
                        - storage_from_mass
                    )
                    <= MASS_TOL,
                    f"{tag} physical mass identity",
                )
                require(
                    abs(float(e1["storage_change_native"])) <= MASS_TOL,
                    f"{tag} expected zero net inventory change",
                )
                require(
                    math.isfinite(float(e1["u"]))
                    and abs(float(e1["u"])) > 1.0e-12,
                    f"{tag} nonzero finite u",
                )
                print(f"GC_DSW22D_{tag}_SUCCESS_SEMANTICS=PASS")

            rows.append(row)

    first = next(
        row
        for row in rows
        if math.isclose(float(row["duration"]), 5.0e-5)
        and math.isclose(float(row["qbot"]), 5.0e-7)
    )
    require(
        int(first["status"]) == 104,
        f"original falsified first case changed: {first}",
    )

    center = next(
        row
        for row in rows
        if math.isclose(float(row["duration"]), 1.0e-4)
        and math.isclose(float(row["qbot"]), 1.0e-6)
    )
    require(
        int(center["status"]) == 0,
        f"F-GC44 default positive control failed: {center}",
    )

    require(len(rows) == 9, "did not execute the complete fixed 3x3 matrix")
    require(success_count >= 1, "no successful semantic-control case")

    status_matrix = ";".join(
        f"{float(row['duration']):.0e}/{float(row['qbot']):.0e}:{int(row['status'])}"
        for row in rows
    )
    print(f"GC_DSW22D_STATUS_MATRIX={status_matrix}")
    print(f"GC_DSW22D_SUCCESS_COUNT={success_count}")
    print("GC_DSW22D_ORIGINAL_FALSIFICATION_PRESERVED=PASS")
    print("GC_DSW22D_FGC44_DEFAULT_POSITIVE_CONTROL=PASS")
    print("GC_DSW22D_SUCCESSFUL_CASE_ALGEBRA_AND_MASS=PASS")
    print("GC_DSW22D_COMPLETE_FIXED_MATRIX=PASS")
    print("GC_DSW22D_DIAGNOSTIC_GATE=PASS")


if __name__ == "__main__":
    main()
