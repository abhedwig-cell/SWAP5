"""Four corrected NoHeat representatives and actual typed restart controls."""
import argparse,json,subprocess,sys
from pathlib import Path
from ria12_boundary_batch import extract
R=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir()
 for archive,folder in [('RIA12_CORRECTED_KSAT_INPUTS_V1','inputs'),('RIA12_NATIVE_CONTROL_ORIGINS_V1','origins/legacy'),('RIA12_BOUNDARY_NATIVE_ORIGINS_V1','origins/parent')]:extract(archive,a.output/folder)
 def run(script,*args):subprocess.run([sys.executable,'-B',str(R/'tests/nomacro_drainage'/script),*map(str,args)],cwd=R,check=True)
 head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip();record=dict(status='RUNNING_CORRECTED_NOHEAT_NOT_ADMITTED',actual_source=head,optimization=a.optimization,cases=[],canonical_admission=False)
 def save():(a.output/'BATCH.json').write_text(json.dumps(record,indent=2)+'\n')
 save()
 for label,kind,relative in [('water-primary-dry','water','water-d1-b6'),('cde-primary-dry','cde','cde-d1-b6'),('water-boundary5','water','water-d0-b5'),('cde-wet8-d1','cde','cde-wet8-d1')]:
  profile=a.output/label;sample=a.output/(label+'-original-samples');independent=a.output/(label+'-INDEPENDENT.json');opposite=a.output/(label+'-opposite-initial')
  run('ria12_corrected_period.py','--input',a.output/'inputs'/relative,'--reference-work',a.reference_work,'--build-root',a.build_root/label,'--output',profile,'--optimization',a.optimization)
  run('ria12_corrected_reference_samples.py','--profile',profile,'--reference-work',a.reference_work,'--build-root' if not record['cases'] else '--reuse-component',a.build_root/'original-ria-component','--output',sample)
  run('ria12_corrected_science.py','--profile',profile,'--reference-samples',sample,'--output',independent)
  run('ria12_corrected_postimage.py','--profile',profile,'--reference-work',a.reference_work,'--build-root',a.build_root/(label+'-opposite'),'--output',opposite,*(['--short-native'] if kind=='cde' else []))
  record['cases'].append(dict(label=label,kind=kind,profile=str(profile),original_samples=str(sample),independent=str(independent),opposite_initial=str(opposite)));save()
 for case in record['cases']:
  label=case['label'];kind=case['kind'];other=next(c for c in record['cases'] if c['kind']!=kind);foreign=next(c for c in record['cases'] if c['kind']==kind and c['label']!=label)
  control=a.output/(label+'-controls')
  run('ria12_corrected_controls.py','--profile',case['profile'],'--reference-work',a.reference_work,'--reference-samples',case['original_samples'],'--model1-origin',a.output/'origins/legacy/model1/accepted-column-1-day-1.zip','--legacy-ria-origin',a.output/'origins/legacy/legacy-ria/accepted-column-1-day-1.zip','--primary-origin',a.output/f'origins/parent/primary-{kind}/accepted-column-1-day-2.zip','--other-kind-origin',Path(other['profile'])/'trajectory/accepted-column-1-day-2.zip','--foreign-context-origin',Path(foreign['profile'])/'trajectory/accepted-column-1-day-2.zip','--output',control)
  transaction=a.output/(label+'-transactions');run('ria12_corrected_transactions.py','--profile',case['profile'],'--reference-work',a.reference_work,'--current-controls',control,'--output',transaction)
  case.update(controls=str(control),transactions=str(transaction));save()
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip()==head
 record['status']='FOUR_CORRECTED_NOHEAT_FULL35_ORIGINAL_RIA_NATIVE_COLD_OPPOSITE_AND_EXTERNAL_PASS_NOT_ADMITTED';save();print(record['status'])
if __name__=='__main__':main()
