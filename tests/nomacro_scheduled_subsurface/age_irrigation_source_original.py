"""Actual original fixed age-source capture; isolated diagnostic, no activation."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
import re
import age_fixed

ROOT=age_fixed.ROOT
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def source(original,refresh=False):
    text=original.decode('cp1252').replace('\r\n','\n')
    first=text.index('submodule (MOD_Solute) MOD_calc_AgeTracer')
    last=text.index('end submodule MOD_calc_AgeTracer',first)
    before,body,after=text[:first],text[first:last],text[last:]
    anchor='      use variables,     only: dt';assert body.count(anchor)==1
    body=body.replace(anchor,anchor+',daycum,t1900',1)
    anchor='! === calculate Solute rate variables ========================';assert body.count(anchor)==1
    diagnostic="""
         if(nird>0d0)write(*,'(a,1x,i0,7(1x,es25.17e3))')'AGE_FIXED_SOURCE', &
            daycum,t1900,dt,nird,cirr,Ageirr,nird*Ageirr*dt,nird*cirr*dt
"""
    body=body.replace(anchor,anchor+('\n         Ageirr=cirr\n' if refresh else '')+diagnostic,1)
    return (before+body+after).encode('cp1252')


def profile(case):
    files=[p for p in case.glob('*.csv') if p.name.lower()=='result.ageprofile.csv'];assert len(files)==1
    return [line.strip() for line in files[0].read_text(encoding='cp1252').splitlines() if line.strip() and not line.startswith('*')]


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();provider=a.reference_work/'build';objects=provider/'swap-obj';tt=provider/'ttutil-obj';original=(provider/'swap-selected/solute.f90').read_bytes()
    assert hashlib.sha256(original).hexdigest()=='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2'
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),original_solute_sha256=hashlib.sha256(original).hexdigest(),original_irrigation_sha256=sha(provider/'swap-selected/irrigation.f90'),provider_objects={p.name:sha(p) for p in objects.glob('*.o')},ttutil_library_sha256=sha(tt/'libttutil.a'),profiles={},SWAP5_activation=False,whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def call(cmd,cwd,label):
        start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,text=True,timeout=60);(cwd/(label+'.stdout')).write_text(r.stdout);(cwd/(label+'.stderr')).write_text(r.stderr)
        return r,time.monotonic()-start
    try:
        for opt in ('O0','O2'):
            record=dict(builds={},runs={},comparisons={});q['profiles'][opt]=record;executables={}
            for variant,body in [('original',original),('probe',source(original)),('refresh-probe',source(original,True))]:
                build=a.output/(opt+'-'+variant+'-build');build.mkdir();path=build/'solute.f90';path.write_bytes(body)
                flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-fcheck=all','-fbacktrace','-g','-ffp-contract=off','-march=x86-64','-mtune=generic','-J'+str(build),'-I'+str(build),'-I'+str(objects),'-I'+str(tt)]
                r,compile_seconds=call(['gfortran',*flags,'-c',path],build,'compile');assert r.returncode==0,r.stderr
                linked=[build/'solute.o' if p.name.lower()=='solute.o' else p for p in sorted(objects.glob('*.o'))];exe=build/'swap_age_source.exe'
                r,link_seconds=call(['gfortran','-o',exe,*linked,tt/'libttutil.a'],build,'link');assert r.returncode==0,r.stderr;executables[variant]=exe
                record['builds'][variant]=dict(source_sha256=sha(path),executable_sha256=sha(exe),flags=flags,compile_seconds=compile_seconds,link_seconds=link_seconds,actual_link_closure={str(p):sha(p) for p in linked});save()
            for kind in ('surface','sprinkler'):
                actual={}
                for variant,exe in executables.items():
                    for age in (0,20):
                        key=kind+'-'+variant+'-'+str(age);case=a.output/(opt+'-'+key);age_fixed.fixture(case,kind)
                        control=case/'swap.swp';text=control.read_text(encoding='cp1252')
                        text,n=re.subn(r'(?mi)^([ \t]*TEND[ \t]*=)[^\r\n!]*',lambda m:m[1]+' 2002-01-08',text);assert n==1;control.write_text(text,encoding='cp1252')
                        path=case/'fixed-irrigation.irg';text=path.read_text();assert '2002-01-05 24.0 0.0' in text;path.write_text(text.replace('2002-01-05 24.0 0.0','2002-01-05 24.0 '+str(age)+'.0'))
                        inputs={p.relative_to(case).as_posix():sha(p) for p in case.rglob('*') if p.is_file()};r,seconds=call([exe,'./swap.swp'],case,'run');assert r.returncode in (0,100) and (case/'swap.ok').exists(),r.stderr
                        observations=[list(map(float,line.split()[1:])) for line in r.stdout.splitlines() if line.startswith('AGE_FIXED_SOURCE ')]
                        rows=profile(case);actual[(variant,age)]=rows
                        record['runs'][key]=dict(returncode=r.returncode,seconds=seconds,swap_ok=True,input_sha256=inputs,observations=observations,profile_rows=len(rows)-1,profile_sha256=hashlib.sha256(json.dumps(rows).encode()).hexdigest(),actual_event_water_cm=sum(row[2]*row[3] for row in observations),captured_source_cm_day=sum(row[6] for row in observations),current_event_source_cm_day=sum(row[7] for row in observations));save()
                assert actual[('original',0)]==actual[('original',20)]==actual[('probe',0)]==actual[('probe',20)]
                assert actual[('refresh-probe',0)]==actual[('original',0)] and actual[('refresh-probe',20)]!=actual[('original',20)]
                old=record['runs'][kind+'-probe-20'];new=record['runs'][kind+'-refresh-probe-20'];assert old['observations'] and old['captured_source_cm_day']==0 and old['current_event_source_cm_day']>0
                assert all(row[5]==0 and row[4]==20 for row in old['observations'])
                assert new['captured_source_cm_day']==new['current_event_source_cm_day']==old['current_event_source_cm_day']
                record['comparisons'][kind]=dict(original_ignores_nonzero_fixed_age=True,diagnostic_nonmutation=True,zero_age_refresh_preserved=True,actual_current_source_positive=True,refreshed_profile_changes=True,actual_event_water_cm=old['actual_event_water_cm'],actual_source_cm_day=old['current_event_source_cm_day']);save();print(opt,kind,'ORIGINAL_AGE_SOURCE_CAPTURE_COUNTEREXAMPLE_OBSERVED',flush=True)
            assert {p.name:sha(p) for p in objects.glob('*.o')}==q['provider_objects'] and sha(tt/'libttutil.a')==q['ttutil_library_sha256']
        q['status']='ORIGINAL_FIXED_AGE_CAPTURE_O0_O2_COUNTEREXAMPLE_AND_NONMUTATING_DIAGNOSTIC_PASS_NOT_ACTIVE'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
