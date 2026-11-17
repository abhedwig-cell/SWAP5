"""Preserve current canonical wetting with explicit changed Python identity.

Every generated Fortran byte, compiler/provider closure, physical prefix and
native payload must match. New age-off renderer identity is never rebound.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
from age_composition_ci import extract_wetting,ROOT

sys.path.insert(0,str(ROOT/'tests/local_wetting'))
from run import m,POLICY


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True);a=p.parse_args();a.output.mkdir()
    prior=a.output/'prior';extract_wetting(prior,a.platform.lower())
    import shutil
    shutil.copytree(prior/'inputs',a.output/'inputs')
    result=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),profiles={},tolerances_changed=False,original_full_science='FAIL_PRESERVED',full_scientific_equivalence='NOT_CLAIMED')
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    for key in ('water-surface-history','chemical-surface-history'):
        project=m.e.load(a.output/'inputs'/key,time_step_policy=POLICY)
        for opt in ('O0','O2'):
            name=key+'-'+opt;build=a.output/(name+'-build');old=prior/(name+'-build')
            cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',project.input_directory,
                 '--experimental-time-step-policy',POLICY,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
            t=time.monotonic();r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);seconds=time.monotonic()-t
            (a.output/(name+'.log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
            meta,_=m.validate_bundle(build,a.reference_work,project);previous=json.loads((old/'BUILD.json').read_text());assert meta['inputs']==previous['inputs']
            generated=lambda p:{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in p.glob('*.f90')}
            assert generated(build)==generated(old),'Wetting emitted physical source changed'
            changed={k for k in set(meta['identity'])|set(previous['identity']) if meta['identity'].get(k)!=previous['identity'].get(k)}
            allowed={'host','experimental_input_adapter','restart_publisher','time_step_policy_source','budget_source','local_wetting_time'}
            assert changed<=allowed,changed
            def line_hashes(path):
                data=path.read_bytes().replace(b'\r\n',b'\n');return {hashlib.sha256(data).hexdigest(),hashlib.sha256(data.replace(b'\n',b'\r\n')).hexdigest()}
            # Only checkout newline encoding can differ for these unchanged inputs.
            if 'budget_source' in changed:assert {meta['identity']['budget_source'],previous['identity']['budget_source']}<=line_hashes(ROOT/'app/hybrid_water/hybrid_step_budget.f90')
            if 'local_wetting_time' in changed:
                new=dict(meta['identity']['local_wetting_time']);oldpolicy=dict(previous['identity']['local_wetting_time']);assert {new.pop('source_sha256'),oldpolicy.pop('source_sha256')}<=line_hashes(ROOT/'app/hybrid_water/local_wetting_time.py');assert new==oldpolicy
            assert 'conserved_original_age' not in meta['identity']
            full=a.output/(name+'-prefix365');brief,data=m.trajectory(build,a.reference_work,project,full,365,{4,6,199,201,362,365},30)
            parent=prior/(name+'-prefix365');assert m.physical(data)==m.physical(m.rows(parent))
            import zipfile
            for day in (6,365):
                with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as new,zipfile.ZipFile(parent/f'accepted-column-1-day-{day}.zip') as oldzip:
                    assert all(new.read(n)==oldzip.read(n) for n in ('result.end','macro.bin'))
            brief['own']=[m.own(build,a.reference_work,project,full,data,s,e,a.output/(name+'-own'+str(s))) for s,e in ((4,6),(199,201),(362,365))]
            result['profiles'][name]=dict(build_seconds=seconds,generated_sources=generated(build),changed_identity_fields=sorted(changed),
                all_other_identity_fields_exact=True,aquifer_enabled=False,input_exact=True,prefix_physical_exact=True,coverage=brief)
            save();print(name,'AGE_OFF_WETTING_SOURCE_CLOSURE_PHYSICAL_NATIVE_EXACT',flush=True)
    result['status']='SELECTED_CANONICAL_COMPOSITION_PASS';save()


if __name__=='__main__':main()
