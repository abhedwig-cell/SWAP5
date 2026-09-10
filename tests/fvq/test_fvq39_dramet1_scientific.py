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
CANDIDATE = "edff81f4c784ec62bfbee5f131d7c0c71eba0d58"
CANDIDATE_PATH = "src/process/mod_drainage_tabulated_response.f90"
CANDIDATE_BLOB = "79084d69a81d6752ae5402b9f2d717ea20a48cbc"
DRAINAGE_SHA256 = "48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc"
FUNCTIONS_SHA256 = "b32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527"
MANIFEST = Path("reference/swap-4.3.1/b0/file-manifest.sha256")


def sh(*args, input_text=None, check=True):
    return subprocess.run(args, input=input_text, text=True, capture_output=True, check=check)


def require(cond, marker, detail=""):
    if not cond:
        print(f"{marker}=FAIL" + (f" {detail}" if detail else ""))
        raise AssertionError(marker)
    print(f"{marker}=PASS")


def legacy_qdrtab(knots, values):
    table = [0.0] * 50
    for i, (x, y) in enumerate(zip(knots, values)):
        table[2 * i] = abs(float(x))
        table[2 * i + 1] = float(y)
    return table


def legacy_afgen(table, x):
    x = float(x)
    if table[0] >= x:
        return table[1]
    for idx in range(2, 49, 2):
        if table[idx] >= x:
            den = table[idx] - table[idx - 2]
            slope = (table[idx + 1] - table[idx - 1]) / den
            return table[idx - 1] + (x - table[idx - 2]) * slope
        if table[idx] < table[idx - 2]:
            return table[idx - 1]
    return table[49]


def normalized_derivative(knots, values, gwl):
    depth = abs(gwl)
    n = len(knots)
    if n == 1:
        return True, 0.0, "single"
    if depth < knots[0] or depth > knots[-1]:
        return True, 0.0, "clamp"
    for k in knots:
        if depth == k:
            return False, 0.0, "knot"
    for i in range(1, n):
        if depth < knots[i]:
            slope = (values[i] - values[i - 1]) / (knots[i] - knots[i - 1])
            sign = 1.0 if gwl > 0.0 else -1.0
            return True, slope * sign, "segment"
    raise RuntimeError("unreachable derivative branch")


def make_cases():
    cases = []
    cases.append(([10.0, 50.0, 100.0], [-0.2, 0.4, 1.7]))
    cases.append(([0.0, 2.0, 11.0, 80.0], [0.0, -0.1, 0.8, 2.0]))
    cases.append(([7.5], [0.63]))
    cases.append(([float(i * i + 1) for i in range(25)], [math.sin(i / 3.0) for i in range(25)]))
    rng = random.Random(390821)
    for _ in range(28):
        n = rng.randint(2, 25)
        x = rng.uniform(0.0, 4.0)
        knots = []
        for _j in range(n):
            x += rng.uniform(0.05, 40.0)
            knots.append(x)
        values = [rng.uniform(-3.0, 6.0) for _j in range(n)]
        cases.append((knots, values))
    return cases


def probe_levels(knots):
    probes = {0.0, -0.0, knots[0] - 1.0, -(knots[0] - 1.0), knots[-1] + 2.0, -(knots[-1] + 2.0)}
    for k in knots:
        probes.add(k)
        probes.add(-k)
    for a, b in zip(knots[:-1], knots[1:]):
        mid = a + 0.371 * (b - a)
        probes.add(mid)
        probes.add(-mid)
    return sorted(probes)


def write_sources(tmp, candidate_source):
    Path(tmp, "mod_process_hydraulic_view.f90").write_text(
        """module mod_process_hydraulic_view
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  type :: process_hydraulic_view_t
    real(real64) :: groundwater_level = 0.0_real64
  end type process_hydraulic_view_t
end module mod_process_hydraulic_view
"""
    )
    Path(tmp, "candidate.f90").write_text(candidate_source)
    Path(tmp, "driver.f90").write_text(
        """program fvq39_driver
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_tabulated_response
  implicit none
  type(drainage_tabulated_parameters_t) :: p
  type(process_hydraulic_view_t) :: h
  type(drainage_tabulated_result_t) :: r
  type(drainage_tabulated_diagnostics_t) :: d
  integer :: n, m, i
  real(real64) :: gwl
  read(*,*) n
  allocate(p%groundwater_depth(n), p%signed_exchange_rate(n))
  read(*,*) p%groundwater_depth
  read(*,*) p%signed_exchange_rate
  read(*,*) m
  do i=1,m
    read(*,*) gwl
    h%groundwater_level = gwl
    call evaluate_tabulated_drainage_response(p,h,r,d)
    write(*,'(ES26.17E3,1X,L1,1X,ES26.17E3,1X,I0,1X,L1,1X,L1,1X,L1,1X,I0)') &
      r%signed_soil_to_drain_rate, r%derivative_defined, r%dq_dgroundwater_level, d%status, &
      d%clamped_lower, d%clamped_upper, d%at_table_knot, d%segment_index
  end do
end program fvq39_driver
"""
    )


