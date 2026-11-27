"""Qualification-only replay for an exact physical bundle with prepared publication.
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
  if k not in ['build','macro_policy'] and tb.get(k)!=pb.get(k):raise ValueError('Physical binding differs:'+k)
 for k in ['project','inputs']:
  if tm[k]!=pm[k]:raise ValueError('Project/input differs:'+k)
 for k in set(tm['identity'])|set(pm['identity']):
  if k not in ['coupled_macro','macro_policy','restart_publisher'] and tm['identity'].get(k)!=pm['identity'].get(k):raise ValueError('Physical identity differs:'+k)
 for field,allowed in [('coupled_macro',['policy','generator_sha256']),('macro_policy',['name','generator_sha256'])]:
  for k in set(tm['identity'][field])|set(pm['identity'][field]):
   if k not in allowed and tm['identity'][field].get(k)!=pm['identity'][field].get(k):raise ValueError('Numerical identity differs:'+field+'/'+k)
 if 'restart_publisher' in pm['identity']:raise ValueError('Not the old compile-per-route parent')
 h.validate_restart_publisher(target,tm['identity']['restart_publisher'])
 for field in ['donor_generated']:
  assert tm['identity'][field]==pm['identity'][field]
  for n,digest in tm['identity'][field].items():
   if h.sha(target/n)!=digest or h.sha(parent/n)!=digest:raise ValueError('Physical source differs:'+n)
 objects=tm['identity']['coupled_macro']['owner_objects_sha256'];assert objects==pm['identity']['coupled_macro']['owner_objects_sha256']
 for n,digest in objects.items():
  if h.sha(target/n)!=digest or h.sha(parent/n)!=digest:raise ValueError('Physical object differs:'+n)
 if tm['executable_sha256']['kernel']!=pm['executable_sha256']['kernel']:raise ValueError('Kernel differs')
 proof=dict(kind='PREPARED_PUBLICATION_ONLY_FROZEN_CONTEXT',parent_binding_sha256=hashlib.sha256(json.dumps(pb,sort_keys=True).encode()).hexdigest(),target_binding_sha256=hashlib.sha256(json.dumps(tb,sort_keys=True).encode()).hexdigest(),source_differences=[],object_differences=[],kernel_exact=True,all_physical_state_forcing_codec_residual_sources_and_objects_exact=True,numerical_policy_unchanged=True,publication_source_unchanged=True,publication_compiled_once_in_bundle=True,origin_package_modified=False,production_checkpoint_guard_modified=False,target_own_prefix_qualified=False)
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
 if q['status'].startswith('OWN_RESTART_'):q['status']='PREPARED_PUBLICATION_CONTEXT_WINDOW_COMPLETE'
 report.write_text(json.dumps(q,indent=2)+'\n');(a.output/'COMPATIBILITY_PROOF.json').write_text(json.dumps(proof,indent=2)+'\n')
 raise SystemExit(rc)
