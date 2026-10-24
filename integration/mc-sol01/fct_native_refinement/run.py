"""Prepare and execute bounded native experiments; never changes the kernel."""
import argparse,base64,hashlib,io,json,re,stat,subprocess,tarfile,time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
MESH='1 1 40.0 20\n2 2 2.0 1\n3 2 78.0 20'

def fixture():
    index=json.loads((HERE.parent/'fct_native_domain/NATIVE_EVIDENCE_INDEX.json').read_text())
    raw=base64.b64decode((HERE.parent/'fct_native_domain/NATIVE_EVIDENCE.tar.xz.b64').read_bytes())
    assert sha(raw)==index['sha256']
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:
        prefix='native-o2/1.0-1.0-unequal/'
        return {p:t.extractfile(prefix+p).read().decode() for p in ['input.nml','project.swp']}

def prepare(original,factor,days,tolerance,exponent):
    text=original['input.nml'];swp=original['project.swp'];assert swp.count(MESH)==1
    mesh=f'1 1 40.0 {20*factor}\n2 2 2.0 {factor}\n3 2 78.0 {20*factor}'
    swp=swp.replace(MESH,mesh)
    swp=re.sub(r'(?im)^FREXP\s*=.*$',f'FREXP={exponent}',swp)
    assert len(re.findall(r'(?im)^TSCF=1.0$',swp))==1
    def replace(old,new):
        nonlocal text
        assert text.count(old)>0,old;text=text.replace(old,new)
    replace('41*.1',f'{41*factor}*.1')
    replace('41*.00005',f'{41*factor}*{.00005/factor:.17g}')
    replace('upper_layer_bottom_node=20',f'upper_layer_bottom_node={20*factor}')
    replace('freundlich_exponent=1.0',f'freundlich_exponent={exponent}')
    replace('temporal_tolerance=.001',f'temporal_tolerance={tolerance:.17g}')
    replace('ends_day=.1,.2,.3,.4','ends_day='+','.join(f'{days*j/4:.17g}' for j in range(1,5)))
    return {'input.nml':text,'project.swp':swp}

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--build',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--phase',choices=['pilot','refinement','duration'],required=True)
    a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    build=a.build.resolve();meta=json.loads((build/'build.json').read_text());exe=build/'native_fct'
    assert meta['status']=='BUILT_RESEARCH_NATIVE' and sha(exe.read_bytes())==meta['executable_sha256']
    for p,h in meta['inputs'].items():assert sha((ROOT/p).read_bytes())==h,p
    for p,h in meta['generated'].items():assert sha((build/p).read_bytes())==h,p
    for p in ['generate.py','build_native.py']:
        assert (HERE.parent/'fct_native_domain'/p).read_bytes()==subprocess.check_output(['git','show','93f12afe:integration/mc-sol01/fct_native_domain/'+p],cwd=ROOT)
    specs={'pilot':[(1,.4,.001,1.)],
           'refinement':[(f,.4,.001,1.) for f in [1,2,4]]+[(1,.4,t,1.) for t in [.0005,.00025]],
           'duration':[(1,4.,.001,e) for e in [.5,1.,2.]]}[a.phase]
    r=dict(status='RUNNING',phase=a.phase,baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
           build=meta,runner_sha256=sha(Path(__file__).read_bytes()),cases=[])
    def save():(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n')
    original=fixture();save()
    for factor,days,tol,exp in specs:
        name=f'f{factor}-d{days}-t{tol}-e{exp}';case=out/name;case.mkdir()
        for p,text in prepare(original,factor,days,tol,exp).items():(case/p).write_text(text)
        record=dict(name=name,factor=factor,days=days,tolerance=tol,exponent=exp,events=[])
        r['cases'].append(record);save()
        labels=[('full','-',4)]
        if a.phase=='duration':labels += [('split','-',2),('resume',str(case/'split/restart.bin'),4)]
        for label,restart,stop in labels:
            folder=case/label;folder.mkdir();exe.chmod(exe.stat().st_mode|stat.S_IXUSR)
            cmd=[str(exe),str(case/'input.nml'),restart,str(stop),str(case/'project.swp')]
            start=time.monotonic();censored=False
            try:
                cp=subprocess.run(cmd,cwd=folder,capture_output=True,timeout=180)
                stdout,stderr,rc=cp.stdout,cp.stderr,cp.returncode
            except subprocess.TimeoutExpired as exc:
                stdout,stderr,rc=exc.stdout or b'',exc.stderr or b'',None;censored=True
            (folder/'stdout').write_bytes(stdout);(folder/'stderr').write_bytes(stderr)
            e=dict(label=label,command=cmd,seconds=time.monotonic()-start,returncode=rc,censored=censored)
            record['events'].append(e);save();print(json.dumps(dict(case=name,**e)),flush=True)
            if rc!=0:break
    r['status']='EXECUTIONS_COMPLETE' if all(len(c['events'])==(3 if a.phase=='duration' else 1) and all(e['returncode']==0 and not e['censored'] for e in c['events']) for c in r['cases']) else 'FAILED_OR_CENSORED'
    save()
    if r['status']!='EXECUTIONS_COMPLETE':raise SystemExit(1)

if __name__=='__main__':main()
