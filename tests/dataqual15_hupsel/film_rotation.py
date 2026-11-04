"""Actual complete private default rotation using the sealed native closure."""
import argparse,copy,hashlib,io,json,os,re,shutil,struct,subprocess,tarfile,time,zipfile,zlib
from pathlib import Path,PurePosixPath,PureWindowsPath
import film_runtime as runtime
import film_runtime_evidence as inherited
from film_runtime_profiles import profile4
from film_runtime_audit import rows

ROOT=runtime.ROOT;BASE=runtime.BASE
REG='FILM_ROTATION_PREREGISTRATION_20261104.json'
sha=lambda raw:hashlib.sha256(raw).hexdigest()


def closure_files(opt,platform):
    manifest=BASE/('FILM_RUNTIME_WINDOWS_20261104.json'if platform=='windows'else'FILM_RUNTIME_POSIX_20261104.json')
    record=json.loads(manifest.read_text())
    assert record['production_admission']is False and record['whole_scientific_admission']is False
    if platform=='windows':
        archive=BASE/record['archive'];raw=archive.read_bytes();assert sha(raw)==record['archive_sha256']
        with tarfile.open(fileobj=io.BytesIO(raw))as t:
            members=t.getmembers();assert all(m.isfile()for m in members)
            files={m.name:t.extractfile(m).read()for m in members}
        assert len(files)==len(members)and set(files)==set(record['files_sha256'])
        assert all(sha(raw)==record['files_sha256'][n]for n,raw in files.items())
    else:
        pin=record['original_artifacts'][opt];archive=BASE/pin['archive'];raw=archive.read_bytes();assert sha(raw)==pin['archive_sha256']
        with zipfile.ZipFile(io.BytesIO(raw))as z:
            names=[n for n in z.namelist()if n.startswith('film-runtime/')and not n.endswith('/')]
            assert len(names)==len(set(names));files={n.removeprefix('film-runtime/'):z.read(n)for n in names}
        assert all(sha(raw)==record['files_sha256'][n]for n,raw in files.items())
    assert all(not PurePosixPath(n).is_absolute()and not PureWindowsPath(n).drive and '..'not in PurePosixPath(n).parts for n in files)
    return files,dict(manifest=manifest.name,manifest_sha256=sha(manifest.read_bytes()),archive=archive.name,archive_sha256=sha(raw if isinstance(raw,bytes)else archive.read_bytes()))


def materialize(out,opt,platform,compiler):
    files,origin=closure_files(opt,platform);out.mkdir();builds={}
    for observed in ([False,True]if opt=='O2'else[False]):
        original=inherited.source_binding(files,opt,observed)
        assert subprocess.check_output([str(compiler),'--version'],text=True).splitlines()[0]==original['compiler']
        variant='build-observed'if observed else'build';prefix=opt+'/'+variant+'/'
        folder=out/variant;folder.mkdir();sources=folder/'providers';sources.mkdir()
        old=original['baseline'];root=list(old['source_sha256'])[-1].replace('\\','/').removesuffix('/app/solute_project/main.f90')
        workspace=old['ttutil_archive'].replace('\\','/').removesuffix('/baseline-'+opt+'/libttutil.a')
        metadata=copy.deepcopy(original);relocated={};links=[]
        for i,(name,pin)in enumerate(original['source_sha256'].items()):
            raw=files[inherited.key(name,root,workspace)];assert sha(raw)==pin
            target=sources/(str(i)+'-'+PurePosixPath(name.replace('\\','/')).name);target.write_bytes(raw)
            relocated[str(target)]=pin;links.append(dict(original=name,materialized=str(target),sha256=pin))
        metadata['source_sha256']=relocated
        assert {k:v for k,v in metadata.items()if k!='source_sha256'}=={k:v for k,v in original.items()if k!='source_sha256'}
        (folder/'ORIGINAL_BUILD.json').write_bytes(files[prefix+'BUILD.json'])
        (folder/'BUILD.json').write_text(json.dumps(metadata,indent=2)+'\n')
        name='swap5_hupsel_germination.exe'if platform=='windows'else'swap5_hupsel_germination'
        executable=folder/name;executable.write_bytes(files[prefix+name]);assert sha(executable.read_bytes())==original['executable_sha256']
        if platform=='posix':executable.chmod(executable.stat().st_mode|0o100)
        receipt=dict(origin,optimization=opt,observed=observed,original_build_sha256=sha(files[prefix+'BUILD.json']),executable_sha256=original['executable_sha256'],source_relocation=links,
                     scope='EXACT_EXISTING_COMPLETE_COHERENT_NATIVE_CLOSURE_REUSED_NO_RECOMPILATION_NO_STATE_CONVERSION')
        (folder/'MATERIALIZATION.json').write_text(json.dumps(receipt,indent=2)+'\n');builds[variant]=executable
    previous=out/'PREVIOUS584';previous.mkdir()
    for variant in ('unobserved584','observed584')if opt=='O2'else('unobserved584',):
        target=previous/variant;target.mkdir()
        for name in ('checkpoint.bin','budget.csv','crop.csv','state.csv'):(target/name).write_bytes(files[opt+'/'+variant+'/'+name])
    return builds


