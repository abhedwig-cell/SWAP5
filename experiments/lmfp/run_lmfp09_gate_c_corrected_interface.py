from __future__ import annotations

import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_homogeneous_face_matrix as core
from run_lmfp09_coordinate_envelope import FIXTURES, MaterialFixture
from run_lmfp09_mfp_c1_candidates import HermiteMFPTable
from run_lmfp09_homogeneous_c1_coarse import asymptotic_continuity_test, tolerant_bracket
import run_lmfp09_saturation_aligned_ratio_knots as sat
from run_lmfp06_darcian_reference import solve_steady_flux
from lmfp09_staring2018_catalog import CATALOG_BY_ID, b110_material

core.AsinhMFPTable = HermiteMFPTable
core.bracket = tolerant_bracket
core.continuity_test = asymptotic_continuity_test
core.MASTER_NX = 33
core.VIEW_NX = (33,)

HALF_LENGTHS = (5.0, 10.0)
GEOMETRIES = ((5.0, 5.0), (10.0, 10.0), (5.0, 10.0), (10.0, 5.0))
ANCHORS = (-1.0e5, -1.0e3, -100.0, -10.0, -1.0, 0.0, 10.0)
TOTAL_G = (-20.0, -5.0, -1.0, 0.0, 0.5, 1.0, 2.0, 5.0, 20.0)
ROOT_TOL = 1.0e-10
ROOT_MAX = 60
CONT_EPS = (1.0e-3, 2.0e-4, 4.0e-5, 8.0e-6, 1.6e-6)

SYNTHETIC_PAIRS = (("reference_sand","reference_clay"),("reference_clay","reference_sand"),("very_fast","slow_heavy"),("slow_heavy","very_fast"))
CATALOG_PAIRS = (("B06","B14"),("B14","B06"),("B02","O13"),("O13","B02"),("B06","B12"),("B12","B06"),("O05","O14"),("O14","O05"))


class CoverageFailure(RuntimeError):
    pass


@dataclass(frozen=True)
class RootResult:
    q: float
    h_interface: float
    iterations: int
    residual: float
    scaled_residual: float
    bracket: tuple[float, float]


def percentile(values, p):
    values = sorted(values)
    if not values:
        return math.nan
    return values[min(len(values)-1, int(p*len(values)))]


def material_group(group):
    if group == "synthetic":
        by_name = {f.name: f for f in FIXTURES}
        names = sorted({name for pair in SYNTHETIC_PAIRS for name in pair})
        return {name: by_name[name] for name in names}, SYNTHETIC_PAIRS
    if group == "catalog":
        names = sorted({name for pair in CATALOG_PAIRS for name in pair})
        return {name: MaterialFixture(name, b110_material(CATALOG_BY_ID[name])) for name in names}, CATALOG_PAIRS
    raise ValueError(("unknown_group", group))


def build_provider(fixture, length):
    coord = core.AsinhCoordinate(core.H_SCALE, hmin=core.MFP_HMIN, hmax=core.MFP_HMAX)
    mfp = HermiteMFPTable(fixture.material, coord, core.MFP_N)
    master = core.RatioMaster(fixture, length, mfp)
    view = sat.SaturationAlignedRatioView(master)
    return view, master.oracle_solves, view.extra_oracle_solves


def feasible_interface_interval(view_u, view_l, h_u, h_l):
    if h_u < core.R_HMIN or h_u > core.R_HMAX:
        raise CoverageFailure(("upper_endpoint_outside_ratio_envelope", h_u))
    if h_l < core.R_HMIN or h_l > core.R_HMAX:
        raise CoverageFailure(("lower_endpoint_outside_gate_c_endpoint_envelope", h_l))
    lo = max(core.R_HMIN, core.MFP_HMIN,
             h_u + core.G_AXIS[0]*view_u.length,
             h_l - core.G_AXIS[-1]*view_l.length)
    hi = min(core.R_HMAX, core.MFP_HMAX,
             h_u + core.G_AXIS[-1]*view_u.length,
             h_l - core.G_AXIS[0]*view_l.length)
    if lo > hi:
        raise CoverageFailure(("empty_interface_coverage", lo, hi, h_u, h_l))
    return lo, hi


