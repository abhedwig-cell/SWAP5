#!/usr/bin/env python3
"""Exact additive RAINTB source eligibility, not admission or full preservation.

The incumbent source guard and all mandatory scientific gates remain unchanged.
This proposed owner check fails closed on unknown source, references or evidence.
"""
from pathlib import Path
import argparse
import base64
import hashlib
import importlib.util
import io
import json
import subprocess
import tarfile
import tempfile

ROOT=Path(__file__).resolve().parents[2]
BASE='c591205c5e03f1c96c6488eb53c562265f749556'
ADAPTER='src/adapter/mod_swap_daily_weather_file_adapter.f90'
PREIMAGE='44b07cd1046632a38b36e9b1ed5608f67ca41fdd'
POSTIMAGE='8ea1c1551c185112ad3f84db598eff8b823e0aeb'
PILOT='integration/audits/evidence/MC_MET01_LEGACY_RAINTB_MODULAR_PILOT_20261014.tar.xz.b64'
PILOT_SHA='c630bc221d319e39064ae23c12748eca40bcb4f1498f1d219e374cb5f8ac2794'
OWNER='integration/audits/evidence/MC_MET01_LEGACY_RAINTB_OWNER_PRESERVATION_20261014.tar.xz.b64'
OWNER_SHA='bec1ab99d93346eabe3010d6e485204f523fbb00aa654f8e0c1495028177d7fa'
PUBLIC_OLD=b'  public :: construct_swap_raintb, resolve_swap_raintb_pulse\n'
PUBLIC_NEW=b'  public :: construct_swap_raintb, construct_swap_raintb_legacy_table, resolve_swap_raintb_pulse\n'


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT).decode().strip()
def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()


def validate_change(old,new):
    if blob(old)!=PREIMAGE:raise ValueError('unknown adapter preimage')
    if blob(new)!=POSTIMAGE:raise ValueError('unknown adapter postimage')
    start=new.index(b'  ! B1.11 functions.f90 AFGEN:')
    end=new.index(b'  subroutine record_pm_values',start)
    addition=new[start:end]
    if addition.count(b'  subroutine construct_swap_raintb_legacy_table(')!=1:raise ValueError('unknown added interface')
    if old.count(PUBLIC_OLD)!=1 or new.count(PUBLIC_NEW)!=1:raise ValueError('public API drift')
    if (new[:start]+new[end:]).replace(PUBLIC_NEW,PUBLIC_OLD)!=old:raise ValueError('incumbent adapter changed')
    return {'preimage':PREIMAGE,'postimage':POSTIMAGE,'incumbent_adapter_bytes':'EXACT_RETAINED',
            'addition_sha256':hashlib.sha256(addition).hexdigest()}


def validate_scope(changed,reference_tree,baseline_reference):
    if changed!=[ADAPTER]:raise ValueError('unknown additional production mutation')
    if reference_tree!=baseline_reference:raise ValueError('reference mutation')


def capsule(raw,expected):
    if hashlib.sha256(raw).hexdigest()!=expected:raise ValueError('evidence capsule identity')
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        manifest=json.load(archive.extractfile('MANIFEST.json'))
        identities=manifest.get('member_sha256',manifest.get('members'))
        if not isinstance(identities,dict):raise ValueError('member identities absent')
        data={}
        for name,digest in identities.items():
            if Path(name).is_absolute() or '..' in Path(name).parts:raise ValueError('unsafe evidence member')
            data[name]=archive.extractfile(name).read()
            if hashlib.sha256(data[name]).hexdigest()!=digest:raise ValueError('raw member identity: '+name)
        return manifest,data


def validate_modular(data):
    result=json.loads(data['pilot-modular-persisted/modular/RESULTS.json'])
    if result['status']!='PASS':raise ValueError('direct terminal result')
    expected={(opt,build) for opt in (0,2) for build in ('cold','warm_same_transaction')}
    keys=[(r['optimization'],r['build']) for r in result['records']]
    if len(keys)!=4 or set(keys)!=expected:raise ValueError('direct case coverage')
    if len({r['stdout_sha256'] for r in result['records']})!=1:raise ValueError('direct scientific output drift')
    for record in result['records']:
        if record['sources']!=[ADAPTER,'tests/modularity/test_raintb_legacy_table.f90']:raise ValueError('direct production closure')
        for path,digest in record['inputs'].items():
            if hashlib.sha256((ROOT/path).read_bytes()).hexdigest()!=digest:raise ValueError('direct current dependency: '+path)
    if b'MC_MET01_LEGACY_TABLE_ACTUAL_RICHARDS_O0_O2=PASS' not in data['pilot-integration/stdout.log']:raise ValueError('physical integration absent')
    physical=json.loads(data['pilot-integration/RESULTS.json'])
    if physical['terminal_exit']!=0:raise ValueError('physical integration failed')
    native=[e for e in physical['events'] if e['kind']=='native']
    if len(native)!=8 or any(e['returncode'] for e in native):raise ValueError('physical integration incomplete')
    for opt in (0,2):
        outputs=[data[f'pilot-integration/build/o{opt}/{table}-{mode}.txt'] for table in ('typed','legacy') for mode in ('continuous','restart')]
        if len(set(outputs))!=1:raise ValueError('physical representation/restart drift')
    if data['pilot-integration/build/o0/output.txt']!=data['pilot-integration/build/o2/output.txt']:raise ValueError('physical optimization drift')


