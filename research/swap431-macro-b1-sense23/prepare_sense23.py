"""Prepare a scoped MACRORATE transaction, not a general/native restart format."""
from pathlib import Path
import json,re,difflib
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-fresh22'
SRC=Path('C:/Users/Veldh012/swap431-state02-work/audit/build/swap-selected')
for p in P.glob('*.f90'):(R/p.name).write_bytes(p.read_bytes())
patch=[];schema={}
def put(n,s,old):
 (R/n).write_text(s);patch.append(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='baseline/'+n,tofile='SENSE23/'+n)))
def names(s,save_only=False):
 out=[]
 for line in s.splitlines():
  t=line.split('!')[0].strip()
  if not re.match(r'(?i)^(real|integer|logical|character)\b',t) or '::' not in t:continue
  lhs,rhs=t.split('::',1)
  if 'parameter' in lhs.lower() or (save_only and 'save' not in lhs.lower()):continue
  depth=0;items=[];start=0
  for i,c in enumerate(rhs):
   if c=='(':depth+=1
   if c==')':depth-=1
   if c==',' and depth==0:items.append(rhs[start:i]);start=i+1
  items.append(rhs[start:])
  out += [re.match(r'\s*(\w+)',x)[1] for x in items]
 return out
def entry(s,start,end,ename,fields):
 a=s.lower().index(start);b=s.lower().index(end,a);part=s[a:b]
 needle=re.search(r'(?im)^\s*implicit\s+none\s*$',part)
 assert needle;pos=needle.end();part=part[:pos]+'\n      integer::snap23_unit,snap23_mode\n'+part[pos:]
 payload='\n'.join('      '+op+'(snap23_unit) '+','.join(fields[i:i+6]) for i in range(0,len(fields),6) for op in ['write'])
 reads=payload.replace('write(','read(')
 code='\n      return\n      entry '+ename+'(snap23_unit,snap23_mode)\n      if(snap23_mode==1) then\n'+payload+'\n      else\n'+reads+'\n      end if\n      return\n'
 # Append entry after original final return, before internal procedures if present.
 marker=re.search(r'(?im)^\s*contains\s*$',part)
 pos=marker.start() if marker else len(part)
 part=part[:pos]+code+part[pos:]
 schema[ename]=fields
 return s[:a]+part+s[b:]
s=(R/'diag_state.f90').read_text();old=s
s=s.replace('integer,save::kind=', 'logical,save::probe_busy=.false.\ninteger,save::probe_u,point_id=0,point_node=0\nreal(8),save::point_delta=0\ninteger,save::kind=',1)
put('diag_state.f90',s,old)
s=(R/'head_diag.f90').read_text();old=s
s=s.replace('      call diag_log(2)\n','      call diag_log(2)\n      if(target.and.numbit==30) call sense23_probe()\n',1)
put('head_diag.f90',s,old)
s=(R/'macrorate_node.f90').read_text();old=s
s=s.replace('only:target,attempts,iter_index,nvec,limit_u,macro_seq','only:target,attempts,iter_index,nvec,limit_u,macro_seq,probe_busy,probe_u,point_id,point_node,point_delta',1)
needle='      write(limit_u,*) attempts'
assert needle in s
# Same limiter values in both streams; probe metadata precedes the native43 columns.
start=s.index(needle);end=s.index('\n      end subroutine limit21_trace',start)
line=s[start:end]
probe_line=line.replace('write(limit_u,*) attempts','write(probe_u,*) point_id,point_node,point_delta,attempts',1)
s=s[:start]+'''      if(probe_busy) then
      if(stage==3) then
'''+probe_line+'''
      end if
      return
      end if
'''+s[start:]
# Snapshot explicit persistent locals; ordinary automatic scratch is not retained.
head=s[:s.index('!     for FORCHECK')]
s=entry(s,'subroutine macrorate(itask)','end subroutine macrorate','sense23_rate_io',names(head,True))
s=entry(s,'subroutine satflow(itask','end subroutine','sense23_sat_io',['DelHDmCp','FlwMtxSatDmCp'])
s=entry(s,'subroutine absorption','\n      end\n','sense23_abs_io',['DelHDmCp','Diffusivity','FlSorp'])
put('macrorate_node.f90',s,old)
s=(SRC/'calcgwl.f90').read_text();old=s
s=s.replace('public :: calcgwl, no_deltaGWL_warning','public :: calcgwl, no_deltaGWL_warning,sense23_gwl_io',1)
s=entry(s,'subroutine calcgwl ()','end subroutine calcgwl','sense23_gwl_io',['i','node','nodheq1','flsat','message','datexti','datetime','cval'])
put('calcgwl_probe.f90',s,old)
# All own module data, including arrays, are preserved, not only the native restart fields.
mac=names((P/'macropore_native.f90').read_text().split('   contains')[0])
vs=(SRC/'variables.f90').read_text();mpblock=re.search(r'(?is)module MOD_swap_mp\b(.*?)end module MOD_swap_mp',vs)[1]
mp=names(mpblock)
var=['h','theta','k','kmean','dimoca','gwl','nodgwl','bpegwl','npegwl','pegwl','pegwl_bot','gwlm1','gwlconv','pond','dt','t1900']
groups=[('MOD_macropore','m',mac),('MOD_swap_mp','p',mp),('variables','v',var),('DIAG19','d',['macro_seq'])]
aliases=[];uses=[]
for mod,tag,ns in groups:
 for i in range(0,len(ns),5):uses.append('use '+mod+',only:'+','.join(tag+'_'+n+'=>'+n for n in ns[i:i+5]))
 aliases += [tag+'_'+n for n in ns]
 schema['module_fields']={mod:ns for mod,tag,ns in groups}
