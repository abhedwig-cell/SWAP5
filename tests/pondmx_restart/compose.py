"""Verify the disjoint admitted irrigation source before composed admission."""
from pathlib import Path
import importlib.util,json,subprocess,sys,tarfile,time
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('mixtures',ROOT/'tests/nomacro_mixtures/run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


def main():
    reference=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
    selected=Path(r'C:\SWAP5-testing\pondmx-restart01-qualified')
    previous=Path(r'C:\SWAP5-testing\pondmx-restart01-preservation')
    specs=[(kind+'-'+opt,m.e.load(selected/'inputs'/(kind+'-surface-history')),selected/(kind+'-surface-history-'+opt+'-build'),opt,True) for kind in ('water','chemical') for opt in ('O0','O2')]
    specs += [('plate-v1',m.e.load(Path(r'C:\SWAP5-testing\nomacro-mixtures01\water-plate-history')),previous/'plate-v1','O2',False)]
    specs += [(name,project,previous/name,'O2',False) for name,project in [('grass',m.h.GRASSGROWTH),('hupsel',m.h.HUPSEL),('salt',m.h.SALTFARM)]]
    reports={}
    for key,project,old,opt,affected in specs:
        build=out/key
        cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--reference-work',str(reference),'--build-only','--kernel-opt',opt,'--output',str(build)]
        cmd+=['--experimental-project',project.input_directory,'--donor-opt',opt] if project.input_directory else ['--no-macro-release']
        started=time.perf_counter();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180)
        (out/(key+'.stdout')).write_text(r.stdout);(out/(key+'.stderr')).write_text(r.stderr);assert r.returncode==0,r.stderr
        meta,_=m.validate_bundle(build,reference,project);before=json.loads((old/'BUILD.json').read_text());assert meta['inputs']==before['inputs']
        images={}
        for p in old.glob('*.f90'):
            current=build/p.name;assert current.read_bytes()==p.read_bytes(),(key,p.name)
            images[p.name]=m.sha(current)
        report=reports[key]=dict(generated_sources_byte_exact=True,input_bytes_exact=True,images=images,command=cmd,seconds=time.perf_counter()-started,binary_identity_claim=False)
        if affected:
            warm=out/(key+'-warm201');report['short'],data=m.trajectory(build,reference,project,warm,201,{199,201},30)
            report['own']=m.own(build,reference,project,warm,data,199,201,out/(key+'-own199'))
            assert m.physical(data)==m.physical(m.rows(selected/(key.split('-')[0]+'-surface-history-'+opt+'-full'))[:201])
        print(key,'COMPOSED_GENERATION_AND_SELECTED_NATIVE_PASS',flush=True)
    # The new top-history selection is inactive for the independently admitted
    # no-history external-file fixture. Compare its actual compiled source too;
    # preserve platform line-ending differences, never assert binary identity.
    sys.path.insert(0,str(ROOT/'tools/solute'));from fixed_irrigation_cases import create
    case=out/'N-input';create(case,'water-file-surface');project=m.e.load(case);build=out/'N-build'
    cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(case),'--reference-work',str(reference),'--build-only','--kernel-opt','O2','--donor-opt','O2','--output',str(build)]
    r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180);(out/'N.stdout').write_text(r.stdout);(out/'N.stderr').write_text(r.stderr);assert r.returncode==0,r.stderr
    meta,_=m.validate_bundle(build,reference,project);assert meta['identity'].get('scheduled_pond_history') is None
    images={}
    with tarfile.open(ROOT/'integration/nomacro-coverage01/BLOCK_N_FULL_TRAJECTORIES_RAW.tar.xz') as t:
        for member in t.getmembers():
            if not member.isfile() or '/water-file-surface-O2-build/' not in member.name or not member.name.endswith('.f90'):continue
            name=Path(member.name).name;raw=t.extractfile(member).read();current=(build/name).read_bytes()
            assert current.decode('cp1252').replace('\r\n','\n')==raw.decode('cp1252').replace('\r\n','\n'),name
            images[name]=dict(current_sha256=m.sha(build/name),archived_sha256=__import__('hashlib').sha256(raw).hexdigest(),line_ending_normalized_source_exact=True)
    assert images
    reports['external-irrigation-N']=dict(images=images,scheduled_history_inactive=True,binary_identity_claim=False,command=cmd)
    (out/'RESULT.json').write_text(json.dumps(dict(status='COMPOSED_N_AND_PONDMX_SELECTED_DEPENDENCIES_PRESERVED',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),incoming_canonical='8dcda0fb247ae7823d720817d6340114d5227728',full_physics_reexecuted=False,reports=reports),indent=2))


if __name__=='__main__':main()