def validate_evidence():
    _,pilot=capsule(base64.b64decode((ROOT/PILOT).read_bytes()),PILOT_SHA)
    validate_modular(pilot)
    _,owner=capsule(base64.b64decode((ROOT/OWNER).read_bytes()),OWNER_SHA)
    spec=importlib.util.spec_from_file_location('owner_batch_guard',ROOT/'tests/mc-met01/verify_raintb_legacy_owner_batch.py')
    guard=importlib.util.module_from_spec(spec);spec.loader.exec_module(guard)
    with tempfile.TemporaryDirectory(prefix='raintb-owner-proof-') as name:
        directory=Path(name)
        prefix='owner-preservation-1/'
        for path,raw in owner.items():
            if path.startswith(prefix):
                target=directory/path.removeprefix(prefix);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
        receipt=guard.verify(json.loads(owner[prefix+'RESULTS.json']),json.loads(owner[prefix+'INPUTS.json']),ROOT,directory)
    required=[('owner-direct/daily-demand-source.stdout',b'MC_MET01_LITERAL_DAILY_DEMAND_O0_O2=PASS'),
              ('owner-direct/reference-et.stdout',b'MC_MET01_INCUMBENT_LITERAL_REFERENCE_ET_PRESERVATION_O0_O2=PASS')]
    for name,marker in required:
        if marker not in owner[name]:raise ValueError('direct incumbent oracle absent')
    return {'pilot_capsule':PILOT_SHA,'owner_capsule':OWNER_SHA,'owner_cases':receipt['cases']}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True)
    parser.add_argument('--negative-controls',action='store_true');args=parser.parse_args()
    if subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'],cwd=ROOT).returncode:raise ValueError('canonical baseline absent')
    if git('status','--porcelain','--','src','reference'):raise ValueError('dirty science/reference')
    changed=git('diff','--name-only',BASE,'HEAD','--','src').splitlines()
    reference=git('rev-parse','HEAD:reference');baseline_reference=git('rev-parse',BASE+':reference')
    validate_scope(changed,reference,baseline_reference)
    old=subprocess.check_output(['git','show',BASE+':'+ADAPTER],cwd=ROOT);new=(ROOT/ADAPTER).read_bytes()
    source=validate_change(old,new)
    if git('rev-parse','HEAD:'+ADAPTER)!=POSTIMAGE:raise ValueError('persisted adapter mismatch')
    evidence=validate_evidence()
    negatives={}
    if args.negative_controls:
        tests={
          'wrong-preimage':lambda:validate_change(old+b'\n',new),
          'wrong-postimage':lambda:validate_change(old,new+b'\n'),
          'changed-incumbent':lambda:validate_change(old,new.replace(b'rate=rain_mm*0.1d0/duration',b'rate=rain_mm*0.2d0/duration')),
          'changed-prefix-law':lambda:validate_change(old,new.replace(b'if(flat(i)<flat(i-2)) exit',b'if(flat(i)<=flat(i-2)) exit')),
          'additional-solver':lambda:validate_scope(sorted([ADAPTER,'src/runtime/mod_canonical_interval_runtime.f90']),reference,baseline_reference),
          'changed-reference':lambda:validate_scope([ADAPTER],'0'*40,baseline_reference),
          'corrupt-capsule':lambda:capsule(b'corrupted',OWNER_SHA),
        }
        for name,test in tests.items():
            try:test()
            except ValueError as error:negatives[name]=str(error)
            else:raise ValueError('invalid eligibility accepted: '+name)
    result={'claim':'PROPOSED_EXACT_SOURCE_ELIGIBLE_NOT_ADMITTED','baseline':BASE,'head':git('rev-parse','HEAD'),
            'source':source,'changed_production_paths':changed,'reference_tree':reference,'evidence':evidence,
            'negative_controls':negatives,'full_highest_frost_PPA_FCI':'PENDING; no inheritance or retirement asserted',
            'incumbent_admission_guard_changed':False}
    Path(args.output).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))

if __name__=='__main__':main()
