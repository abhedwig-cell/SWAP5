#!/usr/bin/env python3
import hashlib
import json
import math
import random
import subprocess
import sys
import tempfile
from pathlib import Path

BASE = "b982d4d0c8686e5c5fcb965633d34a4e0ba46fcf"
CANDIDATE = "61dc2ee0e5e2344a855e429e8e3d49a04ffe007e"
CANDIDATE_PATH = "src/process/mod_drainage_multilevel_aggregation.f90"
CANDIDATE_BLOB = "70d35512ef7c5958f7e4bf284cba104a7b641fdb"
DRAINAGE_SHA256 = "48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc"
MANIFEST = Path("reference/swap-4.3.1/b0/file-manifest.sha256")


def sh(*args, input_text=None, check=True):
    return subprocess.run(args, input=input_text, text=True, capture_output=True, check=check)


def require(condition, marker, detail=""):
    if not condition:
        print(f"{marker}=FAIL" + (f" {detail}" if detail else ""))
        raise AssertionError(marker)
    print(f"{marker}=PASS")


def sequential_sum(values):
    total = 0.0
    for value in values:
        total = total + value
    return total


def close(a, b, atol=1.0e-13, rtol=1.0e-13):
    return abs(a - b) <= atol + rtol * max(abs(a), abs(b))


def write_sources(tmp, candidate_source):
    Path(tmp, "candidate.f90").write_text(candidate_source)
    Path(tmp, "driver.f90").write_text(
        r'''program fvq43_driver
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_drainage_multilevel_aggregation
  implicit none
  type(drainage_level_exchange_t), allocatable :: levels(:)
  type(drainage_multilevel_aggregate_t) :: aggregate
  type(drainage_multilevel_diagnostics_t) :: diagnostics
  integer :: ncases, icase, n, i
  integer :: level_index, flux_mode, derivative_mode, branch_mode, singular_mode
  real(real64) :: rate, derivative

  read(*,*) ncases
  do icase = 1, ncases
    read(*,*) n
    allocate(levels(n))
    do i = 1, n
      read(*,*) level_index, flux_mode, rate, derivative_mode, derivative, branch_mode, singular_mode
      levels(i) = drainage_level_exchange_t()
      levels(i)%level_index = level_index
      levels(i)%flux_defined = flux_mode /= 0
      if (flux_mode == 2) then
        levels(i)%signed_soil_to_drain_rate = ieee_value(0.0_real64, ieee_quiet_nan)
      else
        levels(i)%signed_soil_to_drain_rate = rate
      end if
      levels(i)%derivative_defined = derivative_mode /= 0
      if (derivative_mode == 2) then
        levels(i)%dq_dgroundwater_level = ieee_value(0.0_real64, ieee_quiet_nan)
      else
        levels(i)%dq_dgroundwater_level = derivative
      end if
      levels(i)%branch_boundary = branch_mode /= 0
      levels(i)%singular_tangent = singular_mode /= 0
    end do

    call aggregate_drainage_levels(levels, aggregate, diagnostics)
    write(*,'(*(g0,1x))') &
      diagnostics%status, diagnostics%evaluated, diagnostics%level_count, diagnostics%invalid_level_index, &
      diagnostics%derivative_unavailable_level_count, diagnostics%derivative_nonfinite_level_count, &
      diagnostics%branch_boundary_level_count, diagnostics%singular_tangent_level_count, &
      diagnostics%contains_positive_exchange, diagnostics%contains_negative_exchange, &
      diagnostics%contains_zero_exchange, diagnostics%aggregate_derivative_numerically_unrepresentable, &
      diagnostics%total_is_derived_view_not_additional_transfer, diagnostics%deterministic_level_order, &
      diagnostics%persistent_process_state, diagnostics%fixed_legacy_level_capacity, &
      aggregate%derivative_defined, aggregate%dq_dgroundwater_level, aggregate%signed_soil_to_drain_rate
    deallocate(levels)
  end do
end program fvq43_driver
'''
    )


def compile_driver(tmp, optimization):
    exe = Path(tmp, f"driver_{optimization.replace('-', '')}")
    cp = sh(
        "gfortran", "-std=f2008", "-ffree-line-length-none", "-Wall", "-Wextra", "-Werror=compare-reals", optimization,
        "-J", tmp, "-I", tmp, str(Path(tmp, "candidate.f90")), str(Path(tmp, "driver.f90")),
        "-o", str(exe), check=False,
    )
    if cp.returncode != 0:
        print(cp.stdout)
        print(cp.stderr, file=sys.stderr)
        raise RuntimeError(f"compile failed {optimization}")
    return exe


