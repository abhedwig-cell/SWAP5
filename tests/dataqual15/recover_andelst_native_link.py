"""Recover this work unit's successful native compiles after Windows fsync failure.

Never execute or label the failed link as built. Recompile both codec and caller
in a new directory; retain and hash the earlier immutable objects and logs.
"""
import argparse,hashlib,json,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
BASE='1a784a27a'
CHANGED={'app/solute_column/macro_water_restart.f90'}
REBUILD=CHANGED|{'app/solute_project/main_water.f90'}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--failed-build',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 old=a.failed_build.resolve();out=a.output.resolve();out.mkdir()
 before=json.loads((old/'EVENTS.json').read_text());assert before[-1]['label']=='link'and before[-1]['returncode']==1
 assert b"undefined reference to `fsync'"in(old/f'{len(before)-1}.stderr').read_bytes()
 assert all(e['returncode']==0 for e in before[:-1])
 changed=set(subprocess.check_output(['git','diff','--name-only',BASE,'HEAD','--','src','app'],cwd=ROOT,text=True).splitlines())
 assert changed==CHANGED and not subprocess.check_output(['git','diff','HEAD','--','src','app'],cwd=ROOT)
 for path in old.glob('*.mod'):shutil.copyfile(path,out/path.name)
 events=[];sources={};objects=[];reused={};flags=None;fc=None
 def run(command):
  start=time.monotonic();r=subprocess.run(list(map(str,command)),cwd=out,capture_output=True)
  i=len(events);(out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr)
  events.append(dict(command=list(map(str,command)),returncode=r.returncode,seconds=time.monotonic()-start))
  (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,r.stderr
 for e in before:
  if e['label']!='compile':continue
  command=e['command'];source=Path(command[-3]);obj=Path(command[-1]);assert command[-4]=='-c'and command[-2]=='-o'and obj.is_file()
  relative=source.relative_to(ROOT).as_posix()if source.is_relative_to(ROOT)else None
  if relative:
   expected=subprocess.check_output(['git','show',BASE+':'+relative],cwd=ROOT)
   if relative not in CHANGED:assert source.read_bytes().replace(b'\r\n',b'\n')==expected
  else:assert source==old/'legacy_swp_original.f90'
  sources[str(source)]=sha(source)
  flags=[f for f in command[1:-4]if not f.startswith(('-I','-J'))]+['-I'+str(out),'-J'+str(out)];fc=command[0]
  if relative in REBUILD:
   obj=out/obj.name;run([fc,*flags,'-c',source,'-o',obj])
  else:reused[str(obj)]=sha(obj)
  objects.append(obj)
 pub=before[-2];assert pub['label']=='compile-publisher';publication=Path(pub['command'][-3]);pubobj=Path(pub['command'][-1]);reused[str(pubobj)]=sha(pubobj)
 library=Path(before[-1]['command'][-3]);assert library.suffix=='.a'
 exe=out/'swap5_hupsel_germination.exe'
 run([fc,'-fopenmp','-Wl,--stack,16777216',*objects,pubobj,library,'-o',exe])
 assert all(sha(Path(n))==pin for n,pin in reused.items())
 record=dict(status='BUILT',candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  compiler=subprocess.check_output([fc,'--version'],text=True).splitlines()[0],flags=flags,
  provider_count=len(objects),source_sha256=sources,object_sha256={str(o):sha(o)for o in objects},
  executable_sha256=sha(exe),ttutil_archive=str(library),archive_sha256=sha(library),
  publication_provider=dict(source=str(publication),source_sha256=sha(publication),object=str(pubobj),object_sha256=sha(pubobj)),
  recovery=dict(compiled_candidate=BASE,failed_events_sha256=sha(old/'EVENTS.json'),failed_link_retained=str(old),
   rebuilt=sorted(REBUILD),reused_artifacts_sha256=reused),events=events)
 (out/'BUILD.json').write_text(json.dumps(record,indent=2)+'\n');print('NATIVE_LINK_RECOVERED',len(objects),'providers; codec and caller recompiled')

if __name__=='__main__':main()
