"""Seal/replay real matched kernel observations, preserving complete traces losslessly."""
import argparse
import base64
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import zipfile
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
NAME='PERF01_CURRENT_431_20261023_EVIDENCE'
AUTH=['integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64',
      'integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64']
spec=importlib.util.spec_from_file_location('matched',ROOT/'tools/performance/compare_swap431_perf01.py')
matched=importlib.util.module_from_spec(spec);spec.loader.exec_module(matched)
DTYPE,CASES=matched.DTYPE,matched.CASES
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def authority():
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/AUTH[0]).read_bytes())),mode='r:gz')as tar:
        old={m.name:tar.extractfile(m).read() for m in tar.getmembers() if m.isfile()}
    with zipfile.ZipFile(io.BytesIO(base64.b64decode((ROOT/AUTH[1]).read_bytes())))as z:
        tt={p:z.read(p) for p in z.namelist() if not p.endswith('/')}
    sys.path.insert(0,str(ROOT/'tools/vq'))
    from b0_source_runner import select_dec_branches
    return old,tt,select_dec_branches
def expected_source(item,old,tt,select,context=None):
    def repository(path):
        if context:return subprocess.check_output(['git','show',context+':'+path],cwd=ROOT)
        return (ROOT/path).read_bytes()
    if item['kind']=='repository':return repository(item['path'])
    if item['kind']=='selected':return select(old[item['path']].decode('cp1252')).encode('cp1252')
    if item['kind']=='ttutil':return tt[item['path']]
    assert item['kind'] in ['generated_grid','generated_driver']
    if item['kind']=='generated_driver':return repository('tests/performance/swap5_perf01_column.f90')
    raw=repository('tests/f-app07/mc_irr01_realistic_headcalc_stubs.f90').decode()
    for before,after in [
        ('integer, parameter :: numnod = 4','integer, parameter :: numnod = 50\n  integer :: grid_i'),
        ('[-12.5d0, -37.5d0, -62.5d0, -87.5d0]','[(-1.0d0-2.0d0*(grid_i-1),grid_i=1,numnod)]'),
        ('[25.0d0, 25.0d0, 25.0d0, 25.0d0]','2.0d0'),
        ('[12.5d0,25.0d0,25.0d0,25.0d0,12.5d0]','[1.0d0,(2.0d0,grid_i=2,numnod),1.0d0]')]:raw=raw.replace(before,after)
    return raw.encode()
def decode(files,label):
    codec=json.loads(files['TRACE_ENCODING.json'])[label]
    if codec.get('alias'):
        assert label.startswith('historical/')and codec['base']==label.removeprefix('historical/')
        assert files[label+'/trace.xor-byteplanes']==b''
        return decode(files,codec['base'])
    expected_base='O2-'+label.split('-')[1]+'-0-legacy'
    assert codec['base']==(None if label==expected_base else expected_base)
    raw=files[label+'/trace.xor-byteplanes']
    assert len(raw)%DTYPE.itemsize==0
    rows=np.frombuffer(raw,dtype=np.uint8).reshape(DTYPE.itemsize,-1).T
    if codec['base']:
        base=decode(files,codec['base']);assert len(base)==len(raw)
        return np.bitwise_xor(rows,np.frombuffer(base,np.uint8).reshape(-1,DTYPE.itemsize)).tobytes()
    return np.bitwise_xor.accumulate(rows,axis=0).tobytes()
