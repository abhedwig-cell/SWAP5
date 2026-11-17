"""Fresh canonical composition with literal emitted closure and complete age state.

Completed trajectories are consumed only from a current-source validated bundle.
Old native files are read for comparison, never adopted by a fresh executable.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
import zipfile
import age_runtime as age

m=age.m


def main():
    p=argparse.ArgumentParser()
    for key in ('input-root','reference-work','prior','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir(exist_ok=True)
    result=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=age.ROOT,text=True).strip(),profiles={},
                whole_scientific_equivalence='NOT_QUALIFIED',water_guard_cm=1e-10,chemical_mass_guard_changed=False)
    def save():(a.output/'COMPOSITION.json').write_text(json.dumps(result,indent=2)+'\n')
    save()
    for initial in ('0','100'):
        project=m.e.load(a.input_root/initial)
        for opt in ('O0','O2'):
            name=initial+'-'+opt;build=a.output/(name+'-build');prior=a.prior/(name+'-build')
            if not (build/'BUILD.json').exists():
                cmd=[sys.executable,'-B',str(age.ROOT/'tools/solute/run_water.py'),'--model',project.model,
                     '--experimental-project',str(a.input_root/initial),'--reference-work',str(a.reference_work),
                     '--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
                t=time.monotonic();r=subprocess.run(cmd,capture_output=True,text=True,timeout=180)
                (a.output/(name+'-build.log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
            meta,_=m.validate_bundle(build,a.reference_work,project);old=json.loads((prior/'BUILD.json').read_text())
            generated=lambda root:{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in root.glob('*.f90')}
            assert generated(build)==generated(prior),(name,'changed emitted physical source')
            fields=('donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','adapter','driver','conserved_original_age')
            assert all(meta['identity'][k]==old['identity'][k] for k in fields),(name,'changed compiled physical closure')
            assert meta['inputs']==old['inputs']
            full=a.output/(name+'-full');previous=a.prior/(name+'-full')
            if (full/'journal.jsonl').exists():
                data=m.rows(full);assert len(data)==1096
            elif (full/'physical-journal.jsonl').exists():
                data=m.rows(full);assert len(data)==1096
            elif full.exists():
                # The owner journal filename is resolved by its own reader.
                data=m.rows(full);assert len(data)==1096
            else:
                _,data=m.trajectory(build,a.reference_work,project,full,1096,{2,4,199,201,365,367,530,532,1096},90)
            assert m.physical(data)==m.physical(m.rows(previous)),(name,'changed complete physical/age/output rows')
            for f in ('result_output.csv','result.ageProfile.csv','result.ageeffluent.csv','result.ageeffluentqdrain.csv','result.ageeffluentwater.csv'):
                assert m.csvlines(full/'original'/f)==m.csvlines(previous/'original'/f),(name,f)
            for day in (2,4,199,201,365,367,530,532,1096):
                with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as new,zipfile.ZipFile(previous/f'accepted-column-1-day-{day}.zip') as oldzip:
                    for member in ('result.end','macro.bin'):assert new.read(member)==oldzip.read(member),(name,day,member)
            own=[]
            for start in (2,199,365,530):
                target=a.output/(name+'-composition-own'+str(start))
                own.append(age.own(build,a.reference_work,project,full,data,start,start+2,target))
            result['profiles'][name]=dict(days=1096,generated_sources_exact=True,compiled_closure_inputs_exact=True,
                complete_physical_age_output_rows_exact=True,all_five_csv_exact=True,all_nine_full_native_payloads_exact=True,
                prior_native_adopted=False,effluent=age.output_values(full,data),own=own)
            save();print(name,'CANONICAL_COMPOSITION_COMPLETE_NATIVE_EXACT',flush=True)
    result['status']='CANONICAL_COMPOSITION_FOUR_FULL_AGE_SOURCE_STATE_OUTPUT_EXACT';save()


if __name__=='__main__':main()