def corrected_interface_flux(view_u, view_l, h_u, h_l):
    lo, hi = feasible_interface_interval(view_u, view_l, h_u, h_l)
    def residual(h_i):
        q_u = view_u.flux(h_u, h_i)
        q_l = view_l.flux(h_i, h_l)
        return q_u-q_l, q_u, q_l
    f_lo, q_ul, q_ll = residual(lo)
    f_hi, q_uh, q_lh = residual(hi)
    for h, f, q_u, q_l in ((lo,f_lo,q_ul,q_ll),(hi,f_hi,q_uh,q_lh)):
        scale = max(1.0,abs(q_u),abs(q_l))
        if abs(f) <= ROOT_TOL*scale:
            return RootResult(0.5*(q_u+q_l),h,0,f,abs(f)/scale,(lo,hi))
    if f_lo*f_hi > 0.0:
        raise CoverageFailure(("equal_flux_root_not_bracketed_inside_coverage",lo,hi,f_lo,f_hi))
    for iteration in range(1,ROOT_MAX+1):
        mid=0.5*(lo+hi)
        f_mid,q_u,q_l=residual(mid)
        scale=max(1.0,abs(q_u),abs(q_l))
        if abs(f_mid) <= ROOT_TOL*scale:
            return RootResult(0.5*(q_u+q_l),mid,iteration,f_mid,abs(f_mid)/scale,(lo,hi))
        if f_lo*f_mid <= 0.0:
            hi=mid; f_hi=f_mid
        else:
            lo=mid; f_lo=f_mid
    mid=0.5*(lo+hi)
    f_mid,q_u,q_l=residual(mid)
    scale=max(1.0,abs(q_u),abs(q_l))
    raise CoverageFailure(("root_iteration_cap_without_acceptance",ROOT_MAX,f_mid,scale,mid))


def provider_self_check(fixtures,providers):
    rows=[]; all_pass=True
    names=list(fixtures)
    for ni,(name,fixture) in enumerate(fixtures.items()):
        for li,length in enumerate(HALF_LENGTHS):
            view=providers[(name,length)]
            probes=core.build_probe_rows(fixture,length,431092000+100*ni+li)
            identity=core.identity_test(view)
            continuity=asymptotic_continuity_test(view)
            fail_closed=core.fail_closed_test(view)
            face=core.metrics_for_view(view,probes)
            passed=identity["pass"] and continuity["pass"] and fail_closed["pass"] and face["pass"]
            all_pass=all_pass and passed
            rows.append({"material":name,"length_cm":length,"pass":passed,"identity":identity,"continuity":continuity,"fail_closed":fail_closed,"face_matrix":face,"memory":view.memory()})
    return {"pass":all_pass,"rows":rows}


def build_interface_cases(len_u,len_l):
    total=len_u+len_l; cases=[]; seen=set()
    for h_u in ANCHORS:
        for g in TOTAL_G:
            h_l=h_u+g*total
            if not core.R_HMIN <= h_l <= core.R_HMAX:
                continue
            key=(round(h_u,12),round(h_l,12))
            if key not in seen:
                seen.add(key); cases.append({"kind":"matrix","h_u":h_u,"h_l":h_l,"total_g":g})
    for delta in (0.0,-1.0,-0.1,0.1,1.0):
        h_u=-len_u; h_l=len_l+delta
        key=(round(h_u,12),round(h_l,12))
        if core.R_HMIN <= h_l <= core.R_HMAX and key not in seen:
            seen.add(key)
            cases.append({"kind":"hydrostatic_interface_zero" if delta==0.0 else "near_saturation_interface_crossing","h_u":h_u,"h_l":h_l,"delta_from_hydrostatic_cm":delta})
    return cases


