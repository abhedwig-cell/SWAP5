"""Unqualified Linux stall diagnostic; instrument generated copies only."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import age_clock as c


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();root=a.output/'pilot'
    sys.path.insert(0,str(c.c.f.ROOT/'tools/solute'));import user_prepare
    if not (a.reference_work/'PREPARED.json').exists():user_prepare.prepare(a.reference_work)
    user_prepare.validate(a.reference_work)
    subprocess.run([sys.executable,'-B',str(Path(__file__).with_name('age_clock.py')),'--reference-work',str(a.reference_work),'--output',str(root),'--mode','subdaily','--nprint','2','--kind','surface','--optimization','O0','--phase','short'],check=True)
    m=c.m;project=m.e.load(root/'input');build=root/'build';meta,case=m.validate_bundle(build,a.reference_work,project)
    path=build/'headcalc.f90';source=path.read_text(encoding='cp1252')
    anchor='   iBackTr        = 0';assert source.count(anchor)==1
    declaration='   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror, mass_polish_at'
    assert source.count(declaration)==1
    source=source.replace(declaration,declaration+'\n   integer,save::diag_count=0',1)
    anchor='      if (budget_enabled .and. .not.flnonconv) then';assert source.count(anchor)==1
    trace="""      if(t1900>=38309d0.and.t1900<38310d0.and.diag_count<100)then
         diag_count=diag_count+1
         write(0,'(a,2i6,l3,9(1x,es25.17e3))') 'CLOCK_DIAGNOSTIC_ONLY',diag_count,numbit,flnonconv, &
           t1900,tcum,dt,dtmin,budget_start,budget_total,projected_water_residual(), &
           hybrid_output_trial_residual(),1d-10*(t1900-budget_start+dt)
      end if
"""
    source=source.replace(anchor,trace+anchor,1);path.write_text(source,encoding='cp1252')
    provider=a.reference_work/'build';objects=provider/'swap-obj';ttutil=provider/'ttutil-obj'
    def call(cmd,label):
        r=subprocess.run(list(map(str,cmd)),cwd=build,capture_output=True,text=True,timeout=60)
        (a.output/(label+'.log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
    call(['gfortran',*meta['identity']['donor_flags'],'-I'+str(build),'-I'+str(objects),'-I'+str(ttutil),'-c','headcalc.f90'],'diagnostic-compile')
    replacements={p.name.lower():p for p in build.glob('*.o')};linked=[]
    for path in sorted(objects.glob('*.o')):linked.append(replacements.pop(path.name.lower(),path))
    linked+=list(replacements.values());exe=build/'diagnostic_donor'
    call(['gfortran','-o',exe,*linked,ttutil/'libttutil.a'],'diagnostic-link')
    out=a.output/'unqualified-run';out.mkdir()
    report=dict(status='DIAGNOSTIC_ONLY_NOT_QUALIFIED',generated_copy_instrumented=True,scientific_or_admission_evidence=False)
    try:
        result,seconds=m.bounded(30,lambda:m.h.run(exe,m.h.executable(build,'day_kernel'),case,out,1096,runtime=True,checkpoint_binding=meta['binding'],model=project.model,project=project))
        report.update(result=result,seconds=seconds)
    except (TimeoutError,RuntimeError,ValueError) as error:report['error']=repr(error)
    finally:
        report['diagnostic_lines']=[line for path in out.rglob('donor.stderr') for line in path.read_text(errors='replace').splitlines() if line.startswith('CLOCK_DIAGNOSTIC_ONLY')]
        (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report),flush=True)


if __name__=='__main__':main()