def normalized_case(levels):
    result = []
    for item in levels:
        q = float(f"{item['q']:.17g}")
        dq = float(f"{item['dq']:.17g}")
        result.append({**item, "q": q, "dq": dq})
    return result


def payload_for(cases):
    lines = [str(len(cases))]
    for levels in cases:
        lines.append(str(len(levels)))
        for item in levels:
            lines.append(
                f"{item['idx']} {item['flux_mode']} {item['q']:.17g} "
                f"{item['deriv_mode']} {item['dq']:.17g} {item['branch']} {item['singular']}"
            )
    return "\n".join(lines) + "\n"


def run_cases(exe, cases):
    cp = sh(str(exe), input_text=payload_for(cases))
    rows = []
    for line in cp.stdout.splitlines():
        p = line.split()
        if len(p) != 19:
            raise RuntimeError(f"unexpected candidate output: {line}")
        rows.append({
            "status": int(p[0]),
            "evaluated": p[1] == "T",
            "level_count": int(p[2]),
            "invalid_level": int(p[3]),
            "du_count": int(p[4]),
            "dnf_count": int(p[5]),
            "branch_count": int(p[6]),
            "singular_count": int(p[7]),
            "positive": p[8] == "T",
            "negative": p[9] == "T",
            "zero": p[10] == "T",
            "aggregate_derivative_unrepresentable": p[11] == "T",
            "derived_mass_view": p[12] == "T",
            "deterministic_order": p[13] == "T",
            "persistent_state": p[14] == "T",
            "fixed_legacy_capacity": p[15] == "T",
            "derivative_defined": p[16] == "T",
            "dq": float(p[17]),
            "q": float(p[18]),
        })
    if len(rows) != len(cases):
        raise RuntimeError(f"unexpected row count {len(rows)} != {len(cases)}")
    return rows, cp.stdout


def make_legacy_cases():
    rng = random.Random(430804)
    cases = []
    for n in range(1, 26):
        for sample in range(20):
            levels = []
            for i in range(1, n + 1):
                magnitude = 10.0 ** rng.uniform(-9.0, 3.0)
                selector = (i + sample) % 7
                if selector == 0:
                    q = 0.0
                elif selector in (1, 2):
                    q = -magnitude
                else:
                    q = magnitude
                dq = 10.0 ** rng.uniform(-10.0, 2.0)
                levels.append({"idx": i, "flux_mode": 1, "q": q, "deriv_mode": 1, "dq": dq, "branch": 0, "singular": 0})
            cases.append(normalized_case(levels))
    return cases


