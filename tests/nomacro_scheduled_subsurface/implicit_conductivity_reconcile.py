"""Read-only selection of already executed water/CDE from the failed AGE cohort."""
from pathlib import Path
import argparse,json,subprocess,time,zipfile
import implicit_conductivity_ci as cohort
from implicit_conductivity_admission_controls import literal_composition

c=cohort.c


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','source-matrix','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();original=json.loads((a.source_matrix/'RESULT.json').read_text());assert original['status']=='FAILED'
 q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=c.ROOT,text=True).strip(),optimization=original['optimization'],actual_original_source_commit=original['source_commit'],actual_original_matrix_root=str(a.source_matrix),actual_original_matrix_status=original['status'],literal_guard_composition=literal_composition(),cases={},controls={},executed_model_count=0,role='Read-only reconciliation of actual successful water/CDE producers. Failed implicit AGE full remains raw and outside admission. No report, BUILD or native binding is rewritten.',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save();start=time.perf_counter()
 try:
  for name,case in cohort.CASES.items():
   item=original['cases'][name];inputs=Path(item['input_root']);project=c.m.e.load(inputs,original_output=True);build=Path(item['build_root']);meta,_=c.m.validate_bundle(build,a.reference_work,project)
   expected=a.output/('input-equivalence-'+name);sol,hys,bot,k,step,mode,fmt,reset,full,controls=case;c.fixture(expected,sol,hys,bot,step,k,mode,fmt,reset)
   assert c.m.e.inventory(expected)==c.m.e.inventory(inputs),'Actual original input differs: '+name
   for phase,days in [('short',35),*([('full',1096)] if full else [])]:
    root=Path(item[phase+'_root']);report=json.loads((root/'RESULT.json').read_text());assert report==item[phase]
    assert report['status']=='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_'+phase.upper()+'_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS' and report['build_root']==str(build) and report['input_root']==str(inputs)
    data=c.m.rows(root/'trajectory');assert len(data)==days;c.m.check(data)
    windows=[(2,4),(7,9),(30,34)]+([(199,201),(364,367),(530,532),(1094,1096)] if full and phase=='full' else [])
    assert len(report['cold'])==len(windows)
    for low,high in windows:
     cold=root/f'own-{low}';rows=c.m.rows(cold);assert c.m.physical(rows)==c.m.physical(data[low:high]);c.m.check(rows)
     with zipfile.ZipFile(root/f'trajectory/accepted-column-1-day-{high}.zip') as warm,zipfile.ZipFile(cold/f'accepted-column-1-day-{high}.zip') as restored:
      for member in ('result.end','macro.bin'):assert warm.read(member)==restored.read(member),(name,phase,member)
      for z in (warm,restored):
       checkpoint=json.loads(z.read('checkpoint.json'));assert checkpoint['binding']==meta['binding'] and checkpoint['receipt']==data[high-1]
   if controls:
    control=original['controls'][name];report=json.loads((Path(control['root'])/'RESULT.json').read_text());assert report==control['report'] and report['status']=='IMPLICIT_CONDUCTIVITY_NUMERICAL_NATIVE_TRANSACTION_DOMAIN_PASS' and report['build_sha256']==c.m.sha(build/'BUILD.json')
    q['controls'][name]=control
   q['cases'][name]=item;save()
  assert len(q['cases'])==8 and len(q['controls'])==6
  q['actual_foreign_numerical_origin']=original['actual_foreign_numerical_origin'];assert q['actual_foreign_numerical_origin']['status']=='REFUSED' and q['actual_foreign_numerical_origin']['original_unchanged']
  q.update(status='EIGHT_IMPLICIT_WATER_CDE_SHORT_SIX_FULL_ALL_NATIVE_ACTIVE_POLICY_PASS',seconds=time.perf_counter()-start);print(q['status'],flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