def interface_matrix(fixtures,pairs,providers):
    rows=[]; failures=0; sign_mismatch=0
    active_errors=[]; dormant_errors=[]; head_abs=[]; head_scaled=[]; residuals=[]; iterations=[]; hydro_abs=[]
    for name_u,name_l in pairs:
        mat_u=fixtures[name_u].material; mat_l=fixtures[name_l].material
        for len_u,len_l in GEOMETRIES:
            view_u=providers[(name_u,len_u)]; view_l=providers[(name_l,len_l)]
            for case in build_interface_cases(len_u,len_l):
                h_u,h_l=case["h_u"],case["h_l"]
                q_ref,h_ref,oracle_it,oracle_steps,oracle_res=solve_steady_flux(mat_u,mat_l,h_u,h_l,len_u,len_l)
                try:
                    fit=corrected_interface_flux(view_u,view_l,h_u,h_l)
                except Exception as exc:
                    failures+=1
                    rows.append({**case,"upper_material":name_u,"lower_material":name_l,"len_u_cm":len_u,"len_l_cm":len_l,"q_ref":q_ref,"h_interface_ref":h_ref,"failed":True,"error":type(exc).__name__+":"+str(exc)})
                    continue
                ks_scale=max(mat_u.conductivity(0.0),mat_l.conductivity(0.0),1.0); active_floor=1.0e-8*ks_scale
                if abs(q_ref)>=active_floor:
                    err=abs(fit.q-q_ref)/abs(q_ref); active_errors.append(err); dormant=None
                    if fit.q*q_ref<0.0: sign_mismatch+=1
                else:
                    err=None; dormant=abs(fit.q-q_ref)/ks_scale; dormant_errors.append(dormant)
                ha=abs(fit.h_interface-h_ref); hs=ha/max(1.0,abs(h_ref),len_u+len_l)
                head_abs.append(ha); head_scaled.append(hs); residuals.append(fit.scaled_residual); iterations.append(fit.iterations)
                if case["kind"]=="hydrostatic_interface_zero": hydro_abs.append(abs(fit.q))
                rows.append({**case,"upper_material":name_u,"lower_material":name_l,"len_u_cm":len_u,"len_l_cm":len_l,"q_ref":q_ref,"q_candidate":fit.q,"active_rel_error":err,"dormant_abs_error_over_ks":dormant,"h_interface_ref":h_ref,"h_interface_candidate":fit.h_interface,"interface_head_abs_error_cm":ha,"interface_head_scaled_error":hs,"root_iterations":fit.iterations,"equal_flux_residual":fit.residual,"equal_flux_scaled_residual":fit.scaled_residual,"root_bracket":list(fit.bracket),"oracle_iterations":oracle_it,"oracle_ode_steps":oracle_steps,"oracle_head_residual":oracle_res,"failed":False})
    metrics={
        "cases":len(rows),"failures":failures,"active_cases":len(active_errors),"dormant_cases":len(dormant_errors),"sign_mismatches":sign_mismatch,
        "active_rel_error":{"median":percentile(active_errors,0.50),"p90":percentile(active_errors,0.90),"p99":percentile(active_errors,0.99),"maximum":max(active_errors) if active_errors else math.inf},
        "dormant_abs_error_over_ks_max":max(dormant_errors) if dormant_errors else 0.0,
        "interface_head_abs_error_cm":{"median":percentile(head_abs,0.50),"p90":percentile(head_abs,0.90),"p99":percentile(head_abs,0.99),"maximum":max(head_abs) if head_abs else math.inf},
        "interface_head_scaled_error":{"median":percentile(head_scaled,0.50),"p90":percentile(head_scaled,0.90),"p99":percentile(head_scaled,0.99),"maximum":max(head_scaled) if head_scaled else math.inf},
        "equal_flux_scaled_residual_max":max(residuals) if residuals else math.inf,
        "root_iterations":{"p50":percentile(iterations,0.50),"p90":percentile(iterations,0.90),"p99":percentile(iterations,0.99),"maximum":max(iterations) if iterations else ROOT_MAX+1},
        "hydrostatic_abs_flux_max":max(hydro_abs) if hydro_abs else math.inf,
    }
    metrics["pass"]=(failures==0 and sign_mismatch==0 and metrics["active_rel_error"]["p90"]<0.02 and metrics["active_rel_error"]["p99"]<0.10 and metrics["active_rel_error"]["maximum"]<0.30 and metrics["dormant_abs_error_over_ks_max"]<1.0e-7 and metrics["equal_flux_scaled_residual_max"]<1.0e-9 and metrics["root_iterations"]["maximum"]<=ROOT_MAX and metrics["hydrostatic_abs_flux_max"]<2.0e-10)
    return {"pass":metrics["pass"],"metrics":metrics,"rows":rows}


