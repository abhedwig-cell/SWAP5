"""Actual original SSDI age source defect and explicit end-microstep correction."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
import age_fixed
from age_irrigation_source_original import profile

ROOT=age_fixed.ROOT
SOLUTE_SHA='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2'
IRRIGATION_SHA='65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def irrigation_source(raw,corrected):
    assert hashlib.sha256(raw).hexdigest()==IRRIGATION_SHA
    if not corrected:return raw
    text=raw.decode('cp1252').replace('\r\n','\n')
    anchor='                  qssdi(nod_ssdi(1):nod_ssdi(2)) = irrate(nirri)'
    assert text.count(anchor)==1
    return text.replace(anchor,'                  if(swsolu==2)cirr=irconc(nirri)\n'+anchor,1).encode('cp1252')


def solute_source(raw,corrected,probe):
    assert hashlib.sha256(raw).hexdigest()==SOLUTE_SHA
    if not corrected and not probe:return raw
    text=raw.decode('cp1252').replace('\r\n','\n')
    first=text.index('submodule (MOD_Solute) MOD_calc_AgeTracer');last=text.index('end submodule MOD_calc_AgeTracer',first)
    before,body,after=text[:first],text[first:last],text[last:]
    anchor='      use MOD_irrigation,only: nird, cirr';assert body.count(anchor)==1
    body=body.replace(anchor,anchor+',qssdi',1)
    if corrected:
        anchor='!           age of effluent terms';assert body.count(anchor)==1
        body=body.replace(anchor,'            Agemsy=Agemsy+qssdi(1:numnod)*cirr*dtsolu/dz(1:numnod)\n            Ageml(1:numnod)=Agemsy/theta(1:numnod)\n\n'+anchor,1)
    if probe:
        anchor='! === calculate Solute rate variables ========================';assert body.count(anchor)==1
        body=body.replace(anchor,anchor+"\n         if(any(qssdi(1:numnod)>0d0))write(*,'(a,4(1x,es25.17e3))') &\n            'ACTUAL_SSDI_AGE_SOURCE',dt,sum(qssdi(1:numnod)),cirr,sum(qssdi(1:numnod))*cirr*dt\n",1)
    return (before+body+after).encode('cp1252')


def main():
    ap=argparse.ArgumentParser()
    for key in ('reference-work','output'):ap.add_argument('--'+key,type=Path,required=True)
    args=ap.parse_args();out=args.output.resolve();out.mkdir()
    provider=args.reference_work/'build';objects=provider/'swap-obj';tt=provider/'ttutil-obj'
    originals={name:(provider/'swap-selected'/name).read_bytes() for name in ('solute.f90','irrigation.f90')}
    q=dict(status='RUNNING',head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),provider_objects={p.name:sha(p) for p in objects.glob('*.o')},library_sha256=sha(tt/'libttutil.a'),original_sha256={n:hashlib.sha256(b).hexdigest() for n,b in originals.items()},profiles={},SWAP5_activation=False,whole_scientific_equivalence='NOT_QUALIFIED',correction='actual current CIRR plus direct qssdi*age*dtsolu after each transport microstep')
    def save():(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def call(cmd,cwd,label):
        start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,text=True,timeout=90)
        (cwd/(label+'.stdout')).write_text(r.stdout);(cwd/(label+'.stderr')).write_text(r.stderr);return r,time.monotonic()-start
    save()
    try:
        for opt in ('O0','O2'):
            record=dict(builds={},runs={},comparisons={});q['profiles'][opt]=record;exes={}
            for variant,corrected,probe in [('original',False,False),('probe',False,True),('corrected',True,False),('corrected-probe',True,True)]:
                build=out/(opt+'-'+variant+'-build');build.mkdir()
                flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-fcheck=all','-fbacktrace','-g','-ffp-contract=off','-march=x86-64','-mtune=generic','-J'+str(build),'-I'+str(build),'-I'+str(objects),'-I'+str(tt)]
                sources={name:solute_source(raw,corrected,probe) if name=='solute.f90' else irrigation_source(raw,corrected) for name,raw in originals.items()}
                for name,data in sources.items():
                    path=build/name;path.write_bytes(data);r,seconds=call(['gfortran',*flags,'-c',path],build,'compile-'+path.stem);assert r.returncode==0,r.stderr
                linked=[build/p.name if p.name.lower() in ('solute.o','irrigation.o') else p for p in sorted(objects.glob('*.o'))];exe=build/'swap_direct_age.exe'
                r,seconds=call(['gfortran','-o',exe,*linked,tt/'libttutil.a'],build,'link');assert r.returncode==0,r.stderr
                exes[variant]=exe;record['builds'][variant]=dict(flags=flags,source_sha256={n:sha(build/n) for n in sources},executable_sha256=sha(exe),actual_link_closure={str(p):sha(p) for p in [*linked,tt/'libttutil.a']});save()
            for kind in ('subsurface','subsurface-interval'):
                rows={}
                for variant,exe in exes.items():
                    for age in (0,20):
                        key=kind+'-'+variant+'-'+str(age);case=out/(opt+'-'+key);age_fixed.fixture(case,kind)
                        p=case/'swap.swp';text=p.read_text(encoding='cp1252');text,n=re.subn(r'(?mi)^([ \t]*TEND[ \t]*=)[^\r\n!]*',lambda m:m[1]+' 2002-01-08',text);assert n==1;p.write_text(text,encoding='cp1252')
                        p=case/'fixed-irrigation.irg';text=p.read_text();assert '2002-01-05 24.0 0.0' in text;p.write_text(text.replace('2002-01-05 24.0 0.0','2002-01-05 24.0 '+str(age)+'.0'))
                        inputs={p.relative_to(case).as_posix():sha(p) for p in case.rglob('*') if p.is_file()}
                        run,seconds=call([exe,'./swap.swp'],case,'run');assert run.returncode in (0,100) and (case/'swap.ok').exists(),run.stderr
                        obs=[list(map(float,line.split()[1:])) for line in run.stdout.splitlines() if line.startswith('ACTUAL_SSDI_AGE_SOURCE ')]
                        rows[(variant,age)]=profile(case)
                        record['runs'][key]=dict(returncode=run.returncode,seconds=seconds,swap_ok=True,input_sha256=inputs,observations=obs,profile_sha256=hashlib.sha256(json.dumps(rows[(variant,age)]).encode()).hexdigest(),actual_water_cm=sum(x[0]*x[1] for x in obs),actual_direct_age_input_cm_day=sum(x[3] for x in obs));save()
                assert rows[('original',0)]==rows[('original',20)]==rows[('probe',0)]==rows[('probe',20)]
                assert rows[('corrected',0)]==rows[('original',0)]==rows[('corrected-probe',0)]
                assert rows[('corrected',20)]==rows[('corrected-probe',20)] and rows[('corrected',20)]!=rows[('original',20)]
                old=record['runs'][kind+'-probe-20'];new=record['runs'][kind+'-corrected-probe-20']
                assert old['observations'] and all(x[2]==0 for x in old['observations']) and old['actual_direct_age_input_cm_day']==0
                assert abs(old['actual_water_cm']-2.4)<1e-10 and abs(new['actual_water_cm']-2.4)<1e-10 and abs(new['actual_direct_age_input_cm_day']-48)<1e-10
                record['comparisons'][kind]=dict(original_ignored_age=True,original_cirr_zero=True,nonmutating_probe_exact=True,zero_corrected_exact=True,positive_corrected_changes=True,plain_corrected_equals_probe=True,actual_water_cm=new['actual_water_cm'],corrected_input_cm_day=new['actual_direct_age_input_cm_day']);save();print(opt,kind,'ACTUAL_ORIGINAL_DIRECT_SOIL_AGE_DEFECT_AND_SCOPED_CORRECTION_PASS',flush=True)
        assert q['provider_objects']=={p.name:sha(p) for p in objects.glob('*.o')} and q['library_sha256']==sha(tt/'libttutil.a')
        q['status']='ORIGINAL_SSDI_AGE_O0_O2_32_EXECUTIONS_DEFECT_AND_CORRECTION_PASS_NOT_ACTIVE'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
