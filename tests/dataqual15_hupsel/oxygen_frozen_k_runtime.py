"""Coherent private frozen-K discrimination; no production source mutation."""
import argparse,json,subprocess,time
from pathlib import Path
import micro_pressure_runtime as runtime
from micro_pressure_probe import OLD,NEW,PROCESS
ROOT=runtime.ROOT;sha=runtime.sha
BACKEND='src/runtime/mod_fmr_serialized_reference_backend.f90'

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--parent',type=Path,required=True)
 p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);a=p.parse_args()
 parent=a.parent.resolve();out=a.output.resolve();out.mkdir();fc=a.compiler.resolve();build=out/'build-O2';build.mkdir()
 prior=json.loads((parent/'build-O2/BUILD.json').read_text());record=prior['baseline']
 assert all(sha(Path(n))==h for n,h in prior['source_sha256'].items())
 assert all(sha(Path(n))==h for n,h in record['source_sha256'].items())
 assert all(sha(Path(n))==h for n,h in record['object_sha256'].items())
 assert subprocess.check_output([str(fc),'--version'],text=True).splitlines()[0]==record['compiler']
 provider=record['publication_provider'];assert sha(Path(provider['object']))==provider['object_sha256']
 assert sha(Path(record['ttutil_archive']))==record['archive_sha256']
 original=(ROOT/PROCESS).read_text();assert original.count(OLD)==1
 backend=(ROOT/BACKEND).read_text();old='    request%numerical%consistent_provider_conductivity=self%weather_surface_active\n'
 new='    request%numerical%consistent_provider_conductivity=.false. ! isolated frozen-K control\n';assert backend.count(old)==1
 patches={PROCESS:original.replace(OLD,NEW),BACKEND:backend.replace(old,new)}
 assert patches[PROCESS].replace(NEW,OLD)==original and patches[BACKEND].replace(new,old)==backend
 flags=[v for v in record['flags'] if not v.startswith(('-I','-J'))]+['-I'+str(build),'-J'+str(build)]
 objects=[];sources={};events=[]
 def run(cmd):
  start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=build,capture_output=True,timeout=240);i=len(events)
  (build/f'{i}.stdout').write_bytes(r.stdout);(build/f'{i}.stderr').write_bytes(r.stderr)
  events.append(dict(command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-start))
  (build/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,r.stderr
 for i,name in enumerate(record['source_sha256']):
  path=Path(name);relative=path.relative_to(ROOT).as_posix() if path.is_relative_to(ROOT) else None
  if relative in patches:
   actual=build/path.name;actual.write_text(patches[relative],encoding='utf-8',newline='\n')
  else:actual=path
  obj=build/f'{i}.o';run([fc,*flags,'-c',actual,'-o',obj]);objects.append(obj);sources[str(actual)]=sha(actual)
 assert len(objects)==236
 exe=build/'frozen-k.exe';args=['-fopenmp','-Wl,--stack,16777216',*map(str,objects),provider['object'],record['ttutil_archive'],'-o',str(exe)]
 response=build/'link.args';response.write_text('\n'.join('"'+v.replace('\\','/')+'"' for v in args)+'\n');run([fc,'@'+str(response)])
 (build/'BUILD.json').write_text(json.dumps(dict(baseline=record,source_sha256=sources,compiled_objects_sha256={x.name:sha(x) for x in objects},complete_module_closure_rebuilt=True,interventions=list(patches),executable_sha256=sha(exe)),indent=2)+'\n')
 try:runtime.execute(exe,parent/'full-O2',out/'prefix-O2',584,capture=[494,524,537,566,583,584])
 except Exception as e:
  (out/'FAILED.json').write_text(json.dumps(dict(error=str(e),production_admission=False),indent=2)+'\n');raise
 (out/'COMPLETE.json').write_text(json.dumps(dict(fresh_original_input_prefix=584,production_admission=False),indent=2)+'\n')

if __name__=='__main__':main()