def verify(files,prefix='',context=None):
    report=json.loads(files[prefix+'RESULT.json']);inputs=json.loads(files[prefix+'COMPILED_INPUTS.json'])
    if context:
        assert context==report['baseline']
        assert subprocess.check_output(['git','rev-parse',context+':src'],cwd=ROOT,text=True).strip()==report['source_tree']
    assert report['status']=='COMPLETE_MATCHED_REAL_KERNEL_O0_O2_PHYSICAL_SCREEN_PASS'
    old,tt,select=authority()
    for path,digest in inputs['authorities'].items():assert sha((ROOT/path).read_bytes())==digest
    for key,rows in inputs['builds'].items():
        for item in rows:
            raw=files[prefix+item['member']]
            assert sha(raw)==item['sha256'] and raw==expected_source(item,old,tt,select,context),item['member']
    expected=[]
    for opt,repeats in [('O2',5),('O0',1)]:
        for case in CASES:
            for repeat in range(repeats):
                for arm in (['legacy','current']if repeat%2==0 else['current','legacy']):expected.append((opt,case,repeat,arm))
    assert [(r['opt'],r['case'],r['repeat'],r['arm'])for r in report['runs']]==expected
    summary=[]
    for opt in ['O2','O0']:
        for case,(name,days)in CASES.items():
            traces={};arms={}
            for arm in ['legacy','current']:
                records=[r for r in report['runs']if r['opt']==opt and r['case']==case and r['arm']==arm]
                for r in records:
                    label=prefix+f"{opt}-{case}-{r['repeat']}-{arm}"
                    assert r['returncode']==0 and r['steps']==days*200
                    assert sha(files[label+'/stdout'])==r['stdout_sha256']
                    assert sha(files[label+'/stderr'])==r['stderr_sha256']
                    timing=re.search(rb'CPU=\s*(\S+) WALL=\s*(\S+)',files[label+'/stderr']);assert timing
                    assert float(timing[1])==r['core_cpu']>0 and float(timing[2])==r['core_wall']>0
                    assert r['trace_sha256']==records[0]['trace_sha256']
                    assert r['stdout_sha256']==records[0]['stdout_sha256']
                raw=decode(files,prefix+f'{opt}-{case}-0-{arm}')
                assert sha(raw)==records[0]['trace_sha256']
                trace=np.frombuffer(raw,dtype=DTYPE);assert len(trace)==days*200
                for field in DTYPE.names:assert np.isfinite(trace[field]).all()
                assert np.abs(trace['mass']).max()<=1e-12
                assert int(trace['nl'].sum())==records[0]['nonlinear_iterations']
                assert float(np.abs(trace['mass']).max())==records[0]['max_mass_cm']
                traces[arm]=trace
                cpu=[r['core_cpu']for r in records]
                arms[arm]=dict(cpu_seconds=cpu,median_cpu_seconds=statistics_median(cpu),
                    min_cpu_seconds=min(cpu),max_cpu_seconds=max(cpu),steps=len(trace),
                    nonlinear_iterations=int(trace['nl'].sum()),max_mass_cm=max(r['max_mass_cm']for r in records))
            l,c=traces['legacy'],traces['current']
            for field in ['step','dt','root','drain']:assert np.array_equal(l[field],c[field])
            delta={field:float(np.abs(c[field]-l[field]).max())for field in DTYPE.names}
            assert delta['h']<=1e-8 and delta['theta']<=1e-10
            assert all(delta[k]<=1e-8 for k in ['pond','gwl','top','bottom'])
            summary.append(dict(opt=opt,case=case,name=name,days=days,historical_max_abs=delta,arms=arms,
                current_over_431_cpu=arms['current']['median_cpu_seconds']/arms['legacy']['median_cpu_seconds']))
    assert report['summary']==summary
    result=dict(status='MATCHED_CURRENT_431_RAW_TRACE_REPLAY_PASS',native_processes=96,
        physical_rows=sum(r['steps']for r in report['runs']if r['repeat']==0),
        maximum_historical_head_difference_cm=max(r['historical_max_abs']['h']for r in summary),
        maximum_mass_cm=max(a['max_mass_cm']for r in summary for a in r['arms'].values()),
        O2_summary=[r for r in summary if r['opt']=='O2'],scope=report['scope'])
    if not prefix and 'HISTORICAL_CONTEXT.json'in files:
        prior=json.loads(files['HISTORICAL_CONTEXT.json'])
        result['historical_preserved']=verify(files,'historical/',prior['baseline'])
    return result
def statistics_median(values):
    import statistics
    return statistics.median(values)
