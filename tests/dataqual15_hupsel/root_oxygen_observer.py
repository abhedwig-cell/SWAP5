"""Read-only accepted root receipt observer; never changes production state."""
import argparse,csv,hashlib,json,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
MAIN='app/solute_project/main.f90'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
BLOCK='''
        block
          integer,save::root_observer_unit=0,root_nodes_unit=0
          if(root_observer_unit==0)then
            open(newunit=root_observer_unit,file='root_accepted.dat',status='replace',action='write')
            open(newunit=root_nodes_unit,file='root_nodes.dat',status='replace',action='write')
          end if
          write(root_observer_unit,'(*(es25.17e3,1x))')s%t0,s%t1,s%root_potential_cm_day, &
            s%root_drought_reduction_cm_day,s%root_oxygen_reduction_cm_day,s%root_salinity_reduction_cm_day, &
            sum(s%root_sink),s%deepest_root_oxygen_factor,merge(1d0,0d0,s%substep_root_available)
          if((s%t0>=524d0.and.s%t1<=525d0).or.(s%t0>=583d0.and.s%t1<=584d0))then
            write(root_nodes_unit,'(*(es25.17e3,1x))')s%t0,s%t1,s%root_pressure_head_start,s%water_start,s%root_sink
          end if
        end block
'''
def instrument(source):
 anchor='      associate(s=>observation%accepted_water_flux_substeps(k))\n'
 assert source.count(anchor)==1
 result=source.replace(anchor,anchor+BLOCK)
 assert result.replace(BLOCK,'')==source
 return result
def build(bundle,out,fc):
 out.mkdir();r=json.loads((bundle/'BUILD.json').read_text());events=[]
 assert subprocess.check_output([str(fc),'--version'],text=True).splitlines()[0]==r['compiler']
 assert all(sha(Path(p))==h for p,h in r['source_sha256'].items())
 assert all(sha(Path(p))==h for p,h in r['object_sha256'].items())
 assert sha(Path(r['ttutil_archive']))==r['archive_sha256']
 pub=r['publication_provider']
 assert sha(Path(pub['source']))==pub['source_sha256'] and sha(Path(pub['object']))==pub['object_sha256']
 for f in bundle.glob('*.mod'):shutil.copyfile(f,out/f.name)
 source=out/'main.f90';source.write_text(instrument((ROOT/MAIN).read_text()),encoding='utf-8',newline='\n')
 flags=[v for v in r['flags'] if not v.startswith(('-I','-J'))]+['-I'+str(out),'-J'+str(out)]
 def run(cmd):
  started=time.monotonic();p=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=180)
  i=len(events);(out/f'{i}.stdout').write_bytes(p.stdout);(out/f'{i}.stderr').write_bytes(p.stderr)
  events.append(dict(command=list(map(str,cmd)),returncode=p.returncode,seconds=time.monotonic()-started))
  (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert p.returncode==0,p.stderr
 obj=out/'main.o';run([fc,*flags,'-c',source,'-o',obj])
 objects=list(map(Path,r['object_sha256']));sources=list(r['source_sha256'])
 index=sources.index(str(ROOT/MAIN));objects[index]=obj
 exe=out/'observed.exe';args=['-fopenmp','-Wl,--stack,16777216',*map(str,objects),pub['object'],r['ttutil_archive'],'-o',str(exe)]
 response=out/'link.args';response.write_text('\n'.join('"'+str(v).replace('\\','/')+'"' for v in args)+'\n',encoding='utf-8')
 run([fc,'@'+str(response)])
 (out/'BUILD.json').write_text(json.dumps(dict(baseline=r,source_before=sha(ROOT/MAIN),source_after=sha(source),
  object_sha256=sha(obj),executable_sha256=sha(exe),link_arguments=args,link_response_sha256=sha(response),events=events),indent=2)+'\n')
 return exe
def run(exe,case,seed,out,capture=None,compatible=False):
 cmd=[sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/run_canopy_observation.py'),'--exe',str(exe),
 '--predecessor',str(case),'--strict-restart',str(seed),'--output',str(out),'--end','584','--timeout','900']
 if capture:cmd+=['--capture',str(capture)]
 if compatible:cmd+=['--compatibility-control']
 p=subprocess.run(cmd,cwd=ROOT,capture_output=True,timeout=960)
 out.with_suffix('.stdout').write_bytes(p.stdout);out.with_suffix('.stderr').write_bytes(p.stderr)
 assert p.returncode==0,(p.stdout,p.stderr)
 assert json.loads((out/'RESULT.json').read_text())['returncode']==0
def daily(p):
 with p.open() as f:return list(csv.DictReader(f))
def qualify(opt,bundle,case,out,fc):
 out.mkdir();exe=build(bundle,out/'build',fc);seed=case/'checkpoint-524.bin'
 plain=out/'unobserved';run(bundle/'swap5_hupsel_germination.exe',case,seed,plain,compatible=True)
 whole=out/'whole';run(exe,case,seed,whole,537,True)
 tail=out/'strict-own-537';run(exe,case,whole/'checkpoint-537.bin',tail)
 assert (whole/'checkpoint.bin').read_bytes()==(plain/'checkpoint.bin').read_bytes()==(tail/'checkpoint.bin').read_bytes()
 for name,clock in [('budget.csv','t1_day'),('crop.csv','day')]:
  assert daily(whole/name)==daily(plain/name)
  assert daily(tail/name)==[r for r in daily(whole/name) if float(r[clock])>537]
 for name in ('root_accepted.dat','root_nodes.dat'):
  lines=(whole/name).read_text().splitlines()
  assert (tail/name).read_text().splitlines()==[v for v in lines if float(v.split()[0])>=537]
 if opt=='O2':
  for name,clock in [('budget.csv','t1_day'),('crop.csv','day')]:
   assert daily(whole/name)==[r for r in daily(case/name) if 524<float(r[clock])<=584]
  assert (whole/'checkpoint.bin').read_bytes()==(case/'checkpoint-584.bin').read_bytes()
 (out/'RESULT.json').write_text(json.dumps(dict(optimization=opt,exact_unobserved_endpoint=True,exact_daily=True,
  strict_own_537=True,exact_accepted_trace=True,initial_seed_scope='input-bound prior-build compatibility only',
  scientific_admission=False),indent=2)+'\n')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for n in ('o0','o2','case','output','compiler'):p.add_argument('--'+n,type=Path,required=True)
 a=p.parse_args();out=a.output.resolve();out.mkdir()
 for opt,bundle in [('O0',a.o0),('O2',a.o2)]:qualify(opt,bundle.resolve(),a.case.resolve(),out/opt,a.compiler.resolve())
