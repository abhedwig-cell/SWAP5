#!/usr/bin/env python3
"""Bounded multilevel admission and immutable signed-incumbent inheritance."""
from pathlib import Path
from functools import lru_cache
import argparse,base64,copy,gzip,hashlib,json,os,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/audits/SWAP431_DRAIN_FROST_CLUSTER_STATUS.json'
PHASE='multilevel_phase_20261016'
PATHS=['src/process/mod_drainage_spatial_distribution.f90','src/runtime/mod_fmr_divdra_runtime_binding.f90',
       'src/runtime/mod_fmr_divdra_serialized_composition.f90','src/runtime/mod_fmr_divdra_serialized_runtime.f90']
def require(ok,why):
    if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def verify(s,r,reader=lambda p:(ROOT/p).read_bytes()):
    p=s[PHASE]
    require(p['qualified'] is True,'unqualified multilevel')
    frozen=json.loads(subprocess.check_output(['git','show',p['frozen_conditions_commit']+':'+STATUS],cwd=ROOT))[PHASE]
    for key in ['baseline','existing_branch','existing_pr','existing_candidate','ledger_rows','conditions_frozen','excluded','invariants']:
        require(p[key]==frozen[key],'frozen admission condition drift '+key)
    require(p['ledger_rows']==['SW431-DRAIN-DIV-MULTI'],'multilevel ledger scope')
    cases={'multilevel_contract','signed_contract','positive_process','positive_binder','multilevel_runtime','signed_runtime'}
    results=r['result']['results']
    require(len(results)==12 and {(x['case'],x['optimization']) for x in results}=={(c,o) for c in cases for o in (0,2)},'complete O0/O2 records')
    for path,h in p['qualification_inputs_sha256'].items():require(sha(reader(path))==h,'harness drift '+path)
    for x in results:
        require('-fcheck=all' in x['flags'] and '-ffpe-trap=invalid,zero,overflow' in x['flags'],'scientific checks')
        for path,h in x['inputs'].items():require(sha(reader(path))==h,'scientific drift '+path)
        raw=r['outputs'][x['case']+':'+str(x['optimization'])].encode()
        require(sha(raw)==x['stdout_sha256'],'raw output integrity')
        pair=next(y for y in results if y['case']==x['case'] and y['optimization']!=x['optimization'])
        require(pair['stdout_sha256']==x['stdout_sha256'],'optimization identity')
        if x['case']=='multilevel_contract':require(b'MULTILEVEL_ORIGINAL_CASES=1890' in raw and b'MULTILEVEL_LITERAL_ORIGINAL_BINDER_NEGATIVES=PASS' in raw,'original/literal contracts')
        if x['case'] in {'multilevel_runtime','signed_runtime'}:
            prefix=b'SW431_MULTI' if x['case']=='multilevel_runtime' else b'SW431_SIGNED'
            require(raw.count(prefix+b'_SINGLE ')==24,'runtime signed cases')
            require(raw.count(prefix+b'_REJECT_REPLAY_RESTART=PASS')==4,'rollback restart cases')
            require(raw.count(prefix+b'_INACTIVE_EXACT_IDENTITY=PASS')==2,'inactive exact preservation')
            require(prefix+b'_TWO_ACTIVE_COLUMNS_NO_CROSS_CONTAMINATION=PASS' in raw,'column isolation')
            require(prefix+b'_FAIL_CLOSED_PREMUTATION_MATRIX=PASS' in raw,'preflight negatives')
    require(all(e['returncode']==0 for e in r['result']['events']),'failed or censored science')
    # Each admitted positive/signed single-level process and binder body is exact.
    for path,names in [(PATHS[0],['distribute_single_level_positive_divdra','distribute_single_level_signed_divdra','valid_parameters']),
                       (PATHS[1],['fmr_bind_single_level_positive_divdra','fmr_bind_single_level_signed_divdra'])]:
        old=subprocess.check_output(['git','show',p['baseline']+':'+path],cwd=ROOT,text=True)
        new=reader(path).decode()
        for name in names:
            kind='function' if name=='valid_parameters' else 'subroutine'
            pattern=r'^  (?:logical function|subroutine) '+name+r'\(.*?^  end '+kind+' '+name+r'\n'
            require(re.search(pattern,old,re.M|re.S)[0]==re.search(pattern,new,re.M|re.S)[0],'incumbent body drift '+name)
    parallel=p.get('parallel_annual_reconciliation')
    if parallel:
        base=parallel['canonical_commit']
        require(base=='5bacc7419f5ad73614f8e55b1d0c7c88706da00c','unregistered parallel admission')
        paths=subprocess.check_output(['git','diff','--name-only',p['baseline'],base,'--','src','tests','tools','reference','.github'],cwd=ROOT,text=True).splitlines()
        for path in paths:
            if path=='tests/fmig431/verify_signed_divdra_successor.py' and p.get('parallel_reference_reconciliation'):continue
            old=subprocess.check_output(['git','show',base+':'+path],cwd=ROOT)
            current=reader(path)
            if path==parallel['guard']:
                text=current.decode()
                for name,args in [('verify_source','git_reader'),('verify_qualification','')]:
                    addition=" if (ROOT/'tests/fmig431/verify_multilevel_divdra_successor.py').exists():\n  sys.path.insert(0,str(ROOT/'tests/fmig431'));import verify_multilevel_divdra_successor as drain\n  return drain."+name+'('+args+')\n'
                    require(text.count(addition)==1,'annual delegation drift')
                    text=text.replace(addition,'',1)
                current=text.encode()
            require(current==old,'parallel admitted body changed '+path)
    reference=p.get('parallel_reference_reconciliation')
    if reference:
        base=reference['canonical_commit']
        require(base=='36862e06001154f5097b438ae4b851ae092423df','unregistered reference admission')
        paths=subprocess.check_output(['git','diff','--name-only',reference['baseline'],base,'--','src','tests','tools','reference','.github'],cwd=ROOT,text=True).splitlines()
        for path in paths:
            old=subprocess.check_output(['git','show',base+':'+path],cwd=ROOT)
            current=reader(path)
            if path==reference['guard']:
                value=current.decode()
                for name in ['verify_source','verify_qualification']:
                    addition=" if (ROOT/'tests/fmig431/verify_multilevel_divdra_successor.py').exists():\n  sys.path.insert(0,str(ROOT/'tests/fmig431'));import verify_multilevel_divdra_successor as drain\n  return drain."+name+'()\n'
                    require(value.count(addition)==1,'reference delegation drift')
                    value=value.replace(addition,'',1)
                current=value.encode()
            require(current==old,'parallel reference body changed '+path)
    return True

