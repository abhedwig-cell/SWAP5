"""Work-unit rebuild: identical provider modules, one changed runtime body."""
import argparse,copy,hashlib,json,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];p=argparse.ArgumentParser();p.add_argument('--base',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();base=a.base.resolve();out=a.output.resolve();out.mkdir();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();b=json.loads((base/'build-complete.json').read_text());original=copy.deepcopy(b);changed=[p for p,h in b['input_sha256'].items()if sha(ROOT/p)!=h]
assert changed==['src/runtime/mod_fmr_serialized_reference_backend.f90'],changed
# Copy generated source/module/archive artifacts; all untouched object paths
# continue to reference the measured original build. Never overwrite that build.
for p in base.iterdir():
 if p.is_file()and(p.suffix in ['.mod','.a']):shutil.copy2(p,out/p.name)
for rel in b['generated_input_sha256']:
 p=out/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(base/rel,p)
flags=[f.replace(str(base),str(out))if f.startswith(('-J','-I'))else f for f in b['flags']];fc=b['compiler_command'];fresh=[]
def run(cmd,label):
 t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True)
 for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(r,stream))
 e=dict(command=list(map(str,cmd)),category=label,seconds=time.monotonic()-t,returncode=r.returncode);fresh.append(e);(out/'fresh-events.json').write_text(json.dumps(fresh,indent=2));assert not r.returncode,r.stderr.decode()[-3000:];return e
index=next(i for i,e in enumerate(b['events'])if e['category']=='compile'and str(ROOT/changed[0])in e['command']);old=b['events'][index];obj=out/Path(old['command'][-1]).name
e=run(fc+flags+['-c',ROOT/changed[0],'-o',obj],'recompile-runtime');b['events'][index]=dict(e,category='compile')
assert sha(out/'mod_fmr_serialized_reference_backend.mod')==sha(base/'mod_fmr_serialized_reference_backend.mod'),'runtime module interface changed'
objects=[e['command'][-1]for e in b['events']if e['category']=='compile'];exe=out/'swap5_solute_column';run(fc+flags+objects+[out/'libttutil.a','-o',exe],'relink-crop')
b.update(candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),flags=flags,executable_sha256=sha(exe),reused_source_build=original,fresh_events=fresh,reused_provider_objects=len(objects)-1,exact_runtime_module_interface=True)
b['input_sha256'][changed[0]]=sha(ROOT/changed[0]);assert all(sha(ROOT/p)==h for p,h in b['input_sha256'].items());(out/'build-complete.json').write_text(json.dumps(b,indent=2)+'\n')
# The standalone column is rebuilt from the same measured production objects.
col=out/'column';col.mkdir();cflags=[f for f in flags if not f.startswith('-J')]+['-J'+str(col),'-I'+str(col)]
heat=ROOT/'app/solute_column/read_swp_heat.f90';main=ROOT/'app/solute_column/main.f90';hobj=col/'heat.o';mobj=col/'main.o'
for src,target in [(heat,hobj),(main,mobj)]:run(fc+cflags+['-c',src,'-o',target],'column-'+target.stem)
providers=objects[:-1];cexe=col/'swap5_solute_column';link=run(fc+cflags+providers+[hobj,mobj,out/'libttutil.a','-o',cexe],'link')
inputs={p:h for p,h in b['input_sha256'].items()if p!='app/solute_crop/main.f90'};inputs.update({str(p.relative_to(ROOT)):sha(p)for p in [heat,main,Path(__file__)]})
c=dict(b,input_sha256=inputs,flags=cflags,events=[link],generated_input_sha256={},generated_input_root=str(out),executable_sha256=sha(cexe));(col/'build-complete.json').write_text(json.dumps(c,indent=2)+'\n');print(json.dumps(dict(status='BUILT',reused=len(providers)-1,exact_runtime_module_interface=True)))
