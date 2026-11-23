"""Preserve all actual integrated Windows compiled closures and failed observers."""
import argparse,json
from pathlib import Path
from explicit_bottom9_combined_postimages import ROOT,SHA,git,verify
from initial_profile_frost_preserve import seal

def preserve(ev,stage):
 source=verify();files={};projection={};roles=[]
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for child in sorted(path.rglob('*')):
   assert not child.is_symlink()
   if child.is_file():
    name=prefix+'/'+child.relative_to(path).as_posix();assert name not in files;files[name]=child
 for kind,version,count,status in [('postimages','v1',22,'ALL22_OPT_INTEGRATED_ANALYTICAL_SNOW_HISTORY_AND_PRIOR_WHOLE_COMPILED_POSTIMAGES_PASS_NO_MODEL_PERIODS'),('legacy-seams','v2',6,'ALL6_OPT_OLD_HISTORY40_AND_SNOW_INTEGRATED_WHOLE_COMPILED_POSTIMAGES_PASS_NO_MODELS')]:
  for opt in ('O0','O2'):
   path=ev/('explicit-bottom9-combined-'+kind+'-'+opt+'-'+version);q=json.loads((path/'RESULT.json').read_text());assert q['status']==status and len(q['contexts'])==q['compiler_executions']==count and q['model_executions']==0
   producer=q.get('actual_source',q.get('source'));assert len(producer)==40 and not git('diff',source['composition_core'],producer,'--','app','src','tools','reference')
   for role in q['contexts']:
    build=Path(role['build_root']);prefix='compiled/'+kind+'/'+opt+'/'+role['label'];tree(build,prefix);assert str(build) not in projection;projection[str(build)]=dict(archive_prefix=prefix,actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()));roles.append(dict(kind=kind,optimization=opt,producer=producer,profile='profiles/'+path.name+'/'+Path(role['output']).name,compiled=prefix))
 assert len(roles)==len(projection)==56
 for path in sorted(ev.iterdir()):
  if path.is_dir() and path.name.startswith('explicit-bottom9-combined-'):tree(path,'profiles/'+path.name)
  elif path.is_file() and path.name.lower().startswith(('explicit-bottom9-combined-','explicit_bottom9_combined_')):files['observations/'+path.name]=path
 extra={'COMPILED_PROJECTION_V1.json':(json.dumps(projection,indent=2)+'\n').encode(),'actual-sealer.py':Path(__file__).read_bytes()}
 seal(stage/'EXPLICIT_BOTTOM9_COMBINED_WINDOWS_POSTIMAGES_RAW_V1.zip','EXPLICIT_BOTTOM9_COMBINED_WINDOWS_POSTIMAGES_RAW_V1',files,extra,dict(status='ALL56_ACTUAL_INTEGRATED_WINDOWS_COMPILED_CLOSURES_AND_SOURCE_CONTROLLERS_FAILURES_PRESERVED_NOT_ADMITTED',composition_core=source['composition_core'],roles=roles,actual_compiled_closures=56,new_sibling_contexts=32,prior_paired9_contexts=12,prior_hysteresis_contexts=8,prior_Snow_contexts=4,model_executions=0,canonical_admission=False))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--staging',type=Path,required=True);a=p.parse_args();preserve(a.evidence,a.staging)
