#!/usr/bin/env python3
"""Exact NET01 successor; historical references and unrelated owners stay immutable."""
import argparse, base64, copy, gzip, hashlib, json, re, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='0747fd7c8a5e754d73fa5d981e8f5437ee4c12f3'
STATUS='integration/audits/PPA_WU05B20_STATUS.json'
SURFACE=['src','tests','tools','reference','.github']
def check(ok,why):
    if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['production_reopening_20261017']
def capsule():
    e=record()['evidence'];data=base64.b64decode((ROOT/e['path']).read_bytes())
    check(sha(data)==e['sha256'],'NET01 capsule hash')
    return json.loads(gzip.decompress(data))
def validate(r,data):
    check(r['qualified']and r['owner_policy_accepted'],'NET01 not owner-authorized and qualified')
    check(r['contract_sha256']==sha((ROOT/r['contract']).read_bytes()),'completion contract changed')
    check(data['baseline']==BASE and data['production_changed']==[
        'src/process/mod_frost_multilevel_divdra_effect.f90',
        'src/runtime/mod_fmr_production_application_bootstrap.f90',
        'src/runtime/mod_fmr_serialized_reference_backend.f90'],'NET01 production scope')
    check(data['component']['passed']and data['component']['cases']==9216,'incomplete source matrix')
    check(data['component']['max_unit_rate_difference']<2e-12 and data['component']['max_scalar_difference']<1e-14,
          'source conformance criterion')
    check(data['component']['max_signed_net_residual']<1e-14,'source signed net criterion')
    check(len(data['component']['executions'])==2 and all(x['exit']==0 and x['invalid_nonmutation_ABA_controls']==26
          for x in data['component']['executions']),'missing trapped contracts')
    check(data['b18']['passed']and data['b18']['cases']==4536 and data['b18']['accepted']==3240
          and data['b18']['held']==1296 and data['b18']['invalid']==32,'original B18 preservation')
    check(data['incumbent_proof']['qualified']and data['incumbent_proof']['full_capability']
          and data['incumbent_proof']['sensor_batch_successor'],'unqualified incumbent')
    check(len(data['runtime']['results'])==6,'incomplete runtime and preservation')
    for case,marker in [('net01_runtime','NET01_ACTUAL_RUNTIME=PASS'),
                        ('ordinary_multi','SW431_MULTI_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS'),
                        ('ordinary_inf','SW431_INF_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS')]:
        pair=[x for x in data['runtime']['results']if x['case']==case]
        check(len(pair)==2 and {x['optimization']for x in pair}=={0,2},'missing runtime optimization')
        check(pair[0]['stdout_sha256']==pair[1]['stdout_sha256'],'runtime O0/O2 drift')
        for row in pair:
            output=data['runtime_outputs'][case+':'+str(row['optimization'])]
            check(sha(output.encode())==row['stdout_sha256']and marker in output,'runtime raw output drift')
            if case=='net01_runtime':
                check(output.count('NET01_CASE_')==128 and 'NET01_POLICY_CASES=36'in output,'physical matrix incomplete')
                masses=re.findall(r'MASS=\s*(\S+)',output)
                check(len(masses)==128 and all(abs(float(v))<=1e-12 for v in masses),'hard mass gate')
    check(all(e['returncode']==0 for e in data['runtime']['events']),'failed terminal execution')
    check(set(data['default_projections'])=={'src/runtime/mod_fmr_serialized_reference_backend.f90',
          'src/runtime/mod_fmr_production_application_bootstrap.f90','tests/mc-irr01/verify_sensor_batch_successor.py'},
          'missing complete incumbent projections')
    fixture=(ROOT/'tests/frost/test_ppa_wu05b19_divdra_runtime.f90').read_text()
    start=fixture.index('  requested_case=0;');end=fixture.index('\ncontains\n',start)
    generated=fixture[:start]+(ROOT/'tests/frost/net01_runtime_body.inc').read_text()+fixture[end:]
    check(generated==data['generated_runtime'],'unexecuted runtime fixture')
    for row in data['runtime']['results']:
        check(all(f in row['flags']for f in ['-fcheck=all','-ffpe-trap=invalid,zero,overflow',f"-O{row['optimization']}"]),
              'runtime checking flags changed')
        for path,h in row['inputs'].items():
            if Path(path).is_absolute():check(sha(generated.encode())==h,'generated runtime digest')
            else:check(data['executed_inputs'][path]==h,'runtime input receipt drift')
    for path,h in data['executed_inputs'].items():check(sha((ROOT/path).read_bytes())==h,'stale executed input '+path)
    for path,patches in data['default_projections'].items():
        lines=(ROOT/path).read_text().splitlines(True)
        for patch in reversed(patches):
            lo,hi=patch['range'];check(lines[lo:hi]==patch['current'],'reviewed successor hunk changed '+path)
            lines[lo:hi]=patch['baseline']
        check(''.join(lines).encode()==subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT),
              'incumbent complete body projection '+path)
    for path,raw in data['retained_outputs'].items():
        check(sha(raw.encode())==data['retained_output_sha256'][path],'raw retained output changed')
    return True
