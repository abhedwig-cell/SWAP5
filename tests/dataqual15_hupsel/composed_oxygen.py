"""Actual composed-runtime accepted-state observation, never numeric rebinding."""
import argparse,io,json,os,re,struct,subprocess,tarfile,time,zipfile,zlib
from pathlib import Path
import pressure_film_evidence as parent
import pressure_oxygen_observer as seams
import root_oxygen_observer as root
from root_oxygen_evidence import data
from film_runtime_profiles import profile4
from film_runtime_audit import rows
ROOT=parent.ROOT;BASE=parent.BASE;sha=parent.sha;REG='COMPOSED_OXYGEN_PREREGISTRATION_20261105.json'

def inherited(opt,platform,verify=True):
    if platform=='windows':
        record=json.loads((BASE/f'PRESSURE_FILM_WINDOWS_{opt}_20261105.json').read_text());raw=(BASE/f'PRESSURE_FILM_WINDOWS_{opt}_20261105.tar.xz').read_bytes()
    else:
        m=json.loads((BASE/'PRESSURE_FILM_POSIX_20261105.json').read_text());pin=m['original_artifacts'][opt];zipped=(BASE/pin['archive']).read_bytes();assert sha(zipped)==pin['archive_sha256']
        with zipfile.ZipFile(io.BytesIO(zipped))as z:record=json.loads(z.read(f'pressure-film/{opt}/CAPSULE.json'));raw=z.read(f'pressure-film/{opt}/CAPSULE.tar.xz')
    assert sha(raw)==record['archive_sha256']and record['qualification_dependencies']==parent.dependencies()and record['production_admission']is False and record['whole_scientific_admission']is False
    with tarfile.open(fileobj=io.BytesIO(raw))as t:
        members=t.getmembers();assert all(m.isfile()and parent.prior.safe(m.name)for m in members);files={m.name:t.extractfile(m).read()for m in members}
    assert len(files)==len(members)and set(files)==set(record['files_sha256'])and all(sha(b)==record['files_sha256'][n]for n,b in files.items())
    parent.audit.source_binding(files,opt)
    if verify:parent.read_capsule(raw,record,opt)
    return files,dict(platform=platform,optimization=opt,archive_sha256=sha(raw),qualification_dependencies=record['qualification_dependencies'])

def replacements(reg):
    d={root.MAIN:root.instrument((ROOT/root.MAIN).read_text(encoding='utf-8'))}
    if reg is not None:d[seams.BACKEND]=seams.backend((ROOT/seams.BACKEND).read_text(encoding='utf-8'),reg)
    return d

def compile_observed(files,opt,out,fc,reg=None):
    out.mkdir();providers=out/'providers';providers.mkdir();old=json.loads(files[opt+'/build/BUILD.json']);context=parent.audit.paths(old,opt)
    assert subprocess.check_output([str(fc),'--version'],text=True).splitlines()[0]==old['compiler']
    flags=[x for x in old['flags']if not x.startswith(('-I','-J'))]+['-I'+str(out),'-J'+str(out)];patches=replacements(reg);sources=[];objects=[];events=[]
    def execute(cmd):
        start=time.monotonic();p=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=300);i=len(events)
        (out/f'{i}.stdout').write_bytes(p.stdout);(out/f'{i}.stderr').write_bytes(p.stderr);events.append(dict(command=list(map(str,cmd)),returncode=p.returncode,seconds=time.monotonic()-start));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert p.returncode==0,p.stderr.decode(errors='replace')[-2000:]
    for i,(name,pin)in enumerate(old['source_sha256'].items()):
        raw=files[parent.audit.key(name,context,opt)];assert sha(raw)==pin
        relative=next((r for r in patches if name.replace('\\','/').endswith('/'+r)),None)
        after=patches[relative].encode()if relative else raw
        source=providers/(str(i)+'-'+Path(name).name);source.write_bytes(after);obj=out/(str(i)+'.o');execute([fc,*flags,'-c',source,'-o',obj]);objects.append(obj)
        sources.append(dict(original=name,source=source.relative_to(out).as_posix(),before_sha256=pin,after_sha256=sha(after),object=obj.name,object_sha256=sha(obj.read_bytes()),observation_patch=relative))
    assert len(objects)==236 and {s['observation_patch']for s in sources if s['observation_patch']}==set(patches)
    pub=old['publication_provider'];publication=out/'publication.o';library=out/'libttutil.a'
    publication.write_bytes(files[parent.audit.key(pub['object'],context,opt)]);library.write_bytes(files[parent.audit.key(old['ttutil_archive'],context,opt)])
    assert sha(publication.read_bytes())==pub['object_sha256']and sha(library.read_bytes())==old['archive_sha256']
    exe=out/('observed.exe'if os.name=='nt'else'observed');args=['-fopenmp']+(['-Wl,--stack,16777216']if os.name=='nt'else[])+list(map(str,objects))+[str(publication),str(library),'-o',str(exe)]
    rsp=out/'link.args';rsp.write_text('\n'.join('"'+s.replace('\\','/')+'"'for s in args)+'\n',encoding='utf-8');execute([fc,'@'+str(rsp)])
    record=dict(parent_build_sha256=sha(files[opt+'/build/BUILD.json']),compiler=old['compiler'],flags=flags,sources=sources,events=events,link_arguments=args,executable_sha256=sha(exe.read_bytes()),publication_sha256=sha(publication.read_bytes()),archive_sha256=sha(library.read_bytes()),source_scope='ALL236_COHERENT_REBUILD_ONLY_PROGRAM_BACKEND_BODY_OUTPUT_CHANGES',production_admission=False,whole_scientific_admission=False)
    (out/'BUILD.json').write_text(json.dumps(record,indent=2)+'\n');return exe

