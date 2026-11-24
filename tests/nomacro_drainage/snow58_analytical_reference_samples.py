"""Observe original constitutive functions at every actual accepted pressure.

This is a component observation, with no physical model period. The only
numerical source correction is the already admitted model7 capacity expression.
"""
import argparse, hashlib, json, os, subprocess, sys, time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tests/nomacro_drainage')]
from snow58_analytical_source import complete_inverse,git
from analytical_hydraulic_archives import SHA


def build(reference,folder,opt,output):
 import user_prepare
 from daily_host import NO_MACRO_FP_FLAGS
 user_prepare.validate(reference);ref=reference/'build';objects=ref/'swap-obj';folder.mkdir(exist_ok=True)
 flags=['gfortran','-'+opt,'-ffree-line-length-none','-fcheck=all','-fimplicit-none','-finit-local-zero','-ffpe-trap=invalid,zero,overflow',*NO_MACRO_FP_FLAGS,'-I'+str(folder),'-I'+str(objects),'-I'+str(ref/'ttutil-obj'),'-J'+str(folder)]
 q=dict(source=git('rev-parse','HEAD').decode().strip(),optimization=opt,compiler=[],build_root=str(folder),original_provider_files={},original_rebuilt_sources={})
 def run(command):return subprocess.run(command,cwd=folder,capture_output=True,text=True,timeout=90)
 def compile(command):
  start=time.perf_counter();r=run(command);q['compiler'].append(dict(command=command,returncode=r.returncode,seconds=time.perf_counter()-start,stdout=r.stdout,stderr=r.stderr));r.check_returncode()
 def symbols(paths,flag):
  r=run(['nm','-g',flag,'--format=posix',*map(str,paths)]);r.check_returncode();table={};current=None
  for line in r.stdout.splitlines():
   if line.endswith(':'):current=Path(line[:-1]);table[current]=set()
   elif current is not None and line.strip():table[current].add(line.split()[0])
  assert set(table)==set(paths);return table
 files=sorted(p for p in objects.glob('*.o') if p.name!='swap_main.o');defined=symbols(files,'--defined-only');undefined=symbols(files,'--undefined-only');lookup={}
 for path,values in defined.items():
  for value in values:lookup.setdefault(value,path)
 affected={}
 for name in ('WC_K_models_04_11','MOD_MvG_functions'):
  source=ref/'swap-selected'/(name+'.f90');raw=source.read_bytes();q['original_provider_files']['build/swap-selected/'+source.name]=SHA(raw)
  if name=='WC_K_models_04_11':
   text=raw.decode('cp1252').replace('\r\n','\n');assert SHA(text.encode('cp1252'))=='1d40c5ea7aa1b2344409275603a3a603a52355fe3928ad7af24eb3bbbf379dcc'
   before='   C_MvG_2_s = (WCs-WCr)*(Omega1*C1(h)/(1.0d0-Gam01) + Omega2*C2(h)/(1.0d0-Gam02))'
   after='   C_MvG_2_s = (WCs-WCr)*(Omega1*C1(h) + Omega2*C2(h))/(1.0d0-Omega1*Gam01-Omega2*Gam02)'
   assert text.count(before)==1;raw=text.replace(before,after,1).encode('cp1252');assert SHA(raw)=='7910cd29c045037778bfffdc7e40a77802d70fb477e0afa78be426776bd26e27'
  target=folder/source.name;target.write_bytes(raw);obj=folder/(name+'.o');compile([*flags,'-c',str(target),'-o',str(obj)]);affected[objects/(name+'.o')]=obj;q['original_rebuilt_sources'][source.name]=SHA(raw);(output/source.name).write_bytes(raw)
 driver=ROOT/'tests/nomacro_drainage/explicit_bottom9_snow_analytical_reference_probe.f90';q['driver_sha256']=SHA(driver.read_bytes());obj=folder/'driver.o';compile([*flags,'-c',str(driver),'-o',str(obj)])
 selected={lookup[symbol] for values in symbols([obj,*affected.values()],'--undefined-only').values() for symbol in values if symbol in lookup}
 while True:
  before=set(selected)
  for path in before:selected.update(lookup[symbol] for symbol in undefined[path] if symbol in lookup)
  if before==selected:break
 linked=[affected.get(path,path) for path in sorted(selected)]
 for path in affected.values():
  if path not in linked:linked.append(path)
 q['original_provider_files'].update({'build/swap-obj/'+p.name:SHA(p.read_bytes()) for p in selected});q['original_provider_files']['build/ttutil-obj/libttutil.a']=SHA((ref/'ttutil-obj/libttutil.a').read_bytes())
 exe=folder/('actual-sampled-hydraulic'+('.exe' if os.name=='nt' else ''));compile([*flags,str(obj),*map(str,linked),str(ref/'ttutil-obj/libttutil.a'),'-o',str(exe)])
 q['executable']=exe.name;q['executable_sha256']=SHA(exe.read_bytes());q['status']='ACTUAL_ORIGINAL_SAMPLED_CONSTITUTIVE_COMPONENT_COMPILED_NO_MODEL_PERIOD';(output/driver.name).write_bytes(driver.read_bytes());(output/exe.name).write_bytes(exe.read_bytes());(output/'COMPONENT.json').write_text(json.dumps(q,indent=2)+'\n');return q


