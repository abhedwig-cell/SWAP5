#!/usr/bin/env python3
"""Bind later adjudication and test-only proposal while retaining prior negatives."""
import argparse
import copy
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys
sys.dont_write_bytecode=True
from run_ppa_wu05b20_net_transfer_proposal import proposal_source

ROOT=Path(__file__).resolve().parents[2]
PATHS={
 'prior':('docs/audits/evidence/PPA_WU05B20_MULTILEVEL_REFERENCE_REPLAY.json.gz','b9722a11a7684247b90cd34e3c38e27337fbd7a9d36e43888f9893ec8bd6b368'),
 'precision':('docs/audits/evidence/PPA_WU05B20_PRECISION_ADJUDICATION.json.gz','ce69b00c117acd6892a1f19aa9a2b75a03eb14e36c71e5a6e714d5b6e34d5e38'),
 'proposal':('docs/audits/evidence/PPA_WU05B20_NET_TRANSFER_PROPOSAL.json.gz','2d09105252d3db72ba416545a7eff992a5ab32397998fb2a4445cf35439bad6d')}
def sha(data):return hashlib.sha256(data).hexdigest()

def validate(records):
    prior,precision,proposal=[records[k]for k in('prior','precision','proposal')]
    assert prior['independent_oracle_passed']is False and len(prior['precision_findings']['candidate'])==645
    assert precision['qualified_reference_partition']is True
    assert precision['runtime_admitted']is False and precision['aggregate_frost_migration_complete']is False
    assert precision['cases']==proposal['cases']==9216
    assert precision['decimal_digits']==[80,100]
    assert precision['criteria']=={'unit_rate_partition_error':2e-12,'nodal_scalar_residual_cm_day':1e-14,'precision_80_100_error_cm_day':1e-25}
    for k,limit in [('unit_rate_partition_error',2e-12),('native_nodal_scalar_residual',1e-14),('decimal_80_100_error',1e-25)]:
        assert precision['maxima'][k]<limit
    assert {x['case']for x in precision['resolved_cases']}=={x['case']for x in prior['precision_findings']['candidate']}
    assert all(x['unit_rate_error']<2e-12 for x in precision['resolved_cases'])
    assert precision['prior_evidence']['sha256']==proposal['parent_evidence_sha256']==PATHS['prior'][1]
    assert proposal['precision_evidence_sha256']==PATHS['precision'][1]
    for record in(precision,proposal):
        for path,identity in record['source_sha256'].items():assert sha((ROOT/path).read_bytes())==identity,path
    for opt in('o0','o2'):
        receipt=precision['receipts'][opt]
        assert receipt['exit_code']==0 and receipt['cases']==9216 and receipt['sealed_prior_output_identity']
        assert receipt['stdout_sha256']==sha(prior['outputs']['candidate'].encode())
        receipt=proposal['receipts'][opt]
        assert receipt['exit_code']==0 and receipt['cases']==9216
        assert receipt['stdout_sha256']==sha(proposal['output'].encode())
        preservation=proposal['preservation'][opt]
        assert preservation['exit_code']==0 and preservation['cases']==4536 and preservation['immutable_B17_output_identity']
    assert len(proposal['output'].splitlines())==9216
    assert {int(line.split()[0])for line in proposal['output'].splitlines()}==set(range(1,9217))
    assert proposal['counts']=={'altered_cases':1344,'byte_exact_unaltered_controls':7872}
    assert all(proposal[k]is False for k in('production_modified','reference_authority_modified','admitted','runtime_admitted','aggregate_frost_migration_complete'))
    for k,limit in [('unit_rate_geometry_error',2e-12),('nodal_scalar_residual',1e-14),('altered_signed_net_error',1e-14),('decimal_80_100_error',1e-25)]:assert proposal['maxima'][k]<limit
    original=(ROOT/'reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90').read_bytes()
    candidate,patch=proposal_source(original)
    assert sha(original)=='edd16b08ff238ee41d264d1c4870726f1232fb1143c1340f2dc21f94a3b909cf'
    assert patch==proposal['patch'] and sha(candidate)==proposal['patch']['scratch_candidate_sha256']
    assert abs(proposal['witnesses']['5']['net_bottom_minus_nodal'])<1e-14
    assert abs(proposal['witnesses']['7']['proposed_final_rates'][0])<.02
    return dict(work_unit='PPA-WU05B20',status='REFERENCE_GEOMETRY_QUALIFIED_TEST_ONLY_NET_PROPOSAL_AWAITING_OWNER',
        reference_geometry_qualified=True,old645_screens_retained_and_resolved=True,
        precision_cases=9216,precision_maxima=precision['maxima'],
        policy_proposal='FROST-MULTILEVEL-NET01',proposal_verified_in_test_scope=True,
        proposal_counts=proposal['counts'],proposal_maxima=proposal['maxima'],proposal_witnesses=proposal['witnesses'],
        production_source_tree='24fda78fd9a38964c16c89d5505b0056185ac410',
        qualified=False,admitted=False,runtime_admitted=False,aggregate_frost_migration_complete=False,
        remaining_owner_decision='Retain/bound native mixed-sign transfer or authorize absolute-rate net-preserving proposal as an explicit SWAP5 policy difference before production implementation.',
        evidence={k:dict(path=p,sha256=h,bytes=(ROOT/p).stat().st_size)for k,(p,h)in PATHS.items()})

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--summary',type=Path);args=ap.parse_args()
    records={}
    for key,(path,identity)in PATHS.items():
        data=(ROOT/path).read_bytes();assert sha(data)==identity;records[key]=json.loads(gzip.decompress(data))
    result=validate(records)
    mutations=[lambda r:r['proposal'].update(admitted=True),lambda r:r['proposal'].update(reference_authority_modified=True),
        lambda r:r['proposal']['counts'].update(altered_cases=1343),lambda r:r['proposal']['preservation']['o2'].update(exit_code=1),
        lambda r:r['precision']['criteria'].update(unit_rate_partition_error=1e-9),lambda r:r['precision']['resolved_cases'].pop(),
        lambda r:r['proposal']['receipts']['o2'].update(stdout_sha256='wrong'),lambda r:r['prior'].update(independent_oracle_passed=True)]
    for mutate in mutations:
        bad=copy.deepcopy(records);mutate(bad)
        try:validate(bad)
        except AssertionError:pass
        else:raise AssertionError('negative successor mutation accepted')
    assert subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()==result['production_source_tree']
    assert not subprocess.check_output(['git','diff','--name-only','78acf56f931763d2e1d4924b3dea0742f231d2e8','--','src'],cwd=ROOT,text=True).strip()
    result['negative_successor_evidence_tests']=8
    if args.summary:args.summary.write_text(json.dumps(result,indent=2)+'\n')
    print('B20_SUCCESSOR_EVIDENCE=PASS_REFERENCE_ONLY_POLICY_REVIEW_REQUIRED')
    print(json.dumps({k:v for k,v in result.items()if k not in('proposal_witnesses','evidence')},sort_keys=True))
if __name__=='__main__':main()
