"""Plain corrected original source against the actual nonmutating diagnostic."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import time
import age_irrigation_source_original as original

ROOT=original.ROOT
PATCH=ROOT/'reference/swap-4.3.1/patches/NOMACRO-AGE-IRRIGATION-SOURCE-01/source.py'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','prior','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();prior=json.loads((a.prior/'RESULT.json').read_text());assert prior['status']=='ORIGINAL_FIXED_AGE_CAPTURE_O0_O2_COUNTEREXAMPLE_AND_NONMUTATING_DIAGNOSTIC_PASS_NOT_ACTIVE'
    provider=a.reference_work/'build';objects=provider/'swap-obj';tt=provider/'ttutil-obj';assert prior['provider_objects']=={p.name:sha(p) for p in objects.glob('*.o')} and prior['ttutil_library_sha256']==sha(tt/'libttutil.a')
    spec=importlib.util.spec_from_file_location('current_fixed_original_age',PATCH);patch=importlib.util.module_from_spec(spec);spec.loader.exec_module(patch);body=patch.source((provider/'swap-selected/solute.f90').read_bytes())
    q=dict(status='RUNNING',original_probe_sha256=sha(a.prior/'RESULT.json'),corrected_source_sha256=hashlib.sha256(body).hexdigest(),patch_sha256=sha(PATCH),profiles={},SWAP5_activation=False,whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def call(cmd,cwd,label):
        t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,text=True,timeout=60);(cwd/(label+'.stdout')).write_text(r.stdout);(cwd/(label+'.stderr')).write_text(r.stderr);return r,time.monotonic()-t
    try:
        for opt in ('O0','O2'):
            build=a.output/(opt+'-build');build.mkdir();source=build/'solute.f90';source.write_bytes(body);flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-fcheck=all','-fbacktrace','-g','-ffp-contract=off','-march=x86-64','-mtune=generic','-J'+str(build),'-I'+str(build),'-I'+str(objects),'-I'+str(tt)]
            r,compile_seconds=call(['gfortran',*flags,'-c',source],build,'compile');assert r.returncode==0,r.stderr;linked=[build/'solute.o' if p.name.lower()=='solute.o' else p for p in sorted(objects.glob('*.o'))];exe=build/'swap_age_current.exe';r,link_seconds=call(['gfortran','-o',exe,*linked,tt/'libttutil.a'],build,'link');assert r.returncode==0,r.stderr
            record=dict(flags=flags,source_sha256=sha(source),executable_sha256=sha(exe),compile_seconds=compile_seconds,link_seconds=link_seconds,actual_link_closure={str(p):sha(p) for p in [*linked,tt/'libttutil.a']},cases={});q['profiles'][opt]=record
            for kind in ('surface','sprinkler'):
                for age in (0,20):
                    key=kind+'-'+str(age);oldkey=kind+'-refresh-probe-'+str(age);old=a.prior/(opt+'-'+oldkey);case=a.output/(opt+'-'+key);case.mkdir();inputs=prior['profiles'][opt]['runs'][oldkey]['input_sha256']
                    for name,digest in inputs.items():
                        assert sha(old/name)==digest;target=case/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(old/name,target)
                    r,seconds=call([exe,'./swap.swp'],case,'run');assert r.returncode in (0,100) and (case/'swap.ok').exists(),r.stderr
                    actual=original.profile(case);assert actual==original.profile(old);assert bool(age)==(actual!=original.profile(a.prior/(opt+'-'+kind+'-original-0')))
                    record['cases'][key]=dict(returncode=r.returncode,seconds=seconds,input_sha256=inputs,exact_to_actual_refreshed_diagnostic=True,zero_age_original_preserved=not age,nonzero_profile_changes=bool(age),profile_sha256=hashlib.sha256(json.dumps(actual).encode()).hexdigest());save()
            print(opt,'PLAIN_CORRECTED_ORIGINAL_FOUR_PROFILES_EXACT',flush=True)
        assert prior['provider_objects']=={p.name:sha(p) for p in objects.glob('*.o')} and prior['ttutil_library_sha256']==sha(tt/'libttutil.a')
        q['status']='PLAIN_ORIGINAL_CURRENT_AGE_SOURCE_O0_O2_EIGHT_PROFILES_EXACT_TO_REAL_DIAGNOSTIC_NOT_ACTIVE'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
