#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, sqlite3, subprocess, sys
from pathlib import Path

PRIOR_IDS={90116260,11060,10260,8016,3030}
TARGET_HORIZON_COUNTS=(1,2,3,4)

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL load {path}")
    mod=importlib.util.module_from_spec(spec)
    sys.modules[spec.name]=mod
    spec.loader.exec_module(mod)
    return mod

def gpkg_one(d):
    hits=list(Path(d).rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL gpkg hits={len(hits)}")
    return hits[0].resolve()

def independent_selection(gpkg:Path):
    con=sqlite3.connect(f"file:{gpkg}?mode=ro",uri=True)
    try:
        pids=[int(r[0]) for r in con.execute("select normalsoilprofile_id from normalsoilprofiles order by normalsoilprofile_id")]
        eligible=[]
        for pid in pids:
            if pid<=0 or pid in PRIOR_IDS: continue
            prow=con.execute("select soilunit from normalsoilprofiles where normalsoilprofile_id=?",(pid,)).fetchone()
            rows=list(con.execute(
                "select layernumber,lowervalue,uppervalue,staringseriesblock,organicmattercontent,peattype,density "
                "from soilhorizon where normalsoilprofile_id=? order by layernumber",(pid,)))
            if not rows or len(rows)>16: continue
            ok=True; prev=None; blocks=[]
            for idx,(layer,low,up,block,om,peat,density) in enumerate(rows,1):
                if int(layer)!=idx: ok=False; break
                low=float(low); up=float(up)
                if up<=low or (idx==1 and abs(low)>1e-10) or (prev is not None and abs(low-prev)>1e-10):
                    ok=False; break
                prev=up
                ib=int(block)
                if not (101<=ib<=118 or 201<=ib<=218): ok=False; break
                if peat is not None: ok=False; break
                if density is None or float(density)<=0: ok=False; break
                if om is not None and float(om)>20.0: ok=False; break
                blocks.append(ib)
            if ok:
                eligible.append({"profile_id":pid,"soilunit":None if prow is None else prow[0],
                                 "horizon_count":len(rows),"blocks":blocks})
    finally:
        con.close()

    # Deduplicate by the ELASTIC55 diversity key.
    uniq=[]; seen=set()
    for p in eligible:
        key=(p["soilunit"],p["horizon_count"],tuple(p["blocks"]))
        if key in seen: continue
        seen.add(key); uniq.append(p)

    selected=[]
    for hc in TARGET_HORIZON_COUNTS:
        c=[p for p in uniq if p["horizon_count"]==hc]
        if not c:
            raise SystemExit(f"F_PE_ELASTIC58_FAIL no independent profile for horizon_count={hc}")
        selected.append(min(c,key=lambda x:x["profile_id"]))
    return selected

def make_oracle_fixture(selector_fixture:Path, oracle_fixture:Path):
    s=selector_fixture.read_text(encoding="utf-8")

    # Remove research indicator imports/types/logic; retain profile-specific physical materialization.
    s=s.replace(
"""  use mod_fpe_elastic53_reference_richards_temporal_indicator, only: &
       evaluate_fpe_elastic53_reference_richards_temporal_indicator
  use mod_soil_water_solver_contract, only: soil_water_temporal_indicator_request_t, &
       soil_water_temporal_indicator_result_t, SW_TEMPORAL_INDICATOR_AVAILABLE
""","")
    s=s.replace(
"""  type(soil_water_temporal_indicator_request_t)::indicator_request
  type(soil_water_temporal_indicator_result_t)::indicator
""","")
    s=s.replace(
"""  logical::all_converged,exact_identity,indicator_available
  real(real64)::indicator_binf,indicator_raw,indicator_defect
""",
"""  logical::all_converged,exact_identity
""")

    start=s.find("  indicator_available=.false.")
    end=s.find("  call bind_b110_default_mvg_provider(constitutive_half",start)
    if start<0 or end<0:
        raise SystemExit("F_PE_ELASTIC58_FAIL indicator block anchors")
    s=s[:start]+s[end:]

    # Add independent mass-ledger scalars to the generated program.
    s=s.replace(
        "  real(real64)::dh_inf,dtheta_inf,dpond,dgwl,storage_full,storage_half\n",
        "  real(real64)::dh_inf,dtheta_inf,dpond,dgwl,storage_full,storage_half,storage0,storage_oracle,candidate_mass,oracle_mass\n",1)

    # Replace the full-vs-two-half experiment with candidate-vs-32-substep oracle.
    start=s.find("  call bind_b110_default_mvg_provider(constitutive_half")
    end=s.find("  write(*,'(*(g0))')'ELASTIC55_BANK",start)
    if start<0 or end<0:
        raise SystemExit("F_PE_ELASTIC58_FAIL half-step block anchors")

    replacement=r"""  call run_refined_oracle(p,heads,water,h0,qeq+delta,qeq,dt,res_half2,all_converged,storage_half,storage_oracle)

  dh_inf=0.0_real64;dtheta_inf=0.0_real64;dpond=0.0_real64;dgwl=0.0_real64
  storage_full=0.0_real64;ih=0;itheta=0;exact_identity=.false.
  if(res_full%status==SW_SOLVE_CONVERGED.and.all_converged)then
    dh_inf=maxval(abs(res_full%candidate_state%pressure_head-res_half2%candidate_state%pressure_head))
    ih=maxloc(abs(res_full%candidate_state%pressure_head-res_half2%candidate_state%pressure_head),dim=1)
    dtheta_inf=maxval(abs(res_full%candidate_state%water_content-res_half2%candidate_state%water_content))
    itheta=maxloc(abs(res_full%candidate_state%water_content-res_half2%candidate_state%water_content),dim=1)
    dpond=abs(res_full%candidate_state%ponding_depth-res_half2%candidate_state%ponding_depth)
    dgwl=abs(res_full%candidate_state%groundwater_level-res_half2%candidate_state%groundwater_level)
    storage_full=sum(res_full%candidate_state%water_content*p%dz)
    exact_identity=all(same_bits(res_full%candidate_state%pressure_head,res_half2%candidate_state%pressure_head)).and. &
       all(same_bits(res_full%candidate_state%water_content,res_half2%candidate_state%water_content)).and. &
       same_scalar_bits(res_full%candidate_state%ponding_depth,res_half2%candidate_state%ponding_depth).and. &
       same_scalar_bits(res_full%candidate_state%groundwater_level,res_half2%candidate_state%groundwater_level)
    call req(ieee_is_finite(dh_inf).and.ieee_is_finite(dtheta_inf),'finite oracle discrepancy')
  end if

"""
    s=s[:start]+replacement+s[end:]

    # Replace output record with oracle diagnostics.
    out_start=s.find("  write(*,'(*(g0))')'ELASTIC55_BANK")
    out_end=s.find("  write(*,'(A)')'F_PE_ELASTIC55_EXEC=PASS'",out_start)
    if out_start<0 or out_end<0:
        raise SystemExit("F_PE_ELASTIC58_FAIL output anchors")
    out_end=s.find("\n",out_end)+1
    output=r"""  storage_full=sum(res_full%candidate_state%water_content*p%dz)
  storage0=sum(water*p%dz)
  candidate_mass=(storage_full-storage0)-((-qeq-delta)*dt+res_full%bottom_flux*dt)
  oracle_mass=(storage_oracle-storage0)-((-qeq-delta)*dt+storage_half)
  write(*,'(*(g0))')'ELASTIC58_ORACLE|regime=',trim(regime),'|h0=',h0,'|delta=',delta,'|dt=',dt, &
       '|candidate_status=',res_full%status,'|oracle_complete=',all_converged,'|dh_inf=',dh_inf, &
       '|dtheta_inf=',dtheta_inf,'|candidate_qbot=',res_full%bottom_flux,'|oracle_qbot=',res_half2%bottom_flux, &
       '|candidate_exchange=',res_full%bottom_flux*dt,'|oracle_exchange=',storage_half, &
       '|candidate_mass=',candidate_mass,'|oracle_mass=',oracle_mass
  write(*,'(A)')'F_PE_ELASTIC58_ORACLE_EXEC=PASS'
"""
    s=s[:out_start]+output+s[out_end:]

    # Insert refined-oracle routine before init_base.
    anchor="  subroutine init_base(q,zv,dzv)\n"
    idx=s.find(anchor)
    if idx<0: raise SystemExit("F_PE_ELASTIC58_FAIL init_base insertion anchor")
    routine=r"""  subroutine run_refined_oracle(q,hinit,winit,forcing_top_head,qtop,qbot,interval,result,ok,exchange,storage_end)
    type(fmr_b110_physical_parameters_t),intent(in)::q
    real(real64),intent(in)::hinit(N),winit(N),forcing_top_head,qtop,qbot,interval
    type(soil_water_solve_result_t),intent(out)::result
    logical,intent(out)::ok
    real(real64),intent(out)::exchange,storage_end
    type(soil_water_parameter_set_t),target::s
    type(reference_richards_legacy_solver_t)::solver
    type(reference_richards_legacy_workspace_t)::ws
    type(b110_default_mvg_provider_t),target::c
    type(b110_source_sink_provider_t),target::src
    type(fixed_flux_top_boundary_provider_t),target::tp
    type(soil_water_solve_request_t)::r
    type(soil_water_solve_result_t)::step_result
    type(soil_water_physical_state_t)::current
    real(real64),target::d(1,N),si(N),rt(N)
    real(real64)::subdt
    integer::j

    ok=.false.;exchange=0.0_real64;storage_end=0.0_real64
    call init_soil(s,q)
    d=0.0_real64;si=0.0_real64;rt=0.0_real64
    call bind_b110_source_sink_provider(src,d,si,rt)
    subdt=interval/32.0_real64
    call bind_b110_default_mvg_provider(c,q%prepared_default_mvg,subdt)
    current%active_nodes=N
    allocate(current%pressure_head(N),current%water_content(N))
    current%pressure_head=hinit;current%water_content=winit
    current%ponding_depth=max(0.0_real64,forcing_top_head)
    current%groundwater_level=-2.0_real64
    result=soil_water_solve_result_t()

    do j=1,32
      call make_request_from_state(r,s,c,src,tp,current,forcing_top_head,qtop,qbot,subdt)
      call solver%solve(r,ws,step_result)
      if(step_result%status/=SW_SOLVE_CONVERGED)then
        result=step_result
        return
      end if
      exchange=exchange+step_result%bottom_flux*subdt
      current=step_result%candidate_state
      result=step_result
    end do
    storage_end=sum(current%water_content*q%dz)
    ok=.true.
  end subroutine

"""
    s=s[:idx]+routine+s[idx:]

    # Program name and marker cleanup.
    s=s.replace("program test_fpe_elastic50_full_half_discrepancy","program test_fpe_elastic58_physical_oracle",1)
    s=s.replace("end program test_fpe_elastic50_full_half_discrepancy","end program test_fpe_elastic58_physical_oracle",1)
    oracle_fixture.write_text(s,encoding="utf-8")

def main():
    ap=argparse.ArgumentParser()
    sub=ap.add_subparsers(dest="cmd",required=True)
    sp=sub.add_parser("select")
    sp.add_argument("--artifact-dir",required=True);sp.add_argument("--output",required=True)
    op=sub.add_parser("oracle")
    op.add_argument("--selector-fixture",required=True);op.add_argument("--oracle-fixture",required=True)
    a=ap.parse_args()
    if a.cmd=="select":
        x=independent_selection(gpkg_one(a.artifact_dir))
        Path(a.output).write_text(json.dumps(x,indent=2,sort_keys=True)+"\n",encoding="utf-8")
        print("ELASTIC58_SELECTED="+json.dumps(x,sort_keys=True,separators=(",",":")))
        print("F_PE_ELASTIC58_SELECT=PASS")
    else:
        make_oracle_fixture(Path(a.selector_fixture),Path(a.oracle_fixture))
        print("F_PE_ELASTIC58_ORACLE_PREP=PASS")

if __name__=="__main__":
    main()
