#!/usr/bin/env python3
"""Source/evidence guard for the existing MC-DRAIN01 signed successor.

No numerical execution and no full-FCI PASS. Historical positive bodies remain
byte-exact; signed entry points are additive orientation adapters.
"""
from pathlib import Path
import argparse,base64,copy,gzip,hashlib,json,re,subprocess,sys,os
from functools import lru_cache
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/audits/SWAP431_DRAIN_FROST_CLUSTER_STATUS.json'
PATHS=['src/process/mod_drainage_spatial_distribution.f90',
       'src/runtime/mod_fmr_divdra_runtime_binding.f90',
       'src/runtime/mod_fmr_divdra_serialized_composition.f90',
       'src/runtime/mod_fmr_divdra_serialized_runtime.f90']
def sha(data):return hashlib.sha256(data).hexdigest()
def require(ok,why):
    if not ok:raise ValueError(why)
def verify(status,record,reader=lambda p:(ROOT/p).read_bytes()):
    require(status['qualified'] is True,'qualified evidence missing')
    require(status['closure_conditions_frozen_20261016']['ledger_rows']==['SW431-DRAIN-DIV-SIGNED'],'ledger scope')
    results=record['result']['results']
    cases={'signed_contract','positive_process','positive_binder','signed_runtime'}
    require(len(results)==8 and {(r['case'],r['optimization']) for r in results}=={(c,o) for c in cases for o in (0,2)},'complete O0/O2 cases')
    for path,h in status['qualification_inputs_sha256'].items():require(sha(reader(path))==h,'qualification harness drift '+path)
    for r in results:
        require('-fcheck=all' in r['flags'] and '-ffpe-trap=invalid,zero,overflow' in r['flags'],'scientific flags')
        for p,h in r['inputs'].items():require(sha(reader(p))==h,'scientific dependency drift '+p)
        raw=record['outputs'][r['case']+':'+str(r['optimization'])].encode()
        require(sha(raw)==r['stdout_sha256'],'raw output mismatch')
        other=next(x for x in results if x['case']==r['case'] and x['optimization']!=r['optimization'])
        require(other['stdout_sha256']==r['stdout_sha256'],'O0/O2 output drift')
        if r['case']=='signed_runtime':
            require(raw.count(b'SW431_SIGNED_SINGLE ')==24,'runtime signed count')
            require(raw.count(b'SW431_SIGNED_REJECT_REPLAY_RESTART=PASS')==4,'rollback/restart count')
            require(raw.count(b'SW431_SIGNED_INACTIVE_EXACT_IDENTITY=PASS')==2,'inactive count')
            require(b'SW431_SIGNED_TWO_ACTIVE_COLUMNS_NO_CROSS_CONTAMINATION=PASS' in raw,'column isolation')
            require(b'SW431_SIGNED_FAIL_CLOSED_PREMUTATION_MATRIX=PASS' in raw,'preflight negatives')
    require(all(e['returncode']==0 for e in record['result']['events']),'nonterminal/failed science')
    for p in PATHS:
        text=reader(p).decode()
        old=subprocess.check_output(['git','show',status['baseline']+':'+p],cwd=ROOT).decode()
        if p.endswith('mod_drainage_spatial_distribution.f90'):
            text=text.replace('  public :: distribute_single_level_signed_divdra\n','')
            text=re.sub(r'  ! SWDIVDINF=0 uses exactly.*?  end subroutine distribute_single_level_signed_divdra\n\n','',text,flags=re.S)
        elif p.endswith('mod_fmr_divdra_runtime_binding.f90'):
            text=text.replace('  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite\n','').replace(', DRAIN_DIST_INVALID_TRANSFER','')
            text=text.replace('  public :: fmr_bind_single_level_signed_divdra\n','')
            text=re.sub(r'  subroutine fmr_bind_single_level_signed_divdra\(.*?  end subroutine fmr_bind_single_level_signed_divdra\n\n','',text,flags=re.S)
        else:
            text=text.replace('fmr_bind_single_level_signed_divdra','fmr_bind_single_level_positive_divdra')
        require(text==old,'incumbent positive body changed '+p)
    return True


def load_verified():
    status=json.loads((ROOT/STATUS).read_text());e=status['closure_evidence']
    blob=base64.b64decode((ROOT/e['path']).read_bytes());require(sha(blob)==e['sha256'],'archive integrity')
    record=json.loads(gzip.decompress(blob));verify(status,record)
    # Exact additive owner scope. Documentary canonical successors are outside
    # this scientific comparison; unknown source/test changes cannot inherit.
    rows={s.split('\t')[1]:s.split('\t')[0] for s in subprocess.check_output(
        ['git','diff','--name-status',status['baseline'],'--','src','tests','tools','reference','.github'],cwd=ROOT,text=True).splitlines()}
    require(rows=={p:v['status'] for p,v in status['successor_postimages'].items()},'foreign signed successor science')
    for p,v in status['successor_postimages'].items():
        raw=(ROOT/p).read_bytes()
        require(hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==v['blob'],'unqualified successor '+p)
    return status,record