def main():
 p=argparse.ArgumentParser()
 for name in ('profile','reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--build-root',type=Path);p.add_argument('--reuse-component',type=Path);a=p.parse_args();complete_inverse();assert bool(a.build_root)!=bool(a.reuse_component);a.output.mkdir();prior=json.loads((a.profile/'RESULT.json').read_text());assert git('cat-file','-t',prior['source']).strip()==b'commit' and len(set(prior['layer_models']))==1
 model=prior['layer_models'][0];rows=[json.loads(line) for line in (a.profile/'trajectory/daily.jsonl').read_text().splitlines()];assert len(rows)==35
 heads=sorted({-10.,*(h for row in rows for h in row['pressure_head_cm'])});text=str(len(heads))+'\n'+'\n'.join(repr(h) for h in heads)+'\n';sample=a.output/'actual-heads.txt';sample.write_text(text);assert [float(x) for x in text.splitlines()[1:]]==heads
 component=build(a.reference_work,a.build_root,prior['optimization'],a.output) if a.build_root else json.loads((a.reuse_component/'COMPONENT.json').read_text())
 assert component['status']=='ACTUAL_ORIGINAL_SAMPLED_CONSTITUTIVE_COMPONENT_COMPILED_NO_MODEL_PERIOD' and component['optimization']==prior['optimization'] and git('cat-file','-t',component['source']).strip()==b'commit'
 assert component['driver_sha256']==SHA((ROOT/'tests/nomacro_drainage/explicit_bottom9_snow_analytical_reference_probe.f90').read_bytes())
 for name,digest in component['original_provider_files'].items():assert SHA((a.reference_work/name).read_bytes())==digest
 executable=Path(component['build_root'])/component['executable'];assert SHA(executable.read_bytes())==component['executable_sha256']
 start=time.perf_counter();r=subprocess.run([str(executable),str(model),str(sample),str(Path(prior['input_root'])/'swap.swp')],cwd=a.output,capture_output=True,text=True,timeout=90);(a.output/'sample.stdout').write_text(r.stdout);(a.output/'sample.stderr').write_text(r.stderr);r.check_returncode();assert not r.stderr
 observed={}
 for line in r.stdout.splitlines():
  if not line.startswith('ACTUAL_ORIGINAL_HYDRAULIC_SAMPLE '):continue
  words=line.split();assert len(words)==14;actual_model,soil,index=map(int,words[1:4]);values=list(map(float,words[4:]));assert actual_model==model and soil in (1,2) and 1<=index<=len(heads) and values[0]==heads[index-1] and (soil,index) not in observed;observed[soil,index]=values
 assert len(observed)==2*len(heads)
 # Actual original soil layers are observed separately; equality is not assumed.
 q=dict(status='ACTUAL_ORIGINAL_CONSTITUTIVE_FUNCTIONS_OBSERVED_AT_ALL_ACCEPTED_NODE_PRESSURES_NO_MODEL_PERIOD',source=git('rev-parse','HEAD').decode().strip(),profile=str(a.profile),profile_RESULT_sha256=SHA((a.profile/'RESULT.json').read_bytes()),daily_sha256=SHA((a.profile/'trajectory/daily.jsonl').read_bytes()),model=model,optimization=prior['optimization'],heads=heads,component=component,component_profile=str(a.reuse_component or a.output),component_reused=bool(a.reuse_component),stdout_sha256=SHA((a.output/'sample.stdout').read_bytes()),head_input_sha256=SHA(sample.read_bytes()),actual_soil_input_sha256=SHA((Path(prior['input_root'])/'swap.swp').read_bytes()),observations_by_layer={str(soil):[observed[soil,i] for i in range(1,len(heads)+1)] for soil in (1,2)},seconds=time.perf_counter()-start,model_periods=0,canonical_admission=False)
 (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'],model,len(heads),flush=True)


if __name__=='__main__':main()
