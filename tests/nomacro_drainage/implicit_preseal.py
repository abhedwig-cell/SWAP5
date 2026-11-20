"""Retain all actual pre-correction source phases and censored periods once."""
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
   profiles[prefix]=dict(actual_build_prefix=builds[build],actual_build_sha256=digest,producer_source=q['source'],producer_status=q['status'])
   directories.append((prefix,root))
  add('full-water',f'implicit-extended-full-water-{opt}-v1')
  add('failed-cde-h2',f'implicit-extended-full-cde-{opt}-v1')
  add('failed-cde-h0',f'implicit-extended-full-cde-h0-{opt}-v1')
  for case in ('water','automatic'):
   for h in (0,1,2):add(f'short-{case}-h{h}',f'implicit-extended-short-{case}-h{h}-{opt}-v2')
  for case,h in [('water',0),('automatic',0),('water',1),('automatic',2)]:add(f'off-{case}-h{h}',f'implicit-off-{case}-h{h}-{opt}-v1')
  for solu,h in [(0,0),(1,2)]:add(f'ordinary-s{solu}-h{h}',f'implicit-ordinary-zero-s{solu}-h{h}-{opt}-v1')
  directories += [('pond-component',a.evidence/f'implicit-extended-pond-{opt}-v1'),('saturation-component',a.evidence/f'implicit-saturation-component-{opt}-v1')]
  index=a.evidence/f'IMPLICIT_PRECORRECTION_{opt}_ACTUAL_COMPILED_ALIASES_V1.json'
  with index.open('x') as stream:json.dump(dict(status='ACTUAL_SUCCESS_AND_FAILURE_BUILD_CUSTODY_NO_REBINDING',profiles=profiles),stream,indent=2)
  q=archive(a.output,f'EXTENDED_DRAINAGE_IMPLICIT_PRECORRECTION_WINDOWS_{opt}_RAW_ARCHIVE',directories,[('ACTUAL_COMPILED_ALIASES.json',index)],[(prefix,root) for root,prefix in builds.items()])
  print(opt,q['bytes'],q['sha256'],flush=True)
 q=archive(a.output,'EXTENDED_DRAINAGE_IMPLICIT_PRECORRECTION_WINDOWS_SOURCE_RAW_ARCHIVE',[('short-source',a.evidence/'implicit-extended-windows-source-v1'),('source',a.evidence/'implicit-extended-windows-source-v2')],[('provider-PREPARED.json',a.provider/'PREPARED.json'),('saturation-component-controller.tar',a.evidence/'IMPLICIT_SATURATION_COMPONENT_CONTROLLER_V1.tar')]);print('SOURCE',q['bytes'],q['sha256'],flush=True)
 directories=[(p.name,p) for p in sorted(a.evidence.glob('implicit-primary-*')) if p.is_dir()]
 q=archive(a.output,'EXTENDED_DRAINAGE_IMPLICIT_ORIGINAL_DIAGNOSTICS_RAW_ARCHIVE',directories,[]);print('DIAGNOSTICS',q['bytes'],q['sha256'],flush=True)
if __name__=='__main__':main()
