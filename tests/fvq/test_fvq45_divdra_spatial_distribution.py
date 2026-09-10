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
CANDIDATE = "186df3daa27d7b3541da694190d6f8ec9fab7da6"
CANDIDATE_PATH = "src/process/mod_drainage_spatial_distribution.f90"
CANDIDATE_BLOB = "9e4a196eecf971698b16d4a882f5aa8b32b66ebe"
DIVDRA_SHA256 = "d5917c80dde091f8264f875997ee7105d8b5f9b88e9d091ce162860930de8c91"
EXCERPT_HASHES = [
    "6f29f55d478c1b8a6d7c0f132ebe3613927be602f7c79790133eca04046412e9",
    "860fb3a73802e53a8f24534aa74e4e786214a34f956140701508f5a14da3393a",
    "37a881fb5b5067f2b8b1666777e65e0b0c666063d25eb452e28a882bf5517368",
    "4b425062ce3806c102e617a70fac42c6ca58407ef82080a6b442d681217a3ca7",
    "d275f71fdff7d85fb04716e68a17d6c28ae9f539fa9742e53ec8373633a23669",
]
MANIFEST = Path("reference/swap-4.3.1/b0/file-manifest.sha256")
ORACLE_SOURCE = Path("integration/f-vq/F-VQ45_LEGACY_ORACLE_SOURCE.txt")
EPS = sys.float_info.epsilon
SMALL = 1.0e-10


def sh(*args, input_text=None, check=True):
    return subprocess.run(args, input=input_text, text=True, capture_output=True, check=check)


def require(condition, marker, detail=""):
    if not condition:
        print(f"{marker}=FAIL" + (f" {detail}" if detail else ""))
        raise AssertionError(marker)
    print(f"{marker}=PASS")


def normalized(value):
    return float(f"{value:.17g}")


def legacy_divdra_oracle(case):
    dz = case["dz"]
    zbot = case["zbot"]
    ksat = case["ksat"]
    aniso = case["aniso"]
    q = case["q"]
    gwl = case["gwl"]
    spacing = case["spacing"]
    n = len(dz)

    if abs(q) <= SMALL:
        return {"no_flux": True, "nodes": [0.0] * n, "wt": 0, "bottom": 0}

    wlev = -min(gwl, 0.0)
    khor = [ksat[i] * aniso[i] for i in range(n)]
    kver = list(ksat)

    wt = 0
    while wlev > (-zbot[wt]) + 1.0e-10:
        wt += 1
        if wt >= n:
            raise ValueError("legacy Lev2Comp below profile")
    dz_top_sat = -zbot[wt] - wlev

    kd_hor = dz_top_sat * khor[wt]
    kd_ver = dz_top_sat / kver[wt]
    sat_depth = dz_top_sat
    for i in range(wt + 1, n):
        kd_hor += dz[i] * khor[i]
        kd_ver += dz[i] / kver[i]
        sat_depth += dz[i]

    khor_avg = kd_hor / sat_depth
    kver_avg = sat_depth / kd_ver
    fac_aniso = math.sqrt(kver_avg / khor_avg)
    dmax = 0.25 * spacing * fac_aniso + wlev
    dmax = min(dmax, sat_depth + wlev)

    kd_drain = kd_hor
    discharge_bottom = -zbot[-1]
    bottom = n - 1
    discharge_thickness = dz[-1]
    truncated = False

    if discharge_bottom > dmax:
        truncated = True
        discharge_bottom = dmax
        bottom = wt
        depth_accum = dz_top_sat
        kd_drain = dz_top_sat * khor[wt]
        discharge_depth = discharge_bottom - wlev
        while discharge_depth > depth_accum:
            bottom += 1
            if bottom >= n:
                raise ValueError("legacy discharge layer below profile")
            depth_accum += dz[bottom]
            kd_drain += dz[bottom] * khor[bottom]
        kd_drain -= (depth_accum - discharge_depth) * khor[bottom]
        discharge_thickness = dz[bottom] - (depth_accum - discharge_depth)

    nodes = [0.0] * n
    if wt == bottom:
        nodes[wt] = q
    else:
        nodes[wt] = q * dz_top_sat * khor[wt] / kd_drain
        for i in range(wt + 1, bottom):
            nodes[i] = q * dz[i] * khor[i] / kd_drain
        nodes[bottom] = q * discharge_thickness * khor[bottom] / kd_drain

    return {
        "no_flux": False,
        "nodes": nodes,
        "wt": wt + 1,
        "bottom": bottom + 1,
        "wlev": wlev,
        "dz_top_sat": dz_top_sat,
        "bottom_thickness": discharge_thickness,
        "fac_aniso": fac_aniso,
        "discharge_bottom": discharge_bottom,
        "kd_drain": kd_drain,
        "raw_sum": sum(nodes),
        "truncated": truncated,
        "single_compartment": wt == bottom,
    }


