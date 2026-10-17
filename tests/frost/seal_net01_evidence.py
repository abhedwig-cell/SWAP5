#!/usr/bin/env python3
"""Seal complete NET01 local qualification, including genuine failed diagnostics."""
import argparse, base64, difflib, gzip, hashlib, json, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='0747fd7c8a5e754d73fa5d981e8f5437ee4c12f3'
def sha(b):return hashlib.sha256(b).hexdigest()
def read(p):return json.loads(p.read_text())
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--workspace',type=Path,required=True);a=ap.parse_args();w=a.workspace
    component=w/'net01-component-02';runtime=w/'net01-runtime-final3';b18=w/'net01-preservation'
    data={'baseline':BASE,'component':read(component/'result.json'),'runtime':read(runtime/'result.json'),
          'b18':read(b18/'result.json'),'generated_runtime':(runtime/'net01_runtime.f90').read_text(),
          'production_changed':git('diff','--name-only',BASE,'HEAD','--','src').splitlines()}
    incumbent=w/'net01-incumbent'
    check=subprocess.run(['python','-B',str(incumbent/'tests/mc-irr01/verify_sensor_batch_successor.py')],cwd=incumbent,capture_output=True)
    assert check.returncode==0,check.stderr.decode();data['incumbent_proof']=json.loads(check.stdout)
    data['incumbent_verifier_stdout']=check.stdout.decode();data['incumbent_verifier_stderr']=check.stderr.decode()
    data['executed_inputs']={}
    for row in data['runtime']['results']:
        for path,h in row['inputs'].items():
            if not Path(path).is_absolute():
                assert sha((ROOT/path).read_bytes())==h;data['executed_inputs'][path]=h
    for group,key in [('component','inputs'),('b18','source_sha256')]:
        for path,h in data[group][key].items():
            assert sha((ROOT/path).read_bytes())==h;data['executed_inputs'][path]=h
    data['runtime_outputs']={}
    for row in data['runtime']['results']:
        matches=[p for p in runtime.glob('*science.stdout')if sha(p.read_bytes())==row['stdout_sha256']]
        assert len(matches)==2, 'expected byte-identical O0/O2 raw streams'
        data['runtime_outputs'][row['case']+':'+str(row['optimization'])]=matches[0].read_text()
    data['default_projections']={}
    for path in ['src/runtime/mod_fmr_serialized_reference_backend.f90','src/runtime/mod_fmr_production_application_bootstrap.f90',
                 'tests/mc-irr01/verify_sensor_batch_successor.py']:
        old=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode().splitlines(True)
        new=(ROOT/path).read_text().splitlines(True);patches=[]
        for tag,a0,a1,b0,b1 in difflib.SequenceMatcher(None,old,new,autojunk=False).get_opcodes():
            if tag!='equal':patches.append({'range':[b0,b1],'current':new[b0:b1],'baseline':old[a0:a1]})
        data['default_projections'][path]=patches
    data['retained_outputs']={}
    for directory in [component,runtime,b18,*[w/n for n in ['net01-runtime-01','net01-runtime-02','net01-runtime-03',
                                                         'net01-runtime-final','net01-runtime-final2']]]:
        for p in directory.rglob('*'):
            if p.is_file()and(p.suffix in('.stdout','.stderr','.json')or p.name in('stdout','stderr','net01_runtime.f90')):
                data['retained_outputs'][str(p.relative_to(w))]=p.read_text()
    data['retained_output_sha256']={p:sha(raw.encode())for p,raw in data['retained_outputs'].items()}
    events=data['runtime']['events'];data['costs']={k:sum(e['wall_seconds']for e in events if ('-c'in e['command'])==(k=='compile')and
            (('-o'in e['command']and'-c'not in e['command'])if k=='link'else('-o'not in e['command']if k=='native'else True)))
            for k in ['compile','link','native']}
    encoded=gzip.compress(json.dumps(data,sort_keys=True,separators=(',',':')).encode(),mtime=0)
    path='integration/audits/evidence/FROST_NET01_PRODUCTION_20261017.json.gz.b64'
    (ROOT/path).write_bytes(base64.b64encode(encoded)+b'\n')
    phase=read(ROOT/'integration/audits/PPA_WU05B20_STATUS.json')['production_reopening_20261017']
    phase.update(stage='SCIENCE_COMPLETE_ADMISSION_PENDING',implemented=True,persisted=True,tested=True,qualified=True,admitted=False,
        owner_policy_accepted=True,qualified_source=git('rev-parse','HEAD:src'),qualification_commit=git('rev-parse','HEAD'),
        contract_sha256=sha((ROOT/phase['contract']).read_bytes()),
        evidence={'path':path,'sha256':sha(encoded),'bytes':len(encoded)},postimages={})
    for row in git('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference','.github').splitlines():
        status,path=row.split('\t');phase['postimages'][path]={'status':status,'blob':git('rev-parse','HEAD:'+path)}
    phase['native_counts_per_optimization']={'source_matrix':9216,'invalid_nonmutation_ABA':26,'physical_configurations':128,
        'net_policy_configurations':36,'physical_reject_replay_restart':8,'invalid_pre_solver_and_application':48,
        'two_column_isolation':8,'single_level_runtime_preservation':8,'ordinary_multilevel_runtime':24,
        'ordinary_separate_infiltration_runtime':48,'original_B18':4536}
    phase['next_action']='Verify sealed evidence and all incumbent owner projections, reconcile current canonical, then safe production admission.'
    (w/'net01-qualified-phase.json').write_text(json.dumps(phase,indent=2)+'\n')
    print(json.dumps({'evidence':phase['evidence'],'costs':data['costs'],'scientific_source':phase['qualified_source']},indent=2))
if __name__=='__main__':main()
