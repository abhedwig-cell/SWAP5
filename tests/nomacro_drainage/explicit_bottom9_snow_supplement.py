"""Preserve only new prior-context compiled closures and compiled startup controls."""
import argparse,json
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_snow_source_inverse import ROOT,CORE,complete_inverse,git
from explicit_bottom9_snow_preserve import committed_sources
from initial_profile_frost_preserve import seal


def preserve(ev,staging):
 complete_inverse();files={};projection={};epochs={git('rev-parse','HEAD').decode().strip()}
 def tree(path,prefix):
  assert path.is_dir() and not path.is_symlink()
  for child in sorted(path.rglob('*')):
   assert not child.is_symlink()
   if child.is_file():
    key=prefix+'/'+child.relative_to(path).as_posix();assert key not in files;files[key]=child
 def build(actual):
  if actual in projection:return
  path=Path(actual);prefix='compiled/'+path.parent.name+'/bundle';tree(path,prefix);projection[actual]=dict(archive_prefix=prefix,actual_BUILD_sha256=SHA((path/'BUILD.json').read_bytes()))
 prior=json.loads((ev/'EXPLICIT_BOTTOM9_SNOW_PRIOR_ACTUAL_PARENT_POSTIMAGES_V1.json').read_text());assert len(prior['comparisons'])==4 and prior['actual_compile_only_builds']==8 and prior['model_executions']==0
 for item in prior['comparisons']:
  for role in ('actual_parent','actual_candidate'):q=item[role];build(q['build_root']);epochs.add(q['source'])
 for opt in ('O0','O2'):
  path=ev/('explicit-bottom9-snow-prior-paired9-cde-monthly-'+opt+'-v1');q=json.loads((path/'RESULT.json').read_text());assert q['actual_compiler_start_HEAD']==q['actual_compiler_end_HEAD'];build(q['build_root']);epochs.add(q['actual_compiler_start_HEAD'])
 assert len(projection)==10
 controls=json.loads((ev/'EXPLICIT_BOTTOM9_SNOW_WINDOWS_COMPILED_NATIVE_CONTROLS_INDEPENDENT_V1.json').read_text());assert len(controls['contexts'])==4 and controls['accepted_model_days']==0
 base_names=json.loads((ROOT/'integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_SNOW_WINDOWS_RAW_V1.json').read_text())['members']
 for path in sorted(ev.iterdir()):
  if path.is_dir() and path.name.startswith('explicit-bottom9-snow-') and ('-native-controls-' in path.name or '-prior-' in path.name):tree(path,'profiles/'+path.name)
  elif path.is_file() and path.name.lower().startswith(('explicit_bottom9_snow','explicit-bottom9-snow')):
   # The period archive already retains older observations byte-for-byte.
   key='observations/'+path.name
   if key not in base_names:files[key]=path
 with ExitStack() as stack:
  base=Archive(ROOT/'integration/f-ci/nomacro-complete01','EXPLICIT_BOTTOM9_SNOW_WINDOWS_RAW_V1',stack);extra=committed_sources(epochs);extra={k:v for k,v in extra.items() if not(k.startswith('committed-source/blobs/') and k in base.names)}
  extra['BASE_SOURCE_ARCHIVE_V1.json']=(json.dumps(dict(archive=base.record['archive'],sha256=base.record['sha256'],missing_unchanged_source_blobs_are_stored_once_in_base=True),indent=2)+'\n').encode()
 extra['COMPILED_PROJECTION_V1.json']=(json.dumps(projection,indent=2)+'\n').encode();extra['actual-sealer.py']=Path(__file__).read_bytes()
 seal(staging/'EXPLICIT_BOTTOM9_SNOW_PRIOR_CONTROLS_RAW_V1.zip','EXPLICIT_BOTTOM9_SNOW_PRIOR_CONTROLS_RAW_V1',files,extra,dict(status='ACTUAL_SNOW9_PRIOR_SNOW_AND_PAIRED9_COMPILED_POSTIMAGES_AND100_WINDOWS_NATIVE_REFUSALS_PRESERVED_NOT_ADMITTED',composition_core=CORE,actual_compile_only_closures=10,prior_unchanged_Snow_contexts=4,prior_unchanged_paired9_contexts=2,actual_compiled_native_refusals=100,actual_positive_native_startups=4,accepted_native_control_model_days=0,prior_full_model_periods_replayed=0,canonical_admission=False))


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--staging',type=Path,required=True);a=p.parse_args();preserve(a.evidence,a.staging)
