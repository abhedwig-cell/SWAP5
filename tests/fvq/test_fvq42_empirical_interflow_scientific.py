#!/usr/bin/env python3
import hashlib
import json
import math
import random
import subprocess
import sys
import tempfile
from pathlib import Path

BASE = "3553c63e753bbf714378cd0dff5047769ad3185b"
CANDIDATE = "66199567e95369f42bbc75b1b279aa959050a733"
CANDIDATE_PATH = "src/process/mod_drainage_empirical_interflow_response.f90"
CANDIDATE_BLOB = "eb53096b678d08b76d3fb1adb2247bc2a58ee748"
DRAINAGE_SHA256 = "48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc"
MANIFEST = Path("reference/swap-4.3.1/b0/file-manifest.sha256")


def sh(*args, input_text=None, check=True):
    return subprocess.run(args, input=input_text, text=True, capture_output=True, check=check)


def require(condition, marker, detail=""):
    if not condition:
        print(f"{marker}=FAIL" + (f" {detail}" if detail else ""))
        raise AssertionError(marker)
    print(f"{marker}=PASS")


def close(a, b, atol=5.0e-13, rtol=5.0e-13):
    return abs(a - b) <= atol + rtol * max(abs(a), abs(b))


def legacy_active_oracle(coefficient, exponent, difference):
    return coefficient * difference ** exponent


def legacy_active_tangent_oracle(coefficient, exponent, difference):
    return coefficient * exponent * difference ** (exponent - 1.0)


def write_sources(tmp, candidate_source):
    Path(tmp, "mod_process_hydraulic_view.f90").write_text(
        "module mod_process_hydraulic_view\n"
        "  use, intrinsic :: iso_fortran_env, only: real64\n"
        "  implicit none\n"
        "  type :: process_hydraulic_view_t\n"
        "    real(real64) :: groundwater_level = 0.0_real64\n"
        "  end type process_hydraulic_view_t\n"
        "end module mod_process_hydraulic_view\n"
    )
    Path(tmp, "candidate.f90").write_text(candidate_source)
    Path(tmp, "driver.f90").write_text(
        """program fvq42_driver
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_empirical_interflow_response
  implicit none
  type(empirical_interflow_parameters_t) :: p
  type(empirical_interflow_control_t) :: c
  type(process_hydraulic_view_t) :: h
  type(empirical_interflow_response_t) :: r
  type(empirical_interflow_diagnostics_t) :: d
  integer :: n, i
  real(real64) :: gwl
  read(*,*) p%coefficient, p%exponent, c%drain_head, n
  do i=1,n
    read(*,*) gwl
    h%groundwater_level = gwl
    call evaluate_empirical_interflow_response(p,c,h,r,d)
    write(*,'(I0,1X,L1,1X,L1,1X,L1,1X,L1,1X,L1,1X,L1,1X,L1,1X,ES26.17E3,1X,L1,1X,ES26.17E3,1X,ES26.17E3)') &
      d%status, d%evaluated, d%active, d%inactive_below_activation, d%at_activation, &
      d%singular_activation_tangent, d%drainage_side_activation_tangent_defined, &
      d%tangent_numerically_unrepresentable, d%drainage_side_activation_tangent, &
      r%derivative_defined, r%dq_dgroundwater_level, r%signed_soil_to_drain_rate
  end do
end program fvq42_driver
"""
    )


def compile_driver(tmp, optimization):
    exe = Path(tmp, f"driver_{optimization.replace('-', '')}")
    cp = sh(
        "gfortran", "-std=f2008", "-Wall", "-Wextra", "-Werror=compare-reals", optimization,
        "-J", tmp, "-I", tmp,
        str(Path(tmp, "mod_process_hydraulic_view.f90")),
        str(Path(tmp, "candidate.f90")),
        str(Path(tmp, "driver.f90")),
        "-o", str(exe), check=False,
    )
    if cp.returncode != 0:
        print(cp.stdout)
        print(cp.stderr, file=sys.stderr)
        raise RuntimeError(f"compile failed {optimization}")
    return exe


def run_points(exe, coefficient, exponent, drain_head, groundwater_levels):
    payload = [f"{coefficient:.17g} {exponent:.17g} {drain_head:.17g} {len(groundwater_levels)}"]
    payload.extend(f"{g:.17g}" for g in groundwater_levels)
    cp = sh(str(exe), input_text="\n".join(payload) + "\n")
    rows = []
    for line in cp.stdout.splitlines():
        p = line.split()
        rows.append({
            "status": int(p[0]),
            "evaluated": p[1] == "T",
            "active": p[2] == "T",
            "inactive": p[3] == "T",
            "activation": p[4] == "T",
            "singular": p[5] == "T",
            "right_defined": p[6] == "T",
            "tangent_unrepresentable": p[7] == "T",
            "right_tangent": float(p[8]),
            "derivative_defined": p[9] == "T",
            "dq": float(p[10]),
            "q": float(p[11]),
        })
    if len(rows) != len(groundwater_levels):
        raise RuntimeError(f"unexpected row count {len(rows)} != {len(groundwater_levels)}")
    return rows


