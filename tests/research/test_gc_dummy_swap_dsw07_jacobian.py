from __future__ import annotations

import math


H0 = 8.0
DT = 1.0


def residual(
    head: float,
    s_mf: float,
    hcof: float,
    rhs: float,
) -> float:
    return s_mf * (head - H0) / DT - hcof * head + rhs


def exact_jacobian(s_mf: float, hcof: float) -> float:
    return s_mf / DT - hcof


def centered_jacobian(
    head: float,
    s_mf: float,
    hcof: float,
    rhs: float,
    eps: float = 1.0e-6,
) -> float:
    return (
        residual(head + eps, s_mf, hcof, rhs)
        - residual(head - eps, s_mf, hcof, rhs)
    ) / (2.0 * eps)


def require_close(
    actual: float,
    expected: float,
    name: str,
    atol: float = 1.0e-9,
) -> None:
    if not math.isclose(actual, expected, rel_tol=0.0, abs_tol=atol):
        raise AssertionError(
            f"{name}: {actual:.17g} != {expected:.17g}"
        )


def main() -> None:
    # Consistent shared-storage partition:
    # S_total=0.20, split 0.10/0.10, R=0.01 m/day.
    s_mf = 0.10
    s_swap = 0.10
    rain = 0.010
    hcof = -s_swap / DT
    rhs = hcof * H0 - rain

    jac = exact_jacobian(s_mf, hcof)
    require_close(jac, 0.20, "consistent total-storage Jacobian")
    for head in (7.5, 8.0, 8.05, 8.5, 9.0):
        fd = centered_jacobian(head, s_mf, hcof, rhs)
        require_close(fd, jac, f"finite-difference Jacobian at {head}")

    require_close(
        residual(8.05, s_mf, hcof, rhs),
        0.0,
        "consistent physical root",
        atol=1.0e-14,
    )

    # Deliberately overlapping current-positive-u DSW-01 construction.
    s_mf = 0.20
    u = 0.20
    hcof = u / DT
    rhs = 1.60

    jac = exact_jacobian(s_mf, hcof)
    require_close(jac, 0.0, "positive-u overlap Jacobian", atol=1.0e-15)

    for head in (0.0, 4.0, 7.0, 8.0, 8.05, 9.0, 12.0):
        value = residual(head, s_mf, hcof, rhs)
        require_close(
            value,
            0.0,
            f"DSW-01 overlap residual at H={head}",
            atol=1.0e-14,
        )
        fd = centered_jacobian(head, s_mf, hcof, rhs)
        require_close(
            fd,
            0.0,
            f"DSW-01 overlap FD Jacobian at H={head}",
            atol=1.0e-9,
        )

    print("GC_DSW07_STO_API_RESIDUAL_IDENTITY=PASS")
    print("GC_DSW07_CONSISTENT_TOTAL_STORAGE_JACOBIAN=PASS")
    print("GC_DSW07_CENTERED_FD_JACOBIAN=PASS")
    print("GC_DSW07_POSITIVE_U_ZERO_JACOBIAN=PASS")
    print("GC_DSW07_DSW01_RESIDUAL_IDENTICALLY_ZERO=PASS")
    print("GC_DSW07_ANALYTIC_GATE=PASS")


if __name__ == "__main__":
    main()
