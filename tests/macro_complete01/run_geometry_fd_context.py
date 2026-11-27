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
 from run_jacobian_context_window import compatible as physical_compatible
 from geometry_jacobian_probe import render_head
 base=target.parent/'worker-coupled-original-geometry-v33'
 bm,case,pm,physical=physical_compatible(base,parent,reference)
 tm,tcase=validate_bundle(target,reference)
 if tm['inputs']!=bm['inputs'] or tm['project']!=bm['project']:raise ValueError('Diagnostic input differs')
 if tm['identity']['coupled_macro']['physical_origin_fields']!=bm['identity']['coupled_macro']['physical_origin_fields']:raise ValueError('Physical codec differs')
 ts,bs=tm['identity']['donor_generated'],bm['identity']['donor_generated']
 if set(ts)!=set(bs)|{'native_rejection_probe.f90'}:raise ValueError('Unexpected diagnostic source owner')
 for n,digest in ts.items():
  if h.sha(target/n)!=digest:raise ValueError('Diagnostic source identity differs:'+n)
  if n not in ['headcalc.f90','native_rejection_probe.f90'] and digest!=bs[n]:raise ValueError('Physical source differs:'+n)
 if (target/'headcalc.f90').read_text()!=render_head((base/'headcalc.f90').read_text()):raise ValueError('Not the reviewed finite-difference head observer')
 layout=json.loads((target/'REPLAY_PHYSICAL_LAYOUT.json').read_text());from macro_trial_origin import PHYSICAL_FIELDS
 if [x['name'] for x in layout]!=list(PHYSICAL_FIELDS):raise ValueError('Physical dump layout differs')
 writes=[]
 for item in layout:
  section='('+','.join('1:'+{'madm':'NumDm','macp':'NumNod'}[d] for d in item['shape'])+')' if item['shape'] else ''
  writes.append('write(u)'+item['name']+section)
 expected=(Path(__file__).with_name('native_rejection_probe.f90').read_text().split('subroutine macro_replay_event',1)[0].replace('@PHYSICAL_WRITES@','\n'.join(writes)))
 if (target/'native_rejection_probe.f90').read_text()!=expected:raise ValueError('Not the pure state/flux dump helper')
 objects=tm['identity']['coupled_macro']['owner_objects_sha256'];baseobjects=bm['identity']['coupled_macro']['owner_objects_sha256']
 if set(objects)!=set(baseobjects)|{'native_rejection_probe.o'}:raise ValueError('Unexpected diagnostic object')
 for n,digest in objects.items():
  if h.sha(target/n)!=digest:raise ValueError('Diagnostic object differs')
  if n not in ['headcalc.o','native_rejection_probe.o'] and digest!=baseobjects[n]:raise ValueError('Physical object differs')
 if tm['executable_sha256']['kernel']!=bm['executable_sha256']['kernel']:raise ValueError('Kernel differs')
 proof=dict(kind='EXPLICIT_REVIEWED_LIVE_GEOMETRY_FD_CONTEXT',physical_candidate=physical,reviewed_head_observer_exact=True,pure_25field_matrix_flux_dump_only=True,perturbations_restore_and_assert_current_F=True,origin_package_modified=False,production_checkpoint_guard_modified=False,target_own_prefix_qualified=False)
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
 if q['status'].startswith('OWN_RESTART_'):q['status']='LIVE_GEOMETRY_FD_CONTEXT_WINDOW_COMPLETE'
 report.write_text(json.dumps(q,indent=2)+'\n');(a.output/'COMPATIBILITY_PROOF.json').write_text(json.dumps(proof,indent=2)+'\n')
 raise SystemExit(rc)
