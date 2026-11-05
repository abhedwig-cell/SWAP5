"""Cap-only temporal diagnosis on the exact qualified composed native O2 binary."""
import argparse,io,json,os,re,subprocess,tarfile,zipfile
from pathlib import Path
import pressure_film_evidence as parent
import film_rotation as runner

ROOT=parent.ROOT;BASE=parent.BASE;sha=parent.sha
REG='COMPOSED_TEMPORAL_PREREGISTRATION_20261105.json'
CAPS=(.005,.0025);DAYS=(120,365,494,524,537,566,583,584)
PATTERN=rb'(?im)^(\s*DTMAX\s*=\s*)([\d.eE+\-]+)'


def cap_input(raw,cap):
    assert cap in CAPS
    matches=re.findall(PATTERN,raw);assert len(matches)==1 and float(matches[0][1])==.01
    changed=re.sub(PATTERN,lambda m:m[1]+str(cap).encode(),raw)
    assert re.sub(PATTERN,lambda m:m[1]+b'CAP',raw)==re.sub(PATTERN,lambda m:m[1]+b'CAP',changed)
    return changed


def inherited(platform,verify=True):
    assert platform in ('windows','posix')
    if platform=='windows':
        record=json.loads((BASE/'PRESSURE_FILM_WINDOWS_O2_20261105.json').read_text())
        raw=(BASE/'PRESSURE_FILM_WINDOWS_O2_20261105.tar.xz').read_bytes()
    else:
        manifest=json.loads((BASE/'PRESSURE_FILM_POSIX_20261105.json').read_text());pin=manifest['original_artifacts']['O2']
        zipped=(BASE/pin['archive']).read_bytes();assert sha(zipped)==pin['archive_sha256']
        with zipfile.ZipFile(io.BytesIO(zipped))as z:
            record=json.loads(z.read('pressure-film/O2/CAPSULE.json'));raw=z.read('pressure-film/O2/CAPSULE.tar.xz')
    assert sha(raw)==record['archive_sha256'] and record['qualification_dependencies']==parent.dependencies()
    assert record['production_admission']is False and record['whole_scientific_admission']is False
    with tarfile.open(fileobj=io.BytesIO(raw))as t:
        members=t.getmembers();assert all(m.isfile()and parent.prior.safe(m.name)for m in members)
        files={m.name:t.extractfile(m).read()for m in members}
    assert len(files)==len(members)and set(files)==set(record['files_sha256'])
    assert all(sha(b)==record['files_sha256'][n]for n,b in files.items())
    parent.audit.source_binding(files,'O2')
    if verify:parent.read_capsule(raw,record,'O2')
    return files,dict(platform=platform,archive_sha256=sha(raw),qualification_dependencies=record['qualification_dependencies'])


def materialize(files,out,cap,platform):
    out.mkdir();exe=out/('model.exe'if platform=='windows'else'model')
    original='O2/build/'+('swap5_hupsel_germination.exe'if platform=='windows'else'swap5_hupsel_germination')
    exe.write_bytes(files[original]);exe.chmod(exe.stat().st_mode|0o100)
    build=json.loads(files['O2/build/BUILD.json']);assert sha(exe.read_bytes())==build['executable_sha256']
    inputs=out/'inputs';inputs.mkdir()
    pins=json.loads((BASE/'PRESSURE_DIAGNOSTIC_INPUTS_20261104.json').read_text())['files_sha256']
    for name,pin in pins.items():
        raw=files['O2/full1096/'+name];assert sha(raw)==pin
        (inputs/name).write_bytes(cap_input(raw,cap)if name=='swap.swp'else raw)
    return exe,inputs


def cross_cap_refusal(exe,inputs,case,out,cap):
    out.mkdir();other=next(x for x in CAPS if x!=cap)
    for item in inputs.iterdir():(out/item.name).write_bytes(item.read_bytes())
    raw=(inputs/'swap.swp').read_bytes()
    assert len(re.findall(PATTERN,raw))==1
    (out/'swap.swp').write_bytes(re.sub(PATTERN,lambda m:m[1]+str(other).encode(),raw))
    seed=case/'checkpoint-583.bin';cmd=json.loads((case/'START.json').read_text())['command'][:]
    cmd[2]=str(seed);env=dict(os.environ,OMP_NUM_THREADS='1');env.pop('SWAP5_DIAG_PREDECESSOR',None)
    p=subprocess.run(cmd,cwd=out,env=env,capture_output=True,timeout=30)
    (out/'stdout').write_bytes(p.stdout);(out/'stderr').write_bytes(p.stderr)
    result=dict(command=cmd,returncode=p.returncode,seed_sha256=sha(seed.read_bytes()),cap=cap,changed_cap=other,executable_sha256=sha(exe.read_bytes()),diagnostic_override=False)
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    assert p.returncode==1 and b'source rotation envelope rejected before publication'in p.stdout+p.stderr
    assert not any((out/n).exists()for n in ('budget.csv','checkpoint.bin','crop.csv','state.csv'))


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cap',type=float,choices=CAPS,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    out=a.output.resolve();out.mkdir();os.environ['OMP_NUM_THREADS']='1';os.environ.pop('SWAP5_DIAG_PREDECESSOR',None)
    platform='windows'if os.name=='nt'else'posix';files,origin=inherited(platform)
    exe,inputs=materialize(files,out/'native',a.cap,platform)
    (out/'REGISTRATION.json').write_bytes((BASE/REG).read_bytes())
    (out/'ORIGIN.json').write_text(json.dumps(dict(origin,cap=a.cap,executable_sha256=sha(exe.read_bytes()),production_admission=False,whole_scientific_admission=False),indent=2)+'\n')
    case=runner.execute(exe,inputs,out/'prefix584',584,capture=DAYS);runner.ensure_captures(exe,inputs,case,out,DAYS)
    strict=runner.execute(exe,inputs,out/'strict584',584,seed=case/'checkpoint-583.bin');runner.exact_window(case,strict,584)
    cross_cap_refusal(exe,inputs,case,out/'cross-cap-refusal',a.cap)
    from composed_temporal_audit import audit
    result=audit(out,files,origin);(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)


if __name__=='__main__':main()
