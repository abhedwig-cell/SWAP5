#!/usr/bin/env python3
"""Fail-closed B1.12 identity, lineage, expected-difference and source-science gate."""
from pathlib import Path
import importlib.util,json,subprocess,sys,yaml
ROOT=Path(__file__).resolve().parents[2]
BASE='5bacc7419f5ad73614f8e55b1d0c7c88706da00c'
def prior(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
def module(name,path):
 s=importlib.util.spec_from_file_location(name,ROOT/path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def verify():
 ref='reference/swap-4.3.1/';mp=ref+'b1-manifest.yml';sp=ref+'snapshots/B1.12.yml'
 m=yaml.safe_load((ROOT/mp).read_text());s=yaml.safe_load((ROOT/sp).read_text());old=yaml.safe_load(prior(mp));old_snapshot=yaml.safe_load(prior(ref+'snapshots/B1.11.yml'))
 b=m['b1'];entry=b['patches'][-1];h=module('swap019_gate_apply',ref+'patches/SWAP-019/apply_and_verify.py')
 registry=json.loads((ROOT/'docs/verification/expected-differences.json').read_text());edge=registry['comparison_edges']['B0_to_B1'];old_edge=json.loads(prior('docs/verification/expected-differences.json'))['comparison_edges']['B0_to_B1'];diff=edge['entries'][-1]
 checks={
 'current_manifest':b['snapshot']=='B1.12'and b['snapshot_definition']==sp and b['supersedes_snapshot']=='B1.11',
 'qualified_oracle':b['oracle_status']=='QUALIFIED_NUMERICAL_BEHAVIOURAL',
 'snapshot_identity':s['snapshot']=='B1.12'and s['supersedes']=='B1.11',
 'prior_ordered_manifest_unchanged':b['patches'][:-1]==old['b1']['patches'],
 'prior_snapshot_patch_order_unchanged':s['patches'][:-1]==old_snapshot['patches'],
 'manifest_snapshot_order_agrees':[(x['id'],x['patch_sha256'])for x in b['patches']]==[(x['id'],x['patch_sha256'])for x in s['patches']],
 'correction_identity':entry['id']=='SWAP-019'and entry['ordered_preimage_snapshot']=='B1.11'and entry['patch_sha256']==h.PATCH_SHA256,
 'target_identities':{x['target'].split('/')[-1]:(x['ordered_preimage_sha256'],x['corrected_target_sha256'])for x in entry['targets']}==h.TARGETS,
 'source_identity':b['source_tree']==s['source_tree']and s['source_tree']['member_manifest_sha256']==h.SOURCE_MANIFEST and s['source_tree']['member_count']==63 and s['source_tree']['source_bytes']==1886750,
 'stored_patch_identity':h.sha((ROOT/entry['patch_path']).read_bytes())==h.PATCH_SHA256,
 'immutable_B0_and_published_snapshots':not subprocess.check_output(['git','diff',BASE,'HEAD','--',ref+'b0',ref+'snapshots/B1.11.yml'],cwd=ROOT),
 'production_unchanged':not subprocess.check_output(['git','diff',BASE,'HEAD','--','src'],cwd=ROOT),
 'prior_expected_differences_preserved':edge['entries'][:-1]==old_edge['entries'],
 'new_expected_difference':edge['candidate']=='B1.12'and diff['difference_id']=='SWAP-019'and diff['status']=='ADMITTED_B1'and diff['first_admitted_tag_or_commit']=='B1.12',
 'human_ledger':'| `B1.12` | `SWAP-019` |'in(ROOT/'docs/verification/legacy-differences.md').read_text()}
 if not all(checks.values()):raise ValueError('B1.12 admission checks rejected '+str([k for k,v in checks.items()if not v]))
 return {'snapshot':'B1.12','status':'PASS','checks':checks,'canonical_admission_claimed':False,'SWAP5_partial_return_admitted':False}
if __name__=='__main__':print(json.dumps(verify(),indent=2))
