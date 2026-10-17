#!/usr/bin/env python3
"""Seal count-complete NET01 evidence without duplicating identical streams."""
import argparse, base64, difflib, gzip, hashlib, json, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='f9f1614a794cf5a7e2f219a60fd1a61da245176b'
STATUS='integration/audits/PPA_WU05B20_STATUS.json'
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--workspace',required=True,type=Path);a=ap.parse_args();w=a.workspace
    dirs={'component':w/'net01-level-component-02','runtime':w/'net01-level-runtime-01',
          'original':w/'net01-level-original-component','failed':w/'net01-level-component-01'}
    data={'baseline':BASE,'source':git('rev-parse','HEAD:src'),'commit':git('rev-parse','HEAD'),
          'streams':{},'files':{},'projections':{}}
    for name,d in dirs.items():
        for p in sorted(d.rglob('*')):
            if p.is_file()and(p.suffix in('.stdout','.stderr','.json','.f90')or p.name in('stdout','stderr','inputs')):
                raw=p.read_bytes();h=sha(raw);data['streams'].setdefault(h,raw.decode())
                data['files'][name+'/'+str(p.relative_to(d))]=h
    for key in ('component','runtime','original'):
        data[key]=json.loads((dirs[key]/'result.json').read_text())
    proof=(w/'net01-level-incumbent-proof.stdout').read_text()
    assert 'NET01_EVIDENCE_CORRUPTION_CONTROLS=10_PASS'in proof
    data['incumbent_proof']=json.loads(proof[proof.index('{'):]);data['incumbent_stdout']=proof
    for path in ['src/process/mod_frost_multilevel_divdra_effect.f90',
                 'src/runtime/mod_fmr_serialized_reference_backend.f90','tests/frost/verify_net01_successor.py']:
        before=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode().splitlines(True)
        after=(ROOT/path).read_text().splitlines(True)
        data['projections'][path]=[{'range':[b0,b1],'current':after[b0:b1],'baseline':before[a0:a1]}
            for tag,a0,a1,b0,b1 in difflib.SequenceMatcher(None,before,after,autojunk=False).get_opcodes()if tag!='equal']
    data['executed_inputs']={}
    for row in data['runtime']['results']:
        for path,h in row['inputs'].items():
            if not Path(path).is_absolute():assert sha((ROOT/path).read_bytes())==h;data['executed_inputs'][path]=h
    for key,field in [('component','source_sha256'),('original','inputs')]:
        for path,h in data[key][field].items():assert sha((ROOT/path).read_bytes())==h;data['executed_inputs'][path]=h
    data['generated_runtime']=(dirs['runtime']/'full_levels_runtime.f90').read_text()
    data['costs']={k:sum(r[field]for r in data['runtime']['results'])for k,field in
                   [('compile','compile_seconds'),('link','link_seconds'),('native','execution_seconds'),('validation','validation_seconds')]}
    raw=gzip.compress(json.dumps(data,sort_keys=True,separators=(',',':')).encode(),mtime=0)
    path='integration/audits/evidence/FROST_NET01_FULL_LEVELS_20261017.json.gz.b64'
    (ROOT/path).write_bytes(base64.b64encode(raw)+b'\n')
    d=json.loads((ROOT/STATUS).read_text());phase=d['full_levels_20261017']
    phase.update(stage='QUALIFIED_ADMISSION_PENDING',implemented=True,persisted=True,tested=True,qualified=True,admitted=False,
        qualified_source=data['source'],qualification_commit=data['commit'],
        contract_sha256=sha((ROOT/phase['contract']).read_bytes()),
        evidence={'path':path,'sha256':sha(raw),'bytes':len(raw)},costs=data['costs'],postimages={})
    for row in git('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference','.github').splitlines():
        status,p=row.split('\t');phase['postimages'][p]={'status':status,'blob':git('rev-parse','HEAD:'+p)}
    phase['next_action']='Verify sealed source/qualification and current owner, then reconcile and safely admit exact candidate; update existing master count gap.'
    (w/'net01-full-levels-qualified-phase.json').write_text(json.dumps(phase,indent=2)+'\n')
    print(json.dumps({'evidence':phase['evidence'],'costs':data['costs']},indent=2))
if __name__=='__main__':main()