def explicit_fail_closed(fixtures,providers):
    name=next(iter(fixtures)); view_u=providers[(name,5.0)]; view_l=providers[(name,5.0)]
    trials=[(core.R_HMIN-1.0,-10.0),(-10.0,core.R_HMAX+1.0),(-10.0,990.0)]
    rows=[]
    for h_u,h_l in trials:
        failed=False; error=None
        try: corrected_interface_flux(view_u,view_l,h_u,h_l)
        except Exception as exc: failed=True; error=type(exc).__name__+":"+str(exc)
        rows.append({"h_u":h_u,"h_l":h_l,"explicit_failure":failed,"error":error})
    return {"pass":all(r["explicit_failure"] for r in rows),"rows":rows}


def continuity_checks(fixtures,pairs,providers):
    rows=[]; final_ratios=[]; finite=True
    for name_u,name_l in pairs:
        for len_u,len_l in ((5.0,5.0),(10.0,10.0)):
            view_u=providers[(name_u,len_u)]; view_l=providers[(name_l,len_l)]; h_u=-100.0; h_l=-50.0
            try: q0=corrected_interface_flux(view_u,view_l,h_u,h_l).q
            except Exception as exc:
                rows.append({"pair":[name_u,name_l],"geometry":[len_u,len_l],"failed":True,"error":type(exc).__name__+":"+str(exc)}); finite=False; continue
            for which in ("upper","lower"):
                distances=[]
                for eps in CONT_EPS:
                    def q(sign):
                        hu=h_u+sign*eps if which=="upper" else h_u; hl=h_l+sign*eps if which=="lower" else h_l
                        return corrected_interface_flux(view_u,view_l,hu,hl).q
                    distances.append(max(abs(q(-1.0)-q0),abs(q(1.0)-q0)))
                ratios=[b/max(a,1.0e-300) for a,b in zip(distances[:-1],distances[1:])]
                finite=finite and all(math.isfinite(v) for v in distances+ratios); final_ratios.append(ratios[-1])
                rows.append({"pair":[name_u,name_l],"geometry":[len_u,len_l],"perturbed_endpoint":which,"epsilons":list(CONT_EPS),"distances":distances,"consecutive_ratios":ratios,"final_ratio":ratios[-1],"failed":False})
    maximum=max(final_ratios) if final_ratios else math.inf
    return {"pass":finite and maximum<=0.35,"maximum_final_ratio":maximum,"rows":rows}


def homogeneous_reduction(fixtures,providers,group):
    names=("reference_sand","reference_clay") if group=="synthetic" else ("B06","B12")
    rel=[]; sign_mismatch=0; rows=[]
    for name in names:
        fixture=fixtures[name]; mat=fixture.material
        for half in (5.0,10.0):
            total=2.0*half; full,_,_=build_provider(fixture,total); upper=providers[(name,half)]; lower=providers[(name,half)]
            for h_u in (-100.0,-10.0,-1.0,0.0):
                for g in (-5.0,0.0,0.5,1.0,2.0,5.0):
                    h_l=h_u+g*total
                    if not core.R_HMIN<=h_l<=core.R_HMAX: continue
                    fit=corrected_interface_flux(upper,lower,h_u,h_l); q_full=full.flux(h_u,h_l); q_ref=solve_steady_flux(mat,mat,h_u,h_l,half,half)[0]
                    floor=1.0e-8*max(mat.conductivity(0.0),1.0)
                    if abs(q_ref)>=floor:
                        e=abs(fit.q-q_full)/max(abs(q_full),floor); rel.append(e)
                        if fit.q*q_full<0.0: sign_mismatch+=1
                    else: e=abs(fit.q-q_full)/max(mat.conductivity(0.0),1.0)
                    rows.append({"material":name,"half_length_cm":half,"h_u":h_u,"h_l":h_l,"g_total":g,"q_composed":fit.q,"q_full_candidate":q_full,"q_ref":q_ref,"composed_vs_full_error":e})
    summary={"active_p90":percentile(rel,0.90),"active_maximum":max(rel) if rel else math.inf,"sign_mismatches":sign_mismatch}
    return {"pass":sign_mismatch==0 and summary["active_p90"]<0.02 and summary["active_maximum"]<0.10,"summary":summary,"rows":rows}


