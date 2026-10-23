"""Replay qualified owner on the actual canonical merge before admitting it."""
import argparse,hashlib,json,runpy,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
STATUS=ROOT/'benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261023_STATUS.json'
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--merge',required=True);p.add_argument('--qualified-tree',required=True);p.add_argument('--published-head',required=True);a=p.parse_args()
 git=lambda *v:subprocess.check_output(['git',*v],cwd=ROOT,text=True).strip()
 assert git('rev-parse','HEAD')==a.merge and git('rev-parse','HEAD^{tree}')==a.qualified_tree
 assert a.published_head in git('show','-s','--format=%P','HEAD').split(),'unexpected actual merge parents'
 r=json.loads(STATUS.read_text());live=r['live_composition'];q=live['qualification']
 raw=(ROOT/q['path']).read_bytes();assert sha(raw)==q['sha256'];qualified=json.loads(raw)
 owner=runpy.run_path(str(ROOT/'integration/audits/verify_perf01_live_composition.py'))
 result=owner['verify']();controls=owner['self_test']();assert result['qualified']and controls==qualified['current_controls']
 primary=runpy.run_path(str(ROOT/'benchmarks/performance/seal_perf01_typed_water_flux.py'))
 index=json.loads((ROOT/'benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261023_RESULT.json').read_text());raw=(ROOT/index['evidence']['path']).read_bytes()
 assert sha(raw)==index['evidence']['sha256'];f=primary['unpack'](raw);assert primary['validate'](f)['native_option_processes']==62
 negatives=primary['controls'](f);assert len(negatives)==6
 report=dict(status='ACTUAL_CANONICAL_MERGE_VERIFIED',merge_commit=a.merge,published_head=a.published_head,
  qualified_complete_tree=a.qualified_tree,actual_complete_tree=git('rev-parse','HEAD^{tree}'),whole_tree_exact=True,
  actual_merge_owner=result,current_source_raw_controls=controls,typed_evidence_controls=negatives,
  original_fsi35='Qualified original O0/O2 raw gate retained; exact whole merge tree and all input identities unchanged',
  qualified_record=q,canonically_admitted=True,default_on=False,full_mc_sol01_closed=False,full_mc_nut01_closed=False,
  scope='Bounded explicit changed-accuracy option only; no accuracy-matched4.3.1 or end-to-end timing claim')
 target=ROOT/'benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261024_ACTUAL_MERGE.json';target.write_text(json.dumps(report,indent=2)+'\n')
 r.update(status='CANONICALLY_ADMITTED_ACTUAL_MERGE_VERIFIED',qualified=True,canonically_admitted=True,
  actual_merge=a.merge,actual_qualified_tree=a.qualified_tree,actual_merge_receipt=str(target.relative_to(ROOT)),
  next_action='Bounded optional policy admitted; retain default OFF and existing day470/wet-day7 and fullSOL/NUT limits')
 live.update(status='CANONICALLY_ADMITTED_ACTUAL_MERGE_VERIFIED',canonically_admitted=True,actual_merge=a.merge)
 STATUS.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(dict(merged=a.merge,tree_exact=True,current_controls=len(controls),typed_controls=6)))
if __name__=='__main__':main()
