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
CANDIDATE = "97c5f4fd7cbc2024248a6b3df927ca4fa6b6dee7"
CANDIDATE_PATH = "src/process/mod_drainage_process.f90"
CANDIDATE_BLOB = "dbacd49da3bb0b94f822f9ee0478d15183e9c0fa"
DRAINAGE_SHA256 = "48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc"
MOD_DRAINAGE_SHA256 = "cb354ea13a099422c9f3b9c87a60ccbe440c0dd3c83ba0502108da8ca70ff255"
DRAINAGE_EXCERPT_SHA256 = "86bede7fbf2547f3801a54afe1fd56c954dc6f7473dcdb7e7f29f84adb1da944"
MOD_DRAINAGE_EXCERPT_SHA256 = "0011000e2897bae2aae1b24fbcd959573b4ab0dce216b185ede434ca40fd4b59"
MANIFEST = Path("reference/swap-4.3.1/b0/file-manifest.sha256")
ORACLE_SOURCE = Path("integration/f-vq/F-VQ44_LEGACY_ORACLE_SOURCE.txt")


def sh(*args, input_text=None, check=True):
    return subprocess.run(args, input=input_text, text=True, capture_output=True, check=check)


def require(condition, marker, detail=""):
    if not condition:
        print(f"{marker}=FAIL" + (f" {detail}" if detail else ""))
        raise AssertionError(marker)
    print(f"{marker}=PASS")


def normalized(x):
    return float(f"{x:.17g}")


def legacy_oracle(gwl, raw_drain_level, zbotdr, resistance):
    effective = max(raw_drain_level, zbotdr)
    diffl = gwl - effective
    if diffl >= 0.0:
        return diffl / resistance, effective
    return 0.0, effective


def write_sources(tmp, candidate_source):
    Path(tmp, "hydraulic_stub.f90").write_text(
        """module mod_process_hydraulic_view\n"
        "  use, intrinsic :: iso_fortran_env, only: real64\n"
        "  implicit none\n"
        "  type :: process_hydraulic_view_t\n"
        "    real(real64) :: groundwater_level = 0.0_real64\n"
        "  end type process_hydraulic_view_t\n"
        "end module mod_process_hydraulic_view\n"""
    )
    Path(tmp, "candidate.f90").write_text(candidate_source)
    Path(tmp, "driver.f90").write_text(
        r'''program fvq44_driver
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_process
  implicit none
  type(drainage_linear_parameters_t) :: parameters
  type(process_hydraulic_view_t) :: hydraulic_view
  type(drainage_control_t) :: control
  type(drainage_transfer_t) :: transfer
  type(drainage_diagnostics_t) :: diagnostics
  integer :: ncases, icase, rmode, gwlmode, hmode
  real(real64) :: resistance, groundwater_level, drain_head

  read(*,*) ncases
  do icase = 1, ncases
    read(*,*) resistance, groundwater_level, drain_head, rmode, gwlmode, hmode
    parameters%drainage_resistance = resistance
    hydraulic_view%groundwater_level = groundwater_level
    control%drain_head = drain_head
    if (rmode == 1) parameters%drainage_resistance = ieee_value(0.0_real64, ieee_quiet_nan)
    if (gwlmode == 1) hydraulic_view%groundwater_level = ieee_value(0.0_real64, ieee_quiet_nan)
    if (hmode == 1) control%drain_head = ieee_value(0.0_real64, ieee_quiet_nan)
    call evaluate_single_level_linear_drainage(parameters, hydraulic_view, control, transfer, diagnostics)
    write(*,*) diagnostics%status, diagnostics%evaluated, diagnostics%active, diagnostics%activation_kink, &
      transfer%derivative_defined, transfer%soil_to_drain_rate, transfer%dq_dgroundwater_level, &
      diagnostics%mass_is_authoritative_external_transfer
  end do
end program fvq44_driver
'''
    )


