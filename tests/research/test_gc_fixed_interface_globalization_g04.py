from __future__ import annotations

import json
import math

S0 = 0.10
S1 = 1.0
SM = 0.10
C = 0.20
WS = 0.010
ROOT_Y = 0.03460974498448890
TOL = 1.0e-12
MAX_ITER = 250
STARTS = (-0.23, -0.10, -0.02, 0.0, 0.02, 0.06, 0.10, 0.30)


def require(x: bool, message: str) -> None:
    if not x:
        raise AssertionError(message)


def x_from_y(y: float) -> float:
    disc = (S0 + C) ** 2 + 2.0 * S1 * (WS + C * y)
    if disc <= 0.0:
        raise ValueError("NH03 head outside monotone physical branch")
    return (-(S0 + C) + math.sqrt(disc)) / S1


def exchange(y: float) -> float:
    x = x_from_y(y)
    return C * (x - y)


def physical_slope(y: float) -> float:
    x = x_from_y(y)
    storage_tangent = S0 + S1 * x
    return -C * storage_tangent / (storage_tangent + C)


def residual(y: float) -> float:
    return exchange(y) - SM * y


def predictor_positive_slope() -> float:
    # Frozen production-style predictor tangent at qb=0, preregistered for G04.
    x = (-S0 + math.sqrt(S0 * S0 + 2.0 * S1 * WS)) / S1
    storage_tangent = S0 + S1 * x
    return C * storage_tangent / (storage_tangent + C)


POSITIVE_S = predictor_positive_slope()


def raw_reanchored_update(y: float, slope: float) -> float:
    # E_surr(Y)=E(y)+slope*(Y-y), solve E_surr(Y)=SM*Y.
    denominator = SM - slope
    require(abs(denominator) > 1.0e-14, "surrogate denominator singular")
    return (exchange(y) - slope * y) / denominator


def iterate(policy: str, start: float) -> dict[str, float | int | str]:
    y = start
    max_abs_y = abs(y)
    contractions_total = 0
    history = [y]

    for outer in range(1, MAX_ITER + 1):
        try:
            if policy == "P0":
                proposal = raw_reanchored_update(y, POSITIVE_S)
            elif policy == "P1":
                proposal = raw_reanchored_update(y, physical_slope(y))
            elif policy == "P2":
                proposal = raw_reanchored_update(y, 0.0)
            elif policy == "P3":
                raw = raw_reanchored_update(y, POSITIVE_S)
                p = physical_slope(y)
                rho = (p - POSITIVE_S) / (SM - POSITIVE_S)
                alpha = 1.0 / (1.0 - rho)
                require(0.0 < alpha <= 1.0, "response-derived P3 alpha outside (0,1]")
                proposal = y + alpha * (raw - y)
            elif policy == "P4":
                raw = raw_reanchored_update(y, physical_slope(y))
                proposal = raw
                contractions = 0
                while True:
                    admissible = True
                    try:
                        new_residual = abs(residual(proposal))
                    except ValueError:
                        admissible = False
                        new_residual = math.inf
                    if admissible and new_residual <= abs(residual(y)) + 1.0e-15:
                        break
                    contractions += 1
                    require(contractions <= 20, "P4 safeguard contraction budget exhausted")
                    proposal = y + (raw - y) * (0.5 ** contractions)
                contractions_total += contractions
            else:
                raise ValueError(policy)

            # Physical-domain check is separate from residual convergence.
            _ = exchange(proposal)
        except ValueError:
            return {
                "classification": "INADMISSIBLE",
                "outer": outer,
                "start_y": start,
                "last_y": y,
                "max_abs_y": max_abs_y,
                "contractions": contractions_total,
            }

        y = proposal
        history.append(y)
        max_abs_y = max(max_abs_y, abs(y))

        if abs(y - ROOT_Y) <= TOL:
            return {
                "classification": "CONVERGED",
                "outer": outer,
                "start_y": start,
                "final_y": y,
                "max_abs_y": max_abs_y,
                "contractions": contractions_total,
            }

    return {
        "classification": "MAX_ITER",
        "outer": MAX_ITER,
        "start_y": start,
        "last_y": y,
        "max_abs_y": max_abs_y,
        "contractions": contractions_total,
    }


def main() -> None:
    require(math.isclose(POSITIVE_S, 0.09282032302755092, rel_tol=0.0, abs_tol=1.0e-14),
            "G04 frozen predictor slope changed")
    require(abs(residual(ROOT_Y)) <= 1.0e-14, "NH03 exact root mismatch")

    results: dict[str, list[dict[str, float | int | str]]] = {}
    for policy in ("P0", "P1", "P2", "P3", "P4"):
        rows = []
        for start in STARTS:
            row = iterate(policy, start)
            rows.append(row)
            print("G04_RESULT=" + json.dumps(
                {"policy": policy, **row}, sort_keys=True, separators=(",", ":")
            ))
        results[policy] = rows

    # Frozen decision expectations.
    require(all(row["classification"] == "INADMISSIBLE" for row in results["P0"]),
            "frozen positive predictor surrogate unexpectedly robust in NH03")
    require(all(row["classification"] == "CONVERGED" for row in results["P1"]),
            "physical Newton failed a preregistered NH03 start")
    require(all(row["classification"] == "CONVERGED" for row in results["P2"]),
            "Picard failed a preregistered NH03 start")
    require(all(row["classification"] == "CONVERGED" for row in results["P3"]),
            "response-derived relaxed P0 failed a preregistered NH03 start")
    require(all(row["classification"] == "CONVERGED" for row in results["P4"]),
            "safeguarded physical Newton failed a preregistered NH03 start")

    # The response-derived alpha cancels the local P0 map derivative exactly:
    # alpha=(SM-s)/(SM-p), so alpha*(raw_P0-y) is the Newton step.
    for p1, p3 in zip(results["P1"], results["P3"]):
        require(abs(float(p1["final_y"]) - float(p3["final_y"])) <= 5.0e-15,
                "P3 and physical Newton final roots disagree")
        require(int(p1["outer"]) == int(p3["outer"]),
                "P3 and physical Newton iteration counts disagree")

    # The difficult lower-branch start demonstrates the role of safeguarding:
    # raw Newton converges only after a large excursion, while P4 contracts the
    # step and keeps the iterate within the initial absolute-head envelope.
    difficult_p1 = results["P1"][0]
    difficult_p4 = results["P4"][0]
    require(float(difficult_p1["max_abs_y"]) > 10.0,
            "difficult NH03 Newton start no longer exposes the large excursion")
    require(int(difficult_p4["contractions"]) > 0,
            "P4 safeguard was not exercised on the difficult NH03 start")
    require(float(difficult_p4["max_abs_y"]) <= abs(STARTS[0]) + 1.0e-14,
            "P4 safeguard failed to bound the difficult-start excursion")

    # Picard is robust but deliberately slow near the root where |p|/SM ~0.86.
    picard_iterations = [int(row["outer"]) for row in results["P2"]]
    require(min(picard_iterations) >= 100,
            "NH03 Picard unexpectedly ceased to be the slow contractive baseline")

    print(f"G04_POSITIVE_PREDICTOR_S={POSITIVE_S:.17g}")
    print(f"G04_ROOT_PHYSICAL_P={physical_slope(ROOT_Y):.17g}")
    print(f"G04_ROOT_PICARD_RHO={physical_slope(ROOT_Y)/SM:.17g}")
    print("GC_GLOBALIZATION_G04_NONLINEAR_NH03=PASS")


if __name__ == "__main__":
    main()
