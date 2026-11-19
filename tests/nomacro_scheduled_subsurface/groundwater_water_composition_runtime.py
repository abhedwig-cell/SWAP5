"""Target only the dispatch/native seams of the actual canonical composition."""
from pathlib import Path,PurePosixPath
import argparse,json,subprocess,sys,time,zipfile
import groundwater_water_runtime as prior
from original_output_files import compare
from groundwater_water_output import metadata

m=prior.m;ROOT=prior.ROOT


def main():
 p=argparse.ArgumentParser()
 for name in ('reference-work','output','prior-root'):p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True)
 a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),optimization=a.optimization,platform=a.platform,contexts={},scope='Two-day shared dispatch/native composition seams only; full qualified periods inherited by literal source/provider proof, no performance experiments.')
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
 if not (a.reference_work/'PREPARED.json').exists():m.user_prepare.prepare(a.reference_work)
 m.user_prepare.validate(a.reference_work)
 salt_proof=ROOT/'integration/f-ci/saltfarm-guard-cost05';salt_record=json.loads((salt_proof/'COMPOSITION_QUALIFICATION.json').read_text())['archives'][a.platform];salt=zipfile.ZipFile(salt_proof/salt_record['archive'])
 require=lambda value,message:None if value else (_ for _ in ()).throw(ValueError(message))
 save()
 try:
  if a.platform=='Windows':previous=json.loads((a.prior_root/'short-RESULT.json').read_text())
  else:previous=json.loads((a.prior_root/'RESULT.json').read_text());producer=PurePosixPath(next(iter(previous['cases'].values()))['short_root']).parent
  for name in ('explicit-history-step','implicit-ordinary-step','named-saltfarm'):
   out=a.output/name;out.mkdir();build=out/'build'
   if name!='named-saltfarm':
    item=previous['cases'][name];report=item['report'] if a.platform=='Windows' else item['short']
    if a.platform=='Windows':oldroot=Path(item['root']);inputs=Path(report['input_root']);oldbuild=Path(report['build_root'])
    else:
     relative=lambda path:Path(PurePosixPath(path).relative_to(producer).as_posix());oldroot=a.prior_root/relative(item['short_root']);inputs=a.prior_root/relative(report['input_root']);oldbuild=a.prior_root/relative(report['build_root'])
    project=m.e.load(inputs,original_output=True);base=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work)];old=json.loads((oldbuild/'BUILD.json').read_text());gold=m.rows(oldroot/'trajectory');original_sources={path.name:path.read_bytes() for path in oldbuild.glob('*.f90')}
   else:
    project=m.h.SALTFARM;base=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--no-macro-release','--reference-work',str(a.reference_work)];old=json.loads(salt.read('qualified-'+a.optimization+'/BUILD.json'));gold=[json.loads(line) for line in salt.read('accept-'+a.optimization+'/full/daily.jsonl').splitlines()];prefix='qualified-'+a.optimization+'/';original_sources={path[len(prefix):]:salt.read(path) for path in salt.namelist() if path.startswith(prefix) and '/' not in path[len(prefix):] and path.endswith('.f90')}
   def call(label,extra):
    command=[*base,*map(str,extra)];start=time.monotonic();result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180);(out/(label+'.stdout')).write_text(result.stdout,encoding='utf8');(out/(label+'.stderr')).write_text(result.stderr,encoding='utf8');result.check_returncode();return dict(command=command,returncode=result.returncode,seconds=time.monotonic()-start)
   actual={};q['contexts'][name]=actual;save();actual['build']=call('build',['--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',build]);save();current=json.loads((build/'BUILD.json').read_text());m.validate_bundle(build,a.reference_work,project)
   generated={path.name:path.read_bytes() for path in build.glob('*.f90')};require(generated==original_sources,'Actual composed Fortran providers differ: '+name);require(current['inputs']==old['inputs'],'Actual original input bytes differ: '+name);require(current['identity']['kernel_sources']==old['identity']['kernel_sources'],'Actual original kernel bytes differ: '+name)
   actual['generated_fortran_sha256']={path:m.sha(build/path) for path in sorted(generated)};actual['build_sha256']=m.sha(build/'BUILD.json');actual['direct_selected']=current['identity'].get('direct_day_kernel') is not None;require(actual['direct_selected']==(name=='named-saltfarm'),'Direct selection crossed project authority')
   actual['warm']=call('warm',['--build-bundle',build,'--days',2,'--checkpoint-at',1,'--output',out/'warm']);save();origin=out/'warm/accepted-column-1-day-1.zip';origin_hash=m.sha(origin);actual['cold']=call('cold',['--build-bundle',build,'--days',2,'--checkpoint-at',2,'--restart',origin,'--restart-day',1,'--output',out/'cold']);save();warm=m.rows(out/'warm');cold=m.rows(out/'cold');m.check(warm);m.check(cold);require(m.physical(warm)==m.physical(gold[:2]) and m.physical(cold)==m.physical(warm[1:2]),'Actual composed physical projection differs: '+name)
   # Public warm publishes day1 only. An independent actual warm endpoint
   # publishes day2 for complete warm/cold payload comparison.
   actual['warm_endpoint']=call('warm-endpoint',['--build-bundle',build,'--days',2,'--checkpoint-at',2,'--output',out/'warm-endpoint']);save()
   require(m.physical(m.rows(out/'warm-endpoint'))==m.physical(warm),'Independent current warm differs')
   with zipfile.ZipFile(out/'cold/accepted-column-1-day-2.zip') as x,zipfile.ZipFile(out/'warm-endpoint/accepted-column-1-day-2.zip') as y:
    require(all(x.read(member)==y.read(member) for member in ('result.end','macro.bin')),'Complete composed warm/cold native differs')
   if name!='named-saltfarm':
    with zipfile.ZipFile(out/'cold/accepted-column-1-day-2.zip') as x,zipfile.ZipFile(oldroot/'trajectory/accepted-column-1-day-2.zip') as y:require(all(x.read(member)==y.read(member) for member in ('result.end','macro.bin')),'Actual full-producer groundwater complete native differs')
    actual['original_output']=compare(out/'warm/original',out/'cold/original',metadata(project),1,2,project.start_date)
   require(m.sha(origin)==origin_hash,'Actual composed source origin mutated');actual.update(status='ACTUAL_COMPOSED_DISPATCH_PHYSICAL_NATIVE_REPLAY_PASS',physical_first_two_days_exact=True,complete_native_replay_exact=True,origin_unchanged=True);save()
  q['status']='THREE_ACTUAL_COMPOSED_GROUNDWATER_AND_NAMED_SALTFARM_DISPATCH_NATIVE_SEAMS_PASS';print(q['status'],flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:salt.close();save()


if __name__=='__main__':main()
