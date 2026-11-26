"""Qualification-only replay from a verified Jacobian-compatible frozen native context.
Never modifies/relabels an origin package and never weakens production verify_checkpoint.
The inherited prefix is explicitly not a fixed-target own trajectory qualification.
"""
from pathlib import Path
import sys,json,os,copy,hashlib,traceback
os.environ['PATH']=r'C:\msys64\ucrt64\bin;C:\Program Files\Git\cmd;'+os.environ.get('PATH','')
ROOT=Path(__file__).resolve().parents[2];sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(Path(__file__).resolve().parent)]
import daily_host as h
from coupled_macro_policy import validate_bundle
from daily_coupling import validate_bundle as validate_parent
import run_worker_window as runner

def compatible(target,parent,reference):
 tm,case=validate_bundle(target,reference);pm,pcase=validate_parent(parent,reference,h.ANDELST)
 tb,pb=tm['binding'],pm['binding']
 for k in set(tb)|set(pb):
  if k not in ['build','macro_policy'] and tb.get(k)!=pb.get(k):raise ValueError('Different physical binding:'+k)
 for k in ['project','inputs']:
  if tm[k]!=pm[k]:raise ValueError('Different project/input:'+k)
 if tm['executable_sha256']['kernel']!=pm['executable_sha256']['kernel']:raise ValueError('Kernel differs')
 if pm['identity']['coupled_macro']['native_codec']!=tm['identity']['coupled_macro']['native_codec']:raise ValueError('Native codec differs')
 if pm['identity']['coupled_macro']['physical_origin_fields']!=tm['identity']['coupled_macro']['physical_origin_fields']:raise ValueError('State schema differs')
 if pm['identity']['coupled_macro']['owner_flags']!=tm['identity']['coupled_macro']['owner_flags']:raise ValueError('Compiler policy differs')
 for field in ['donor_objects','ttutil_library']:
  if pm['identity'][field]!=tm['identity'][field]:raise ValueError('Reference provider differs:'+field)
 ps,ts=pm['identity']['donor_generated'],tm['identity']['donor_generated'];assert set(ps)==set(ts)
 source_diff=[]
 for n in ps:
  if h.sha(parent/n)!=ps[n] or h.sha(target/n)!=ts[n]:raise ValueError('Generated source identity differs:'+n)
  if ps[n]!=ts[n]:source_diff.append(n)
 if source_diff!=['macro_stock_rank2.f90']:raise ValueError('Not the selected Jacobian-only source delta:'+str(source_diff))
 po,to=[m['identity']['coupled_macro']['owner_objects_sha256'] for m in [pm,tm]];assert set(po)==set(to)
 object_diff=[]
 for n in po:
  if h.sha(parent/n)!=po[n] or h.sha(target/n)!=to[n]:raise ValueError('Owner object identity differs:'+n)
  if po[n]!=to[n]:object_diff.append(n)
 if object_diff!=['macro_stock_rank2.o']:raise ValueError('Not the selected Jacobian-only object delta:'+str(object_diff))
 # All other generated source owners, native codecs, forcing, state and residual
 # code are byte-identical. The reviewed helper writes solver outputs and scratch
 # only; it cannot convert an inherited prefix into a target-own trajectory.
 proof=dict(kind='FROZEN_CONTEXT_JACOBIAN_ONLY_REPLAY',parent_binding_sha256=hashlib.sha256(json.dumps(pb,sort_keys=True).encode()).hexdigest(),target_binding_sha256=hashlib.sha256(json.dumps(tb,sort_keys=True).encode()).hexdigest(),source_differences=source_diff,object_differences=object_diff,kernel_exact=True,all_other_physical_state_forcing_codec_residual_sources_and_objects_exact=True,origin_package_modified=False,production_checkpoint_guard_modified=False,target_own_prefix_qualified=False)
 return tm,case,pm,proof

if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--parent',type=Path,required=True);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--reference',type=Path,required=True);p.add_argument('--checkpoint',type=Path,required=True);p.add_argument('--cut',type=int,required=True);p.add_argument('--end',type=int,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--cap-seconds',default='20');a=p.parse_args()
 tm,case,pm,proof=compatible(a.bundle,a.parent,a.reference);origin_sha=h.sha(a.checkpoint)
 normal_verify=h.verify_checkpoint
 def verify_inherited(origin,cut,binding,unpacked):
  if binding!=tm['binding'] or cut!=a.cut or Path(origin)!=a.checkpoint:raise ValueError('Unexpected compatibility path')
  return normal_verify(origin,cut,pm['binding'],unpacked)
 h.verify_checkpoint=verify_inherited
 sys.argv=[sys.argv[0],'--bundle',str(a.bundle),'--reference',str(a.reference),'--checkpoint',str(a.checkpoint),'--cut',str(a.cut),'--end',str(a.end),'--output',str(a.output),'--cap-seconds',a.cap_seconds]
 rc=runner.main()
 assert h.sha(a.checkpoint)==origin_sha
 report=a.output/'RESULT.json';q=json.loads(report.read_text());proof['origin_sha256']=origin_sha;q['qualification_context']=proof;q['initial_state_exact']=True;q['fixed_target_own_prefix_qualified']=False
 if q['status'].startswith('OWN_RESTART_'):q['status']='COMPATIBLE_JACOBIAN_CONTEXT_WINDOW_COMPLETE'
 report.write_text(json.dumps(q,indent=2)+'\n');(a.output/'COMPATIBILITY_PROOF.json').write_text(json.dumps(proof,indent=2)+'\n')
 raise SystemExit(rc)
