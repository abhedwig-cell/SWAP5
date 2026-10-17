#!/usr/bin/env python3
"""Exact count successor: sealed science and complete immutable predecessor projection."""
import base64, copy, gzip, hashlib, json, math, re, subprocess, sys, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='f9f1614a794cf5a7e2f219a60fd1a61da245176b'
STATUS='integration/audits/PPA_WU05B20_STATUS.json'
SURFACE=['src','tests','tools','reference','.github']
PRODUCTION={'src/process/mod_frost_multilevel_divdra_effect.f90','src/runtime/mod_fmr_serialized_reference_backend.f90'}
def check(ok,why):
    if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['full_levels_20261017']
def capsule():
    e=record()['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes())
    check(sha(raw)==e['sha256']and len(raw)==e['bytes'],'full levels capsule changed')
    return json.loads(gzip.decompress(raw))
def restored(path,data):
    lines=(ROOT/path).read_text().splitlines(True)
    for p in reversed(data['projections'].get(path,[])):
        lo,hi=p['range'];check(lines[lo:hi]==p['current'],'projection postimage '+path);lines[lo:hi]=p['baseline']
    return ''.join(lines).encode()
def stream(d,path):
    h=d['files'][path];raw=d['streams'][h];check(sha(raw.encode())==h,'raw output identity '+path);return raw
def validate(r,d):
    check(r['qualified']and d['baseline']==BASE,'unqualified count successor')
    check(sha((ROOT/r['contract']).read_bytes())==r['contract_sha256'],'count contract changed')
    check(d['incumbent_proof']['qualified']and d['incumbent_proof']['net01_successor'],'unqualified bounded incumbent')
    for p in d['projections']:
        check(restored(p,d)==subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT),'incomplete predecessor projection '+p)
    # Bind every old executed dependency either literally or via its complete old body.
    oldr=json.loads((ROOT/STATUS).read_text())['production_reopening_20261017']
    raw=base64.b64decode((ROOT/oldr['evidence']['path']).read_bytes())
    check(sha(raw)==oldr['evidence']['sha256'],'bounded predecessor evidence changed')
    old=json.loads(gzip.decompress(raw))
    for p,h in old['executed_inputs'].items():check(sha(restored(p,d))==h,'bounded inherited input '+p)
    for p,h in d['executed_inputs'].items():check(sha((ROOT/p).read_bytes())==h,'unexecuted count source '+p)
    for h,raw in d['streams'].items():check(sha(raw.encode())==h,'retained stream changed')
    c=d['component'];check(c['passed']and c['cases']==18432 and c['counts']==list(range(2,26)),'missing count/source matrix')
    from run_net01_full_levels import fixtures
    with tempfile.TemporaryDirectory()as temp:
        fixtures(Path(temp))
        for p in Path(temp).glob('*.f90'):
            check(p.read_text()==c['generated'][p.name]==stream(d,'component/'+p.name),'unexecuted full-source fixture '+p.name)
    check(len(c['executions'])==4 and {(x['name'],x['opt'])for x in c['executions']}==
          {(n,o)for n in ('production','reference')for o in (0,2)},'missing component optimization')
    for row in c['executions']:
        check(row['exit']==row['build_exit']==0,'failed component execution')
        check(all(f in row['command']for f in ['-fcheck=all','-ffpe-trap=invalid,zero,overflow',f"-O{row['opt']}"]),
              'unchecked source execution')
        raw=stream(d,f"component/{row['name']}-o{row['opt']}/stdout")
        check(sha(raw.encode())==row['stdout_sha256'],'component raw drift')
        if row['name']=='production':
            check(row['invalid_ABA_per_count']==26,'missing count invalid contracts')
            for n in range(2,26):
                check('NET01_INVALID_NONMUTATION_ABA_26=PASS'in stream(d,f"component/production-o{row['opt']}/contracts-{n}.stdout"),'missing invalid count')
        check(raw==stream(d,f"component/{row['name']}-o{2-row['opt']}/stdout"),'component optimization drift')
    from run_net01_full_levels import cases
    inputs=cases();check(stream(d,'component/inputs')==''.join(' '.join(map(str,r))+'\n'for r in inputs),'count inputs changed')
    actual=stream(d,'component/production-o0/stdout').splitlines();native=stream(d,'component/reference-o0/stdout').splitlines()
    check(len(actual)==len(native)==len(inputs)==18432,'incomplete raw count matrix')
    maxima={'unit_nodal':0.,'scalar':0.,'signed_net':0.};net_cases=0
    for case,x,y in zip(inputs,actual,native):
        v=list(map(float,x.split()));w=list(map(float,y.split()));n=case[1]
        check(v[0]==w[0]==case[0]and v[-1]==w[-1],'source identity/bottom')
        for l in range(n):
            q=v[l+1];a=v[26+l*8:34+l*8];b=w[226+l*8:234+l*8]
            scalar=abs(q-w[201+l]);unit=max(abs(u-t)/max(abs(q),1e-10)for u,t in zip(a,b))
            check(scalar<1e-14 and unit<2e-12 and abs(math.fsum(a)-q)<1e-14,'count source geometry/scalar')
            maxima['scalar']=max(maxima['scalar'],scalar);maxima['unit_nodal']=max(maxima['unit_nodal'],unit)
        if case[5]<.01 and case[4]<-1.5:
            retained=[q if case[4]>=z else 0. for q,z in zip(case[7:7+n],case[57:57+n])]
            if min(retained)<-1e-10 and max(retained)>1e-10:
                err=abs(v[-1]-math.fsum(v[26:226])+math.fsum(retained));check(err<1e-14,'count signed net')
                maxima['signed_net']=max(maxima['signed_net'],err);net_cases+=1
    check(maxima==c['maxima']and net_cases==c['active_net_cases']==736,'count summary drift')
    o=d['original'];check(o['passed']and o['cases']==9216 and o['optimization_stdout_identity'],'original source preservation')
    check(len(o['executions'])==2 and all(x['exit']==0 for x in o['executions']),'original missing optimization')
    fixture=(ROOT/'tests/frost/test_ppa_wu05b19_divdra_runtime.f90').read_text()
    from run_net01_full_levels_runtime import body
    start=fixture.index('  requested_case=0;');end=fixture.index('\ncontains\n',start)
    generated=fixture[:start]+body()+fixture[end:]
    check(generated==d['generated_runtime'],'runtime generator changed')
    rows=d['runtime']['results'];check(len(rows)==6,'runtime matrix incomplete')
    for case,marker in [('full_levels_runtime','NET01_ACTUAL_RUNTIME=PASS'),
                         ('ordinary_multi','SW431_MULTI_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS'),
                         ('ordinary_inf','SW431_INF_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS')]:
        pair=[x for x in rows if x['case']==case]
        check(len(pair)==2 and {x['optimization']for x in pair}=={0,2},'runtime optimization incomplete')
        check(pair[0]['stdout_sha256']==pair[1]['stdout_sha256'],'runtime optimization drift')
        for row in pair:
            raws=[raw for h,raw in d['streams'].items()if h==row['stdout_sha256']]
            check(len(raws)==1 and marker in raws[0],'missing executed runtime stream')
            check(all(f in row['flags']for f in ['-fcheck=all','-ffpe-trap=invalid,zero,overflow',f"-O{row['optimization']}"]), 'unchecked runtime')
            if case=='full_levels_runtime':
                masses=re.findall(r'NET01_CASE_\d+ MASS=\s*(\S+)',raws[0])
                check(len(masses)==1536 and all(abs(float(v))<=1e-12 for v in masses),'physical hard mass matrix')
            for p,h in row['inputs'].items():
                check(sha(generated.encode())==h if Path(p).is_absolute()else d['executed_inputs'][p]==h,'runtime input mismatch')
    check(all(e['returncode']==0 for e in d['runtime']['events']),'failed terminal runtime')
    # The only physical edits are the two limits and shared named constant.
    p=(ROOT/'src/process/mod_frost_multilevel_divdra_effect.f90').read_text()
    b=(ROOT/'src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
    check('FROST_DIVDRA_MAX_LEVELS=25'in p and 'size(p)>FROST_DIVDRA_MAX_LEVELS'in p and
          'size(forcing%frost_divdra_scalars_cm_per_day)>FROST_DIVDRA_MAX_LEVELS'in b,'parameter/forcing bound ownership')
    return True
def verify_source(git_reader=None):
    g=git if git_reader is None else git_reader;r=record();check(r['baseline']==BASE,'count baseline')
    g('merge-base','--is-ancestor',BASE,'HEAD')
    dirty=g('status','--porcelain','--untracked-files=all','--',*SURFACE).splitlines()
    check(not[x for x in dirty if not re.fullmatch(r'\?\? .*/__pycache__/[^/]+\.pyc',x)],'dirty count science')
    delta={x.split('\t')[1]:x.split('\t')[0]for x in g('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
    check(delta=={p:v['status']for p,v in r['postimages'].items()},'foreign count science')
    check({p for p in delta if p.startswith('src/')}==PRODUCTION,'count production scope')
    for p,v in r['postimages'].items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'count postimage '+p)
    check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'reference changed')
    p='integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    check(g('rev-parse','HEAD:'+p)==g('rev-parse',BASE+':'+p)==blob((ROOT/p).read_bytes()),'source array authority changed')
    return {**capsule()['incumbent_proof'],'net01_full_levels_successor':True,'source_tree':g('rev-parse','HEAD:src'),
            'current_source_tree':g('rev-parse','HEAD:src'),'baseline':BASE,'qualified':False,'admitted':False,'full_capability':False}
def verify_qualification():
    result=verify_source();validate(record(),capsule())
    return {**result,'qualified':True,'full_capability':True,'scope':'NET01 2..25 strictly depth-ordered signed interacting levels; rootless ordinary Reference mode2; normal/low air and INF',
            'full_master_row':False,'full_fci':'NOT_SELECTED_IMPACT','highest_low_air':'NOT_SELECTED_POLICY'}
def self_test():
    r=record();d=capsule()
    mutations=[lambda a,b:a.update(qualified=False),lambda a,b:b['component'].update(cases=18431),
        lambda a,b:b['component'].update(counts=list(range(2,25))),lambda a,b:b['component']['executions'].pop(),
        lambda a,b:b['runtime']['results'].pop(),lambda a,b:b['runtime']['events'][0].update(returncode=1),
        lambda a,b:b['incumbent_proof'].update(qualified=False),lambda a,b:b['original'].update(cases=0),
        lambda a,b:b['projections'].update({'src/runtime/mod_fmr_serialized_reference_backend.f90':[]}),
        lambda a,b:b.update(generated_runtime='forged')]
    for mutate in mutations:
        a,b=copy.deepcopy(r),copy.deepcopy(d);mutate(a,b)
        try:validate(a,b)
        except (ValueError,KeyError):continue
        raise ValueError('corrupted count evidence accepted')
    print('NET01_FULL_LEVELS_EVIDENCE_CORRUPTION_CONTROLS=10_PASS')
if __name__=='__main__':
    if '--self-test'in sys.argv:self_test()
    print(json.dumps(verify_qualification(),indent=2))