def compile_driver(tmp, opt):
    exe = Path(tmp, f"driver_{opt.replace('-', '')}")
    cmd = [
        "gfortran", "-std=f2008", "-Wall", "-Wextra", "-pedantic", opt,
        "-J", tmp, "-I", tmp,
        str(Path(tmp, "mod_process_hydraulic_view.f90")),
        str(Path(tmp, "candidate.f90")),
        str(Path(tmp, "driver.f90")), "-o", str(exe),
    ]
    cp = sh(*cmd, check=False)
    if cp.returncode != 0:
        print(cp.stdout)
        print(cp.stderr, file=sys.stderr)
        raise RuntimeError(f"compile failed {opt}")
    return exe


def run_case(exe, knots, values, probes):
    payload = [
        str(len(knots)),
        " ".join(f"{x:.17g}" for x in knots),
        " ".join(f"{y:.17g}" for y in values),
        str(len(probes)),
    ]
    payload.extend(f"{g:.17g}" for g in probes)
    cp = sh(str(exe), input_text="\n".join(payload) + "\n")
    rows = []
    for line in cp.stdout.splitlines():
        parts = line.split()
        rows.append({
            "q": float(parts[0]),
            "defined": parts[1] == "T",
            "dq": float(parts[2]),
            "status": int(parts[3]),
            "lower": parts[4] == "T",
            "upper": parts[5] == "T",
            "knot": parts[6] == "T",
            "segment": int(parts[7]),
        })
    if len(rows) != len(probes):
        raise RuntimeError("unexpected driver row count")
    return rows, cp.stdout


def close(a, b, atol=2e-12, rtol=2e-12):
    return abs(a - b) <= atol + rtol * max(abs(a), abs(b))


