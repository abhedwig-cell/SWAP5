"""Execute real MODFLOW6 A/B. Requires external mf6 6.8.0 and FloPy.

Never download executables implicitly and never label oracle-only output MF6.
"""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
import numpy as np
from oracle import discrete

HEAD_LIMIT_M = .005  # frozen discretization allowance; mesh evidence remains separate
RATE_LIMIT_M3_D = 1e-8
VOLUME_LIMIT_M3 = 1e-6


def build(flopy, folder, executable, k, n=50, conductance=100., transient=False):
    sim = flopy.mf6.MFSimulation(sim_name="strip01", sim_ws=str(folder), exe_name=str(executable))
    periods = [(1., 1, 1.)] if not transient else [(1., 4, 1.)]*120
    flopy.mf6.ModflowTdis(sim, time_units="DAYS", perioddata=periods, nper=len(periods))
    flopy.mf6.ModflowIms(sim, outer_dvclose=1e-10, inner_dvclose=1e-11,
                        outer_maximum=200, inner_maximum=300, rcloserecord=1e-10,
                        linear_acceleration="BICGSTAB")
    gwf = flopy.mf6.ModflowGwf(sim, modelname="strip", save_flows=True,
                             newtonoptions="NEWTON")
    flopy.mf6.ModflowGwfdis(gwf, nlay=1, nrow=1, ncol=n, delr=50/n, delc=1,
                          top=0., botm=-10.)
    flopy.mf6.ModflowGwfic(gwf, strt=-3. if transient else -4.5)
    flopy.mf6.ModflowGwfnpf(gwf, icelltype=1, k=k, save_flows=True)
    flopy.mf6.ModflowGwfsto(gwf, iconvert=1, sy=.2, ss=0.,
                          transient={0: True} if transient else None,
                          steady_state=None if transient else {0: True})
    flopy.mf6.ModflowGwfdrn(gwf, stress_period_data=[((0,0,0), -5., conductance)])
    if not transient:
        flopy.mf6.ModflowGwfrcha(gwf, recharge=.001)
    flopy.mf6.ModflowGwfoc(gwf, head_filerecord="strip.hds", budget_filerecord="strip.cbc",
                         saverecord=[("HEAD", "ALL"), ("BUDGET", "ALL")])
    sim.write_simulation(silent=True)
    ok, log = sim.run_simulation(silent=True, report=True)
    (folder/"execution.log").write_text("\n".join(log)+"\n")
    if not ok:
        raise RuntimeError(f"MODFLOW failed: {folder}")
    return flopy.utils.HeadFile(folder/"strip.hds"), flopy.utils.CellBudgetFile(folder/"strip.cbc", precision="double")