def compile_driver(tmp, optimization):
    exe = Path(tmp, f"driver_{optimization.replace('-', '')}")
    cp = sh(
        "gfortran", "-std=f2008", "-Wall", "-Wextra", "-ffree-line-length-none", optimization,
        "-J", tmp, "-I", tmp,
        str(Path(tmp, "hydraulic_stub.f90")), str(Path(tmp, "candidate.f90")), str(Path(tmp, "driver.f90")),
        "-o", str(exe), check=False,
    )
    if cp.returncode != 0:
        print(cp.stdout)
        print(cp.stderr, file=sys.stderr)
        raise RuntimeError(f"compile failed {optimization}")
    return exe


def payload_for(cases):
    lines = [str(len(cases))]
    for c in cases:
        lines.append(
            f"{c['r']:.17g} {c['gwl']:.17g} {c['head']:.17g} "
            f"{c.get('rmode', 0)} {c.get('gwlmode', 0)} {c.get('hmode', 0)}"
        )
    return "\n".join(lines) + "\n"


def run_cases(exe, cases):
    cp = sh(str(exe), input_text=payload_for(cases))
    rows = []
    for line in cp.stdout.splitlines():
        p = line.split()
        if len(p) != 8:
            raise RuntimeError(f"unexpected candidate output: {line}")
        rows.append({
            "status": int(p[0]),
            "evaluated": p[1] == "T",
            "active": p[2] == "T",
            "kink": p[3] == "T",
            "derivative_defined": p[4] == "T",
            "q": float(p[5]),
            "dq": float(p[6]),
            "mass_transfer": p[7] == "T",
        })
    if len(rows) != len(cases):
        raise RuntimeError(f"unexpected row count {len(rows)} != {len(cases)}")
    return rows, cp.stdout


def make_valid_cases():
    rng = random.Random(440801)
    cases = []
    clamp_count = 0
    free_count = 0
    positive_count = 0
    negative_count = 0
    zero_count = 0

    for i in range(1200):
        resistance = normalized(10.0 ** rng.uniform(-3.0, 5.0))
        zbot = normalized(rng.uniform(-600.0, 20.0))
        raw = normalized(rng.uniform(-650.0, 50.0))
        effective = max(raw, zbot)
        if raw < zbot:
            clamp_count += 1
        else:
            free_count += 1

        selector = i % 12
        scale = normalized(10.0 ** rng.uniform(-8.0, 2.0))
        if selector == 0:
            gwl = effective
            zero_count += 1
        elif selector in (1, 2, 3, 4, 5, 6, 7):
            gwl = normalized(effective + scale)
            if gwl == effective:
                gwl = math.nextafter(effective, math.inf)
            positive_count += 1
        else:
            gwl = normalized(effective - scale)
            if gwl == effective:
                gwl = math.nextafter(effective, -math.inf)
            negative_count += 1

        qref, effective_check = legacy_oracle(gwl, raw, zbot, resistance)
        cases.append({
            "r": resistance,
            "gwl": normalized(gwl),
            "head": normalized(effective_check),
            "raw": raw,
            "zbot": zbot,
            "qref": qref,
        })

    return cases, {
        "effective_head_clamped_cases": clamp_count,
        "effective_head_unclamped_cases": free_count,
        "positive_cases": positive_count,
        "negative_cases": negative_count,
        "kink_cases": zero_count,
    }