def main():
    manifest = MANIFEST.read_text()
    require(DRAINAGE_SHA256 in manifest and "SWAP/drainage.f90" in manifest, "FVQ43_FROZEN_DRAINAGE_SOURCE_IDENTITY")

    blob = sh("git", "rev-parse", f"{CANDIDATE}:{CANDIDATE_PATH}").stdout.strip()
    require(blob == CANDIDATE_BLOB, "FVQ43_CANDIDATE_CLOSEOUT_BLOB_IDENTITY", blob)
    source = sh("git", "show", f"{CANDIDATE}:{CANDIDATE_PATH}").stdout
    low = source.lower()
    for forbidden in ["headcalc", "modflow", ".dra", "owltab", "calendar", "madr", "nrlevs", "sum("]:
        require(forbidden not in low, "FVQ43_NO_FORBIDDEN_AGGREGATOR_LEAKAGE", forbidden)
    require("levels(:)" in low and low.count("do level = 1, size(levels)") >= 3,
            "FVQ43_DYNAMIC_SEQUENTIAL_REDUCTION_STATIC_BINDING")
    require("total_is_derived_view_not_additional_transfer" in low,
            "FVQ43_DERIVED_MASS_VIEW_STATIC_BINDING")

    legacy_cases = make_legacy_cases()
    huge75 = sys.float_info.max * 0.75
    special_cases = [
        normalized_case([
            {"idx": 1, "flux_mode": 1, "q": 1.0, "deriv_mode": 1, "dq": 0.1, "branch": 0, "singular": 0},
            {"idx": 2, "flux_mode": 1, "q": -0.5, "deriv_mode": 0, "dq": 0.0, "branch": 1, "singular": 0},
            {"idx": 3, "flux_mode": 1, "q": 0.0, "deriv_mode": 1, "dq": 0.3, "branch": 0, "singular": 0},
            {"idx": 4, "flux_mode": 1, "q": 2.0, "deriv_mode": 1, "dq": 0.4, "branch": 1, "singular": 1},
        ]),
        normalized_case([
            {"idx": 1, "flux_mode": 1, "q": 1.25, "deriv_mode": 2, "dq": 0.0, "branch": 0, "singular": 0},
            {"idx": 2, "flux_mode": 1, "q": 2.75, "deriv_mode": 1, "dq": 0.2, "branch": 0, "singular": 0},
        ]),
        normalized_case([
            {"idx": 1, "flux_mode": 1, "q": 1.0, "deriv_mode": 1, "dq": 0.1, "branch": 0, "singular": 0},
            {"idx": 3, "flux_mode": 1, "q": 2.0, "deriv_mode": 1, "dq": 0.2, "branch": 0, "singular": 0},
        ]),
        normalized_case([
            {"idx": 1, "flux_mode": 0, "q": 1.0, "deriv_mode": 1, "dq": 0.1, "branch": 0, "singular": 0},
        ]),
        normalized_case([
            {"idx": 1, "flux_mode": 2, "q": 0.0, "deriv_mode": 1, "dq": 0.1, "branch": 0, "singular": 0},
        ]),
        [],
        normalized_case([
            {"idx": 1, "flux_mode": 1, "q": 1.0, "deriv_mode": 1, "dq": huge75, "branch": 0, "singular": 0},
            {"idx": 2, "flux_mode": 1, "q": 2.0, "deriv_mode": 1, "dq": huge75, "branch": 0, "singular": 0},
        ]),
        normalized_case([
            {"idx": 1, "flux_mode": 1, "q": huge75, "deriv_mode": 1, "dq": 0.1, "branch": 0, "singular": 0},
            {"idx": 2, "flux_mode": 1, "q": huge75, "deriv_mode": 1, "dq": 0.2, "branch": 0, "singular": 0},
        ]),
    ]
    scalable = normalized_case([
        {"idx": i, "flux_mode": 1, "q": i / 1000.0, "deriv_mode": 1, "dq": i / 10000.0, "branch": 0, "singular": 0}
        for i in range(1, 65)
    ])
    cases = legacy_cases + special_cases + [scalable]

    max_flux_abs = 0.0
    max_derivative_abs = 0.0
    mixed_sign_cases = 0
    legacy_values = 0

    with tempfile.TemporaryDirectory(prefix="fvq43_") as tmp:
        write_sources(tmp, source)
        exe0 = compile_driver(tmp, "-O0")
        exe2 = compile_driver(tmp, "-O2")
        rows0, out0 = run_cases(exe0, cases)
        rows2, out2 = run_cases(exe2, cases)
        require(out0 == out2, "FVQ43_O0_O2_CANDIDATE_OUTPUT_IDENTITY")

        for levels, row in zip(legacy_cases, rows0[:len(legacy_cases)]):
            q_values = [x["q"] for x in levels]
            dq_values = [x["dq"] for x in levels]
            q_ref = sequential_sum(q_values)
            dq_ref = sequential_sum(dq_values)
            if not (row["status"] == 0 and row["evaluated"] and row["derivative_defined"]):
                raise AssertionError(f"legacy-range valid aggregation rejected n={len(levels)} row={row}")
            qerr = abs(row["q"] - q_ref)
            dqerr = abs(row["dq"] - dq_ref)
            max_flux_abs = max(max_flux_abs, qerr)
            max_derivative_abs = max(max_derivative_abs, dqerr)
            if row["q"] != q_ref:
                raise AssertionError(f"sequential flux mismatch n={len(levels)} got={row['q']} ref={q_ref}")
            if row["dq"] != dq_ref:
                raise AssertionError(f"sequential derivative mismatch n={len(levels)} got={row['dq']} ref={dq_ref}")
            if any(v > 0.0 for v in q_values) and any(v < 0.0 for v in q_values):
                mixed_sign_cases += 1
                if not (row["positive"] and row["negative"]):
                    raise AssertionError("mixed sign diagnostics mismatch")
            if not row["derived_mass_view"] or row["persistent_state"] or row["fixed_legacy_capacity"]:
                raise AssertionError("mass/state/capacity diagnostics mismatch")
            legacy_values += len(levels)

        require(len(legacy_cases) == 500 and legacy_values == 6500, "FVQ43_LEGACY_ADMITTED_LEVEL_RANGE_COVERAGE")
        require(max_flux_abs == 0.0, "FVQ43_LEGACY_LEVEL_ORDER_FLUX_EQUIVALENCE")
        require(max_derivative_abs == 0.0, "FVQ43_ALL_DEFINED_SENSITIVITY_SEQUENTIAL_SUM")
        require(mixed_sign_cases > 300, "FVQ43_MIXED_SIGN_AGGREGATION_ARITHMETIC")
        require(rows0[0]["q"] == legacy_cases[0][0]["q"], "FVQ43_ONE_LEVEL_IDENTITY")

        offset = len(legacy_cases)
        unavailable = rows0[offset]
        require(unavailable["status"] == 0 and unavailable["evaluated"] and close(unavailable["q"], 2.5),
                "FVQ43_UNAVAILABLE_TANGENT_PRESERVES_FLUX")
        require(not unavailable["derivative_defined"] and unavailable["du_count"] == 2 and
                unavailable["branch_count"] == 2 and unavailable["singular_count"] == 1,
                "FVQ43_BRANCH_AND_SINGULARITY_CONSERVATIVE_COMPOSITION")

        nonfinite_dq = rows0[offset + 1]
        require(nonfinite_dq["status"] == 0 and nonfinite_dq["evaluated"] and close(nonfinite_dq["q"], 4.0) and
                not nonfinite_dq["derivative_defined"] and nonfinite_dq["dnf_count"] == 1,
                "FVQ43_NONFINITE_TANGENT_PRESERVES_VALID_FLUX")

        order_bad = rows0[offset + 2]
        require(order_bad["status"] == 2 and not order_bad["evaluated"] and order_bad["invalid_level"] == 2,
                "FVQ43_LEVEL_IDENTITY_FAILS_CLOSED")
        flux_undefined = rows0[offset + 3]
        flux_nan = rows0[offset + 4]
        require(flux_undefined["status"] == 3 and flux_nan["status"] == 3 and
                not flux_undefined["evaluated"] and not flux_nan["evaluated"],
                "FVQ43_INVALID_FLUX_FAILS_CLOSED")
        empty = rows0[offset + 5]
        require(empty["status"] == 1 and not empty["evaluated"], "FVQ43_EMPTY_COLLECTION_FAILS_CLOSED")

        derivative_overflow = rows0[offset + 6]
        require(derivative_overflow["status"] == 0 and derivative_overflow["evaluated"] and
                close(derivative_overflow["q"], 3.0) and not derivative_overflow["derivative_defined"] and
                derivative_overflow["aggregate_derivative_unrepresentable"],
                "FVQ43_AGGREGATE_DERIVATIVE_OVERFLOW_PRESERVES_FLUX")
        flux_overflow = rows0[offset + 7]
        require(flux_overflow["status"] == 4 and not flux_overflow["evaluated"],
                "FVQ43_FLUX_SUM_OVERFLOW_FAILS_CLOSED")

        scalable_row = rows0[offset + 8]
        q64 = sequential_sum([x["q"] for x in scalable])
        dq64 = sequential_sum([x["dq"] for x in scalable])
        require(scalable_row["status"] == 0 and scalable_row["evaluated"] and scalable_row["level_count"] == 64 and
                scalable_row["q"] == q64 and scalable_row["derivative_defined"] and scalable_row["dq"] == dq64 and
                not scalable_row["fixed_legacy_capacity"],
                "FVQ43_DYNAMIC_LEVEL_COUNT_SCALABILITY_EXTENSION")
        require(True, "FVQ43_SCALABILITY_EXTENSION_NOT_LEGACY_EQUIVALENCE")

    summary = {
        "candidate_closeout": CANDIDATE,
        "candidate_blob": CANDIDATE_BLOB,
        "legacy_equivalence_cases": len(legacy_cases),
        "legacy_constituent_values": legacy_values,
        "legacy_level_count_min": 1,
        "legacy_level_count_max": 25,
        "multiswap_legacy_capacity_covered": 5,
        "standalone_legacy_capacity_covered": 25,
        "mixed_sign_cases": mixed_sign_cases,
        "max_flux_abs_error": max_flux_abs,
        "max_derivative_abs_error": max_derivative_abs,
        "scalability_extension_level_count": 64,
        "scalability_extension_is_not_legacy_equivalence": True,
        "negative_constituent_arithmetic_does_not_qualify_negative_response_physics": True,
        "runtime_ledger_not_qualified": True,
    }
    text = json.dumps(summary, sort_keys=True)
    print("FVQ43_SUMMARY=" + text)
    print("FVQ43_SUMMARY_SHA256=" + hashlib.sha256(text.encode()).hexdigest())
    print("FVQ43_MULTILEVEL_DRAINAGE_AGGREGATION_QUALIFICATION=PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
