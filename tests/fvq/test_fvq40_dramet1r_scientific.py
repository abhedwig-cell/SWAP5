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
CANDIDATE = "d87e21c9603063add7a7440a0aebe6fbac326d03"
CANDIDATE_PATH = "src/process/mod_drainage_tabulated_response.f90"
CANDIDATE_BLOB = "738f57c334910ab73bc8870e3aa8dda1c1a48c7a"
DRAINAGE_SHA256 = "48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc"
FUNCTIONS_SHA256 = "b32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527"
MANIFEST = Path("reference/swap-4.3.1/b0/file-manifest.sha256")
DEGENERATE_STATUS = 3


def sh(*args, input_text=None, check=True):
    return subprocess.run(args, input=input_text, text=True, capture_output=True, check=check)


def require(condition, marker, detail=""):
    if not condition:
        print(f"{marker}=FAIL" + (f" {detail}" if detail else ""))
        raise AssertionError(marker)
    print(f"{marker}=PASS")


def close(a, b, atol=2.0e-12, rtol=2.0e-12):
    return abs(a-b) <= atol + rtol*max(abs(a), abs(b))


def legacy_qdrtab(knots, values):
    table = [0.0]*50
    for i, (x, y) in enumerate(zip(knots, values)):
        table[2*i] = abs(float(x))
        table[2*i+1] = float(y)
    return table


def legacy_afgen(table, x):
    x = float(x)
    if table[0] >= x:
        return table[1]
    for idx in range(2, 49, 2):
        if table[idx] >= x:
            slope = (table[idx+1]-table[idx-1])/(table[idx]-table[idx-2])
            return table[idx-1] + (x-table[idx-2])*slope
        if table[idx] < table[idx-2]:
            return table[idx-1]
    return table[49]


def expected_derivative(knots, values, gwl):
    depth = abs(gwl)
    if len(knots) == 1:
        return True, 0.0, "single"
    if depth < knots[0] or depth > knots[-1]:
        return True, 0.0, "clamp"
    if any(depth == k for k in knots):
        return False, 0.0, "knot"
    for i in range(1, len(knots)):
        if depth < knots[i]:
            slope = (values[i]-values[i-1])/(knots[i]-knots[i-1])
            return True, slope if gwl > 0.0 else -slope, "segment"
    raise RuntimeError("unreachable derivative branch")


def valid_cases():
    cases = [
        ([10.0, 50.0, 100.0], [-0.2, 0.4, 1.7]),
        ([0.0, 2.0, 11.0, 80.0], [0.0, -0.1, 0.8, 2.0]),
        ([7.5], [0.63]),
        ([40.0], [-0.17]),
        ([float(i*i+1) for i in range(25)], [math.sin(i/3.0) for i in range(25)]),
    ]
    rng = random.Random(400831)
    for _ in range(64):
        n = rng.randint(2, 25)
        knots = []
        x = rng.uniform(0.0, 5.0)
        for _j in range(n):
            x += rng.uniform(0.05, 35.0)
            knots.append(x)
        values = [rng.uniform(-5.0, 7.0) for _j in range(n)]
        cases.append((knots, values))
    return cases


def probes_for(knots):
    depths = {0.0}
    if knots[0] > 0.0:
        depths.add(0.25*knots[0])
    depths.add(knots[-1] + max(1.0, 0.1*knots[-1]))
    for k in knots:
        depths.add(k)
    for a, b in zip(knots[:-1], knots[1:]):
        depths.add(a + 0.371*(b-a))
        depths.add(a + 0.733*(b-a))
    gwls = set()
    for d in depths:
        gwls.add(d)
        gwls.add(-d)
    return sorted(gwls)


def write_sources(tmp, candidate_source):
    Path(tmp, "mod_process_hydraulic_view.f90").write_text("""module mod_process_hydraulic_view
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  type :: process_hydraulic_view_t
    real(real64) :: groundwater_level = 0.0_real64
  end type process_hydraulic_view_t
end module mod_process_hydraulic_view
""")
    Path(tmp, "candidate.f90").write_text(candidate_source)
    Path(tmp, "driver.f90").write_text("""program fvq40_driver
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
    write(*,'(ES26.17E3,1X,L1,1X,ES26.17E3,1X,I0,1X,L1,1X,L1,1X,L1,1X,L1,1X,I0)') &
      r%signed_soil_to_drain_rate, r%derivative_defined, r%dq_dgroundwater_level, d%status, d%evaluated, &
      d%clamped_lower, d%clamped_upper, d%at_table_knot, d%segment_index
  end do
end program fvq40_driver
""")