def main():
    manifest = MANIFEST.read_text()
    require(DRAINAGE_SHA256 in manifest and "SWAP/drainage.f90" in manifest,
            "FVQ39_FROZEN_DRAINAGE_SOURCE_IDENTITY")
    require(FUNCTIONS_SHA256 in manifest and "SWAP/functions.f90" in manifest,
            "FVQ39_FROZEN_AFGEN_SOURCE_IDENTITY")

    blob = sh("git", "rev-parse", f"{CANDIDATE}:{CANDIDATE_PATH}").stdout.strip()
    require(blob == CANDIDATE_BLOB, "FVQ39_CANDIDATE_CLOSEOUT_BLOB_IDENTITY", blob)
    candidate_source = sh("git", "show", f"{CANDIDATE}:{CANDIDATE_PATH}").stdout
    low = candidate_source.lower()
    require("abs(hydraulic_view%groundwater_level)" in low,
            "FVQ39_CANDIDATE_ABS_GWL_STATIC_BINDING")
    require("open(" not in low and "read(" not in low and ".dra" not in low and "headcalc" not in low,
            "FVQ39_NO_IO_OR_HEADCALC_LEAKAGE")

    total = 0
    derivative_checks = 0
    max_flux_abs = 0.0
    max_flux_rel = 0.0
    max_dq_abs = 0.0
    max_dq_rel = 0.0
    raw_identity = True

    with tempfile.TemporaryDirectory(prefix="fvq39_") as tmp:
        write_sources(tmp, candidate_source)
        exe0 = compile_driver(tmp, "-O0")
        exe2 = compile_driver(tmp, "-O2")

        for knots, values in make_cases():
            probes = probe_levels(knots)
            rows0, raw0 = run_case(exe0, knots, values, probes)
            rows2, raw2 = run_case(exe2, knots, values, probes)
            raw_identity = raw_identity and raw0 == raw2
            table = legacy_qdrtab(knots, values)
            for gwl, row in zip(probes, rows0):
                q_ref = legacy_afgen(table, abs(gwl))
                if row["status"] != 0:
                    raise AssertionError(f"candidate status {row['status']} on admissible table")
                err = abs(row["q"] - q_ref)
                rel = err / max(abs(q_ref), 1e-30)
                max_flux_abs = max(max_flux_abs, err)
                max_flux_rel = max(max_flux_rel, rel)
                if not close(row["q"], q_ref):
                    raise AssertionError(f"flux mismatch gwl={gwl} got={row['q']} ref={q_ref}")
                defined, dq_ref, branch = normalized_derivative(knots, values, gwl)
                if branch == "knot":
                    if row["defined"] or not row["knot"]:
                        raise AssertionError("knot derivative policy mismatch")
                else:
                    if not row["defined"]:
                        raise AssertionError("smooth derivative unexpectedly unavailable")
                    derr = abs(row["dq"] - dq_ref)
                    drel = derr / max(abs(dq_ref), 1e-30)
                    max_dq_abs = max(max_dq_abs, derr)
                    max_dq_rel = max(max_dq_rel, drel)
                    if not close(row["dq"], dq_ref, atol=5e-12, rtol=5e-12):
                        raise AssertionError(f"derivative mismatch gwl={gwl} got={row['dq']} ref={dq_ref}")
                    derivative_checks += 1
                total += 1

        require(raw_identity, "FVQ39_CANDIDATE_O0_O2_OUTPUT_IDENTITY")
        require(True, "FVQ39_NORMALIZED_AFGEN_FLUX_EQUIVALENCE")
        require(True, "FVQ39_POSITIVE_NEGATIVE_ABS_GWL_PARITY")
        require(True, "FVQ39_ENDPOINT_CLAMPING_AND_INTERPOLATION")
        require(True, "FVQ39_OPEN_SEGMENT_DERIVATIVE_INDEPENDENT_CHECK")
        require(True, "FVQ39_KNOT_DERIVATIVE_UNAVAILABLE_CONSERVATIVE")

        # Source-observable legacy-degenerate case. RDADOR permits a one-element
        # array. read_drainage_basic writes qdrtab(1)=abs(0)=0 and qdrtab(2)=q,
        # leaving qdrtab(3:50)=0. AFGEN therefore returns q at x=0 but, for x>0,
        # never sees a strictly decreasing terminator and eventually returns
        # qdrtab(50)=0. The current candidate instead treats n=1 as constant.
        knots = [0.0]
        values = [2.75]
        probes = [0.0, 1.0, -1.0, 100.0]
        rows0, raw0 = run_case(exe0, knots, values, probes)
        rows2, raw2 = run_case(exe2, knots, values, probes)
        require(raw0 == raw2, "FVQ39_DEGENERATE_CASE_O0_O2_IDENTITY")
        table = legacy_qdrtab(knots, values)
        refs = [legacy_afgen(table, abs(g)) for g in probes]
        got = [r["q"] for r in rows0]
        mismatch = any(not close(a, b) for a, b in zip(got, refs))

        summary = {
            "candidate_closeout": CANDIDATE,
            "candidate_blob": CANDIDATE_BLOB,
            "normal_cases": total,
            "derivative_checks": derivative_checks,
            "max_flux_abs_error": max_flux_abs,
            "max_flux_rel_error": max_flux_rel,
            "max_derivative_abs_error": max_dq_abs,
            "max_derivative_rel_error": max_dq_rel,
            "degenerate_one_point_zero": {
                "knots": knots,
                "values": values,
                "probes": probes,
                "legacy": refs,
                "candidate": got,
                "mismatch": mismatch,
            },
        }
        text = json.dumps(summary, sort_keys=True)
        print("FVQ39_SUMMARY=" + text)
        print("FVQ39_SUMMARY_SHA256=" + hashlib.sha256(text.encode()).hexdigest())

        if mismatch:
            print("FVQ39_ONE_POINT_ZERO_LEGACY_COUNTEREXAMPLE=FAIL_CLOSED_SOURCE_OBSERVABLE_MISMATCH")
            print("FVQ39_DRAMET1_SCIENTIFIC_EQUIVALENCE=FAIL_CLOSED_REMEDIATION_REQUIRED")
            return 2

    print("FVQ39_ONE_POINT_ZERO_LEGACY_COUNTEREXAMPLE=PASS")
    print("FVQ39_DRAMET1_SCIENTIFIC_EQUIVALENCE=PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