def load_verified():
    s=json.loads((ROOT/STATUS).read_text());p=s[PHASE];e=p['evidence']
    blob=base64.b64decode((ROOT/e['path']).read_bytes());require(sha(blob)==e['sha256'],'archive integrity')
    r=json.loads(gzip.decompress(blob));verify(s,r)
    rows={x.split('\t')[1]:x.split('\t')[0] for x in subprocess.check_output(['git','diff','--name-status',p['baseline'],'--','src','tests','tools','reference','.github'],cwd=ROOT,text=True).splitlines()}
    require(rows=={path:v['status'] for path,v in p['successor_postimages'].items()},'foreign multilevel science')
    for path,v in p['successor_postimages'].items():
        raw=(ROOT/path).read_bytes()
        require(hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==v['blob'],'unqualified successor '+path)
    return s,r

@lru_cache(None)
def incumbent(source_only=False):
    p=json.loads((ROOT/STATUS).read_text())[PHASE];base=p.get('parallel_reference_reconciliation',p.get('parallel_annual_reconciliation',{})).get('canonical_commit',p['baseline'])
    namespace=ROOT.parent/'multilevel-immutable-chain'
    namespace.mkdir(exist_ok=True)
    root=namespace/('multi-incumbent-'+base[:12])
    if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),base],cwd=ROOT,check=True,capture_output=True)
    require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==base,'incumbent moved')
    module='verify_annual_successor' if p.get('parallel_annual_reconciliation') else 'verify_signed_divdra_successor'
    directory='tests/fmig431/annual' if p.get('parallel_annual_reconciliation') else 'tests/fmig431'
    if p.get('parallel_reference_reconciliation'):module='verify_successor';directory='reference/swap-4.3.1/patches/SWAP-019'
    code='import sys,json;sys.path.insert(0,'+json.dumps(directory)+');import '+module+' as v;print(json.dumps(v.'+('verify_source' if source_only else 'verify_qualification')+'()))'
    cp=subprocess.run([sys.executable,'-B','-c',code],cwd=root,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1','PYTHONPYCACHEPREFIX':str(ROOT.parent/'multi-python-cache')})
    require(cp.returncode==0,'original signed owner rejected '+cp.stderr[-2000:])
    result=json.loads(cp.stdout)
    if not source_only:require(result['qualified'] and result['signed_divdra_successor'],'signed incumbent qualification')
    if p.get('parallel_annual_reconciliation'):require(result['classic_annual_successor'],'parallel annual qualification')
    if p.get('parallel_reference_reconciliation'):require(result['reference_leaf_successor'],'reference qualification')
    return result

def verify_source(git_reader=None):
    if (ROOT/'tests/mc-irr01/verify_tcs6_successor.py').exists():
        sys.path.insert(0,str(ROOT/'tests/mc-irr01'));import verify_tcs6_successor as tcs6
        return tcs6.verify_source(git_reader)
    require(git_reader is None,'unregistered projected git reader')
    load_verified();old=incumbent(True)
    return {**old,'multilevel_divdra_successor':True,'current_source_tree':subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),'qualified':False}
