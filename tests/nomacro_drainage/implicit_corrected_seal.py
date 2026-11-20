"""Seal corrected numeric source before final input-only admission guard."""
import argparse,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
from weather_surface_seal import archive,sha

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('evidence','output','provider'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args()
 for opt in ('O0','O2'):
  directories=[];builds={};profiles={}
  def add(prefix,name):
   root=a.evidence/name;q=json.loads((root/'RESULT.json').read_text());build=Path(q['build_root']);digest=sha((build/'BUILD.json').read_bytes())
   if build not in builds:builds[build]=prefix+'-build'
   if q['status']!='FAILED':assert digest==q['trajectory']['build_sha256']
   profiles[prefix]=dict(actual_build_prefix=builds[build],actual_build_sha256=digest,producer_source=q['source'],producer_status=q['status']);directories.append((prefix,root))
  add('full-cde-h2',f'implicit-extended-full-cde-{opt}-v2');add('full-cde-h0',f'implicit-extended-full-cde-h0-{opt}-v2');add('failed-water-secondary',f'implicit-extended-full-water-{opt}-v2')
  for case,h in [('water',0),('automatic',0),('water',1),('automatic',2)]:add(f'off-{case}-h{h}',f'implicit-off-{case}-h{h}-{opt}-v2')
  add('primary-water-short',f'implicit-primary-water-short-{opt}-v1')
  for solu,h in [(0,0),(1,2)]:directories.append((f'ordinary-current-s{solu}-h{h}',a.evidence/f'implicit-ordinary-current-s{solu}-h{h}-{opt}-v1'))
  index=a.evidence/f'IMPLICIT_CORRECTED_{opt}_ACTUAL_COMPILED_ALIASES_V1.json'
  with index.open('x') as stream:json.dump(dict(status='ACTUAL_CORRECTED_NUMERIC_SOURCE_SUCCESS_FAILURE_CUSTODY',profiles=profiles),stream,indent=2)
  q=archive(a.output,f'EXTENDED_DRAINAGE_IMPLICIT_CORRECTED_WINDOWS_{opt}_RAW_ARCHIVE',directories,[('ACTUAL_COMPILED_ALIASES.json',index)],[(prefix,root) for root,prefix in builds.items()]);print(opt,q['bytes'],q['sha256'],flush=True)
 q=archive(a.output,'EXTENDED_DRAINAGE_IMPLICIT_CORRECTED_WINDOWS_SOURCE_RAW_ARCHIVE',[('source',a.evidence/'implicit-extended-windows-source-v3')],[('provider-PREPARED.json',a.provider/'PREPARED.json'),('regression-controller.tar',a.evidence/'IMPLICIT_CORRECTED_REGRESSION_CONTROLLER_V1.tar')]);print('SOURCE',q['bytes'],q['sha256'],flush=True)
if __name__=='__main__':main()
