"""Fresh unaffected build closure; no duplicate full unchanged histories."""
from pathlib import Path
import importlib.util,json,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
import experimental_project as e
from daily_coupling import validate_bundle


def main():
    reference=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
    specs=[('plate-v1',e.load(Path(r'C:\SWAP5-testing\nomacro-mixtures01\water-plate-history')),Path(r'C:\SWAP5-testing\nomacro-mixtures01\water-plate-history-O2-build'))]
    specs += [(name,project,Path(r'C:\SWAP5-testing\hupsel51\actual-merge\named')/name/'build') for name,project in [('grass',h.GRASSGROWTH),('hupsel',h.HUPSEL),('salt',h.SALTFARM)]]
    reports={}
    for key,project,old in specs:
        build=out/key
        cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--reference-work',str(reference),'--build-only','--kernel-opt','O2','--output',str(build)]
        cmd+=['--experimental-project',project.input_directory,'--donor-opt','O2'] if project.input_directory else ['--no-macro-release']
        started=time.perf_counter();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180)
        (out/(key+'.stdout')).write_text(r.stdout);(out/(key+'.stderr')).write_text(r.stderr);assert r.returncode==0,r.stderr
        meta,_=validate_bundle(build,reference,project)
        assert meta['identity'].get('scheduled_pond_history') is None
        files={}
        for original in old.glob('*.f90'):
            current=build/original.name;assert current.exists() and current.read_bytes()==original.read_bytes(),(key,original.name)
            files[original.name]=h.sha(current)
        previous=json.loads((old/'BUILD.json').read_text())
        assert meta['inputs']==previous['inputs']
        reports[key]=dict(status='UNAFFECTED_EMITTED_SOURCE_INPUTS_EXACT',generated_sources=files,input_sha256=meta['inputs'],
                          command=cmd,seconds=time.perf_counter()-started,build_sha256=h.sha(build/'BUILD.json'),binary_identity_claim=False)
        print(key,'UNAFFECTED_GENERATION_EXACT',flush=True)
    (out/'RESULT.json').write_text(json.dumps(dict(status='DEFAULT_AND_LEGACY_HISTORY_GENERATION_PRESERVED',reports=reports),indent=2))


if __name__=='__main__':main()
