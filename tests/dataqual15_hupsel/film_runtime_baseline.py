"""Resume only completed clean native compilation after Windows long-argv failure.

The immutable ordinary producer is not edited; no source/object is omitted.
"""
import argparse,json,os,subprocess,time
from pathlib import Path
from film_runtime import ROOT,sha

def resume(out,compiler):
 assert os.name=='nt'and not(out/'BUILD.json').exists()
 events=json.loads((out/'EVENTS.json').read_text());assert all(e['returncode']==0 for e in events)
 compiles=[e for e in events if e['label']=='compile'];assert len(compiles)==236
 commands=[e['command']for e in compiles];flags=commands[0][1:commands[0].index('-c')]
 assert all(cmd[0]==str(compiler)and cmd[1:cmd.index('-c')]==flags for cmd in commands)
 sources={};objects=[]
 for i,cmd in enumerate(commands):
  source=Path(cmd[cmd.index('-c')+1]);obj=Path(cmd[-1]);assert cmd[-2]=='-o'and obj==out/f'{i}.o'and obj.is_file()
  assert source.is_file();sources[str(source)]=sha(source);objects.append(obj)
 assert len(sources)==236 and Path(list(sources)[-1])==ROOT/'app/solute_project/main.f90'
 assert len([e for e in events if e['label']=='compile-publisher'])==1
 pub=events[-1];assert pub['label']=='compile-publisher';publisher=ROOT/'app/support/restart_publish.c';pubobj=out/'restart_publish.o'
 assert Path(pub['command'][-1])==pubobj and pubobj.is_file()
 archive=out/'libttutil.a';assert archive.is_file();oldraw=(out/'EVENTS.json').read_bytes();(out/'ORIGINAL_EVENTS.json').write_bytes(oldraw)
 def run(cmd,label):
  start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=300);i=len(events)
  (out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr)
  events.append(dict(command=list(map(str,cmd)),label=label,returncode=r.returncode,seconds=time.monotonic()-start));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,r.stderr.decode(errors='replace')[-2000:]
 exe=out/'swap5_hupsel_germination.exe';args=['-fopenmp','-Wl,--stack,16777216',*map(str,objects),str(pubobj),str(archive),'-o',str(exe)]
 response=out/'link.args';response.write_text('\n'.join('"'+x.replace('\\','/')+'"'for x in args)+'\n',encoding='utf-8');run([compiler,'@'+str(response)],'link-response-after-WinError206')
 reader=out/'read_fallow';run([compiler,*flags,ROOT/'src/process/mod_pmdirect_swetr0_process.f90',ROOT/'app/solute_project/read_fallow_project.f90',archive,'-o',reader],'reader')
 cc=compiler.with_name('gcc.exe')
 result=dict(status='BUILT',candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),compiler=subprocess.check_output([compiler,'--version'],text=True).splitlines()[0],
  build_mode='clean-source',reuse_candidate=None,ttutil_archive=str(archive),flags=flags,source_sha256=sources,object_sha256={str(p):sha(p)for p in objects},
  executable_sha256=sha(exe),provider_count=236,changed=list(sources),archive_sha256=sha(archive),publication_provider=dict(source=str(publisher),source_sha256=sha(publisher),object=str(pubobj),object_sha256=sha(pubobj),compiler=subprocess.check_output([cc,'--version'],text=True).splitlines()[0]),
  clean_compile_recovery=dict(reason='WinError206 before unchanged producer link process creation; original completed236 clean compiles retained',original_events_sha256=__import__('hashlib').sha256(oldraw).hexdigest(),original_producer_sha256=sha(ROOT/'tests/dataqual15_hupsel/build_and_run.py'),response_file_sha256=sha(response)))
 (out/'BUILD.json').write_text(json.dumps(result,indent=2)+'\n');print('ALL236_ACTUAL_CLEAN_COMPILES_RETAINED_RESPONSE_LINK_PASS')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--baseline',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);a=p.parse_args();resume(a.baseline.resolve(),a.compiler.resolve())