def execute(executable,inputs,out,end,seed=None,capture=()):
    out.mkdir();pins={}
    for item in inputs.iterdir():
        if item.suffix.lower()in('.nml','.swp','.crp','.dra','.met'):
            shutil.copyfile(item,out/item.name);pins[item.name]=sha(item.read_bytes())
    ends=[float(x)for x in re.search(r'^ends_day=(.*)$',(out/'input.nml').read_text(),re.M)[1].split(',')if x.strip()]
    stop=next(i+1 for i,value in enumerate(ends)if value==end)
    command=[str(executable),'input.nml',str(seed)if seed else'-',str(stop),'swap.swp','maize.crp']
    record=dict(scope='STRICT_OWN_BUILD_RESTART'if seed else'ORIGINAL_INPUT_INITIALIZATION',command=command,executable_sha256=sha(executable.read_bytes()),restart_sha256=sha(seed.read_bytes())if seed else None,inputs=pins,diagnostic_override=False,production_admission=False)
    (out/'START.json').write_text(json.dumps(record,indent=2)+'\n');env=dict(os.environ,OMP_NUM_THREADS='1');env.pop('SWAP5_DIAG_PREDECESSOR',None)
    start=time.monotonic();captured=[]
    with(out/'stdout').open('wb')as stdout,(out/'stderr').open('wb')as stderr:
        process=subprocess.Popen(command,cwd=out,env=env,stdout=stdout,stderr=stderr)
        while process.poll()is None:
            if time.monotonic()-start>7200:process.kill();process.wait();raise TimeoutError(str(out))
            if len(captured)<len(capture):
                try:
                    raw=(out/'checkpoint.bin').read_bytes();assert raw[:8]==b'S5HR0004'and zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0]
                    day=struct.unpack_from('=d',raw,8)[0]
                    if day in capture and day not in captured:
                        (out/f'checkpoint-{int(day)}.bin').write_bytes(raw);captured.append(day)
                except(OSError,AssertionError,struct.error):pass
            time.sleep(.002)
    record.update(returncode=process.returncode,seconds=time.monotonic()-start,captured=captured)
    (out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
    assert process.returncode==0,(out,(out/'stderr').read_text(errors='replace')[-2000:])
    raw=(out/'checkpoint.bin').read_bytes();assert profile4(raw)['day']==end
    if end in capture:(out/f'checkpoint-{end}.bin').write_bytes(raw)
    return out


def ensure_captures(executable,inputs,case,out,days):
    recovered=[]
    for day in days:
        if(case/f'checkpoint-{day}.bin').exists():continue
        genuine=execute(executable,inputs,out/f'recovered-own{day}',day)
        raw=(genuine/'checkpoint.bin').read_bytes();assert profile4(raw)['day']==day
        (case/f'checkpoint-{day}.bin').write_bytes(raw)
        recovered.append(dict(day=day,origin=str(genuine),checkpoint_sha256=sha(raw),scope='GENUINE_SAME_EXECUTABLE_ORIGINAL_INITIALIZATION_PREFIX'))
    (out/'CAPTURE_RECOVERY.json').write_text(json.dumps(recovered,indent=2)+'\n')


def exact_window(case,strict,end):
    expected=case/f'checkpoint-{end}.bin'
    assert(strict/'checkpoint.bin').read_bytes()==expected.read_bytes()
    for name in ('budget.csv','crop.csv'):
        suffix=rows(strict/name);assert suffix;key=next(iter(suffix[0]));whole={r[key]:r for r in rows(case/name)}
        assert all(r==whole[r[key]]for r in suffix)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--optimization',choices=['O0','O2'],required=True);parser.add_argument('--compiler',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();out=args.output.resolve();out.mkdir();platform='windows'if os.name=='nt'else'posix'
    registration=json.loads((BASE/REG).read_text());(out/'REGISTRATION.json').write_bytes((BASE/REG).read_bytes())
    scope=json.loads((ROOT/runtime.SCOPE).read_text());runtime.current_guard(scope)
    builds=materialize(out/'native',args.optimization,platform,args.compiler.resolve());inputs=runtime.inputs(out/'inputs');exe=builds['build']
    days=sorted(set(registration['profile_days']+registration['additional_capture_days']))
    case=execute(exe,inputs,out/'unobserved1096',1096,capture=days);ensure_captures(exe,inputs,case,out,days)
    previous=out/'native/PREVIOUS584/unobserved584'
    assert(case/'checkpoint-584.bin').read_bytes()==(previous/'checkpoint.bin').read_bytes()
    for name in ('budget.csv','crop.csv'):
        old=rows(previous/name);now=rows(case/name);assert now[:len(old)]==old
    restarts=out/'restarts';restarts.mkdir()
    for cut in registration['wet_cuts']:
        for first,last in ((cut-1,cut),(cut,cut+1)):
            strict=execute(exe,inputs,restarts/f'{first}-to-{last}',last,seed=case/f'checkpoint-{first}.bin');exact_window(case,strict,last)
    strict=execute(exe,inputs,restarts/'1095-to-1096',1096,seed=case/'checkpoint-1095.bin');exact_window(case,strict,1096)
    if'build-observed'in builds:
        observed=execute(builds['build-observed'],inputs,out/'observed1096',1096)
        for name in ('checkpoint.bin','budget.csv','crop.csv','state.csv'):assert(case/name).read_bytes()==(observed/name).read_bytes(),name
    from production_diagnostic_native import app_refusals
    from production_diagnostic_guards import qualify
    app_refusals(exe,case,out/'app-refusals');qualify(exe.parent,case,case/'checkpoint.bin',out/'owner-controls')
    runtime.current_guard(scope)
    (out/'EXECUTED.json').write_text(json.dumps(dict(status='ACTUAL_FULL1096_PRIVATE_DEFAULT_AND_STRICT_CUT_RESTARTS_EXECUTED_AUDIT_PENDING',optimization=args.optimization,platform=platform,production_admission=False,whole_scientific_admission=False),indent=2)+'\n')
    print('ACTUAL_FULL1096_AND_STRICT_CUT_RESTARTS_EXECUTED',args.optimization,flush=True)

if __name__=='__main__':main()
