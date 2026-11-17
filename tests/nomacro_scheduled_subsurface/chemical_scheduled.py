"""Original scheduled chemical source through the real conserved daily host."""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('fixed_controls',Path(__file__).with_name('chemical_fixed.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
s=q.s;m=q.m


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--configuration',choices=['point','interval'],required=True)
    p.add_argument('--reference-work',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--short-only',action='store_true')
    p.add_argument('--resume',action='store_true')
    a=p.parse_args();out=a.output.resolve();out.mkdir(exist_ok=a.resume)
    reference=a.reference_work.resolve()
    if not (reference/'PREPARED.json').exists():m.user_prepare.prepare(reference)
    m.user_prepare.validate(reference)
    case=out/'input'
    if not a.resume:
        s.fixture(case,a.configuration)
        path=case/'swap.swp';body=s.assignment(path.read_text(encoding='cp1252'),'SWSOLU',1)
        body=s.assignment(body,'INLIST_CSV',"'WATBAL,ETTERMS,SOLBAL,GWL,CROP,WOFOST,GRASS'")
        path.write_text(body,encoding='cp1252')
        for crop in case.glob('*.crp'):
            crop.write_text(s.assignment(crop.read_text(encoding='cp1252'),'CIRRS','20.0'),encoding='cp1252')
    project=m.e.load(case)
    result=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                configuration=a.configuration,inputs=m.e.inspect(case),profiles={},water_guard_cm=1e-10,
                chemical_guard_mg_cm2=1e-10,science='NOT_QUALIFIED',new_persistent_codec=False)
    if a.resume:
        previous=json.loads((out/'RESULT.json').read_text())
        assert previous['inputs']==json.loads(json.dumps(result['inputs'])) and previous['configuration']==a.configuration
        result=previous;result['retained_failure']=dict(status=previous['status'],error=previous.pop('error',None))
        result['controller_commit']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
        result['status']='RESUMING'
    def save():(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    save()
    try:
        for opt in ('O0','O2'):
            build=out/(opt+'-build')
            command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,
                     '--experimental-project',str(case),'--reference-work',str(reference),'--build-only',
                     '--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
            if a.resume and (build/'BUILD.json').exists():m.validate_bundle(build,reference,project)
            else:
                started=time.perf_counter();r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
                (out/(opt+'-build.stdout')).write_text(r.stdout);(out/(opt+'-build.stderr')).write_text(r.stderr)
                result['profiles'][opt]=dict(build_seconds=time.perf_counter()-started,returncode=r.returncode);save()
                assert r.returncode==0,r.stderr
            short=out/(opt+'-short')
            if a.resume and 'short' in result['profiles'].get(opt,{}):brief=result['profiles'][opt]['short']
            else:
                brief,data=m.trajectory(build,reference,project,short,5,{2,4},30)
                brief['own']=m.own(build,reference,project,short,data,2,4,out/(opt+'-short-own'))
            result['profiles'][opt]['short']=brief;save()
            print(a.configuration,opt,'SHORT_NATIVE_PASS',flush=True)
            if a.short_only:continue
            full=out/(opt+'-full')
            if a.resume and (full/'daily.jsonl').exists():
                data=m.rows(full);assert len(data)==1096
                report=dict(status='FULL_PASS',days=1096,budgets=m.check(data),model_seconds='UNKNOWN_RETAINED_PRIOR_EXECUTION',build_sha256=m.sha(build/'BUILD.json'))
            else:report,data=m.trajectory(build,reference,project,full,1096,{2,4,365,367,530,532,544,546,1096},60)
            result['profiles'][opt].update(report);save()
            water=sum(row['external_flux_cm'][5] for row in data)
            mass=sum(row['solute_ledger_mg_cm2'][3] for row in data)
            assert water>0 and mass>0 and abs(mass-water*20)<=1e-10,(water,mass)
            first=next(row['day'] for row in data if row['solute_ledger_mg_cm2'][3]>0)
            active=next(row['day'] for row in data[532:] if row['solute_ledger_mg_cm2'][3]>0)
            assert active==545,active
            report.update(irrigation_water_cm=water,irrigation_mass_mg_cm2=mass,first_actual_source_day=first,
                          active_source_day=active,own=[m.own(build,reference,project,full,data,start,start+2,out/(opt+'-own'+str(start))) for start in (2,365,530,active-1)])
            report['controls']=q.controls(build,reference,project,full,data,out/(opt+'-controls'),
                policy_key='conserved_scheduled_subsurface_solute',policy_error='Foreign conserved scheduled subsurface solute policy',active_day=active)
            result['profiles'][opt].update(report);save()
            print(a.configuration,opt,'FULL_SOURCE_NATIVE_TRANSACTION_PASS',flush=True)
        result['status']='SHORT_O0_O2_PASS' if a.short_only else 'FULL_O0_O2_PASS'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