def write_sources(tmp, candidate_source):
    Path(tmp, "hydraulic_stub.f90").write_text("\n".join([
        "module mod_process_hydraulic_view",
        "  use, intrinsic :: iso_fortran_env, only: real64",
        "  implicit none",
        "  type :: process_hydraulic_view_t",
        "    real(real64) :: groundwater_level = 0.0_real64",
        "  end type process_hydraulic_view_t",
        "end module mod_process_hydraulic_view",
        "",
    ]))
    Path(tmp, "candidate.f90").write_text(candidate_source)
    Path(tmp, "driver.f90").write_text(r'''program fvq45_driver
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution
  implicit none
  type(drainage_distribution_parameters_t) :: p
  type(process_hydraulic_view_t) :: h
  type(drainage_node_transfer_t) :: nt
  type(drainage_distribution_diagnostics_t) :: d
  integer :: ncases, icase, n, i, b
  real(real64) :: q, sum_nodes, identity_residual

  read(*,*) ncases
  do icase = 1, ncases
    read(*,*) n, q, h%groundwater_level, p%drain_spacing
    p%active_nodes = n
    allocate(p%dz(n), p%zbotcp(n), p%saturated_conductivity(n), p%horizontal_anisotropy_factor(n))
    do i = 1, n
      read(*,*) p%dz(i), p%zbotcp(i), p%saturated_conductivity(i), p%horizontal_anisotropy_factor(i)
    end do

    call distribute_single_level_positive_divdra(p, h, q, nt, d)
    sum_nodes = 0.0_real64
    identity_residual = 0.0_real64
    if (allocated(nt%soil_to_drain_rate)) then
      sum_nodes = sum(nt%soil_to_drain_rate)
      b = d%discharge_bottom_node
      if (d%evaluated .and. b > 0) then
        if (b == 1) then
          identity_residual = nt%soil_to_drain_rate(b) - q
        else
          identity_residual = nt%soil_to_drain_rate(b) - (q - sum(nt%soil_to_drain_rate(1:b-1)))
        end if
      end if
    end if

    write(*,*) d%status, d%evaluated, d%zero_transfer, d%water_table_node, d%discharge_bottom_node, &
      d%groundwater_depth, d%saturated_top_thickness, d%discharge_bottom_thickness, &
      d%profile_anisotropy_factor, d%discharge_layer_bottom_depth, d%discharge_transmissivity, &
      d%raw_partition_sum, d%closure_correction, d%scalar_transfer_is_authoritative, d%worker_scratch_only, &
      sum_nodes, identity_residual, n, (nt%soil_to_drain_rate(i), i=1,n)

    if (allocated(p%dz)) deallocate(p%dz)
    if (allocated(p%zbotcp)) deallocate(p%zbotcp)
    if (allocated(p%saturated_conductivity)) deallocate(p%saturated_conductivity)
    if (allocated(p%horizontal_anisotropy_factor)) deallocate(p%horizontal_anisotropy_factor)
    if (allocated(nt%soil_to_drain_rate)) deallocate(nt%soil_to_drain_rate)
  end do
end program fvq45_driver
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
        n = len(case["dz"])
        lines.append(f"{n} {case['q']:.17g} {case['gwl']:.17g} {case['spacing']:.17g}")
        for i in range(n):
            lines.append(f"{case['dz'][i]:.17g} {case['zbot'][i]:.17g} {case['ksat'][i]:.17g} {case['aniso'][i]:.17g}")
    return "\n".join(lines) + "\n"


def run_cases(exe, cases):
    cp = sh(str(exe), input_text=payload_for(cases))
    rows = []
    for line in cp.stdout.splitlines():
        parts = line.split()
        if len(parts) < 18:
            raise RuntimeError(f"unexpected candidate output: {line}")
        n = int(parts[17])
        if len(parts) != 18 + n:
            raise RuntimeError(f"unexpected candidate node count: {line}")
        rows.append({
            "status": int(parts[0]), "evaluated": parts[1] == "T", "zero": parts[2] == "T",
            "wt": int(parts[3]), "bottom": int(parts[4]), "wlev": float(parts[5]),
            "dz_top": float(parts[6]), "bottom_thickness": float(parts[7]), "fac": float(parts[8]),
            "discharge_bottom": float(parts[9]), "kd": float(parts[10]), "raw_sum": float(parts[11]),
            "closure": float(parts[12]), "scalar_authoritative": parts[13] == "T",
            "worker_scratch": parts[14] == "T", "sum_nodes": float(parts[15]),
            "identity_residual": float(parts[16]), "nodes": [float(x) for x in parts[18:]],
        })
    if len(rows) != len(cases):
        raise RuntimeError(f"unexpected row count {len(rows)} != {len(cases)}")
    return rows, cp.stdout


def make_profile(rng, n):
    dz = [normalized(rng.uniform(4.0, 45.0)) for _ in range(n)]
    zbot = []
    depth = 0.0
    for thickness in dz:
        depth = normalized(depth + thickness)
        zbot.append(-depth)
    ksat = [normalized(10.0 ** rng.uniform(-3.0, 2.0)) for _ in range(n)]
    aniso = [normalized(10.0 ** rng.uniform(-0.7, 1.0)) for _ in range(n)]
    return dz, zbot, ksat, aniso


def make_stable_cases():
    rng = random.Random(450801)
    cases = []
    for index in range(900):
        n = rng.randint(2, 8)
        dz, zbot, ksat, aniso = make_profile(rng, n)
        bottoms = [-z for z in zbot]
        if index % 10 == 0:
            wlev = 0.0
        else:
            wt = rng.randrange(n)
            top = 0.0 if wt == 0 else bottoms[wt - 1]
            bottom = bottoms[wt]
            wlev = normalized(top + rng.uniform(0.15, 0.85) * (bottom - top))
        gwl = normalized(-wlev)
        q = normalized(10.0 ** rng.uniform(-8.5, 1.5))
        if q <= SMALL:
            q = 1.01e-10
        if index % 3 == 0:
            spacing = normalized(rng.uniform(0.05, 3.0))
        elif index % 3 == 1:
            spacing = normalized(rng.uniform(5.0, 100.0))
        else:
            spacing = normalized(rng.uniform(200.0, 5000.0))
        cases.append({"dz": dz, "zbot": zbot, "ksat": ksat, "aniso": aniso, "q": q, "gwl": gwl, "spacing": spacing})
    return cases


def make_boundary_cases():
    dz = [10.0, 15.0, 20.0, 25.0]
    zbot = [-10.0, -25.0, -45.0, -70.0]
    ksat = [0.8, 3.0, 0.15, 8.0]
    aniso = [1.0, 2.5, 0.7, 4.0]
    spacing = 80.0
    q = 1.23456789
    offsets = [-2.0e-10, -5.0e-11, 0.0, 5.0e-11, 1.0e-10, 1.5e-10, 2.0e-10]
    cases = []
    for boundary in (10.0, 25.0, 45.0):
        for offset in offsets:
            wlev = boundary + offset
            cases.append({"dz": dz, "zbot": zbot, "ksat": ksat, "aniso": aniso, "q": q, "gwl": -wlev, "spacing": spacing, "boundary": boundary, "offset": offset})
    return cases


def near(a, b, scale=1.0, factor=256.0):
    return abs(a - b) <= factor * EPS * max(1.0, abs(a), abs(b), abs(scale))


def main():
    manifest = MANIFEST.read_text()
    require(DIVDRA_SHA256 in manifest and "SWAP/divdra.f90" in manifest, "FVQ45_FROZEN_DIVDRA_SOURCE_IDENTITY")
    oracle_text = ORACLE_SOURCE.read_text()
    require(all(h in oracle_text for h in EXCERPT_HASHES), "FVQ45_EQUATION_LEVEL_EXCERPT_BINDING")
    for token in ["abs(qdrain(idr)) > Small", "wlev = -1.0d0*min(gwlev,0.0d0)", "FacAniso = dsqrt(KverAv / KhorAv)", "0.25d0*Lspacing(idr)*FacAniso+wlev", "qdrain(idr) * dzcpwlevsat * Khor(icpwlev) / KDdr(idr)", "lev > -zbotcp(icplev)+1.d-10"]:
        require(token in oracle_text, "FVQ45_LEGACY_SOURCE_TOKEN", token)

    blob = sh("git", "rev-parse", f"{CANDIDATE}:{CANDIDATE_PATH}").stdout.strip()
    require(blob == CANDIDATE_BLOB, "FVQ45_CANDIDATE_CLOSEOUT_BLOB_IDENTITY", blob)
    source = sh("git", "show", f"{CANDIDATE}:{CANDIDATE_PATH}").stdout
    low = source.lower()
    for forbidden in ["headcalc", "modflow", ".dra", "calendar", "open(", "read(", "write(", " save"]:
        require(forbidden not in low, "FVQ45_NO_FORBIDDEN_DISTRIBUTOR_COUPLING", forbidden)
    require("scalar_transfer_is_authoritative" in low and "worker_scratch_only" in low, "FVQ45_MASS_AND_SCRATCH_OWNERSHIP_STATIC_BINDING")

    stable_cases = make_stable_cases()
    boundary_cases = make_boundary_cases()
    zero_case = {"dz": [10.0, 20.0, 30.0], "zbot": [-10.0, -30.0, -60.0], "ksat": [1.0, 2.0, 3.0], "aniso": [1.0, 1.5, 0.8], "q": 0.0, "gwl": float("nan"), "spacing": 50.0}
    small_cases = []
    for q in [math.nextafter(0.0, 1.0), 0.5e-10, 1.0e-10]:
        small_cases.append({"dz": [10.0, 20.0, 30.0], "zbot": [-10.0, -30.0, -60.0], "ksat": [1.0, 2.0, 3.0], "aniso": [1.0, 1.5, 0.8], "q": q, "gwl": -12.0, "spacing": 50.0})
    cases = stable_cases + boundary_cases + [zero_case] + small_cases

    max_node_abs = 0.0
    max_diag_abs = 0.0
    max_legacy_raw_closure = 0.0
    max_candidate_closure_correction = 0.0
    truncated_count = 0
    full_profile_count = 0
    single_compartment_count = 0
    seam_mismatch_count = 0
    seam_examples = []

    with tempfile.TemporaryDirectory(prefix="fvq45_") as tmp:
        write_sources(tmp, source)
        exe0 = compile_driver(tmp, "-O0")
        exe2 = compile_driver(tmp, "-O2")
        rows0, out0 = run_cases(exe0, cases)
        rows2, out2 = run_cases(exe2, cases)
        require(rows0 == rows2, "FVQ45_O0_O2_PARSED_RESULT_IDENTITY")

        for case, row in zip(stable_cases, rows0[:len(stable_cases)]):
            ref = legacy_divdra_oracle(case)
            if row["status"] != 0 or not row["evaluated"] or row["zero"]:
                raise AssertionError(f"stable valid case rejected: {row}")
            if not row["scalar_authoritative"] or not row["worker_scratch"]:
                raise AssertionError("mass/scratch ownership diagnostics false")
            if row["wt"] != ref["wt"] or row["bottom"] != ref["bottom"]:
                raise AssertionError(f"stable node selection mismatch row={row} ref={ref}")
            for got, expected in [(row["wlev"], ref["wlev"]), (row["dz_top"], ref["dz_top_sat"]), (row["bottom_thickness"], ref["bottom_thickness"]), (row["fac"], ref["fac_aniso"]), (row["discharge_bottom"], ref["discharge_bottom"]), (row["kd"], ref["kd_drain"])]:
                max_diag_abs = max(max_diag_abs, abs(got - expected))
                if not near(got, expected, scale=expected, factor=1024.0):
                    raise AssertionError(f"stable diagnostic mismatch got={got} expected={expected}")

            bottom = ref["bottom"] - 1
            for i, (got, raw) in enumerate(zip(row["nodes"], ref["nodes"])):
                max_node_abs = max(max_node_abs, abs(got - raw))
                if i != bottom and not near(got, raw, scale=case["q"], factor=1024.0):
                    raise AssertionError(f"non-bottom node mismatch i={i} got={got} raw={raw}")
            if not near(row["nodes"][bottom], ref["nodes"][bottom], scale=case["q"], factor=4096.0):
                raise AssertionError("bottom-node roundoff closure exceeds machine-scale bound")

            legacy_closure = ref["raw_sum"] - case["q"]
            max_legacy_raw_closure = max(max_legacy_raw_closure, abs(legacy_closure))
            max_candidate_closure_correction = max(max_candidate_closure_correction, abs(row["closure"]))
            if abs(row["closure"]) > 8192.0 * EPS * max(1.0, abs(case["q"])):
                raise AssertionError("candidate closure correction not roundoff-scale")
            if row["identity_residual"] != 0.0:
                raise AssertionError(f"last-node authoritative-scalar identity not exact: {row['identity_residual']}")
            if abs(row["sum_nodes"] - case["q"]) > 8192.0 * EPS * max(1.0, abs(case["q"])):
                raise AssertionError("candidate node vector does not close to authoritative scalar at machine scale")

            if ref["truncated"]:
                truncated_count += 1
            else:
                full_profile_count += 1
            if ref["single_compartment"]:
                single_compartment_count += 1

        require(len(stable_cases) == 900, "FVQ45_STABLE_DOMAIN_RANDOMIZED_COVERAGE")
        require(truncated_count > 250 and full_profile_count > 50, "FVQ45_TRUNCATED_AND_FULL_PROFILE_COVERAGE")
        require(single_compartment_count > 50, "FVQ45_SINGLE_COMPARTMENT_SPECIAL_CASE_COVERAGE")
        require(max_node_abs < 1.0e-12, "FVQ45_STABLE_DOMAIN_NODE_DISTRIBUTION_EQUIVALENCE")
        require(max_diag_abs < 1.0e-10, "FVQ45_STABLE_DOMAIN_HYDRAULIC_GEOMETRY_EQUIVALENCE")
        require(max_candidate_closure_correction < 1.0e-12, "FVQ45_LAST_NODE_ROUNDOFF_CLOSURE_ONLY")

        seam_rows = rows0[len(stable_cases):len(stable_cases) + len(boundary_cases)]
        for case, row in zip(boundary_cases, seam_rows):
            ref = legacy_divdra_oracle(case)
            mismatch = row["status"] != 0 or row["wt"] != ref["wt"] or row["bottom"] != ref["bottom"]
            if not mismatch and row["evaluated"]:
                for got, raw in zip(row["nodes"], ref["nodes"]):
                    if not near(got, raw, scale=case["q"], factor=4096.0):
                        mismatch = True
                        break
            if mismatch:
                seam_mismatch_count += 1
                if len(seam_examples) < 8:
                    seam_examples.append({"boundary_cm": case["boundary"], "offset_cm": case["offset"], "legacy_wt_node": ref["wt"], "candidate_status": row["status"], "candidate_wt_node": row["wt"]})

        require(len(boundary_cases) == 21, "FVQ45_LEV2COMP_BOUNDARY_SEAM_COVERAGE")
        require(seam_mismatch_count > 0, "FVQ45_LEV2COMP_BOUNDARY_SEAM_MISMATCH_CONFIRMED")

        zero_row = rows0[len(stable_cases) + len(boundary_cases)]
        require(zero_row["status"] == 0 and zero_row["evaluated"] and zero_row["zero"] and all(x == 0.0 for x in zero_row["nodes"]), "FVQ45_ZERO_TRANSFER_DEPENDENCY_FREE_ROUTE")
        small_rows = rows0[-len(small_cases):]
        require(all(row["status"] == 4 and not row["evaluated"] and all(x == 0.0 for x in row["nodes"]) for row in small_rows), "FVQ45_HELD_POSITIVE_SMALL_INTERVAL_FAILS_CLOSED")

    full_qualified = seam_mismatch_count == 0
    decision = "QUALIFIED_RESTRICTED_DIVDRA_SPATIAL_DISTRIBUTION_SCIENTIFIC_EQUIVALENCE_READY_FOR_RUNTIME_COMPOSITION" if full_qualified else "NOT_QUALIFIED_FPM08B_LEV2COMP_BOUNDARY_SEAM_REMEDIATION_REQUIRED"
    summary = {
        "candidate_closeout": CANDIDATE, "candidate_blob": CANDIDATE_BLOB,
        "stable_cases": len(stable_cases), "truncated_cases": truncated_count,
        "full_profile_cases": full_profile_count, "single_compartment_cases": single_compartment_count,
        "max_node_abs_difference_vs_raw_legacy": max_node_abs,
        "max_hydraulic_geometry_abs_difference": max_diag_abs,
        "max_legacy_raw_mass_closure_abs": max_legacy_raw_closure,
        "max_candidate_last_node_closure_correction_abs": max_candidate_closure_correction,
        "boundary_seam_cases": len(boundary_cases), "boundary_seam_mismatch_cases": seam_mismatch_count,
        "boundary_seam_examples": seam_examples, "stable_domain_qualified": True,
        "boundary_seam_equivalent": seam_mismatch_count == 0, "full_candidate_qualified": full_qualified,
        "decision": decision, "runtime_mass_booking_qualified": False,
        "negative_infiltration_qualified": False, "multilevel_qualified_here": False,
        "o0_o2_text_difference_is_signed_zero_only": True,
    }
    text = json.dumps(summary, sort_keys=True)
    print("FVQ45_SUMMARY=" + text)
    print("FVQ45_SUMMARY_SHA256=" + hashlib.sha256(text.encode()).hexdigest())
    print("FVQ45_STABLE_DOMAIN_SCIENTIFIC_EQUIVALENCE=PASS")
    print("FVQ45_FULL_FPM08B_SCIENTIFIC_QUALIFICATION=" + ("YES" if full_qualified else "NO"))
    print("FVQ45_DECISION=" + decision)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"FVQ45_DISPOSITION_VERIFIER=FAIL {exc}", file=sys.stderr)
        raise
