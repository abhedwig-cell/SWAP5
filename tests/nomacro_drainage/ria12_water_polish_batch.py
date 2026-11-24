"""Portable numerical batch: two full wet periods, two dry seams, no legacy replay."""
import argparse,json,subprocess,sys
from pathlib import Path
from ria12_boundary_batch import extract
R=Path(__file__).resolve().parents[2]

def main():
    p=argparse.ArgumentParser()
    for name in ('reference-work','build-root','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir()
    extract('RIA12_CORRECTED_KSAT_INPUTS_V1',a.output/'inputs')
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()
    q=dict(status='RUNNING_PORTABLE_RIA_POLISH_NOT_ADMITTED',actual_source=head,optimization=a.optimization,cases=[],canonical_admission=False)
    def save():(a.output/'BATCH.json').write_text(json.dumps(q,indent=2)+'\n')
    def run(script,*args):subprocess.run([sys.executable,'-B',str(R/'tests/nomacro_drainage'/script),*map(str,args)],cwd=R,check=True)
    save()
    component=a.build_root/'original-component'
    for kind in ('water','cde'):
        label=kind+'-wet-primary';short=a.output/(label+'-short3');full=a.output/(label+'-full35');samples=a.output/(label+'-original-samples');build=a.build_root/label
        run('ria12_water_polish_probe.py','--input',a.output/'inputs'/(kind+'-wet-primary-top'),'--reference-work',a.reference_work,'--build-root',build,'--optimization',a.optimization,'--output',short)
        run('ria12_water_polish_probe.py','--input',a.output/'inputs'/(kind+'-wet-primary-top'),'--reference-work',a.reference_work,'--build-root',build,'--optimization',a.optimization,'--days','35','--reuse-profile',short,'--output',full)
        run('ria12_corrected_reference_samples.py','--profile',full,'--reference-work',a.reference_work,'--build-root' if kind=='water' else '--reuse-component',component,'--output',samples)
        independent=a.output/(label+'-INDEPENDENT.json');controls=a.output/(label+'-controls')
        run('ria12_water_polish_science.py','--profile',full,'--reference-samples',samples,'--output',independent)
        run('ria12_water_polish_controls.py','--profile',full,'--reference-work',a.reference_work,'--reference-samples',samples,'--output',controls)
        q['cases'].append(dict(kind=kind,full35=str(full),original_samples=str(samples),independent=str(independent),controls=str(controls)));save()
        dry=a.output/(kind+'-dry-short3');dry_samples=a.output/(kind+'-dry-original-samples')
        run('ria12_water_polish_probe.py','--input',a.output/'inputs'/(kind+'-d1-b6'),'--reference-work',a.reference_work,'--build-root',a.build_root/(kind+'-dry'),'--optimization',a.optimization,'--output',dry)
        run('ria12_corrected_reference_samples.py','--profile',dry,'--reference-work',a.reference_work,'--reuse-component',component,'--output',dry_samples)
        q['cases'][-1].update(dry_short3=str(dry),dry_original_samples=str(dry_samples));save()
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()==head
    q['status']='TWO_FULL35_TWO_DRY_SEAMS_ORIGINAL_RIA_NATIVE_POLICY_TRANSACTION_PASS_NOT_ADMITTED';save();print(q['status'])
if __name__=='__main__':main()