def compare_routes(rows0, rows2):
    if len(rows0) != len(rows2):
        return False
    bool_keys = ["status", "evaluated", "active", "inactive", "activation", "singular", "right_defined", "tangent_unrepresentable", "derivative_defined"]
    for a, b in zip(rows0, rows2):
        if any(a[k] != b[k] for k in bool_keys):
            return False
        for k in ("right_tangent", "dq", "q"):
            if not close(a[k], b[k], atol=2.0e-14, rtol=2.0e-14):
                return False
    return True


def active_cases():
    cases = []
    coefficients = [0.01, 0.03, 0.5, 1.0, 3.7, 10.0]
    exponents = [0.1, 0.2, 0.5, 0.75, 0.999, 1.0]
    decades = [1.0e-250, 1.0e-150, 1.0e-80, 1.0e-20, 1.0e-8, 1.0e-3, 0.1, 1.0, 10.0, 1.0e6, 1.0e40, 1.0e100, 1.0e200, 1.0e250]
    for a in coefficients:
        for b in exponents:
            for d in decades:
                cases.append((a, b, 0.0, d))

    rng = random.Random(420803)
    for _ in range(900):
        a = 10.0 ** rng.uniform(math.log10(0.01), math.log10(10.0))
        b = rng.uniform(0.1, 1.0)
        drain = rng.uniform(-5000.0, 5000.0)
        d = 10.0 ** rng.uniform(-4.0, 6.0)
        gwl = drain + d
        actual_d = gwl - drain
        if actual_d > 0.0 and math.isfinite(actual_d):
            cases.append((a, b, drain, gwl))
    return cases