def verify_source(git_reader=None):
    if (ROOT/'tests/frost/verify_net01_full_levels.py').is_file():
        from verify_net01_full_levels import verify_source as successor
        return successor(git_reader)
    g=git if git_reader is None else git_reader;r=record()
    check(r['baseline']==BASE,'NET01 baseline changed');g('merge-base','--is-ancestor',BASE,'HEAD')
    dirty=g('status','--porcelain','--untracked-files=all','--',*SURFACE).splitlines()
    check(not[x for x in dirty if not re.fullmatch(r'\?\? .*/__pycache__/[^/]+\.pyc',x)],'dirty NET01 science')
    delta={x.split('\t')[1]:x.split('\t')[0]for x in g('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
    check(delta=={p:v['status']for p,v in r['postimages'].items()},'foreign NET01 science')
    for p,v in r['postimages'].items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'NET01 postimage '+p)
    check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'reference authority changed')
    return {**capsule()['incumbent_proof'],'net01_successor':True,'current_source_tree':g('rev-parse','HEAD:src'),
            'source_tree':g('rev-parse','HEAD:src'),'baseline':BASE,
            'method':'EXACT_NET01_SOURCE_AND_EXECUTED_EVIDENCE_WITH_COMPLETE_INCUMBENT_BODY_PROJECTIONS',
            'projection_policy':'Original complete backend/application bodies reconstruct exactly; legacy selectors without multilevel parameters retain their original branches. New active semantics require the sealed NET01 native source and actual runtime evidence.',
            'qualified':False,'admitted':False,'full_capability':False}
def verify_qualification():
    if (ROOT/'tests/frost/verify_net01_full_levels.py').is_file():
        from verify_net01_full_levels import verify_qualification as successor
        return successor()
    result=verify_source();data=capsule();validate(record(),data)
    return {**result,'qualified':True,'full_capability':True,'net01_policy':'OWNER_APPROVED_SWAP5_DIFFERENCE',
            'scope':'two/three signed interacting levels; rootless ordinary Reference mode2; normal/low air and separate infiltration',
            'full_fci':'NOT_SELECTED_IMPACT','highest_low_air':'NOT_SELECTED_POLICY'}
def self_test():
    if (ROOT/'tests/frost/verify_net01_full_levels.py').is_file():
        from verify_net01_full_levels import self_test as successor
        return successor()
    r=record();data=capsule()
    mutations=[lambda a,b:a.update(owner_policy_accepted=False),lambda a,b:a.update(qualified=False),
        lambda a,b:b['component'].update(cases=9215),lambda a,b:b['runtime']['results'].pop(),
        lambda a,b:b['runtime']['events'][0].update(returncode=1),lambda a,b:b['b18'].update(held=0),
        lambda a,b:b['default_projections'].update({'src/runtime/mod_fmr_serialized_reference_backend.f90':[]}),
        lambda a,b:b['runtime_outputs'].update({'net01_runtime:0':'forged'}),
        lambda a,b:b['component'].update(max_unit_rate_difference=3e-12),
        lambda a,b:b['production_changed'].append('src/legacy/b1_10_port/headcalc.f90')]
    for mutate in mutations:
        a,b=copy.deepcopy(r),copy.deepcopy(data);mutate(a,b)
        try:validate(a,b)
        except (ValueError,KeyError):continue
        raise ValueError('accepted corrupted NET01 evidence')
    print('NET01_EVIDENCE_CORRUPTION_CONTROLS=10_PASS')
if __name__=='__main__':
    if '--self-test'in sys.argv:self_test()
    print(json.dumps(verify_qualification(),indent=2))