@lru_cache(None)
def incumbent(source_only=False):
    status=json.loads((ROOT/STATUS).read_text());base=status['baseline']
    root=ROOT.parent/('drain-incumbent-'+base[:12])
    if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),base],cwd=ROOT,check=True,capture_output=True)
    require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==base,'incumbent moved')
    command=[sys.executable,'-B','tests/nut-crop/verify_reproductive_successor.py']
    if source_only:command+=['--source-only']
    # Historical capsules compare complete git diff text, whose auto-selected
    # abbreviation otherwise changes as repository objects accumulate. Reuse
    # their original eight-character format; no file or assertion is changed.
    env=os.environ.copy();index=int(env.get('GIT_CONFIG_COUNT','0'))
    env['GIT_CONFIG_KEY_'+str(index)]='core.abbrev'
    env['GIT_CONFIG_VALUE_'+str(index)]='8';env['GIT_CONFIG_COUNT']=str(index+1)
    cp=subprocess.run(command,cwd=root,capture_output=True,text=True,env=env)
    require(cp.returncode==0,'original reproductive owner rejected '+cp.stderr[-1800:])
    result=json.loads(cp.stdout)
    if not source_only:require(result['qualified'] and result['reproductive_successor'],'unqualified incumbent')
    return result

def verify_source(git_reader=None):
    if (ROOT/'tests/fmig431/annual/verify_annual_successor.py').exists():
        sys.path.insert(0,str(ROOT/'tests/fmig431/annual'));import verify_annual_successor as annual
        return annual.verify_source(git_reader)
    require(git_reader is None,'unregistered projected git reader')
    status,_=load_verified();old=incumbent(True)
    tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()
    return {**old,'current_source_tree':tree,'signed_divdra_successor':True,'qualified':False}

def verify_qualification():
    if (ROOT/'tests/fmig431/annual/verify_annual_successor.py').exists():
        sys.path.insert(0,str(ROOT/'tests/fmig431/annual'));import verify_annual_successor as annual
        return annual.verify_qualification()
    status,_=load_verified();old=incumbent(False)
    tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()
    return {**old,'incumbent':old,'current_source_tree':tree,'signed_divdra_successor':True,'qualified':True,
            'drainage_ledger_rows':['SW431-DRAIN-DIV-SIGNED'],'full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS',
            'highest_low_air':'NOT_SELECTED_POLICY'}

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
    status=json.loads((ROOT/STATUS).read_text());e=status['closure_evidence']
    blob=base64.b64decode((ROOT/e['path']).read_bytes());require(sha(blob)==e['sha256'],'archive integrity')
    record=json.loads(gzip.decompress(blob));verify(status,record)
    if a.self_test:
        controls=[]
        def reject(label,s,r,reader=lambda p:(ROOT/p).read_bytes()):
            try:verify(s,r,reader)
            except (ValueError,KeyError,StopIteration):controls.append(label);return
            raise AssertionError('corruption accepted '+label)
        bad=copy.deepcopy(record);bad['result']['results'].pop();reject('missing optimization',status,bad)
        bad=copy.deepcopy(record);bad['outputs']['signed_runtime:0']='forged PASS';reject('forged raw',status,bad)
        bad=copy.deepcopy(record);bad['result']['events'][0]['returncode']=1;reject('failed compile',status,bad)
        bad=copy.deepcopy(status);bad['qualified']=False;reject('unqualified',bad,record)
        bad=copy.deepcopy(status);bad['closure_conditions_frozen_20261016']['ledger_rows'].append('SW431-DRAIN-DIV-MULTI');reject('scope expansion',bad,record)
        reject('source drift',status,record,lambda p:(ROOT/p).read_bytes()+ (b'!corruption' if p==PATHS[0] else b''))
        print('MC_DRAIN01_EVIDENCE_CORRUPTION_CONTROLS='+str(len(controls)))
    print('MC_DRAIN01_SIGNED_SOURCE_EVIDENCE=PASS')
if __name__=='__main__':
    if (ROOT/'tests/fmig431/annual/verify_annual_successor.py').exists():
        sys.path.insert(0,str(ROOT/'tests/fmig431/annual'));import verify_annual_successor as annual
        result=annual.verify_qualification()
        if sys.argv[1:]==['--self-test']:
            annual.run_predecessor_controls()
        elif sys.argv[1:]:
            raise SystemExit('unknown annual successor owner option')
        print(json.dumps(result,indent=2))
    else:
        main()