wr='\n'.join('write(u) '+','.join(aliases[i:i+5]) for i in range(0,len(aliases),5));rd=wr.replace('write(u)','read(u)')
code='''module SENSE23_TRANSACTION
use MOD_gwl,only:sense23_gwl_io
'''+ '\n'.join(uses)+'''
implicit none
contains
subroutine snapshot(path,mode)
character(*),intent(in)::path
integer,intent(in)::mode
integer::u
if(mode==1) then
 open(newunit=u,file=path,status='replace',access='stream',form='unformatted')
'''+wr+'''
else
 open(newunit=u,file=path,status='old',access='stream',form='unformatted')
'''+rd+'''
end if
call sense23_rate_io(u,mode)
call sense23_sat_io(u,mode)
call sense23_abs_io(u,mode)
call sense23_gwl_io(u,mode)
close(u)
end subroutine
end module

subroutine sense23_probe()
use,intrinsic::ieee_exceptions,only:ieee_status_type,ieee_get_status,ieee_set_status
use SENSE23_TRANSACTION,only:snapshot
use DIAG19,only:probe_busy,probe_u,point_id,point_node,point_delta
use variables,only:h,theta,k,swkimpl,dt
use MOD_MvG,only:watcon,hconduc
use MOD_frost,only:rfcp
use MOD_grid,only:numnod,disnod,dz,z
use MOD_swap_mp,only:FrArMtrx,QExcMpMtx,dFdhMp
use MOD_macropore,only:QExcMtxDmCp,VlMpDmCp,WaSrMpDm,SwSoilShr
implicit none
integer::j,lev,sgn,u,flux_u,fp_u
type(ieee_status_type)::fp_before,fp_after
real(8)::eps
character(60)::path
call ieee_get_status(fp_before)
call snapshot('trial23_base.bin',1)
open(newunit=u,file='probe_context.txt',status='replace')
write(u,*) 'h',h(50:52)
write(u,*) 'z',z(50:51)
write(u,*) 'disnod51',disnod(51)
write(u,*) 'volume_density3_50',VlMpDmCp(3,50)/dz(50)
write(u,*) 'dt',dt
write(u,*) 'existing_dFdhMp52',dFdhMp(52)
write(u,*) 'existing_macro_J52_50',0d0
write(u,*) 'swkimpl',swkimpl
write(u,*) 'SwSoilShr',SwSoilShr
close(u)
open(newunit=probe_u,file='probe_limit.txt',status='replace')
open(newunit=flux_u,file='probe_flux.txt',status='replace')
open(newunit=fp_u,file='probe_fp_status.txt',status='replace')
write(fp_u,*) 0,transfer(fp_before,[0])
point_id=0;probe_busy=.true.
call evaluate(0,0d0)
do lev=1,2
 eps=1d-4/dble(lev)
 do j=50,52
  do sgn=-1,1,2
   call evaluate(j,dble(sgn)*eps)
  end do
 end do
end do
call evaluate(0,0d0)
call snapshot('trial23_base.bin',2)
call snapshot('trial23_final.bin',1)
probe_busy=.false.
close(probe_u);close(flux_u)
call ieee_set_status(fp_before)
call ieee_get_status(fp_after)
write(fp_u,*) 99,transfer(fp_after,[0])
close(fp_u)
contains
subroutine evaluate(node,delta)
integer,intent(in)::node
real(8),intent(in)::delta
call snapshot('trial23_base.bin',2)
call ieee_set_status(fp_before)
point_id=point_id+1;point_node=node;point_delta=delta
if(node/=0) then
 h(node)=h(node)+delta
 theta(node)=watcon(node,h(node))
 if(swkimpl==1) k(node)=FrArMtrx(node)*hconduc(node,h(node),theta(node),rfcp(node))
end if
call MACRORATE(1)
write(flux_u,*) point_id,node,delta,QExcMpMtx(52),QExcMtxDmCp(3,52),QExcMpMtx(1:numnod)
call snapshot('trial23_base.bin',2)
write(path,'(a,i0,a)') 'trial23_restored_',point_id,'.bin'
call snapshot(trim(path),1)
call ieee_set_status(fp_before)
call ieee_get_status(fp_after)
write(fp_u,*) point_id,transfer(fp_after,[0])
end subroutine
end subroutine
'''
(R/'probe_state.f90').write_text(code)
s=(P/'fresh22.py').read_text().replace('swap431-fresh22-work','swap431-sense23-work')
s=s.replace("[('diag_state','diag19'),","[('diag_state','diag19'),('calcgwl_probe','calcgwl'),")
s=s.replace('"(\'macropore_native\',\'macropore\'),(\'ledger_state\',\'ledger12\'),"','"(\'macropore_native\',\'macropore\'),(\'probe_state\',\'probe23\'),(\'ledger_state\',\'ledger12\'),"',1)
(R/'sense23.py').write_text(s)
(R/'instrumentation.patch').write_text('\n'.join(patch))
(R/'TRANSACTION_FIELDS.json').write_text(json.dumps(schema,indent=2)+'\n')
(R/'STATUS.json').write_text(json.dumps(dict(stage='PREREGISTERED',baseline='4976c403d7eeeb7c8158d2b34d3d07c1585ffe96',routes=['O0 native attempt38','O2 native attempt38'],probe='Before tridiagonal solve iteration30 of same current-operator head; MACRORATE only, no solver update',points='base; h50,h51,h52 plus/minus1e-4 and5e-5; repeatedbase =14evaluations',restore='allownmacro/swapmpmodule fields, hostmutationclosure and savedMACRORATE/SATFLOW/ABSORPTION/CALCGWLlocals; binary identity aftereachprobe',hard_timeout_seconds=20,no_campaign=True),indent=2)+'\n')