def rate(cbc, text, time):
    values = cbc.get_data(text=text, totim=time)
    if not values:
        raise AssertionError(f"missing budget term {text} at {time}")
    return float(sum(np.sum(v["q"]) if v.dtype.names and "q" in v.dtype.names else np.sum(v)
                     for v in values))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--mf6", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    exe = a.mf6.resolve()
    if not exe.is_file():
        raise FileNotFoundError("real mf6 executable required")
    version = subprocess.check_output([str(exe), "-v"], text=True)
    if "6.8.0" not in version:
        raise ValueError("preregistered MODFLOW6 6.8.0 required")
    import flopy
    if flopy.__version__ != "3.9.5":
        raise ValueError(f"preregistered FloPy 3.9.5 required, got {flopy.__version__}")
    a.output.mkdir(parents=True, exist_ok=True)
    rows=[]
    failures=[]
    def check(ok, gate, case):
        if not ok:
            failures.append(dict(gate=gate,case=case))
    for k in [.1,.25,.5,1.,2.]:
        for n in [50,100]:
            folder=a.output/f"steady_k{k}_n{n}"
            heads, budgets=build(flopy,folder,exe,k,n=n)
            t=heads.get_times()[-1]
            h=heads.get_data(totim=t).ravel()
            expected, total=discrete(n,50/n,1,.001,k,-5,-10,100)
            error=float(np.max(np.abs(h-expected)))
            drn=rate(budgets,"DRN",t)
            rch=rate(budgets,"RCHA",t)
            row=dict(k=k,n=n,head_error_m=error,drain_m3_d=drn,recharge_m3_d=rch,
                     budget_residual_m3_d=rch+drn,heads_m=h.tolist())
            rows.append(row)
            case=dict(phase="steady",k=k,n=n)
            check(error<=HEAD_LIMIT_M,"arithmetic_dupuit_head",case)
            check(abs(rch-total)<=RATE_LIMIT_M3_D and abs(rch+drn)<=RATE_LIMIT_M3_D,"mass_rate",case)
            check(np.min(np.diff(h))>=-1e-9,"spatial_monotonicity",case)
            # Independent diagnostic for upstream saturated-thickness conductance.
            upstream=[-5. + 10. + total/100.]
            for i in range(n-1):
                old=upstream[-1]
                qdx_over_k=.001*(50/n)**2*(n-i-1)/k
                upstream.append((old+np.sqrt(old*old+4*qdx_over_k))/2)
            row["upstream_diagnostic_head_error_m"]=float(np.max(np.abs(h-(np.array(upstream)-10.))))
    # Preregistered finite-conductance sensitivity at the selected K and 50-cell mesh.
    conductance_sensitivity=[]
    for c in [10.,100.,1000.]:
        folder=a.output/f"conductance_c{c:g}"
        heads_c, budgets_c=build(flopy,folder,exe,.5,n=50,conductance=c)
        t_c=heads_c.get_times()[-1]
        h_c=heads_c.get_data(totim=t_c).ravel()
        expected_c, total_c=discrete(50,1.,1,.001,.5,-5,-10,c)
        error_c=float(np.max(np.abs(h_c-expected_c)))
        drn_c=rate(budgets_c,"DRN",t_c)
        rch_c=rate(budgets_c,"RCHA",t_c)
        row_c=dict(conductance_m2_d=c,head_error_m=error_c,drain_m3_d=drn_c,
                   recharge_m3_d=rch_c,budget_residual_m3_d=rch_c+drn_c,
                   heads_m=h_c.tolist())
        conductance_sensitivity.append(row_c)
        case_c=dict(phase="conductance",k=.5,n=50,conductance=c)
        check(error_c<=HEAD_LIMIT_M,"arithmetic_dupuit_head",case_c)
        check(abs(rch_c-total_c)<=RATE_LIMIT_M3_D and abs(rch_c+drn_c)<=RATE_LIMIT_M3_D,"mass_rate",case_c)

    heads, budgets=build(flopy,a.output/"drain_down",exe,.5,transient=True)
    prev_t=0.; prev_storage=.2*50*7.; cumulative=0.; trajectory=[]
    for t in heads.get_times():
        h=heads.get_data(totim=t).ravel()
        storage=float(.2*np.sum(h+10.))
        drn=rate(budgets,"DRN",t)
        sto=rate(budgets,"STO-SY",t)
        cumulative-=drn*(t-prev_t)
        residual=storage-.2*50*7.+cumulative
        row=dict(day=t,storage_m3=storage,cumulative_drain_m3=cumulative,
                 residual_m3=residual,sto_rate_m3_d=sto,drain_rate_m3_d=drn,heads_m=h.tolist())
        trajectory.append(row)
        check(storage<=prev_storage+VOLUME_LIMIT_M3,"storage_monotonicity",dict(phase="drain_down",day=t))
        check(abs(residual)<=VOLUME_LIMIT_M3,"cumulative_mass",dict(phase="drain_down",day=t))
        check(abs(sto+drn)<=RATE_LIMIT_M3_D,"mass_rate",dict(phase="drain_down",day=t))
        prev_t=t; prev_storage=storage
    reference_failures=[f for f in failures if f["case"].get("k",.5)==.5]
    status=("STANDALONE_AB_PASS" if not failures else
            "STANDALONE_REFERENCE_AB_PASS_WITH_SWEEP_NEGATIVE" if not reference_failures else
            "STANDALONE_AB_FAIL")
    result=dict(status=status,gate_failures=failures,reference_qualified=not reference_failures,
                original_limits=dict(head_m=HEAD_LIMIT_M,rate_m3_d=RATE_LIMIT_M3_D,volume_m3=VOLUME_LIMIT_M3),
                version=version.strip(),
                executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
                flopy_version=flopy.__version__,steady=rows,
                conductance_sensitivity=conductance_sensitivity,drain_down=trajectory,
                coupled_executed=False)
    (a.output/"standalone_result.json").write_text(json.dumps(result,indent=2)+"\n")
    print("STRIP01_NATIVE_MODFLOW_STANDALONE_AB="+status)
    if reference_failures:
        raise SystemExit("selected-reference gates failed; full diagnostics persisted")


if __name__=="__main__":
    main()
