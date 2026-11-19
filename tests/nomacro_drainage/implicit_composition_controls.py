"""Actual current policy and emitted-constitutive-source refusals before worker."""
import argparse,copy,json,shutil,subprocess
from pathlib import Path
import calendar_runtime as runtime
m=runtime.m

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();q0=json.loads((a.profile/'RESULT.json').read_text());build=Path(q0['build_root']);project=m.e.load(a.profile/'input',original_output=True);meta,_=m.validate_bundle(build,a.reference_work,project)
 result=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=runtime.ROOT,text=True).strip(),actual_build_sha256=m.sha(build/'BUILD.json'),refusals=[])
 fields=['source_sha256','implicit_pond_renderer_sha256','implicit_soil_pond_chain_rule','continuous_saturation_renderer_sha256','near_saturation_reference_correction','discontinuous_original_near_saturation_behavior_preserved']
 for field in [*fields,'actual-MOD-MvG']:
  target=a.output/field;target.mkdir()
  for path in build.iterdir():
   if path.name=='BUILD.json' or path.suffix.lower() in ('.f90','.dll','.so'):shutil.copyfile(path,target/path.name)
  if field=='actual-MOD-MvG':
   path=target/'MOD_MvG_functions.f90';path.write_bytes(path.read_bytes()+b'\n! deliberately foreign actual constitutive source\n');expected='Foreign actual original implicit saturated derivative provider'
  else:
   bad=copy.deepcopy(meta)
   for identity in (bad['identity'],bad['binding']['build']):identity['extended_drainage'][field]='foreign'
   (target/'BUILD.json').write_text(json.dumps(bad,indent=2));expected='Foreign extended drain state policy'
  try:m.validate_bundle(target,a.reference_work,project)
  except ValueError as error:
   assert expected in str(error),str(error);assert not list(target.rglob('donor.stdout')) and not list(target.rglob('accepted-*.zip'))
   result['refusals'].append(dict(field=field,expected=expected,error=str(error),before_worker=True,no_publication=True))
  else:raise AssertionError('Foreign implicit composition accepted '+field)
  (a.output/'RESULT.json').write_text(json.dumps(result,indent=2))
 result['status']='ACTUAL_SEVEN_IMPLICIT_COMPOSITION_POLICY_CONSTITUTIVE_SOURCE_REFUSALS_PASS';(a.output/'RESULT.json').write_text(json.dumps(result,indent=2));print(result['status'])
if __name__=='__main__':main()