def main():
    if len(sys.argv)!=3: raise SystemExit("usage: run_lmfp09_gate_c_corrected_interface.py EVIDENCE_JSON synthetic|catalog")
    out_path=Path(sys.argv[1]); group=sys.argv[2]; fixtures,pairs=material_group(group)
    providers={}; prep=[]; total_bytes=0; total_base_oracle=0; total_extra_oracle=0
    for name,fixture in fixtures.items():
        for length in HALF_LENGTHS:
            view,base_calls,extra_calls=build_provider(fixture,length); providers[(name,length)]=view; memory=view.memory()["bytes_before_metadata"]
            total_bytes+=memory; total_base_oracle+=base_calls; total_extra_oracle+=extra_calls
            prep.append({"material":name,"half_face_length_cm":length,"ratio_head_nodes":view.nx,"gradient_nodes":len(core.G_AXIS),"bytes_before_metadata":memory,"base_oracle_solves":base_calls,"extra_oracle_solves":extra_calls})
    provider_check=provider_self_check(fixtures,providers); interface=interface_matrix(fixtures,pairs,providers); fail_closed=explicit_fail_closed(fixtures,providers); continuity=continuity_checks(fixtures,pairs,providers); reduction=homogeneous_reduction(fixtures,providers,group)
    evidence={"schema_version":1,"work_unit":"F-LMFP09","gate":"C1_COMPOSED_CORRECTED_HALF_FACE_INTERFACE","group":group,"candidate":"COMPOSED_SATURATION_ALIGNED_HALF_FACE_EQUAL_FLUX","pairs":[list(p) for p in pairs],"geometries_cm":[list(g) for g in GEOMETRIES],"thresholds_changed_from_predeclared_plan":False,"pair_selection_uses_validation_error":False,"provider_preparation":{"classes":prep,"shared_bytes_before_metadata_for_tested_material_geometry_classes":total_bytes,"base_oracle_solves":total_base_oracle,"extra_crossing_knot_oracle_solves":total_extra_oracle,"runtime_oracle_calls":0,"pair_specific_table_classes":0},"provider_self_check":provider_check,"interface_matrix":interface,"explicit_fail_closed":fail_closed,"continuity":continuity,"homogeneous_reduction":reduction,"tangent_readiness":{"production_tangent_admission":False,"piecewise_linear_ratio_knot_derivative_jumps_remain":True,"interface_root_is_value_continuous_only_if_continuity_gate_passes":continuity["pass"],"required_later":"derive or extract response sensitivity only after local derivative behavior is qualified"},"architecture":{"production_code_changed":False,"persistent_column_state_added":False,"pair_specific_tables":False,"scratch":"bounded bisection root is worker-local","single_realized_face_flux":True,"mass_compatible":True,"no_silent_extrapolation":True,"no_silent_solver_switch":True,"fullrichards_reference_preserved":True}}
    evidence["structural_pass"]=all((provider_check["pass"],interface["pass"],fail_closed["pass"],continuity["pass"],reduction["pass"]))
    evidence["decision"]="GATE_C1_GROUP_QUALIFIED" if evidence["structural_pass"] else "GATE_C1_GROUP_FAILED_LOCALIZE_WITHOUT_THRESHOLD_RELAXATION"
    out_path.write_text(json.dumps(evidence,indent=2,sort_keys=True)+"\n"); print(json.dumps(evidence,indent=2,sort_keys=True)); raise SystemExit(0 if evidence["structural_pass"] else 1)


if __name__=="__main__": main()
