"""Seal final primary numerical/input-guard postimages with actual build aliases."""
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
  def add(prefix,root):
   q=json.loads((root/'RESULT.json').read_text());build=Path(q['build_root']);digest=sha((build/'BUILD.json').read_bytes());assert q['status']=='ACTUAL_EXTENDED_DRAINAGE_ORIGINAL_OUTPUT_NATIVE_PASS' and digest==q['trajectory']['build_sha256']
   if build not in builds:builds[build]=prefix+'-build'
   profiles[prefix]=dict(actual_build_prefix=builds[build],actual_build_sha256=digest,producer_source=q['source']);directories.append((prefix,root))
  add('full-water',a.evidence/f'implicit-primary-water-full-{opt}-v1')
  batch=a.evidence/f'implicit-primary-short-{opt}-v1';q=json.loads((batch/'RESULT.json').read_text());assert len(q['contexts'])==9
  for item in q['contexts']:add(f"short-{item['case']}-{item['kind']}-h{item['hysteresis']}",Path(item['root']))
  case,h=('water',0) if opt=='O0' else ('automatic',2);add('final-off',a.evidence/f'implicit-final-off-{case}-h{h}-{opt}-v1')
  for solu,h in [(0,0),(1,2)]:directories.append((f'ordinary-current-s{solu}-h{h}',a.evidence/f'implicit-ordinary-current-s{solu}-h{h}-{opt}-v2'))
  directories.append(('composition-policy',a.evidence/f'implicit-composition-policy-{opt}-v1'))
  index=a.evidence/f'IMPLICIT_FINAL_{opt}_ACTUAL_COMPILED_ALIASES_V1.json'
  with index.open('x') as stream:json.dump(dict(status='ACTUAL_FINAL_PRIMARY_BUILD_CUSTODY_WITH_IDENTICAL_FULL_SHORT_REUSE',profiles=profiles),stream,indent=2)
  q=archive(a.output,f'EXTENDED_DRAINAGE_IMPLICIT_WINDOWS_{opt}_RAW_ARCHIVE',directories,[('ACTUAL_COMPILED_ALIASES.json',index),('SHORT_BATCH_RESULT.json',batch/'RESULT.json')],[(prefix,root) for root,prefix in builds.items()]);print(opt,q['bytes'],q['sha256'],flush=True)
 q=archive(a.output,'EXTENDED_DRAINAGE_IMPLICIT_WINDOWS_SOURCE_RAW_ARCHIVE',[('source',a.evidence/'implicit-extended-windows-source-v4'),('scope',a.evidence/'implicit-public-scope-v1')],[('provider-PREPARED.json',a.provider/'PREPARED.json'),('scope-controller.tar',a.evidence/'IMPLICIT_SCOPE_CONTROLLER_V1.tar')]);print('SOURCE',q['bytes'],q['sha256'],flush=True)
if __name__=='__main__':main()
