"""Independent bounded reproduction of the preregistered B0 observation."""
from pathlib import Path
import hashlib, json, subprocess, shutil, time, os, sys, importlib.util, types, argparse, zipfile

HERE = Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument('--evidence-root',type=Path,required=True)
parser.add_argument('--compiler-root',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
OLD = args.evidence_root.resolve()
COMPILER=args.compiler_root.resolve()
OUT = args.output.resolve()
OUT.mkdir(exist_ok=True)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
identity = json.loads((OLD/'BUILD_IDENTITY.json').read_text())
manifest = OLD/'file-manifest.sha256'
canonical_manifest=manifest.read_bytes().rstrip(b'\n')+b'\n'
assert hashlib.sha1(b'blob '+str(len(canonical_manifest)).encode()+b'\0'+canonical_manifest).hexdigest()=='be8862be45415e49fc366f98d9de76c8b14b1fae'
assert sha(OLD/'SWAP.ZIP') == identity['archive_sha256']
archive=zipfile.ZipFile(OLD/'SWAP.ZIP')
raw_count = 0
for line in manifest.read_text().splitlines():
    if not line or line.startswith('#'): continue
    digest, size, name = line.split()
    data=archive.read(name)
    assert len(data)==int(size) and hashlib.sha256(data).hexdigest()==digest,name
    raw_count += 1
sys.modules['reference_identity'] = types.SimpleNamespace(verify_b0_archive=None)
spec=importlib.util.spec_from_file_location('b0runner', OLD/'evidence/tools/vq/b0_source_runner.py')
runner=importlib.util.module_from_spec(spec); spec.loader.exec_module(runner)
for name, digest in identity['selected_sources'].items():
    p=OLD/'build/swap-selected'/name
    assert sha(p)==digest
    raw=archive.read('SWAP/'+name).decode('cp1252')
    assert p.read_bytes()==runner.select_dec_branches(raw).encode('cp1252'), name
for name, digest in identity['objects'].items():
    assert sha(OLD/'build/swap-obj'/name)==digest, name
assert sha(OLD/'build/ttutil-obj/libttutil.a')==identity['ttutil_library_sha256']
assert sha(COMPILER/'root/usr/bin/x86_64-linux-gnu-gfortran-14')==identity['compiler_sha256']
assert sha(COMPILER/'root/usr/libexec/gcc/x86_64-linux-gnu/14/f951')==identity['frontend_sha256']
for item in json.loads((OLD/'CASE_IDENTITY.json').read_text()):
    data=(OLD/'run-control'/item['path']).read_bytes()
    if item['path']=='swap.swp':
        assert data.count(b'TEND = 1998-01-02')==1
        data=data.replace(b'TEND = 1998-01-02',b'TEND = 1999-04-26')
    assert hashlib.sha256(data).hexdigest()==item['sha256'],item['path']

env=os.environ.copy()
env['PATH']=str(COMPILER/'bin')+':'+env['PATH']
env['GCC_EXEC_PREFIX']=str(COMPILER/'root/usr/lib/gcc/')
env['COMPILER_PATH']=str(COMPILER/'root/usr/libexec/gcc/x86_64-linux-gnu/14')
env['LIBRARY_PATH']=str(COMPILER/'root/usr/lib/gcc/x86_64-linux-gnu/14')+':/usr/lib/gcc/x86_64-linux-gnu/14'
logs=[]
def cmd(args, cwd=OUT):
    start=time.monotonic()
    r=subprocess.run(args,cwd=cwd,env=(os.environ.copy() if args[0]=='gcc' else env),capture_output=True,text=True,timeout=40)
    logs.append(dict(command=list(map(str,args)),returncode=r.returncode,seconds=time.monotonic()-start,stdout=r.stdout,stderr=r.stderr))
    (OUT/'BUILD.json').write_text(json.dumps(logs,indent=2))
    assert r.returncode==0,r.stderr

flags=['gfortran',*identity['flags'],'-I',str(OLD/'build/swap-obj'),'-I',str(OLD/'build/ttutil-obj')]
cmd(flags+['-c',str(OLD/'build/swap-selected/headcalc.f90'),'-o',str(OUT/'control_headcalc.o')])
cmd(flags+['-c',str(OLD/'observer/headcalc.f90'),'-o',str(OUT/'observer_headcalc.o')])
cmd(['gcc','-O2','-c',str(OLD/'observer/fork.c'),'-o',str(OUT/'fork.o')])
objects=[str(p) for p in sorted((OLD/'build/swap-obj').glob('*.o')) if p.name!='headcalc.o']
for label, extra in [('control',[]),('observer',[str(OUT/'fork.o')])]:
    cmd(['gfortran','-B/usr/lib/gcc/x86_64-linux-gnu/14/','-o',str(OUT/label),*objects,str(OUT/(label+'_headcalc.o')),*extra,str(OLD/'build/ttutil-obj/libttutil.a')])

results=[]
for label in ['control','observer']:
    case=OUT/('run-'+label);case.mkdir(exist_ok=True)
    for item in json.loads((OLD/'CASE_IDENTITY.json').read_text()):
        p=Path(item['path']);(case/p).parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(OLD/'run-control'/p,case/p)
    # Reuse precisely the preregistered short-window/output-only input.
    shutil.copy2(OLD/'run-control-output/swap.swp',case/'swap.swp')
    start=time.monotonic()
    r=subprocess.run([str(OUT/label),'./swap.swp'],cwd=case,env=env,capture_output=True,text=True,timeout=20)
    (case/'stdout.txt').write_text(r.stdout+r.stderr)
    assert r.returncode==100 and (case/'swap.ok').exists()
    results.append(dict(label=label,seconds=time.monotonic()-start,returncode=r.returncode,exe_sha256=sha(OUT/label),input_sha256=sha(case/'swap.swp')))

def normalize(p):
    return b'\n'.join(l for l in p.read_bytes().splitlines() if not l.startswith(b'* Generated at:'))
comparisons=[]
for filename in ['result_output.csv','macrogeom.csv','soilshrinkchar.csv','result.end']:
    a=OUT/'run-control'/filename;b=OUT/'run-observer'/filename;c=OLD/'run-control-output'/filename
    assert normalize(a)==normalize(b)==normalize(c),filename
    comparisons.append(dict(file=filename,parent_observer_equal=True,prior_control_equal=True,byte_exact=a.read_bytes()==b.read_bytes()))
assert (OUT/'run-observer/audit_samples.txt').read_bytes()==(OLD/'run-observer/audit_samples.txt').read_bytes()
groups=[]
for line in (OUT/'run-observer/audit_samples.txt').read_text().splitlines():
    k,*v=line.split()
    if k=='META':groups.append({})
    groups[-1][k]=list(map(float,v))
summary=dict(raw_source_members_verified=raw_count,verified_reused_objects=len(objects),freshly_compiled=['control headcalc','observer headcalc','fork helper'],
 baseline='f2377211d2be58d03d96e50fb0a6bc35ced3c90f',prior_preregistration_commit='8ad3a40619b58e614e8c694639a3735c41329911',
 source_archive_sha256=identity['archive_sha256'],runs=results,comparisons=comparisons,observations=len(groups),
 prior_sample_vectors_byte_exact=True,local_failures=sum(g['RESIDUAL'][2]>g['META'][6] for g in groups),
 total_failures=sum(abs(g['RESIDUAL'][3])>g['META'][7] for g in groups),
 max_fresh_local=max(g['RESIDUAL'][2] for g in groups),max_fresh_total=max(abs(g['RESIDUAL'][3]) for g in groups),
 max_attribution_remainder=max(g['EXCHANGE'][1] for g in groups),
 scope='Independent O2 reproduction of existing two hypotheses. No new B1, no B0 day438, no full Jacobian/rollback qualification. Unchanged non-headcalc objects reused only after hash verification.')
(OUT/'VERIFICATION.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
