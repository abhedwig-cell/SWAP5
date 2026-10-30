"""Read-only original4.3.1 nodal diagnostics; scalar trajectory must remain exact."""
import argparse,csv,hashlib,json,shutil,subprocess,time
from pathlib import Path

p=argparse.ArgumentParser();p.add_argument('--donor',type=Path,required=True);p.add_argument('--reference',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);a=p.parse_args()
donor=a.donor.resolve();ref=a.reference.resolve();out=a.output.resolve();out.mkdir();fc=str(a.compiler.resolve());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();build=json.loads((donor/'BUILD.json').read_text())
for n,h in build['original_provider_build']['source_sha256'].items():assert sha(donor/'providers'/n)==h,n
original=donor/'providers/selected/swapoutput.f90';assert sha(original)==build['original_provider_build']['source_sha256']['source/SWAP/swapoutput.f90']
s=original.read_text();before,body=s.split('      subroutine soilwateroutput(task)',1);body,after=body.split('      subroutine outbal (task)',1)
def replace(old,new):
 global body
 assert body.count(old)==1,old;body=body.replace(old,new)
replace('      use Variables,     only: SWCSV, SWAFO, SWAUN, t1900','      use Variables,     only: SWCSV, SWAFO, SWAUN, t1900, h, theta\n      use MOD_grid, only: numnod\n      use MOD_soiltemperature, only: tsoil')
replace('      character(len=10)    :: dtprint','      character(len=10)    :: dtprint\n      integer, save :: dq15_unit, dq15_index\n      integer :: dq15_node')
replace('      case (1)','      case (1)\n         dq15_index=0\n         open(newunit=dq15_unit,file="nodal_profiles.csv",status="replace",action="write")\n         write(dq15_unit,"(a)")"day,node,head_cm,water_content,temperature_c,time1900"')
replace('      case (2)','      case (2)\n         dq15_index=dq15_index+1')
replace('      case (4)','      case (4)\n         close(dq15_unit)')
replace('      end select','''      end select
      if(task==1.or.task==2)then
         if(any(dq15_index==[0,63,71,72,73,113,140,367,731,918,922,1096,1461,1800,1827]))then
            do dq15_node=1,numnod
               write(dq15_unit,'(i0,a,i0,4(a,es25.17e3))')dq15_index,',',dq15_node, &
                    ',',h(dq15_node),',',theta(dq15_node),',',tsoil(dq15_node),',',t1900
            end do
         end if
      end if''')
source=out/'swapoutput_profiles.f90';source.write_text(before+'      subroutine soilwateroutput(task)'+body+'      subroutine outbal (task)'+after)
report=dict(scope='OUTPUT_ONLY_ORIGINAL_PROVIDER_INSTRUMENTATION',physics_replaced=False,original_build_sha256=sha(donor/'BUILD.json'),original_output_source_sha256=sha(original),instrumented_source_sha256=sha(source),events=[])
def command(cmd,label,cwd=out,timeout=120):
 t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=timeout);(out/(label+'.stdout')).write_bytes(r.stdout);(out/(label+'.stderr')).write_bytes(r.stderr);report['events'].append(dict(label=label,command=list(map(str,cmd)),seconds=time.monotonic()-t,returncode=r.returncode));(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');return r.returncode
obj=out/'swapoutput_profiles.o';flags=['-O2','-finit-local-zero','-fallow-argument-mismatch','-ffree-line-length-none','-I'+str(donor/'providers/swobj'),'-I'+str(donor/'providers/ttobj')]
assert command([fc,*flags,'-c',source,'-o',obj],'compile')==0
link=list(build['commands'][-1]);link[0]=fc;idx=next(i for i,s in enumerate(link)if s.endswith('/swapoutput.o'));link[idx]=str(obj);exe=out/'swap431_profiles';link[-1]=str(exe)
report['reused_artifacts_sha256']={s:sha(Path(s))for s in link if s.endswith(('.o','.a'))and s!=str(obj)}
assert command(link,'link')==0;report['executable_sha256']=sha(exe)
case=out/'original';case.mkdir()
for n in ['swap.swp','grass.crp','260.met','swap.bbc','swap.dra']:shutil.copyfile(ref/n,case/n)
report['inputs_sha256']={n:sha(case/n)for n in ['swap.swp','grass.crp','260.met','swap.bbc','swap.dra']}
assert command([exe],'native',cwd=case,timeout=120)==100 and(case/'swap.ok').exists()
lines=lambda f:[l for l in f.read_text().splitlines()if l.strip()and not l.startswith('*')]
assert lines(case/'result_output.csv')==lines(ref/'result_output.csv'),'read-only instrumentation changed scalar trajectory'
rows=list(csv.DictReader((case/'nodal_profiles.csv').open()));days=sorted({int(r['day'])for r in rows});assert days==[0,63,71,72,73,113,140,367,731,918,922,1096,1461,1800,1827]
assert all(len([r for r in rows if int(r['day'])==day])==113 for day in days)
report.update(status='ORIGINAL1827_SCALAR_EXACT_WITH_NODAL_DIAGNOSTICS',original_days=1827,profile_days=days,profile_rows=len(rows),scalar_rows=len(lines(case/'result_output.csv'))-1,scalar_trajectory_exact=True,profile_sha256=sha(case/'nodal_profiles.csv'),scientific_equivalence=False)
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items()if k not in ['events','reused_artifacts_sha256']},indent=2))