def compile_driver(tmp, opt):
    exe = Path(tmp, "driver_" + opt.replace("-", ""))
    cmd = ["gfortran", "-std=f2008", "-Wall", "-Wextra", "-pedantic", opt,
           "-J", tmp, "-I", tmp,
           str(Path(tmp, "mod_process_hydraulic_view.f90")),
           str(Path(tmp, "candidate.f90")), str(Path(tmp, "driver.f90")), "-o", str(exe)]
    cp = sh(*cmd, check=False)
    if cp.returncode != 0:
        print(cp.stdout)
        print(cp.stderr, file=sys.stderr)
        raise RuntimeError("compile failed " + opt)
    return exe


def run_case(exe, knots, values, probes):
    payload = [str(len(knots)),
               " ".join(f"{x:.17g}" for x in knots),
               " ".join(f"{y:.17g}" for y in values),
               str(len(probes))]
    payload.extend(f"{g:.17g}" for g in probes)
    cp = sh(str(exe), input_text="\n".join(payload)+"\n")
    rows = []
    for line in cp.stdout.splitlines():
        p = line.split()
        rows.append({"q": float(p[0]), "defined": p[1] == "T", "dq": float(p[2]),
                     "status": int(p[3]), "evaluated": p[4] == "T", "lower": p[5] == "T",
                     "upper": p[6] == "T", "knot": p[7] == "T", "segment": int(p[8])})
    if len(rows) != len(probes):
        raise RuntimeError("unexpected driver row count")
    return rows, cp.stdout


