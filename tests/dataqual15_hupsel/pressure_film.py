"""Fresh coherent composition of two separately qualified numeric safeguards."""
import argparse,hashlib,json,os,subprocess,time
from pathlib import Path
import film_runtime as native
import film_rotation as rotation
import micro_pressure_probe as pressure

ROOT=native.ROOT;BASE=native.BASE;REG='PRESSURE_FILM_PREREGISTRATION_20261105.json'
sha=lambda raw:hashlib.sha256(raw).hexdigest()


def candidate_sources():
    original=(ROOT/pressure.PROCESS).read_text(encoding='utf-8');assert original.count(pressure.OLD)==1
    candidate=original.replace(pressure.OLD,pressure.NEW);assert candidate.replace(pressure.NEW,pressure.OLD)==original
    film=native.counter.candidate.candidate((ROOT/native.counter.SOURCE).read_text(encoding='utf-8'))
    return {pressure.PROCESS:candidate,native.counter.SOURCE:film}


def build(baseline,out,compiler):
    out.mkdir();old=json.loads((baseline/'BUILD.json').read_text());native.validate_baseline(baseline,old)
    assert subprocess.check_output([str(compiler),'--version'],text=True).splitlines()[0]==old['compiler']
    for field in ('source_sha256','object_sha256'):assert all(native.sha(Path(p))==pin for p,pin in old[field].items())
    pub=old['publication_provider'];assert all(native.sha(Path(pub[k]))==pub[k+'_sha256']for k in ('source','object'))
    assert native.sha(Path(old['ttutil_archive']))==old['archive_sha256']
    copied={}
    for name,body in candidate_sources().items():
        path=out/('private_'+Path(name).name);path.write_text(body,encoding='utf-8',newline='\n');copied[name]=path
    flags=[v for v in old['flags']if not v.startswith(('-I','-J'))]+['-I'+str(out),'-J'+str(out)]
    events=[];objects=[];sources={};changed=[]
    def run(command):
        start=time.monotonic();result=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,timeout=300);i=len(events)
        (out/f'{i}.stdout').write_bytes(result.stdout);(out/f'{i}.stderr').write_bytes(result.stderr)
        events.append(dict(command=list(map(str,command)),returncode=result.returncode,seconds=time.monotonic()-start));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
        assert result.returncode==0,result.stderr.decode(errors='replace')[-2000:]
    for i,name in enumerate(old['source_sha256']):
        before=Path(name);relative=before.relative_to(ROOT).as_posix()if before.is_relative_to(ROOT)else None
        source=copied.get(relative,before)
        if source!=before:changed.append(relative)
        target=out/f'{i}.o';run([compiler,*flags,'-c',source,'-o',target]);objects.append(target);sources[str(source)]=native.sha(source)
    assert set(changed)==set(copied)and len(objects)==236
    executable=out/('swap5_hupsel_germination.exe'if os.name=='nt'else'swap5_hupsel_germination')
    args=['-fopenmp']+(['-Wl,--stack,16777216']if os.name=='nt'else[])+list(map(str,objects))+[pub['object'],old['ttutil_archive'],'-o',str(executable)]
    response=out/'link.args';response.write_text('\n'.join('"'+p.replace('\\','/')+'"'for p in args)+'\n',encoding='utf-8');run([compiler,'@'+str(response)])
    result=dict(status='BUILT',candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),compiler=old['compiler'],flags=flags,provider_count=236,
                source_sha256=sources,object_sha256={str(p):native.sha(p)for p in objects},executable_sha256=native.sha(executable),publication_provider=pub,ttutil_archive=old['ttutil_archive'],archive_sha256=old['archive_sha256'],baseline=old,
                interventions=changed,complete_module_closure_rebuilt=True,events=events,production_admission=False,whole_scientific_admission=False)
    (out/'BUILD.json').write_text(json.dumps(result,indent=2)+'\n');return executable


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('baseline','output','compiler'):parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--optimization',choices=['O0','O2'],required=True);args=parser.parse_args()
    out=args.output.resolve();out.mkdir();os.environ.pop('SWAP5_DIAG_PREDECESSOR',None);os.environ['OMP_NUM_THREADS']='1'
    registration=json.loads((BASE/REG).read_text());(out/'REGISTRATION.json').write_bytes((BASE/REG).read_bytes())
    scope=json.loads((ROOT/native.SCOPE).read_text());native.current_guard(scope)
    record=json.loads((args.baseline.resolve()/'BUILD.json').read_text());assert '-'+args.optimization in record['flags']
    executable=build(args.baseline.resolve(),out/'build',args.compiler.resolve());inputs=native.inputs(out/'inputs')
    case=rotation.execute(executable,inputs,out/'full1096',1096,capture=registration['capture_days'])
    rotation.ensure_captures(executable,inputs,case,out,registration['capture_days']);restarts=out/'restarts';restarts.mkdir()
    pairs=[p for cut in registration['wet_cuts']for p in ((cut-1,cut),(cut,cut+1))]+[(1095,1096)]
    for first,last in pairs:
        strict=rotation.execute(executable,inputs,restarts/f'{first}-to-{last}',last,seed=case/f'checkpoint-{first}.bin');rotation.exact_window(case,strict,last)
    from production_diagnostic_native import writer_build,measure,app_refusals
    from production_diagnostic_guards import qualify
    probe=writer_build(executable.parent,out/'writer-build',args.compiler.resolve(),windows=False)
    measure(executable,probe,inputs,out/'writer-qualification');app_refusals(executable,case,out/'app-refusals');qualify(executable.parent,case,case/'checkpoint.bin',out/'owner-controls')
    rotation.control_environment(out);native.current_guard(scope)
    (out/'EXECUTED.json').write_text(json.dumps(dict(status='ACTUAL_COMPOSED_FULL1096_AND_STRICT_OWN_RESTARTS_EXECUTED_AUDIT_PENDING',optimization=args.optimization,production_admission=False,whole_scientific_admission=False),indent=2)+'\n')
    print('COMPOSED_FULL1096_AND_STRICT_OWN_RESTARTS_EXECUTED',args.optimization,flush=True)

if __name__=='__main__':main()
