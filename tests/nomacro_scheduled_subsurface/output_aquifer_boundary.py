"""Actual first-day and true terminal-day gifts with cold native continuation."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import output_aquifer_runtime as matrix
from original_output_baseline import assignment

m=matrix.m


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--resume',action='store_true');a=p.parse_args();a.output=a.output.resolve();a.output.mkdir(exist_ok=a.resume);q=dict(status='RUNNING',profiles={})
    if a.resume:q['retained_previous_report']=json.loads((a.output/'RESULT.json').read_text())
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    try:
        for opt in ('O0','O2'):
            out=a.output/opt;out.mkdir(exist_ok=a.resume);inputs=out/'input';
            if not inputs.exists():matrix.fixture(inputs,'soil-transfer',3,0,'subsurface')
            p=inputs/'swap.swp';p.write_text(assignment(p.read_text(encoding='cp1252'),'TEND','2002-01-10'),encoding='cp1252');(inputs/'fixed-irrigation.irg').write_text('IRDATE IRDEPTH IRCONC IRTYPE IRRATE\n2002-01-01 24.0 20.0 2 12.0\n2002-01-10 12.0 60.0 2 12.0\nIR_Z = -30.0\n')
            project=m.e.load(inputs,original_output=True);assert project.last_day==10;build=out/'build';cmd=[sys.executable,'-B',str(matrix.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
            if not (a.resume and (build/'BUILD.json').exists()):
                r=subprocess.run(cmd,cwd=matrix.ROOT,capture_output=True,text=True,timeout=180);(out/'build.stdout').write_text(r.stdout);(out/'build.stderr').write_text(r.stderr);assert r.returncode==0,r.stderr
            m.validate_bundle(build,a.reference_work,project)
            full=out/'trajectory'
            if a.resume and (full/'daily.jsonl').exists():
                data=m.rows(full);assert len(data)==10;report=dict(status='ACTUAL_COMPLETED_TRAJECTORY_REVALIDATED',budgets=m.check(data),days=10,build_sha256=m.sha(build/'BUILD.json'))
            else:report,data=m.trajectory(build,a.reference_work,project,full,10,{2,4,6,8,10},45)
            assert abs(data[0]['solute_ledger_mg_cm2'][3]-48.)<=1e-10 and abs(data[-1]['solute_ledger_mg_cm2'][3]-72.)<=1e-10 and abs(sum(row['solute_ledger_mg_cm2'][3] for row in data)-120.)<=1e-10
            assert all(abs(row[k])<=1e-10 for row in data for k in ('aquifer_residual_mg_cm2','aquifer_exchange_residual_mg_cm2','soil_aquifer_residual_mg_cm2'))
            windows=[matrix.own(build,a.reference_work,project,full,data,s,e,out/('own-'+str(s)),resume=a.resume and (out/('own-'+str(s))).exists()) for s,e in ((2,4),(4,8),(6,10))]
            q['profiles'][opt]=dict(actual_build=json.loads((build/'BUILD.json').read_text()),trajectory=report,first_day_source_mg_cm2=data[0]['solute_ledger_mg_cm2'][3],terminal_day_source_mg_cm2=data[-1]['solute_ledger_mg_cm2'][3],total_source_mg_cm2=sum(row['solute_ledger_mg_cm2'][3] for row in data),own=windows);save();print(opt,'FIRST_AND_TRUE_LAST_DAY_AQUIFER_CHEMICAL_OUTPUT_NATIVE_PASS',flush=True)
        q['status']='FIRST_AND_TRUE_TERMINAL_DAY_AQUIFER_CHEMICAL_OUTPUT_GIFTS_O0_O2_COMPLETE_NATIVE_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
