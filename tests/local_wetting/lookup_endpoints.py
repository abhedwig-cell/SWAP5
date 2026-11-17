"""Call the actual private uptake lookup at dry endpoints in an initialized model.

Only the private test build adds this call after ordinary lookup initialization.
No copied constitutive formula, synthetic physical PASS or production test hook.
"""
from pathlib import Path
import argparse,subprocess,json,shutil,contextlib
from run import m,POLICY

PROBE='''
subroutine verify_dry_endpoint_contract()
use MOD_grid,only:numlay,nod1lay
use ieee_arithmetic,only:ieee_is_finite
implicit none
integer::j,i
real(8)::m,k,heads(4),previous
heads=[-20000d0,-19990d0,-10d0**4.3d0,-19509.494434557197d0]
do j=1,numlay
 previous=-1d0
 do i=1,4
  call get_MFLP_K(2,heads(i),nod1lay(j),m,k)
  if(.not.ieee_is_finite(m).or..not.ieee_is_finite(k))error stop 'Undefined dry endpoint'
  if(m<0d0.or.k<0d0.or.m<previous)error stop 'Invalid dry endpoint ordering'
  if(i==1.and.(m/=0d0.or.k/=K_table(431,j)))error stop 'Incorrect exact wilt endpoint'
  previous=m
 enddo
 call get_MFLP_K(2,-20000.1d0,nod1lay(j),m,k)
 if(m/=0d0.or.k/=0d0)error stop 'Changed below-wilt rule'
enddo
write(*,*)'DRY_ENDPOINT_CONTRACT_PASS',numlay
end subroutine
'''

def main():
 p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--prior',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);ref=a.reference_work/'build';result={}
 for opt in ['O0','O2']:
  original=a.prior/('water-surface-history-'+opt+'-build');build=out/(opt+'-build');shutil.copytree(original,build);src=build/'RWU_micro.f90';s=src.read_text();anchor='   call get_MFLP_K (1)';assert s.count(anchor)==1;s=s.replace(anchor,anchor+'\n   call verify_dry_endpoint_contract()');s=s.replace('end module mod_RWU_micro',PROBE+'\nend module mod_RWU_micro');src.write_text(s);meta=json.loads((original/'BUILD.json').read_text());commands=[['gfortran',*meta['identity']['donor_flags'],'-fcheck=all','-I',str(build),'-I',str(ref/'swap-obj'),'-I',str(ref/'ttutil-obj'),'-J',str(build),'-c',str(src)]]
  objects=[build/x.name if (build/x.name).exists() else x for x in sorted((ref/'swap-obj').glob('*.o'))];exe=build/'endpoint.exe';commands.append(['gfortran','-o',str(exe),*map(str,objects),str(build/'hybrid_step_budget.o'),str(ref/'ttutil-obj/libttutil.a')])
  for cmd in commands:
   r=subprocess.run(cmd,cwd=build,capture_output=True,text=True,timeout=30);assert r.returncode==0,r.stderr
  project=m.e.load(a.prior/'inputs/water-surface-history',time_step_policy=POLICY);folder=out/opt;folder.mkdir()
  def trial():
   with contextlib.ExitStack() as stack:
    host=m.h.DailyHost(stack,exe,m.h.executable(original,'day_kernel'),a.prior/'inputs/water-surface-history',folder,[m.h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding={**meta['binding'],'test_only_endpoint_probe':m.sha(src)},model=project.model,project=project)
    data=[host.step(1,checkpoint=False) for _ in range(586)];host.close();return data
  data,seconds=m.bounded(15,trial);assert m.physical(data)==m.physical(m.rows(a.prior/('water-surface-history-'+opt+'-full'))[:586]);text=(folder/'original/donor.stdout').read_text();assert 'DRY_ENDPOINT_CONTRACT_PASS' in text
  result[opt]=dict(status='REAL_LOOKUP_ENDPOINT_AND_UNCHANGED_PREFIX_PASS',seconds=seconds,source_sha256=m.sha(src),executable_sha256=m.sha(exe),commands=commands,witnesses=[s.strip() for s in text.splitlines() if 'DRY_ENDPOINT_CONTRACT_PASS' in s]);(out/'RESULT.json').write_text(json.dumps(result,indent=2));print(opt,'REAL_ENDPOINT_PASS',seconds,flush=True)
if __name__=='__main__':main()
