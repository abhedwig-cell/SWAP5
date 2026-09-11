#!/usr/bin/env python3
import json, re, subprocess
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
CANONICAL='c7379b6b5b5f529ff96de3087379712bd665276a'
CANONICAL_SRC='d5aec38b432242d2674885c8b8bd21d7f0fa0836'
CANONICAL_REF='9d08625217d7c0a7385df9da6a04183bcd9cb9e6'
FTB05='81d4f0479a99bc456803f583457862387c267ec0'
FMR39='87b553094b66980006b69f5ba8b53d70ccd0a8e0'
FMR39_TREE='ff3635e0f6bdcb80259c728a0c4f8f339906f0ab'
FMR39_TEST='tests/fmr/test_fmr39_soil_temperature_runtime_composition.f90'
FMR39_TEST_BLOB='00a0d30fd4f1f3ef3888dbc03cf71d41770c4fab'
FVQ58='5e81e14ad613cff7a72fc3f9cddcebc6696290d7'
FVQ58_TREE='672d697ba570df05558475ed0108badc31f1a277'
REG=ROOT/'testbank/manifests/F-TB06_SOIL_TEMPERATURE_RUNTIME_CASES.json'
CONTRACT=ROOT/'integration/f-tb/F-TB06_WORK_UNIT_CONTRACT.json'
EXPECTED_IDS={
'SWAP5-TB-THERMAL-ATOMIC-0001-v1','SWAP5-TB-THERMAL-ROLLBACK-0002-v1',
'SWAP5-TB-THERMAL-RETRY-0003-v1','SWAP5-TB-THERMAL-RESTART-0004-v1',
'SWAP5-TB-THERMAL-MSW-0005-v1','SWAP5-TB-THERMAL-OPTIONAL-0006-v1',
'SWAP5-TB-THERMAL-DET-0007-v1','SWAP5-TB-THERMAL-SCIENCE-0008-v1'}
EXPECTED_CATS=Counter({'TRANSACTION':3,'RESTART':1,'MULTISWAP':1,'PROCESS':2,'ROBUSTNESS':1})
EXPECTED_PROFILES={'FAST':1,'CANONICAL':7,'RELEASE':8,'DEEP':8}
PROFILES=set(EXPECTED_PROFILES)
CASE_ID=re.compile(r'^SWAP5-TB-[A-Z0-9_-]+-[0-9]{3,5}-v[1-9][0-9]*$')
REQ={'case_id','version','title','layer','category','artifact_kind','physics','solver','parameters','forcing','initial_state','interval','oracle','tolerance_policy','provenance','source_authority','test_matrix_authority','evidence_authority','governance_authority','admission_purpose','maturity','compiler_requirements','cost_class','profiles','requiredness','invariants','negative_paths','mass_gate','current_preservation_eligible','lineage','notes'}

