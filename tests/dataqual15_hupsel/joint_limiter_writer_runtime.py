"""Execute actual deployed reader source using qualified unchanged providers."""
import argparse,functools,io,json,lzma,os,re,shutil,struct,subprocess,tarfile,zlib
from pathlib import Path,PurePosixPath
import joint_production as g
import joint_limiter_writer as writer
import joint_writer_probe as publication_probe
import joint_logical as native
from joint_current_owner import driver as occupied_driver,inputs as occupied_inputs
STORE=g.ROOT/'integration/dataqual15_hupsel'

def local(path,root):
 path=path.replace('\\','/');root=root.replace('\\','/').rstrip('/')+'/'
 assert path.startswith(root);return path[len(root):]
def driver_sources(files):
 meta=json.loads(files['PROVENANCE.json']);events=json.loads(files['baseline/EVENTS.json']);result={}
 for e in events:
  if e['label']!='driver':continue
  path=e['command'][e['command'].index('-c')+1];name=Path(e['command'][e['command'].index('-o')+1].replace('\\','/')).stem;result[name]=files[meta['sources'][path]['snapshot']]
 assert set(result)=={'age','mineral','reactive_n','reactive_original'};return result
def execute(out,platform,opt,fc):
 trees=writer.guard();out.mkdir(parents=True);providers=out/'providers';files=writer.cold(providers,platform,opt,fc)
 for name,raw in files.items():
  relative=PurePosixPath(name);assert not relative.is_absolute()and'..'not in relative.parts
  dest=providers/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw)
 baseline=json.loads(files['baseline/BUILD.json']);meta=json.loads(files['PROVENANCE.json']);assert baseline['provider_count']==335
 compiler=subprocess.check_output([fc,'--version'],text=True).splitlines()[0];assert compiler==baseline['compiler']
 build=out/'build';build.mkdir();flags=[f for f in baseline['flags']if not f.startswith(('-I','-J'))]+['-I'+str(build),'-I'+str(providers/'baseline'),'-I'+str(providers/'fixture'),'-I'+str(g.ROOT/'tests/nut-reactive'),'-J'+str(build)]
 events=[];bindings=[];snapshots={};source_keys=list(baseline['sources_sha256']);object_keys=list(baseline['objects_sha256']);assert len(source_keys)==len(object_keys)==335
 for name in g.NAMES:
  path=writer.DIRECTORY/Path(g.SOURCES[name]).name;snap=out/'sources'/path.name;snap.parent.mkdir(exist_ok=True);snap.write_bytes(path.read_bytes());snapshots[name]=dict(path=snap.relative_to(out).as_posix(),sha256=g.sha(snap.read_bytes()))
 for i,(source_key,object_key)in enumerate(zip(source_keys,object_keys)):
  relative=meta['sources'][source_key]['path'];name=next((n for n,p in g.SOURCES.items()if p==relative),None);old=local(object_key,meta['root']);obj=providers/old
  assert g.sha(obj.read_bytes())==baseline['objects_sha256'][object_key]
  if name:
   obj=build/('%03d.o'%i);native.prior.run([fc,*flags,'-c',writer.DIRECTORY/Path(g.SOURCES[name]).name,'-o',obj],out,events,'provider')
   mod='mod_'+name+'_joint_restart_file.mod';assert(build/mod).read_bytes()==files['candidate/'+mod],'exact compiled public/private module interface'
  bindings.append(dict(source_key=source_key,input_object=old,object=str(obj),sha256=g.sha(obj.read_bytes()),replacement=name))
 cc=subprocess.check_output([fc,'-print-prog-name=gcc'],text=True).strip()
 c=out/'publisher.c';c.write_bytes((g.ROOT/'app/support/restart_publish.c').read_bytes());real=build/'publisher.o'
 shim=out/'shim.c';shim.write_text(publication_probe.publication.shim_source());shim_obj=build/'shim.o'
 native.prior.run([cc,'-'+opt,'-std=c11','-DSWAP5_RESTART_TESTING','-Dswap5_restart_publish=swap5_restart_publish_real','-c',c,'-o',real],out,events,'publisher')
 native.prior.run([cc,'-'+opt,'-std=c11','-c',shim,'-o',shim_obj],out,events,'shim')
 objects=[b['object']for b in bindings]+[str(real),str(shim_obj)];sources=driver_sources(files);executables={}
 def compile_driver(name,source,label):
  path=out/(label+'-sources')/(name+'.f90');path.parent.mkdir(exist_ok=True);path.write_bytes(source);obj=build/(label+'-'+name+'.o');exe=build/(label+'-'+name+('.exe'if os.name=='nt'else'-driver'))
  native.prior.run([fc,*flags,'-c',path,'-o',obj],out,events,label+'-driver')
  args=flags+(['-Wl,--stack,16777216']if os.name=='nt'else[])+[str(obj),*objects,'-o',str(exe)];rsp=build/(label+'-'+name+'.args');rsp.write_text('\n'.join('"'+a.replace('\\','/')+'"'for a in args)+'\n');native.prior.run([fc,'@'+str(rsp)],out,events,label+'-link')
  executables[label+'-'+name]=dict(source=path.relative_to(out).as_posix(),object=obj.relative_to(out).as_posix(),executable=exe.relative_to(out).as_posix(),response=rsp.relative_to(out).as_posix());return exe
 exes={n:compile_driver(n,s,'native')for n,s in sources.items()}
 measured=native.measure(out,exes,events,'candidate');native_events=len(events)
 own_exes={n:compile_driver(n,occupied_driver(sources[n],n),'owner')for n in g.NAMES}
 native_files={'production/'+name+'/'+p.name:p.read_bytes()for name in g.NAMES for p in(out/name).iterdir()if p.is_file()};rows=[]
 for name,seed,probes in occupied_inputs(native_files,'production'):
  seed_path=out/seed.removeprefix('production/')
  for probe,raw in probes.items():
   for occupancy in ('both','water','chemical'):
    key=f'occupied-{name}-{Path(seed).name}-{probe}-{occupancy}';attack=out/(key+'.input');before=out/(key+'.before');after=out/(key+'.after')
    if raw is not None:attack.write_bytes(raw)
    cp=native.prior.run([own_exes[name],'occupied',seed_path,attack,before,after,occupancy,'plain'if seed.endswith('.base')else'history'],out,events,'occupied')
    assert b'OCCUPIED_ATOMIC_REFUSAL=PASS'in cp.stdout and before.read_bytes()==after.read_bytes()==native_files[seed]
    rows.append(dict(codec=name,seed=seed,probe=probe,occupancy=occupancy,key=key,event=len(events)-1))
 assert len(rows)==120;assert trees==writer.guard()
 publication_exes={n:compile_driver(n,publication_probe.driver(sources[n],n),'publication')for n in g.NAMES}
 publication=publication_probe.measure(out,publication_exes,events)
 result=dict(status='PRIVATE_THREE_WRITER_PUBLICATION_PASS',publication=publication,baseline=writer.BASE,head=g.git('rev-parse','HEAD'),production_trees=trees,repo_root=str(g.ROOT),root=str(out),platform=platform,optimization=opt,compiler=compiler,flags=flags,source_snapshots=snapshots,bindings=bindings,executables=executables,native=measured,native_events=native_events,occupied=rows,runner_sha256=g.sha(g.normal(Path(__file__).read_bytes())),production_admission=False,whole_scientific_admission=False)
 (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 import joint_limiter_writer_evidence as evidence
 evidence.pack(out,'JOINT_LIMITER_WRITER_'+platform+'_'+opt+'_20261106')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--platform',choices=('WINDOWS','POSIX'),required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--compiler',default=shutil.which('gfortran'));a=p.parse_args();os.environ['OMP_NUM_THREADS']='1';execute(a.output.resolve(),a.platform,a.optimization,str(Path(a.compiler).resolve()))