def seal(folder,previous_run=None,previous_proof=None):
    files={'RESULT.json':(folder/'RESULT.json').read_bytes()}
    report=json.loads(files['RESULT.json']);old,tt,select=authority()
    inputs=dict(authorities={p:sha((ROOT/p).read_bytes())for p in AUTH},builds={})
    for key,meta in report['builds'].items():
        base=folder/key
        files[key+'/INPUTS.json']=(base/'INPUTS.json').read_bytes()
        if key.startswith('legacy'):
            paths=list(dict.fromkeys(v for cmd in meta['commands']for v in cmd if v.endswith(('.f90','.for'))))
        else:
            paths=json.loads(files[key+'/INPUTS.json'])['ordered_sources']
        rows=[]
        for i,text in enumerate(paths):
            path=Path(text);raw=path.read_bytes()
            if path.is_relative_to(ROOT):item=dict(kind='repository',path=path.relative_to(ROOT).as_posix())
            elif '/selected/'in text:item=dict(kind='selected',path='SWAP/'+path.name)
            elif '/tt/TTUTIL/'in text:item=dict(kind='ttutil',path='TTUTIL/'+text.split('/tt/TTUTIL/',1)[1])
            elif path.name=='stubs.f90':item=dict(kind='generated_grid',path='stubs.f90')
            else:
                assert path.name=='trajectory_driver.f90'
                item=dict(kind='generated_driver',path=path.name)
            assert raw==expected_source(item,old,tt,select),text
            item.update(member=f'compiled/{key}/{i:03d}-{path.name}',sha256=sha(raw))
            files[item['member']]=raw;rows.append(item)
        inputs['builds'][key]=rows
        for path in base.glob('*.stdout'):files['build-logs/'+key+'/'+path.name]=path.read_bytes()
        for path in base.glob('*.stderr'):files['build-logs/'+key+'/'+path.name]=path.read_bytes()
        if (base/'build.log').exists():files['build-logs/'+key+'/build.log']=(base/'build.log').read_bytes()
    files['COMPILED_INPUTS.json']=(json.dumps(inputs,indent=2)+'\n').encode()
    codecs={}
    for r in report['runs']:
        label=f"{r['opt']}-{r['case']}-{r['repeat']}-{r['arm']}"
        for stream in ['stdout','stderr']:files[label+'/'+stream]=(folder/label/stream).read_bytes()
        if r['repeat']==0:
            path=folder/label/('legacy_trajectory.bin'if r['arm']=='legacy'else'trajectory.bin')
            raw=path.read_bytes();assert sha(raw)==r['trace_sha256']
            rows=np.frombuffer(raw,dtype=np.uint8).reshape(-1,DTYPE.itemsize)
            base_label=f"O2-{r['case']}-0-legacy"
            if label==base_label:
                encoded=rows.copy();encoded[1:]=np.bitwise_xor(rows[1:],rows[:-1])
                codecs[label]=dict(base=None)
            else:
                base=(folder/base_label/'legacy_trajectory.bin').read_bytes()
                assert len(raw)==len(base)
                encoded=np.bitwise_xor(rows,np.frombuffer(base,np.uint8).reshape(-1,DTYPE.itemsize))
                codecs[label]=dict(base=base_label)
            files[label+'/trace.xor-byteplanes']=encoded.T.copy().tobytes()
    if previous_run:
        assert previous_proof
        raw=previous_proof.read_bytes()
        index=json.loads(previous_proof.with_name(NAME+'.index.json').read_text())
        assert sha(raw)==index['sha256']and len(raw)==index['bytes']
        with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as tar:
            for m in tar.getmembers():
                assert m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts
                if m.name.endswith('trace.xor-byteplanes')or m.name in ['MANIFEST.json','TRACE_ENCODING.json','ASSESSMENT.json','CONTROLS.json']:continue
                files['historical/'+m.name]=tar.extractfile(m).read()
        prior=json.loads(files['historical/RESULT.json'])
        files['HISTORICAL_CONTEXT.json']=(json.dumps(dict(baseline=prior['baseline'],prior_capsule=index,
            scope='Actual earlier96 native observations and frozen compiled sources; not current-source qualification'),indent=2)+'\n').encode()
        for r in prior['runs']:
            if r['repeat']:continue
            label=f"{r['opt']}-{r['case']}-0-{r['arm']}"
            name='legacy_trajectory.bin'if r['arm']=='legacy'else'trajectory.bin'
            raw=(previous_run/label/name).read_bytes();assert sha(raw)==r['trace_sha256']
            current=(folder/label/name).read_bytes()
            if sha(raw)==sha(current):
                files['historical/'+label+'/trace.xor-byteplanes']=b''
                codecs['historical/'+label]=dict(base=label,alias=True)
                continue
            rows=np.frombuffer(raw,np.uint8).reshape(-1,DTYPE.itemsize)
            base_label=f"O2-{r['case']}-0-legacy"
            base=(folder/base_label/'legacy_trajectory.bin').read_bytes();assert len(base)==len(raw)
            encoded=np.bitwise_xor(rows,np.frombuffer(base,np.uint8).reshape(-1,DTYPE.itemsize))
            files['historical/'+label+'/trace.xor-byteplanes']=encoded.T.copy().tobytes()
            codecs['historical/'+label]=dict(base=base_label)
    files['TRACE_ENCODING.json']=(json.dumps(codecs,indent=2)+'\n').encode()
    for name in ['study_perf01_current_431.py','verify_perf01_current_431.py']:
        files['recipes/'+name]=(ROOT/'benchmarks/performance'/name).read_bytes()
    for name in ['perf01-current-431-build.stdout','perf01-current-431-build.stderr','perf01-current-431-native.stdout','perf01-current-431-native.stderr']:
        files['controller/'+name]=(Path('/tmp')/name).read_bytes()
    for suffix in ['stdout','stderr']:
        path=Path('/tmp/perf01-current-431-final.'+suffix)
        if path.exists():files['controller/'+path.name]=path.read_bytes()
    assessment=verify(files)
    controls=[]
    selected=[('missing stdout','O2-1-0-legacy/stdout','missing'),
        ('changed native clock','O2-1-0-legacy/stderr','bytes'),
        ('changed full physical trace','O2-1-0-current/trace.xor-byteplanes','bytes'),
        ('changed compiled source',inputs['builds']['current-O2'][0]['member'],'bytes'),
        ('missing process','RESULT.json','run'),('changed median','RESULT.json','median')]
    if previous_run:
        historical=json.loads(files['historical/COMPILED_INPUTS.json'])
        head=next(r['member']for r in historical['builds']['current-O2']if r['path']=='src/legacy/b1_10_port/headcalc.f90')
        selected += [('changed historical compiled source','historical/'+head,'bytes'),
            ('missing historical native clock','historical/O2-1-0-legacy/stderr','missing')]
    for label,path,kind in selected:
        bad=dict(files)
        if kind=='missing':bad.pop(path)
        elif kind=='bytes':bad[path]=bad[path]+b'!'
        else:
            data=json.loads(bad[path])
            if kind=='run':data['runs'].pop()
            else:data['summary'][0]['arms']['current']['median_cpu_seconds']+=1
            bad[path]=json.dumps(data).encode()
        try:verify(bad)
        except(AssertionError,KeyError,ValueError):controls.append(label)
        else:raise AssertionError('accepted '+label)
    assert len(controls)==(8 if previous_run else 6)
    initial=Path('/tmp/perf01-current-431-initial-packing')
    for suffix in ['index.json','json']:
        path=initial/(NAME+'.'+suffix)
        if path.exists():files['packing/initial-row-codec.'+suffix]=path.read_bytes()
    files['ASSESSMENT.json']=(json.dumps(assessment,indent=2)+'\n').encode()
    files['CONTROLS.json']=(json.dumps(controls,indent=2)+'\n').encode()
    files['MANIFEST.json']=(json.dumps({p:sha(raw)for p,raw in sorted(files.items())},indent=2)+'\n').encode()
    archive=ROOT/('benchmarks/performance/'+NAME+'.tar.xz')
    with tarfile.open(archive,'w:xz',preset=3)as tar:
        for name,raw in sorted(files.items()):
            info=tarfile.TarInfo(name);info.size=len(raw);tar.addfile(info,io.BytesIO(raw))
    raw=archive.read_bytes();index=dict(sha256=sha(raw),bytes=len(raw),members=len(files),trace_encoding='Byte planes after bytewise XOR: original O2 legacy versus prior record, other traces versus same-case original O2 legacy; exact native SHA256 verified after decoding')
    archive.with_name(NAME+'.index.json').write_text(json.dumps(index,indent=2)+'\n')
    result=dict(assessment=assessment,controls=controls,evidence=dict(path=str(archive.relative_to(ROOT)),**index))
    archive.with_name(NAME+'.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('evidence',type=Path);ap.add_argument('--seal',action='store_true')
    ap.add_argument('--previous-run',type=Path);ap.add_argument('--previous-proof',type=Path);a=ap.parse_args()
    if a.seal:return seal(a.evidence,a.previous_run,a.previous_proof)
    index=json.loads(a.evidence.with_name(NAME+'.index.json').read_text())
    if a.evidence.exists():raw=a.evidence.read_bytes()
    else:
        chunks=[]
        for i,part in enumerate(index['parts']):
            assert part['path']==a.evidence.name+f'.part{i:03d}'
            chunk=a.evidence.with_name(part['path']).read_bytes()
            assert sha(chunk)==part['sha256']and len(chunk)==part['bytes']
            chunks.append(chunk)
        raw=b''.join(chunks)
    assert sha(raw)==index['sha256']and len(raw)==index['bytes']
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as tar:
        members=tar.getmembers();assert len(members)==index['members']==len({m.name for m in members})
        assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members)
        files={m.name:tar.extractfile(m).read()for m in members}
    manifest=json.loads(files['MANIFEST.json']);assert set(manifest)==set(files)-{'MANIFEST.json'}
    for path,digest in manifest.items():assert sha(files[path])==digest,path
    print(json.dumps(verify(files),indent=2))
if __name__=='__main__':main()