def main():
    manifest = MANIFEST.read_text()
    require(DRAINAGE_SHA256 in manifest and "SWAP/drainage.f90" in manifest,
            "FVQ44_FROZEN_DRAINAGE_SOURCE_IDENTITY")
    require(MOD_DRAINAGE_SHA256 in manifest and "SWAP/MOD_drainage.f90" in manifest,
            "FVQ44_FROZEN_MOD_DRAINAGE_SOURCE_IDENTITY")

    oracle_text = ORACLE_SOURCE.read_text()
    require(DRAINAGE_EXCERPT_SHA256 in oracle_text and MOD_DRAINAGE_EXCERPT_SHA256 in oracle_text,
            "FVQ44_PERSISTED_EQUATION_LEVEL_ORACLE_BINDING")
    for required in [
        "drainl(lev) = afgen", "drainl(lev) < zbotdr(lev)", "diffl(lev) = gwl - drainl(lev)",
        "qdrain(lev) = diffl(lev) / drares(lev)", "swallo(lev) == 3", "qdrain(lev) = 0.0d0"
    ]:
        require(required in oracle_text, "FVQ44_LEGACY_REDUCTION_SOURCE_TOKEN", required)

    blob = sh("git", "rev-parse", f"{CANDIDATE}:{CANDIDATE_PATH}").stdout.strip()
    require(blob == CANDIDATE_BLOB, "FVQ44_CANDIDATE_CLOSEOUT_BLOB_IDENTITY", blob)
    source = sh("git", "show", f"{CANDIDATE}:{CANDIDATE_PATH}").stdout
    low = source.lower()
    require("groundwater_level" in low, "FVQ44_GROUNDWATER_INPUT_STATIC_BINDING")
    for forbidden in [
        "headcalc", "modflow", ".dra", "owltab", "calendar", "pressure_head", "water_content",
        "ponding_depth", "jacobian", "residual", "open(", "read(", "write(", " save"
    ]:
        require(forbidden not in low, "FVQ44_NO_FORBIDDEN_PROCESS_COUPLING", forbidden)

    valid_cases, counts = make_valid_cases()
    special_cases = [
        {"r": 0.0, "gwl": 1.0, "head": 0.0},
        {"r": -1.0, "gwl": 1.0, "head": 0.0},
        {"r": 1.0, "gwl": 1.0, "head": 0.0, "rmode": 1},
        {"r": 1.0, "gwl": 1.0, "head": 0.0, "gwlmode": 1},
        {"r": 1.0, "gwl": 1.0, "head": 0.0, "hmode": 1},
    ]
    repeat_cases = [
        {"r": 7.25, "gwl": -1.0, "head": -4.0},
        {"r": 7.25, "gwl": -8.0, "head": -4.0},
        {"r": 7.25, "gwl": -1.0, "head": -4.0},
    ]
    cases = valid_cases + special_cases + repeat_cases

    max_flux_abs = 0.0
    max_derivative_abs = 0.0
    active_fd_cases = 0
    inactive_fd_cases = 0

    with tempfile.TemporaryDirectory(prefix="fvq44_") as tmp:
        write_sources(tmp, source)
        exe0 = compile_driver(tmp, "-O0")
        exe2 = compile_driver(tmp, "-O2")
        rows0, out0 = run_cases(exe0, cases)
        rows2, out2 = run_cases(exe2, cases)
        require(out0 == out2, "FVQ44_O0_O2_CANDIDATE_OUTPUT_IDENTITY")

        for case, row in zip(valid_cases, rows0[:len(valid_cases)]):
            r = case["r"]
            gwl = case["gwl"]
            head = case["head"]
            diffl = gwl - head
            qref = max(0.0, diffl / r)
            qerr = abs(row["q"] - qref)
            max_flux_abs = max(max_flux_abs, qerr)
            if row["q"] != qref:
                raise AssertionError(f"flux mismatch got={row['q']} ref={qref} case={case}")
            if not row["evaluated"] or row["status"] != 0 or not row["mass_transfer"]:
                raise AssertionError(f"valid case rejected or mass flag false: {row}")

            if diffl > 0.0:
                dqref = 1.0 / r
                max_derivative_abs = max(max_derivative_abs, abs(row["dq"] - dqref))
                if not row["active"] or not row["derivative_defined"] or row["dq"] != dqref or row["kink"]:
                    raise AssertionError(f"active derivative/diagnostic mismatch: {row}")
                eps = max(abs(diffl) * 1.0e-6, 1.0e-9)
                if gwl - eps > head:
                    qplus = max(0.0, ((gwl + eps) - head) / r)
                    qminus = max(0.0, ((gwl - eps) - head) / r)
                    fd = (qplus - qminus) / (2.0 * eps)
                    if not math.isclose(row["dq"], fd, rel_tol=3.0e-6, abs_tol=2.0e-10):
                        raise AssertionError(f"active FD mismatch dq={row['dq']} fd={fd}")
                    active_fd_cases += 1
            elif diffl < 0.0:
                if row["active"] or not row["derivative_defined"] or row["dq"] != 0.0 or row["kink"]:
                    raise AssertionError(f"inactive derivative/diagnostic mismatch: {row}")
                eps = max(abs(diffl) * 1.0e-6, 1.0e-9)
                if gwl + eps < head:
                    qplus = max(0.0, ((gwl + eps) - head) / r)
                    qminus = max(0.0, ((gwl - eps) - head) / r)
                    fd = (qplus - qminus) / (2.0 * eps)
                    if fd != 0.0 or row["dq"] != 0.0:
                        raise AssertionError("inactive FD mismatch")
                    inactive_fd_cases += 1
            else:
                if row["active"] or row["derivative_defined"] or row["dq"] != 0.0 or not row["kink"]:
                    raise AssertionError(f"kink policy mismatch: {row}")

        require(len(valid_cases) == 1200, "FVQ44_RANDOMIZED_VALID_DOMAIN_COVERAGE")
        require(counts["effective_head_clamped_cases"] > 250 and counts["effective_head_unclamped_cases"] > 250,
                "FVQ44_EFFECTIVE_DRAIN_HEAD_ABSTRACTION_COVERAGE")
        require(counts["positive_cases"] > 500 and counts["negative_cases"] > 300 and counts["kink_cases"] == 100,
                "FVQ44_ACTIVE_INACTIVE_KINK_COVERAGE")
        require(max_flux_abs == 0.0, "FVQ44_RESTRICTED_LEGACY_FLUX_EQUIVALENCE")
        require(max_derivative_abs == 0.0, "FVQ44_STABLE_BRANCH_ANALYTIC_DERIVATIVE_EQUIVALENCE")
        require(active_fd_cases > 400, "FVQ44_ACTIVE_DERIVATIVE_FINITE_DIFFERENCE")
        require(inactive_fd_cases > 250, "FVQ44_INACTIVE_DERIVATIVE_FINITE_DIFFERENCE")

        offset = len(valid_cases)
        invalid_rows = rows0[offset:offset + len(special_cases)]
        require(all((r["status"] != 0 and not r["evaluated"] and r["q"] == 0.0) for r in invalid_rows),
                "FVQ44_INVALID_NORMALIZED_DOMAIN_FAILS_CLOSED")

        repeat_rows = rows0[offset + len(special_cases):]
        require(repeat_rows[0] == repeat_rows[2], "FVQ44_STATELESS_A_B_A_REPEATABILITY")
        require(repeat_rows[0]["q"] > 0.0 and repeat_rows[1]["q"] == 0.0,
                "FVQ44_REPEATABILITY_SPANS_ACTIVE_INACTIVE_BRANCHES")

    summary = {
        "candidate_closeout": CANDIDATE,
        "candidate_blob": CANDIDATE_BLOB,
        "legacy_valid_cases": len(valid_cases),
        **counts,
        "active_fd_cases": active_fd_cases,
        "inactive_fd_cases": inactive_fd_cases,
        "max_flux_abs_error": max_flux_abs,
        "max_derivative_abs_error": max_derivative_abs,
        "effective_drain_head_is_resolved_external_control": True,
        "negative_side_infiltration_qualified": False,
        "owltab_time_interpolation_qualified": False,
        "runtime_mass_booking_qualified": False,
        "fully_implicit_solver_coupling_qualified": False,
    }
    text = json.dumps(summary, sort_keys=True)
    print("FVQ44_SUMMARY=" + text)
    print("FVQ44_SUMMARY_SHA256=" + hashlib.sha256(text.encode()).hexdigest())
    print("FVQ44_RESTRICTED_SINGLE_LEVEL_LINEAR_DRAINAGE_QUALIFICATION=PASS")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"FVQ44_RESTRICTED_SINGLE_LEVEL_LINEAR_DRAINAGE_QUALIFICATION=FAIL {exc}", file=sys.stderr)
        raise
