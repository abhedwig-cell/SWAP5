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


def normalized(value):
    return float(f"{value:.17g}")


def legacy_oracle(gwl, raw_drain_level, zbotdr, resistance):
    effective = max(raw_drain_level, zbotdr)
    diffl = gwl - effective
    return (diffl / resistance if diffl >= 0.0 else 0.0), effective


def write_sources(tmp, candidate_source):
    stub = "\n".join([
        "module mod_process_hydraulic_view",
        "  use, intrinsic :: iso_fortran_env, only: real64",
        "  implicit none",
        "  type :: process_hydraulic_view_t",
        "    real(real64) :: groundwater_level = 0.0_real64",
        "  end type process_hydraulic_view_t",
        "end module mod_process_hydraulic_view",
        "",
    ])
    Path(tmp, "hydraulic_stub.f90").write_text(stub)
    Path(tmp, "candidate.f90").write_text(candidate_source)
    Path(tmp, "driver.f90").write_text(r'''program fvq44_driver
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
''')


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
    for case in cases:
        lines.append(
            f"{case['r']:.17g} {case['gwl']:.17g} {case['head']:.17g} "
            f"{case.get('rmode', 0)} {case.get('gwlmode', 0)} {case.get('hmode', 0)}"
        )
    return "\n".join(lines) + "\n"


def run_cases(exe, cases):
    cp = sh(str(exe), input_text=payload_for(cases))
    rows = []
    for line in cp.stdout.splitlines():
        parts = line.split()
        if len(parts) != 8:
            raise RuntimeError(f"unexpected candidate output: {line}")
        rows.append({
            "status": int(parts[0]),
            "evaluated": parts[1] == "T",
            "active": parts[2] == "T",
            "kink": parts[3] == "T",
            "derivative_defined": parts[4] == "T",
            "q": float(parts[5]),
            "dq": float(parts[6]),
            "mass_transfer": parts[7] == "T",
        })
    if len(rows) != len(cases):
        raise RuntimeError(f"unexpected row count {len(rows)} != {len(cases)}")
    return rows, cp.stdout


def make_valid_cases():
    rng = random.Random(440801)
    cases = []
    counts = {
        "effective_head_clamped_cases": 0,
        "effective_head_unclamped_cases": 0,
        "positive_cases": 0,
        "negative_cases": 0,
        "kink_cases": 0,
    }
    for index in range(1200):
        resistance = normalized(10.0 ** rng.uniform(-3.0, 5.0))
        zbot = normalized(rng.uniform(-600.0, 20.0))
        raw = normalized(rng.uniform(-650.0, 50.0))
        effective = max(raw, zbot)
        if raw < zbot:
            counts["effective_head_clamped_cases"] += 1
        else:
            counts["effective_head_unclamped_cases"] += 1

        selector = index % 12
        scale = normalized(10.0 ** rng.uniform(-8.0, 2.0))
        if selector == 0:
            gwl = effective
            counts["kink_cases"] += 1
        elif selector <= 7:
            gwl = normalized(effective + scale)
            if gwl == effective:
                gwl = math.nextafter(effective, math.inf)
            counts["positive_cases"] += 1
        else:
            gwl = normalized(effective - scale)
            if gwl == effective:
                gwl = math.nextafter(effective, -math.inf)
            counts["negative_cases"] += 1

        _, effective_check = legacy_oracle(gwl, raw, zbot, resistance)
        cases.append({
            "r": resistance,
            "gwl": normalized(gwl),
            "head": normalized(effective_check),
            "raw": raw,
            "zbot": zbot,
        })
    return cases, counts


