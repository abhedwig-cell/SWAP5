"""One-provider ABI-preserving rebuild with exact predecessor object reuse."""
import argparse,copy,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();p=argparse.ArgumentParser();p.add_argument('--base',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();base=a.base.resolve();out=a.output.resolve();out.mkdir();(out/'column').mkdir();old=json.loads((base/'bundle.json').read_text());m=json.loads((base/'column/build-complete.json').read_text());before=copy.deepcopy(m);changed=[p for p,h in m['input_sha256'].items()if sha(ROOT/p)!=h];assert changed==['src/solver/mod_b110_default_mvg_provider.f90'],changed
for path,h in m['reused_artifact_sha256'].items():assert sha(Path(path))==h,path
flags=[f for f in m['flags']if not f.startswith('-J')]+['-J'+str(out/'column')];fc=m['compiler_command'];events=[]
def run(cmd,label):
 start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True)
 for k in ['stdout','stderr']:(out/(label+'.'+k)).write_bytes(getattr(r,k))
 e=dict(category=label,command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-start);events.append(e);assert r.returncode==0,r.stderr.decode()[-2500:];return e
src=changed[0];obj=out/'column/provider.o';e=run(fc+flags+['-c',ROOT/src,'-o',obj],'provider_compile');physical=m['source_build'];index=next(i for i,e in enumerate(physical['events'])if str(ROOT/src)in e['command']);previous=physical['events'][index]['command'][-1];physical['events'][index]=dict(e,category='compile');physical['input_sha256'][src]=sha(ROOT/src)
for mod in ['mod_b110_default_mvg_provider.mod','mod_b111_analytical_hydraulic_provider.mod']:
 original=next(Path(f[2:])/mod for f in flags if f.startswith('-I')and(Path(f[2:])/mod).exists());assert sha(out/'column'/mod)==sha(original),mod
cmd=next(e['command']for e in m['events']if e['category']=='project_compile_link');cmd=[str(obj)if x==previous else x for x in cmd];exe=out/'column/swap5_solute_project';cmd[cmd.index('-o')+1]=str(exe);e=run(cmd,'project_compile_link');m.update(candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256={**m['input_sha256'],src:sha(ROOT/src)},events=[e],executable_sha256=sha(exe),reused_provider_objects=192,storage_repair_events=events,reused_source_build=before,provider_module_interface_exact=True);m['reused_artifact_sha256'].pop(previous,None)
(out/'column/build-complete.json').write_text(json.dumps(m,indent=2)+'\n');old['exe']=str(exe);old['executable_sha256']={str(Path(old[k])):sha(Path(old[k]))for k in ['project_reader','crop_reader','root_reader','exe']};old['storage_repair_build']=m;(out/'bundle.json').write_text(json.dumps(old,indent=2)+'\n');print(json.dumps(dict(status='BUILT',events=events,reused_provider_objects=192,module_interface_exact=True)))