def main():
    manifest = MANIFEST.read_text()
    require(DRAINAGE_SHA256 in manifest and "SWAP/drainage.f90" in manifest,
            "FVQ40_FROZEN_DRAINAGE_SOURCE_IDENTITY")
    require(FUNCTIONS_SHA256 in manifest and "SWAP/functions.f90" in manifest,
            "FVQ40_FROZEN_AFGEN_SOURCE_IDENTITY")

    blob = sh("git", "rev-parse", f"{CANDIDATE}:{CANDIDATE_PATH}").stdout.strip()
    require(blob == CANDIDATE_BLOB, "FVQ40_REMEDIATED_CANDIDATE_BLOB_IDENTITY", blob)
    source = sh("git", "show", f"{CANDIDATE}:{CANDIDATE_PATH}").stdout
    low = source.lower()
    require("drain_tab_unsupported_legacy_degenerate = 3" in low,
            "FVQ40_EXPLICIT_DEGENERATE_STATUS_STATIC")
    require("abs(hydraulic_view%groundwater_level)" in low,
            "FVQ40_ABS_GWL_STATIC_BINDING")
    require("open(" not in low and "read(" not in low and ".dra" not in low and "headcalc" not in low,
            "FVQ40_NO_IO_OR_HEADCALC_LEAKAGE")

    total = 0
    derivative_checks = 0
    one_point_positive_checks = 0
    max_flux_abs = 0.0
    max_flux_rel = 0.0
    max_dq_abs = 0.0
    max_dq_rel = 0.0
    raw_identity = True
    degenerate_checks = 0
    degenerate_legacy_examples = []

    with tempfile.TemporaryDirectory(prefix="fvq40_") as tmp:
        write_sources(tmp, source)
        exe0 = compile_driver(tmp, "-O0")
        exe2 = compile_driver(tmp, "-O2")

        for knots, values in valid_cases():
            probes = probes_for(knots)
            rows0, raw0 = run_case(exe0, knots, values, probes)
            rows2, raw2 = run_case(exe2, knots, values, probes)
            raw_identity = raw_identity and raw0 == raw2
            table = legacy_qdrtab(knots, values)
            for gwl, row in zip(probes, rows0):
                require_status = row["status"] == 0 and row["evaluated"]
                if not require_status:
                    raise AssertionError(f"valid normalized table rejected gwl={gwl} status={row['status']}")
                q_ref = legacy_afgen(table, abs(gwl))
                err = abs(row["q"]-q_ref)
                rel = err/max(abs(q_ref), 1.0e-30)
                max_flux_abs = max(max_flux_abs, err)
                max_flux_rel = max(max_flux_rel, rel)
                if not close(row["q"], q_ref):
                    raise AssertionError(f"flux mismatch gwl={gwl} got={row['q']} ref={q_ref}")
                defined, dq_ref, branch = expected_derivative(knots, values, gwl)
                if branch == "knot":
                    if row["defined"] or not row["knot"]:
                        raise AssertionError("knot derivative policy mismatch")
                else:
                    if not row["defined"]:
                        raise AssertionError("smooth derivative unavailable")
                    derr = abs(row["dq"]-dq_ref)
                    drel = derr/max(abs(dq_ref), 1.0e-30)
                    max_dq_abs = max(max_dq_abs, derr)
                    max_dq_rel = max(max_dq_rel, drel)
                    if not close(row["dq"], dq_ref, atol=5.0e-12, rtol=5.0e-12):
                        raise AssertionError(f"derivative mismatch gwl={gwl} got={row['dq']} ref={dq_ref}")
                    derivative_checks += 1
                if len(knots) == 1:
                    one_point_positive_checks += 1
                total += 1

        for value in [-3.25, 0.0, 2.75, 9.0]:
            knots = [0.0]
            values = [value]
            probes = [0.0, 1.0, -1.0, 100.0, -100.0]
            rows0, raw0 = run_case(exe0, knots, values, probes)
            rows2, raw2 = run_case(exe2, knots, values, probes)
            raw_identity = raw_identity and raw0 == raw2
            table = legacy_qdrtab(knots, values)
            legacy = [legacy_afgen(table, abs(g)) for g in probes]
            degenerate_legacy_examples.append({"value": value, "legacy": legacy})
            for gwl, row in zip(probes, rows0):
                if not (row["status"] == DEGENERATE_STATUS and not row["evaluated"] and
                        close(row["q"], 0.0) and not row["defined"]):
                    raise AssertionError(f"legacy-degenerate representation not rejected gwl={gwl} row={row}")
                degenerate_checks += 1

    require(raw_identity, "FVQ40_CANDIDATE_O0_O2_OUTPUT_IDENTITY")
    require(total > 2000, "FVQ40_BROAD_VALID_NORMALIZED_DOMAIN_COVERAGE", str(total))
    require(one_point_positive_checks > 0, "FVQ40_POSITIVE_DEPTH_SINGLETON_LEGACY_EQUIVALENCE")
    require(True, "FVQ40_NORMALIZED_AFGEN_FLUX_EQUIVALENCE")
    require(True, "FVQ40_POSITIVE_NEGATIVE_ABS_GWL_PARITY")
    require(True, "FVQ40_ENDPOINT_KNOT_AND_INTERPOLATION_EQUIVALENCE")
    require(True, "FVQ40_OPEN_SEGMENT_DERIVATIVE_INDEPENDENT_CHECK")
    require(True, "FVQ40_KNOT_DERIVATIVE_UNAVAILABLE_CONSERVATIVE")
    require(degenerate_checks == 20, "FVQ40_ZERO_DEPTH_SINGLETON_FAIL_CLOSED_POLICY")

    summary = {
        "candidate_closeout": CANDIDATE,
        "candidate_blob": CANDIDATE_BLOB,
        "valid_normalized_probes": total,
        "derivative_checks": derivative_checks,
        "positive_singleton_probes": one_point_positive_checks,
        "legacy_degenerate_rejection_checks": degenerate_checks,
        "max_flux_abs_error": max_flux_abs,
        "max_flux_rel_error": max_flux_rel,
        "max_derivative_abs_error": max_dq_abs,
        "max_derivative_rel_error": max_dq_rel,
        "degenerate_legacy_examples": degenerate_legacy_examples,
    }
    text = json.dumps(summary, sort_keys=True)
    print("FVQ40_SUMMARY=" + text)
    print("FVQ40_SUMMARY_SHA256=" + hashlib.sha256(text.encode()).hexdigest())
    print("FVQ40_DRAMET1_REMEDIATED_SCIENTIFIC_REQUALIFICATION PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
