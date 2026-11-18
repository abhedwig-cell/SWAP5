"""Compile and exercise the real four-object direct age source closure."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
SOURCES=['src/process/'+n+'.f90' for n in ('mod_solute_compartment_state','mod_b111_age_tracer_substep','mod_direct_soil_age_substep')]+['tests/nomacro_scheduled_subsurface/direct_soil_age_component.f90']


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);args=ap.parse_args()
    args.output.mkdir(parents=True,exist_ok=False)
    q=dict(status='RUNNING_NOT_ADMITTED',head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),source_sha256={p:hashlib.sha256((ROOT/p).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in SOURCES},optimization={})
    def save():(args.output/'report.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for opt in ('O0','O2'):
            out=args.output/opt;out.mkdir();exe=out/('component.exe' if os.name=='nt' else 'component')
            cmd=['gfortran','-'+opt,'-fcheck=all','-ffpe-trap=invalid,zero,overflow','-fbacktrace','-ffree-line-length-none',*[str(ROOT/p) for p in SOURCES],'-o',str(exe)]
            t=time.monotonic();build=subprocess.run(cmd,cwd=out,text=True,capture_output=True)
            (out/'build.stdout').write_text(build.stdout);(out/'build.stderr').write_text(build.stderr)
            assert build.returncode==0,build.stderr
            run=subprocess.run([str(exe)],cwd=out,text=True,capture_output=True)
            (out/'run.stdout').write_text(run.stdout);(out/'run.stderr').write_text(run.stderr)
            assert run.returncode==0 and 'ACTUAL_DIRECT_SOIL_AGE_COMPONENT_PASS' in run.stdout,run
            sys.path.insert(0,str(ROOT/'app/hybrid_water'))
            from direct_soil_age import ledger,validate
            start=[30.,0.,30.]+[0.]*9
            end=[78.,0.,78.]+[0.]*8+[48.]
            measured=ledger(start,end);assert measured['age_direct_soil_input_cm_day']==48. and measured['age_combined_residual_cm_day']==0.
            refused=0
            for bad in (end[:11],end+[0.],end[:11]+[-1.],end[:11]+[float('nan')],end[:11]+[0.],end[:11]+[47.],end[:11]+[49.]):
                try:ledger(start,bad)
                except ValueError:refused+=1
                else:raise AssertionError('Malformed/missing direct source ledger accepted')
            q['optimization'][opt]=dict(status='REAL_FOUR_OBJECT_SOURCE_TRANSPORT_CONSERVATION_REJECTION_CONVERGENCE_PASS',command=cmd,stdout=run.stdout,seconds=time.monotonic()-t,ledger_refusals=refused)
            save();print(opt,q['optimization'][opt]['status'],flush=True)
        q['status']='DIRECT_SOIL_AGE_COMPONENT_O0_O2_PASS_NOT_ACTIVATED_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