def verify_qualification():
    if (ROOT/'tests/mc-irr01/verify_tcs6_successor.py').exists():
        sys.path.insert(0,str(ROOT/'tests/mc-irr01'));import verify_tcs6_successor as tcs6
        return tcs6.verify_qualification()
    load_verified();old=incumbent(False)
    return {**old,'incumbent':old,'multilevel_divdra_successor':True,'qualified':True,
            'current_source_tree':subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),
            'drainage_ledger_rows':['SW431-DRAIN-DIV-SIGNED','SW431-DRAIN-DIV-MULTI'],
            'full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS','highest_low_air':'NOT_SELECTED_POLICY'}
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
    s,r=load_verified()
    if a.self_test:
        controls=[]
        def reject(label,s,r,reader=lambda p:(ROOT/p).read_bytes()):
            try:verify(s,r,reader)
            except (ValueError,KeyError,StopIteration):controls.append(label);return
            raise AssertionError('accepted '+label)
        bad=copy.deepcopy(r);bad['result']['results'].pop();reject('missing O2',s,bad)
        bad=copy.deepcopy(r);bad['outputs']['multilevel_runtime:0']='forged';reject('forged raw',s,bad)
        bad=copy.deepcopy(r);bad['result']['events'][0]['returncode']=1;reject('failed compile',s,bad)
        bad=copy.deepcopy(s);bad[PHASE]['qualified']=False;reject('unqualified',bad,r)
        bad=copy.deepcopy(s);bad[PHASE]['ledger_rows'].append('SW431-DRAIN-INF-SPLIT');reject('scope expansion',bad,r)
        reject('source drift',s,r,lambda p:(ROOT/p).read_bytes()+(b'!corrupt' if p==PATHS[0] else b''))
        print('MULTILEVEL_EVIDENCE_CORRUPTION_CONTROLS='+str(len(controls)))
    verify_qualification()
    print('MC_DRAIN01_MULTILEVEL_SOURCE_EVIDENCE=PASS')
if __name__=='__main__':main()
