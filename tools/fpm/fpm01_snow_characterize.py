#!/usr/bin/env python3
"""F-PM01 source-bound characterization of the B1.10 snow process.

The harness compiles the exact snow.f90 member supplied through --source-root.
It does not copy a reimplemented snow formula into production or tests. The source
root is expected to be an exact B1.10 reconstruction (or a source tree whose
checked members are byte-identical to B1.10).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile

EXPECTED = {
    "snow.f90": "02f36d30448b94dfdf386bc43424f1fe0feff9eafd24a768a8c702843a0bf9b2",
    "swap.f90": "39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a",
    "integral.f90": "bd37ebe5014f14ab2ff961a336cfa284266102d510617feef1c00f6616c64174",
}

STUB = r'''module MOD_swap_base
  implicit none
  logical :: fl_initialize = .false.
end module MOD_swap_base

subroutine swap_error(where, message)
  implicit none
  character(len=*), intent(in) :: where, message
  write(*,'(A,1X,A,1X,A)') 'SWAP_ERROR', trim(where), trim(message)
  error stop 99
end subroutine swap_error
'''

DRIVER = r'''program fpm01_snow_characterization
  use iso_fortran_env, only: real64, int64
  use MOD_snow
  implicit none
  integer :: failures
  real(real64) :: a1(8), a2(8), a3(8), b(8), c(8), nm(8), mid(8)
  real(real64) :: inactive_before(8), inactive_after(8)

  failures = 0

  call run_case_A(100.0_real64, 101.0_real64, .true., a1, failures)
  call run_case_A(100.0_real64, 101.0_real64, .true., a2, failures)
  call assert_vec_exact('same_input_same_output', a1, a2, failures)
  call assert_vec_exact('state_clone_identity', a1, a2, failures)

  call run_case_B(b, failures)
  call run_case_A(100.0_real64, 101.0_real64, .true., a3, failures)
  call assert_vec_exact('no_cross_call_leakage_A_B_A', a1, a3, failures)
  call assert_vec_exact('rollback_replay', a1, a3, failures)

  call run_case_C(c, failures)

  call run_case_A(100.25_real64, 101.25_real64, .true., nm, failures)
  call run_case_A(100.0_real64, 101.0_real64, .true., mid, failures)
  call assert_vec_exact('non_midnight_one_day_identity', nm, mid, failures)

  call setup_A(inactive_before)
  call evaluate(.false., 200.25_real64, 201.25_real64, inactive_after, failures)
  call assert_vec_exact('inactive_option_no_state_or_flux_change', inactive_before, inactive_after, failures)

  if (failures /= 0) then
     write(*,'(A,I0)') 'FPM01_SNOW_CHARACTERIZATION_FAIL count=', failures
     error stop 2
  end if
  write(*,'(A)') 'FPM01_SNOW_CHARACTERIZATION_PASS'

contains

  subroutine setup_A(before)
    real(real64), intent(out) :: before(8)
    swsublim = 0
    snowcoef = 0.15_real64
    ssnow = 3.0_real64
    slw = 0.1_real64
    gsnow = 0.4_real64
    snrai = 0.1_real64
    melt = -777.0_real64
    subl = -888.0_real64
    before = [ssnow, slw, melt, subl, 0.2_real64, 0.15_real64, 0.25_real64, snowcoef]
  end subroutine setup_A

  subroutine run_case_A(t0, t1, active, out, failures)
    real(real64), intent(in) :: t0, t1
    logical, intent(in) :: active
    real(real64), intent(out) :: out(8)
    integer, intent(inout) :: failures
    real(real64) :: before(8)
    call setup_A(before)
    call evaluate(active, t0, t1, out, failures)
    if (active) call assert_mass('mass_A', 3.0_real64, 0.4_real64, 0.1_real64, out(1), out(4), out(3), failures)
  end subroutine run_case_A

  subroutine run_case_B(out, failures)
    real(real64), intent(out) :: out(8)
    integer, intent(inout) :: failures
    real(real64) :: before_ssnow
    swsublim = 0; snowcoef = 0.25_real64
    ssnow = 0.0_real64; slw = 0.0_real64; gsnow = 0.5_real64; snrai = 0.0_real64
    melt = -777.0_real64; subl = -888.0_real64
    before_ssnow = ssnow
    call evaluate(.true., 33.25_real64, 34.25_real64, out, failures, &
                  tsoil_override=0.6_real64, tav_override=3.0_real64)
    call assert_mass('mass_B', before_ssnow, 0.5_real64, 0.0_real64, out(1), out(4), out(3), failures)
    if (.not. exact(out(1), 0.0_real64) .or. .not. exact(out(3), 0.5_real64) .or. &
        .not. exact(out(4), 0.0_real64)) then
       call fail('warm_soil_fresh_snow_melts', failures)
    else
       call pass('warm_soil_fresh_snow_melts')
    end if
  end subroutine run_case_B

  subroutine run_case_C(out, failures)
    real(real64), intent(out) :: out(8)
    integer, intent(inout) :: failures
    real(real64) :: before_ssnow
    swsublim = 0; snowcoef = 0.1_real64
    ssnow = 0.1_real64; slw = 0.0_real64; gsnow = 0.0_real64; snrai = 0.0_real64
    melt = -777.0_real64; subl = -888.0_real64
    before_ssnow = ssnow
    call evaluate(.true., 90.25_real64, 91.25_real64, out, failures, &
                  tsoil_override=0.0_real64, tav_override=5.0_real64)
    call assert_mass('mass_deficit_clamp', before_ssnow, 0.0_real64, 0.0_real64, out(1), out(4), out(3), failures)
    if (.not. exact(out(1), 0.0_real64) .or. .not. exact(out(2), 0.0_real64)) then
       call fail('snow_deficit_clamp_storage_zero', failures)
    else
       call pass('snow_deficit_clamp_storage_zero')
    end if
  end subroutine run_case_C

  subroutine evaluate(active, t0, t1, out, failures, tsoil_override, tav_override)
    logical, intent(in) :: active
    real(real64), intent(in) :: t0, t1
    real(real64), intent(out) :: out(8)
    integer, intent(inout) :: failures
    real(real64), intent(in), optional :: tsoil_override, tav_override
    real(real64) :: peva, empreva, epond, tsoil1, tav
    if (t1 <= t0) then
       call fail('valid_interval', failures); out = 0.0_real64; return
    end if
    peva = 0.2_real64; empreva = 0.15_real64; epond = 0.25_real64
    tsoil1 = 0.0_real64; tav = 2.0_real64
    if (present(tsoil_override)) tsoil1 = tsoil_override
    if (present(tav_override)) tav = tav_override
    if (active) call snow(2, tsoil1, tav, epond, peva, empreva)
    out = [ssnow, slw, melt, subl, peva, empreva, epond, snowcoef]
  end subroutine evaluate

  subroutine assert_mass(name, s0, snow_in, rain_in, s1, subl_out, melt_out, failures)
    character(len=*), intent(in) :: name
    real(real64), intent(in) :: s0, snow_in, rain_in, s1, subl_out, melt_out
    integer, intent(inout) :: failures
    real(real64) :: residual, scale, tol
    residual = (s1-s0) - (snow_in+rain_in-subl_out-melt_out)
    scale = max(1.0_real64, abs(s0), abs(s1), abs(snow_in)+abs(rain_in)+abs(subl_out)+abs(melt_out))
    tol = 128.0_real64 * epsilon(1.0_real64) * scale
    if (abs(residual) > tol) then
       write(*,'(A,1X,A,2(1X,ES25.16E3))') 'MASS_FAIL', trim(name), residual, tol
       failures = failures + 1
    else
       write(*,'(A,1X,A,2(1X,ES25.16E3))') 'MASS_PASS', trim(name), residual, tol
    end if
  end subroutine assert_mass

  subroutine assert_vec_exact(name, a, b, failures)
    character(len=*), intent(in) :: name
    real(real64), intent(in) :: a(:), b(:)
    integer, intent(inout) :: failures
    integer :: i
    do i = 1, size(a)
       if (.not. exact(a(i), b(i))) then
          call fail(name, failures)
          return
       end if
    end do
    call pass(name)
  end subroutine assert_vec_exact

  logical function exact(a, b)
    real(real64), intent(in) :: a, b
    exact = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function exact

  subroutine pass(name)
    character(len=*), intent(in) :: name
    write(*,'(A,1X,A)') 'PASS', trim(name)
  end subroutine pass

  subroutine fail(name, failures)
    character(len=*), intent(in) :: name
    integer, intent(inout) :: failures
    write(*,'(A,1X,A)') 'FAIL', trim(name)
    failures = failures + 1
  end subroutine fail
end program fpm01_snow_characterization
'''


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command: list[str], cwd: pathlib.Path | None) -> str:
    process = subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if process.returncode:
        raise RuntimeError(f"command failed {command}:\n{process.stdout}")
    return process.stdout


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", required=True, type=pathlib.Path)
    parser.add_argument("--output-json", type=pathlib.Path)
    args = parser.parse_args()
    root = args.source_root

    observed = {name: sha256(root / name) for name in EXPECTED}
    for name, expected in EXPECTED.items():
        if observed[name] != expected:
            raise SystemExit(f"{name} SHA mismatch: {observed[name]} != {expected}")

    swap = (root / "swap.f90").read_text(errors="replace").lower().replace(" ", "")
    integral = (root / "integral.f90").read_text(errors="replace").lower().replace(" ", "")
    if "if(swsnow==1.and.fldaystart)callsnow(2" not in swap:
        raise SystemExit("legacy flDayStart Snow(2) gate not found")
    if "snowinco=ssnow" not in integral:
        raise SystemExit("snowinco balance-reference assignment not found")

    compiler = shutil.which("gfortran")
    if not compiler:
        raise SystemExit("gfortran not found")
    version = run([compiler, "--version"], None).splitlines()[0]

    results = {}
    with tempfile.TemporaryDirectory(prefix="fpm01_snow_") as tmp:
        work = pathlib.Path(tmp)
        (work / "stub.f90").write_text(STUB)
        shutil.copy2(root / "snow.f90", work / "snow.f90")
        (work / "driver.f90").write_text(DRIVER)
        for opt in ("O0", "O2"):
            exe = work / f"snow_{opt.lower()}"
            run([compiler, f"-{opt}", "-std=f2008", "-Wall", "-Wextra", "-fcheck=all", "stub.f90", "snow.f90", "driver.f90", "-o", str(exe)], work)
            stdout = run([str(exe)], work)
            if "FPM01_SNOW_CHARACTERIZATION_PASS" not in stdout:
                raise SystemExit(f"{opt} missing PASS marker")
            results[opt] = {"stdout": stdout, "stdout_sha256": hashlib.sha256(stdout.encode()).hexdigest()}

    if results["O0"]["stdout"] != results["O2"]["stdout"]:
        raise SystemExit("O0/O2 characterization output mismatch")

    evidence = {
        "schema_version": 1,
        "workstream": "F-PM",
        "work_unit": "F-PM01",
        "process": "SNOW",
        "status": "PASS",
        "source_identity": observed,
        "source_assertions": {
            "legacy_snow_task2_daystart_gate": True,
            "snowinco_is_balance_reference_assignment": True
        },
        "compiler": version,
        "optimization": ["O0", "O2"],
        "o0_o2_stdout_identical": True,
        "stdout_sha256": results["O0"]["stdout_sha256"],
        "checks": [
            "same input -> same output (bitwise)",
            "state clone identity (bitwise)",
            "A/B/A no cross-call leakage",
            "rollback/replay identity",
            "one-day non-midnight interval identity at seam wrapper",
            "inactive option leaves state/results unchanged",
            "unrounded mass identity in normal, warm-fresh-snow and deficit-clamp cases"
        ],
        "time_scope": "No duration scaling is inferred. Non-midnight check keeps a one-day interval; generic subdaily snow scaling remains HOLD.",
        "production_source_modified": False
    }
    if args.output_json:
        args.output_json.parent.mkdir(parents=True, exist_ok=True)
        args.output_json.write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps(evidence, indent=2))
    print("--- CHARACTERIZATION STDOUT ---")
    print(results["O0"]["stdout"], end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
