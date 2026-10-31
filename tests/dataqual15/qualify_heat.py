"""Real original/current heat operators on sealed Grassgrowth snapshots.

Actual hydraulic snapshots and interpolated adjacent-day water changes distinguish
heat implementation from time integration. These are operator tests, not new
historical trajectories or actual accepted-water-substep replays.
"""
import argparse,csv,hashlib,io,json,os,struct,subprocess,sys,tarfile,time
from pathlib import Path
from checkpoint_layout import layout
from original_sources import build_original
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);fc=str(a.compiler.resolve());started=time.monotonic()
 report=dict(status='IN_PROGRESS',baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),scope=__doc__,events=[],scientific_equivalence=False)
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
 def run(command,label,cwd=out,timeout=240):
  begin=time.monotonic();r=subprocess.run(list(map(str,command)),cwd=cwd,capture_output=True,timeout=timeout)
  i=len(report['events']);(out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr)
  report['events'].append(dict(label=label,command=list(map(str,command)),returncode=r.returncode,seconds=time.monotonic()-begin));save()
  assert r.returncode==0,(label,r.stderr.decode(errors='replace')[-2500:],r.stdout.decode(errors='replace')[-2500:])
  return r.stdout
 report['criteria']=dict(temperature_c=5e-10,top_heat_flux_j_cm2_day=5e-10,storage_and_boundary_j_cm2=5e-9,authority='Existing tests/fci/test_fci43_restricted_soil_temperature_independent.f90 component/dense-oracle criteria; frozen before this execution. Not the project trajectory acceptance gate.')
 (out/'CRITERIA_BEFORE_EXECUTION.json').write_text(json.dumps(report['criteria'],indent=2)+'\n',newline='\n')
 project=ROOT/'reference/swap-4.3.1/projects/2.grassgrowth';(out/'input.swp').write_bytes((project/'swap.swp').read_bytes())
 weather=list(csv.DictReader(line for line in (project/'260.met').read_text().splitlines()if line.strip()and not line.lstrip().startswith('*')));assert len(weather)==1827
 capsule=ROOT/'integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz';spec=json.loads((ROOT/'integration/dataqual15/GRASS_UNION_FULL_SPEC.json').read_text());manifest=json.loads((ROOT/'integration/dataqual15/GRASS_UNION_FULL_MANIFEST.json').read_text())
 assert sha(capsule)==manifest['evidence_sha256']
 snapshots={}
 with tarfile.open(capsule)as tar:
  for name in tar.getnames():
   if name.startswith(spec['full']+'/checkpoint')and name.endswith('.bin'):
    raw=tar.extractfile(name).read();snapshots[int(layout(raw)['clock'])]=raw
 assert len(snapshots)==24
 path=out/'heat-inputs.dat';digest={}
 with path.open('w',newline='\n')as stream:
  first=layout(next(iter(snapshots.values())));raw=next(iter(snapshots.values()));n=first['nodes'];z=struct.unpack_from('='+str(n)+'d',raw,first['header']+48);dz=struct.unpack_from('='+str(n)+'d',raw,first['header']+48+8*n);distance=[.5*dz[0]]+[.5*(dz[i-1]+dz[i])for i in range(1,n)]
  emit=lambda values:stream.write(' '.join(format(v,'.17e')for v in values)+'\n')
  count=3*sum(1+int(day+1 in snapshots)for day in snapshots);assert count==96
  stream.write(str(n)+' '+str(count)+'\n');emit(z);emit(dz);emit(distance)
  for day,raw in sorted(snapshots.items()):
   state=layout(raw);digest[str(day)]=hashlib.sha256(raw).hexdigest();pos=state['physical'];head=struct.unpack_from('='+str(n)+'d',raw,pos);theta=struct.unpack_from('='+str(n)+'d',raw,pos+8*n);temp=struct.unpack_from('='+str(n)+'d',raw,pos+16*n+16);air=.5*(float(weather[day-1]['Tmin'])+float(weather[day-1]['Tmax']))
   for kind in [0]+([1]if day+1 in snapshots else[]):
    for step in [.04,.02,.01]:
     if kind:
      following=snapshots[day+1];right=struct.unpack_from('='+str(n)+'d',following,layout(following)['physical']+8*n);end=[a+step*(b-a)for a,b in zip(theta,right)]
     else:end=theta
     stream.write(f'{day} {kind} {step:.17e} {air:.17e}\n');emit(head);emit(theta);emit(end);emit(temp)
 report.update(input_sha256=sha(path),checkpoint_sha256=digest,capsule_sha256=sha(capsule),physical_input_sha256=sha(out/'input.swp'))
 sources=[ROOT/p for p in ['src/transaction/mod_transaction_reference.f90','src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_process_hydraulic_view.f90','src/process/mod_soil_temperature_contract.f90','src/process/mod_restricted_soil_temperature.f90','app/solute_column/read_swp_heat.f90','tests/dataqual15/heat_oracle.f90']]
 report['source_sha256']={p.relative_to(ROOT).as_posix():sha(p)for p in sources};report['runs']={};save()
 for opt in ['O0','O2']:
  begin=time.monotonic();original=build_original(out/('original-'+opt),fc,opt);report['events'].append(dict(label='original-build-'+opt,seconds=time.monotonic()-begin,returncode=0,build_sha256=sha(original/'BUILD.json')));save()
  folder=out/opt;folder.mkdir();flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(folder),'-J'+str(folder),'-I'+str(original/'swobj'),'-I'+str(original/'ttobj')];objects=[]
  for i,source in enumerate(sources):
   obj=folder/f'{i}.o';run([fc,*flags,'-c',source,'-o',obj],'compile-'+opt);objects.append(obj)
  exe=folder/('heat.exe'if os.name=='nt'else'heat');link=folder/'link.args';link.write_text('\n'.join('"'+str(v).replace('\\','/')+'"'for v in [*flags,*objects,*sorted((original/'swobj').glob('*.o')),original/'ttobj/libttutil.a','-o',exe]),newline='\n');run([fc,'@'+str(link)],'link-'+opt)
  raw=run([exe,path],'native-'+opt);(folder/'stdout').write_bytes(raw);assert b'PAIRED_ORIGINAL_CURRENT_HEAT_SNAPSHOTS_PASS'in raw
  data=[list(map(float,line.split(',')[1:]))for line in raw.decode().splitlines()if line.startswith('HEAT_PAIR,')];assert len(data)==96
  report['runs'][opt]=dict(cases=96,frozen_water_cases=sum(r[-1]==0 for r in data),interpolated_water_cases=sum(r[-1]==1 for r in data),compiler=json.loads((original/'BUILD.json').read_text())['compiler'],executable_sha256=sha(exe),stdout_sha256=sha(folder/'stdout'),maximum_profile_difference_c=max(r[2]for r in data),maximum_flux_difference_j_cm2_day=max(r[3]for r in data),maximum_energy_difference_j_cm2=max(r[4]for r in data),maximum_two_half_difference_c=max(r[5]for r in data),maximum_full_half_defect_c=max(r[6]for r in data),rows=data);save()
 report['O0_O2_observations_identical']=report['runs']['O0']['rows']==report['runs']['O2']['rows']
 report.update(status='PAIRED_ORIGINAL_CURRENT_HEAT_COMPONENT_PASS',seconds=time.monotonic()-started);save();print(json.dumps({k:v for k,v in report.items()if k not in ['events','source_sha256','checkpoint_sha256']},indent=2))
if __name__=='__main__':main()