def execute(exe,inputs,seed,out,scope,capture=False):
    out.mkdir();pins={}
    for n,b in inputs.items():(out/n).write_bytes(b);pins[n]=sha(b)
    ends=[float(x)for x in re.search(r'^ends_day=(.*)$',inputs['input.nml'].decode(),re.M)[1].split(',')if x.strip()];stop=ends.index(584)+1
    cmd=[str(exe),'input.nml',str(seed),str(stop),'swap.swp','maize.crp'];record=dict(scope=scope,command=cmd,executable_sha256=sha(exe.read_bytes()),restart_sha256=sha(seed.read_bytes()),inputs=pins,diagnostic_override=False,production_admission=False)
    (out/'START.json').write_text(json.dumps(record,indent=2)+'\n');env=dict(os.environ,OMP_NUM_THREADS='1');env.pop('SWAP5_DIAG_PREDECESSOR',None);start=time.monotonic()
    with(out/'stdout').open('wb')as so,(out/'stderr').open('wb')as se:
        p=subprocess.Popen(cmd,cwd=out,env=env,stdout=so,stderr=se)
        while p.poll()is None:
            if time.monotonic()-start>7200:p.kill();p.wait();raise TimeoutError(str(out))
            if capture and not(out/'checkpoint-537.bin').exists():
                try:
                    raw=(out/'checkpoint.bin').read_bytes();assert raw[:8]==b'S5HR0004'and zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0]
                    if struct.unpack_from('=d',raw,8)[0]==537:(out/'checkpoint-537.bin').write_bytes(raw)
                except(OSError,AssertionError,struct.error):pass
            time.sleep(.002)
    record.update(returncode=p.returncode,seconds=time.monotonic()-start);(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');assert p.returncode==0,(out,(out/'stderr').read_text(errors='replace')[-2000:]);assert profile4((out/'checkpoint.bin').read_bytes())['day']==584
    if capture:assert profile4((out/'checkpoint-537.bin').read_bytes())['day']==537,'genuine own537 capture missing'
    return out

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();opt=a.optimization;fc=a.compiler.resolve();platform='windows'if os.name=='nt'else'posix'
    os.environ['OMP_NUM_THREADS']='1';os.environ.pop('SWAP5_DIAG_PREDECESSOR',None);files,origin=inherited(opt,platform)
    (out/'ORIGIN.json').write_text(json.dumps(origin,indent=2)+'\n');(out/'REGISTRATION.json').write_bytes((BASE/REG).read_bytes());native=out/'parent';native.mkdir()
    exe=native/('model.exe'if platform=='windows'else'model');exe.write_bytes(files[opt+'/build/'+('swap5_hupsel_germination.exe'if platform=='windows'else'swap5_hupsel_germination')]);exe.chmod(exe.stat().st_mode|0o100)
    seed=native/'checkpoint-524.bin';seed.write_bytes(files[opt+'/full1096/checkpoint-524.bin']);assert profile4(seed.read_bytes())['day']==524
    names=json.loads((BASE/'PRESSURE_DIAGNOSTIC_INPUTS_20261104.json').read_text())['files_sha256'];inputs={n:files[opt+'/full1096/'+n]for n in names};assert all(sha(inputs[n])==pin for n,pin in names.items())
    execute(exe,inputs,seed,out/'unobserved','STRICT_OWN_PARENT_BUILD_RESTART')
    body_scope='NUMERICALLY_IDENTICAL_BODY_ONLY_OBSERVATION_CODEC_CONTROL_NOT_SAME_BUILD_RESTART'
    observed=compile_observed(files,opt,out/'root-build',fc);execute(observed,inputs,seed,out/'root-whole',body_scope,True);execute(observed,inputs,out/'root-whole/checkpoint-537.bin',out/'root-own537','STRICT_OWN_OBSERVED_BUILD_RESTART')
    reg=seams.selected(data((out/'root-whole/root_accepted.dat').read_bytes(),9));(out/'SELECTED.json').write_text(json.dumps(reg,indent=2)+'\n')
    observed=compile_observed(files,opt,out/'forcing-build',fc,reg);execute(observed,inputs,seed,out/'whole',body_scope,True);execute(observed,inputs,out/'whole/checkpoint-537.bin',out/'own537','STRICT_OWN_OBSERVED_BUILD_RESTART')
    from composed_oxygen_audit import audit
    from matched_oxygen_evidence import replay
    from pressure_oxygen_evidence import partition_replay
    report,factors,finals=audit(out,files,origin,replays=False)
    replay(factors,opt,out/'factor-replay',fc);partition_replay(finals,opt,out/'partition-replay',fc)
    report,_,_=audit(out,files,origin);(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'],opt,flush=True)

if __name__=='__main__':main()