def fail(s): raise SystemExit('FTB06_ADOPTION_FAIL:'+s)
def git(*a): return subprocess.check_output(['git',*a],cwd=ROOT,text=True,stderr=subprocess.DEVNULL).strip()
def need(sha):
    try: subprocess.check_call(['git','cat-file','-e',sha+'^{commit}'],cwd=ROOT,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError: subprocess.check_call(['git','fetch','--no-tags','origin',sha],cwd=ROOT,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
for s in (CANONICAL,FTB05,FMR39,FVQ58): need(s)

c=json.loads(CONTRACT.read_text())
if c.get('work_unit')!='F-TB06' or c.get('canonical_base')!=CANONICAL: fail('contract authority')
if c.get('composition_support_authority')!='F-TB05@'+FTB05: fail('F-TB05 authority')
if c.get('runtime_source_authority')!='F-MR39@'+FMR39 or c.get('scientific_authority')!='F-VQ58@'+FVQ58: fail('thermal authority')
for x in ('production source','reference tree','scientific tolerances','soil-temperature physics','solver policy','RB1 authority or archived RB1 bank','canonical branch'):
    if x not in c.get('forbidden_changes',[]): fail('missing prohibition '+x)

if git('rev-parse',CANONICAL+':src')!=CANONICAL_SRC or git('rev-parse','HEAD:src')!=CANONICAL_SRC: fail('source tree')
if git('rev-parse',CANONICAL+':reference')!=CANONICAL_REF or git('rev-parse','HEAD:reference')!=CANONICAL_REF: fail('reference tree')
if git('diff','--name-only',CANONICAL+'..HEAD','--','src','reference'): fail('production/reference delta')

# All inherited testbank-support remains byte-identical to the qualified F-TB05 authority.
paths=git('ls-tree','-r','--name-only',FTB05,'--','testbank','docs/testbank','integration/f-tb').splitlines()
if not paths: fail('missing F-TB05 support')
for p in paths:
    if git('rev-parse','HEAD:'+p)!=git('rev-parse',FTB05+':'+p): fail('inherited drift '+p)
for p in ('ftb01-testbank-architecture.yml','ftb02-hydraulic-case-catalog.yml','ftb03-rb1-release-bank.yml','ftb04-transaction-restart-determinism-multiswap.yml','ftb05-current-canonical-continuous-qualification.yml'):
    q='.github/workflows/'+p
    if git('rev-parse','HEAD:'+q)!=git('rev-parse',FTB05+':'+q): fail('workflow drift '+p)

r=json.loads(REG.read_text())
if r.get('schema_version')!='1.1' or r.get('registry_id')!='F-TB01-SOIL_TEMPERATURE_RUNTIME_FTB06': fail('registry header')
if r.get('source_authority')!={'repository':'abhedwig-cell/SWAP5','ref':'work/f-mr39-restricted-soil-temperature-runtime-composition','commit':FMR39,'tree':FMR39_TREE}: fail('registry source authority')
cases=r.get('cases',[])
ids=[x.get('case_id') for x in cases]
if len(cases)!=8 or set(ids)!=EXPECTED_IDS or len(set(ids))!=8 or any(not CASE_ID.fullmatch(x or '') for x in ids): fail('case identities')
if Counter(x.get('category') for x in cases)!=EXPECTED_CATS: fail('category counts')
counts={p:sum(p in x.get('profiles',[]) for x in cases) for p in PROFILES}
if counts!=EXPECTED_PROFILES: fail('profile counts '+repr(counts))
for x in cases:
    cid=x.get('case_id','?')
    if set(x)!=REQ: fail(cid+' keys')
    if x.get('version')!=1 or x.get('current_preservation_eligible') is not True: fail(cid+' version/preservation')
    if not x.get('physics') or not set(x.get('profiles',[])).issubset(PROFILES): fail(cid+' physics/profiles')
    inv=x.get('invariants',[])
    if not inv or any(type(i) is not int or i<1 or i>30 for i in inv): fail(cid+' invariants')
    req=x.get('requiredness',{}); mandatory=set(req.get('mandatory_profiles',[])); optional=set(req.get('optional_profiles',[]))
    if mandatory|optional!=set(x.get('profiles',[])) or mandatory&optional: fail(cid+' requiredness')
    src=x.get('source_authority',{})
    if cid=='SWAP5-TB-THERMAL-SCIENCE-0008-v1':
        if (src.get('commit'),src.get('tree'),src.get('path'))!=(FVQ58,FVQ58_TREE,'tests/fvq/run_fvq58_restricted_soil_temperature_requalification.sh'): fail(cid+' source authority')
    elif (src.get('commit'),src.get('tree'),src.get('path'))!=(FMR39,FMR39_TREE,FMR39_TEST): fail(cid+' source authority')

if git('rev-parse',FMR39+':'+FMR39_TEST)!=FMR39_TEST_BLOB: fail('F-MR39 oracle blob')
for p,b in {
'src/runtime/mod_fmr_serialized_reference_backend.f90':'07877429f94ccf07c353fa5f8ba969c341ad88dd',
'src/runtime/mod_fmr_restart_state_contract.f90':'bb2c37efce37a73441181f14d15847c652ab45ea',
'src/process/mod_soil_temperature_contract.f90':'baa13df3975de2c699b0ec910477bcfa9b47f15e',
'src/process/mod_restricted_soil_temperature.f90':'fa4e1d7b48d3515e6569c9080d497178c25c4e85'}.items():
    if git('rev-parse','HEAD:'+p)!=b: fail('thermal/runtime blob '+p)

print('FTB06_CURRENT_CANONICAL_AUTHORITY=PASS:'+CANONICAL)
print('FTB06_CURRENT_CANONICAL_SOURCE_TREE=PASS:'+CANONICAL_SRC)
print('FTB06_CURRENT_CANONICAL_REFERENCE_TREE=PASS:'+CANONICAL_REF)
print('FTB06_FTB05_SUPPORT_AUTHORITY_IMMUTABLE=PASS:'+FTB05)
print('FTB06_FMR39_RUNTIME_ORACLE_IMMUTABLE=PASS:'+FMR39_TEST_BLOB)
print('FTB06_CASE_REGISTRY=PASS:COUNT=8')
print('FTB06_PROFILE_COUNTS=PASS:FAST=1,CANONICAL=7,RELEASE=8,DEEP=8')
print('FTB06_PRODUCTION_SOURCE_CHANGED=NO')
print('FTB06_REFERENCE_CHANGED=NO')
print('FTB06_RB1_REOPENED=NO')