def main():
    manifest = MANIFEST.read_text()
    require(DRAINAGE_SHA256 in manifest and "SWAP/drainage.f90" in manifest,
            "FVQ44_FROZEN_DRAINAGE_SOURCE_IDENTITY")
    require(MOD_DRAINAGE_SHA256 in manifest and "SWAP/MOD_drainage.f90" in manifest,
            "FVQ44_FROZEN_MOD_DRAINAGE_SOURCE_IDENTITY")

    oracle_text = ORACLE_SOURCE.read_text()
    require(DRAINAGE_EXCERPT_SHA256 in oracle_text and MOD_DRAINAGE_EXCERPT_SHA256 in oracle_text,
            "FVQ44_PERSISTED_EQUATION_LEVEL_ORACLE_BINDING")
    for token in [
        "drainl(lev) = afgen", "drainl(lev) < zbotdr(lev)", "diffl(lev) = gwl - drainl(lev)",
        "qdrain(lev) = diffl(lev) / drares(lev)", "swallo(lev) == 3", "qdrain(lev) = 0.0d0"
    ]:
        require(token in oracle_text, "FVQ44_LEGACY_REDUCTION_SOURCE_TOKEN", token)

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
    invalid_cases = [
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
    cases = valid_cases + invalid_cases + repeat_cases

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
            resistance = case["r"]
            gwl = case["gwl"]
            head = case["head"]
            diffl = gwl - head
            qref = max(0.0, diffl / resistance)
            max_flux_abs = max(max_flux_abs, abs(row["q"] - qref))
            if row["q"] != qref:
                raise AssertionError(f"flux mismatch got={row['q']} ref={qref} case={case}")
            if row["status"] != 0 or not row["evaluated"] or not row["mass_transfer"]:
                raise AssertionError(f"valid case rejected or mass-transfer flag false: {row}")

            if diffl > 0.0:
                dqref = 1.0 / resistance
                max_derivative_abs = max(max_derivative_abs, abs(row["dq"] - dqref))
                if not row["active"] or not row["derivative_defined"] or row["dq"] != dqref or row["kink"]:
                    raise AssertionError(f"active derivative/diagnostic mismatch: {row}")
                eps = abs(diffl) * 0.25
                upper = gwl + eps
                lower = gwl - eps
                if eps > 0.0 and upper > gwl and lower < gwl and lower > head:
                    qplus = max(0.0, (upper - head) / resistance)
                    qminus = max(0.0, (lower - head) / resistance)
                    fd = (qplus - qminus) / (upper - lower)
                    if not math.isclose(row["dq"], fd, rel_tol=3.0e-12, abs_tol=2.0e-12):
                        raise AssertionError(f"active FD mismatch dq={row['dq']} fd={fd}")
                    active_fd_cases += 1
            elif diffl < 0.0:
                if row["active"] or not row["derivative_defined"] or row["dq"] != 0.0 or row["kink"]:
                    raise AssertionError(f"inactive derivative/diagnostic mismatch: {row}")
                eps = abs(diffl) * 0.25
                upper = gwl + eps
                lower = gwl - eps
                if eps > 0.0 and upper > gwl and lower < gwl and upper < head:
                    qplus = max(0.0, (upper - head) / resistance)
                    qminus = max(0.0, (lower - head) / resistance)
                    fd = (qplus - qminus) / (upper - lower)
                    if fd != 0.0:
                        raise AssertionError(f"inactive FD mismatch fd={fd}")
                    inactive_fd_cases += 1
            else:
                if row["active"] or row["derivative_defined"] or row["dq"] != 0.0 or not row["kink"]:
                    raise AssertionError(f"activation-kink policy mismatch: {row}")

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
        invalid_rows = rows0[offset:offset + len(invalid_cases)]
        require(all(row["status"] != 0 and not row["evaluated"] and row["q"] == 0.0 for row in invalid_rows),
                "FVQ44_INVALID_NORMALIZED_DOMAIN_FAILS_CLOSED")

        repeat_rows = rows0[offset + len(invalid_cases):]
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
    summary_text = json.dumps(summary, sort_keys=True)
    print("FVQ44_SUMMARY=" + summary_text)
    print("FVQ44_SUMMARY_SHA256=" + hashlib.sha256(summary_text.encode()).hexdigest())
    print("FVQ44_RESTRICTED_SINGLE_LEVEL_LINEAR_DRAINAGE_QUALIFICATION=PASS")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"FVQ44_RESTRICTED_SINGLE_LEVEL_LINEAR_DRAINAGE_QUALIFICATION=FAIL {exc}", file=sys.stderr)
        raise