def main():
    manifest = MANIFEST.read_text()
    require(DRAINAGE_SHA256 in manifest and "SWAP/drainage.f90" in manifest, "FVQ42_FROZEN_DRAINAGE_SOURCE_IDENTITY")

    blob = sh("git", "rev-parse", f"{CANDIDATE}:{CANDIDATE_PATH}").stdout.strip()
    require(blob == CANDIDATE_BLOB, "FVQ42_CANDIDATE_CLOSEOUT_BLOB_IDENTITY", blob)
    source = sh("git", "show", f"{CANDIDATE}:{CANDIDATE_PATH}").stdout
    low = source.lower()
    for forbidden in ["headcalc", "open(", "read(", ".dra", "owltab", "jacobian", "smooth", "clip", "tolerance"]:
        require(forbidden not in low, "FVQ42_NO_FORBIDDEN_PROCESS_LEAKAGE", forbidden)
    require("difference**parameters%exponent" in low, "FVQ42_ACTIVE_POWER_LAW_STATIC_BINDING")
    require("tangent_numerically_unrepresentable" in low and "process_side_tangent_regularization" in low,
            "FVQ42_EXPLICIT_SENSITIVITY_DIAGNOSTIC_STATIC_BINDING")

    active_count = 0
    derivative_formula_checks = 0
    fd_checks = 0
    inactive_checks = 0
    activation_checks = 0
    max_flux_abs = 0.0
    max_flux_rel = 0.0
    max_dq_abs = 0.0
    max_dq_rel = 0.0
    max_fd_rel = 0.0
    route_consistent = True

    with tempfile.TemporaryDirectory(prefix="fvq42_") as tmp:
        write_sources(tmp, source)
        exe0 = compile_driver(tmp, "-O0")
        exe2 = compile_driver(tmp, "-O2")

        for a, b, drain, gwl in active_cases():
            rows0 = run_points(exe0, a, b, drain, [gwl])
            rows2 = run_points(exe2, a, b, drain, [gwl])
            route_consistent = route_consistent and compare_routes(rows0, rows2)
            row = rows0[0]
            difference = float(gwl) - float(drain)
            q_ref = legacy_active_oracle(a, b, difference)
            dq_ref = legacy_active_tangent_oracle(a, b, difference)
            if not (math.isfinite(q_ref) and math.isfinite(dq_ref)):
                continue
            if row["status"] != 0 or not row["evaluated"] or not row["active"]:
                raise AssertionError(f"active case rejected a={a} b={b} d={difference} row={row}")
            if not row["derivative_defined"]:
                raise AssertionError(f"active finite tangent unavailable a={a} b={b} d={difference}")
            qerr = abs(row["q"] - q_ref)
            dqerr = abs(row["dq"] - dq_ref)
            max_flux_abs = max(max_flux_abs, qerr)
            max_flux_rel = max(max_flux_rel, qerr / max(abs(q_ref), 1.0e-300))
            max_dq_abs = max(max_dq_abs, dqerr)
            max_dq_rel = max(max_dq_rel, dqerr / max(abs(dq_ref), 1.0e-300))
            if not close(row["q"], q_ref, atol=2.0e-12, rtol=2.0e-12):
                raise AssertionError(f"flux mismatch a={a} b={b} d={difference} got={row['q']} ref={q_ref}")
            if not close(row["dq"], dq_ref, atol=3.0e-12, rtol=3.0e-12):
                raise AssertionError(f"tangent mismatch a={a} b={b} d={difference} got={row['dq']} ref={dq_ref}")
            active_count += 1
            derivative_formula_checks += 1

        require(route_consistent, "FVQ42_O0_O2_NUMERICAL_ROUTE_CONSISTENCY")
        require(active_count >= 1300, "FVQ42_ACTIVE_BRANCH_COVERAGE")
        require(True, "FVQ42_ACTIVE_BRANCH_FLUX_EQUIVALENCE")
        require(True, "FVQ42_ACTIVE_ANALYTIC_TANGENT_EQUIVALENCE")

        fd_cases = [
            (0.01, 0.1, 1.0e-3), (0.5, 0.2, 0.1), (1.0, 0.5, 1.0),
            (3.7, 0.75, 10.0), (10.0, 0.999, 100.0), (10.0, 1.0, 1.0e4),
        ]
        for a, b, d in fd_cases:
            h = d * 1.0e-5
            rows = run_points(exe0, a, b, 0.0, [d-h, d, d+h])
            qm, q0, qp = rows[0]["q"], rows[1]["q"], rows[2]["q"]
            fd = (qp - qm) / (2.0*h)
            ref = legacy_active_tangent_oracle(a, b, d)
            rel = abs(fd-ref) / max(abs(ref), 1.0e-300)
            max_fd_rel = max(max_fd_rel, rel)
            if rel > 2.0e-8:
                raise AssertionError(f"FD mismatch a={a} b={b} d={d} fd={fd} ref={ref}")
            if not close(q0, legacy_active_oracle(a,b,d), atol=2e-12, rtol=2e-12):
                raise AssertionError("FD center flux mismatch")
            fd_checks += 1
        require(fd_checks == len(fd_cases), "FVQ42_SCALE_AWARE_FINITE_DIFFERENCE_TANGENT_CHECK")

        for a, b in [(0.01,0.1), (0.5,0.5), (10.0,0.999), (3.0,1.0)]:
            drain = -37.0
            gwls = [drain-100.0, drain-1.0, drain]
            rows0 = run_points(exe0, a, b, drain, gwls)
            rows2 = run_points(exe2, a, b, drain, gwls)
            route_consistent = route_consistent and compare_routes(rows0, rows2)
            for row in rows0[:2]:
                if row["status"] != 0 or not row["evaluated"] or not row["inactive"]:
                    raise AssertionError(f"negative-difference interflow contribution not inactive: {row}")
                if row["q"] != 0.0 or not row["derivative_defined"] or row["dq"] != 0.0:
                    raise AssertionError(f"inactive contribution semantics mismatch: {row}")
                inactive_checks += 1
            activation = rows0[2]
            if activation["status"] != 0 or not activation["evaluated"] or not activation["activation"]:
                raise AssertionError(f"activation status mismatch: {activation}")
            if activation["q"] != 0.0 or activation["derivative_defined"]:
                raise AssertionError(f"activation flux/full derivative mismatch: {activation}")
            if b < 1.0:
                if not activation["singular"] or activation["right_defined"]:
                    raise AssertionError(f"sublinear activation metadata mismatch: {activation}")
            else:
                if activation["singular"] or not activation["right_defined"]:
                    raise AssertionError(f"linear activation metadata mismatch: {activation}")
                if not close(activation["right_tangent"], a):
                    raise AssertionError(f"linear right tangent mismatch {activation['right_tangent']} != {a}")
            activation_checks += 1

        require(route_consistent, "FVQ42_BRANCH_METADATA_O0_O2_CONSISTENCY")
        require(inactive_checks == 8, "FVQ42_NEGATIVE_DIFFERENCE_INTERFLOW_CONTRIBUTION_INACTIVE")
        require(activation_checks == 4, "FVQ42_ACTIVATION_METADATA_MATRIX")
        require(True, "FVQ42_SUBLINEAR_ACTIVATION_SINGULAR_RIGHT_TANGENT")
        require(True, "FVQ42_LINEAR_ACTIVATION_FINITE_RIGHT_TANGENT_TWO_SIDED_UNAVAILABLE")

    summary = {
        "candidate_closeout": CANDIDATE,
        "candidate_blob": CANDIDATE_BLOB,
        "active_cases": active_count,
        "derivative_formula_checks": derivative_formula_checks,
        "finite_difference_checks": fd_checks,
        "inactive_contribution_checks": inactive_checks,
        "activation_checks": activation_checks,
        "max_flux_abs_error": max_flux_abs,
        "max_flux_rel_error": max_flux_rel,
        "max_derivative_abs_error": max_dq_abs,
        "max_derivative_rel_error": max_dq_rel,
        "max_fd_relative_error": max_fd_rel,
        "scope": "empirical interflow drainage-side contribution only; negative-side DRAMET3 infiltration excluded",
    }
    text = json.dumps(summary, sort_keys=True)
    print("FVQ42_SUMMARY=" + text)
    print("FVQ42_SUMMARY_SHA256=" + hashlib.sha256(text.encode()).hexdigest())
    print("FVQ42_EMPIRICAL_INTERFLOW_SCIENTIFIC_EQUIVALENCE=PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
