"""Independent audit of the already admitted complete scheduled-pond owner."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,shutil,subprocess,sys,tarfile,time
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('mixtures',ROOT/'tests/nomacro_mixtures/run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


def main():
    p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);inputs=out/'inputs';inputs.mkdir();m.fixtures(inputs)
    source='e8d78740663a879945f05b4ecd445db30554ceac'
    assert not subprocess.check_output(['git','diff',source,'HEAD','--','src','app','reference','tools'],cwd=ROOT)
    archive=ROOT/'integration/nomacro-coverage01/BLOCK_O_LOCAL_RAW.tar.xz'
    manifest=json.loads((ROOT/'integration/nomacro-coverage01/BLOCK_O_LOCAL_ARCHIVE.json').read_text())
    assert m.sha(archive)==manifest['sha256']
    q=json.loads((ROOT/'integration/nomacro-coverage01/BLOCK_O_QUALIFICATION.json').read_text())
    assert q['complete_model_days']==8768 and q['full_native_windows']==32 and not q['tolerances_changed']
    result=dict(baseline='fec7b4415932a9c48826e134ce76340adb855778',actual_source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),qualified_runtime=source,
                inherited_complete_days=8768,inherited_exact_native_windows=32,full_SWAP5_reexecuted=False,water_guard_cm=1e-10,solute_guard_mg_cm2=1e-10,science='NOT_QUALIFIED',reports={},events=[])
    def save():(out/'RESULT.json').write_text(json.dumps(result,indent=2))
    with tarfile.open(archive) as t:
        def read(name):
            data=t.extractfile(name).read();assert hashlib.sha256(data).hexdigest()==manifest['files'][name];return data
        for kind in ('water','chemical'):
            key=kind+'-surface-history';project=m.e.load(inputs/key);record=result['reports'][key]={}
            for opt in ('O0','O2'):
                build=out/(kind+'-'+opt+'-build');cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,'--experimental-project',str(inputs/key),'--reference-work',str(a.reference_work),'--build-only','--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
                start=time.perf_counter();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180)
                (out/(kind+'-'+opt+'.stdout')).write_text(r.stdout);(out/(kind+'-'+opt+'.stderr')).write_text(r.stderr);result['events'].append(dict(command=cmd,seconds=time.perf_counter()-start,returncode=r.returncode));assert r.returncode==0,r.stderr
                meta,_=m.validate_bundle(build,a.reference_work,project);assert meta['identity']['scheduled_pond_history']['policy']=='original-top-scheduled-pond-context-v1'
                warm=out/(kind+'-'+opt+'-warm201');record[opt],data=m.trajectory(build,a.reference_work,project,warm,201,{199,201},30)
                record[opt]['own']=m.own(build,a.reference_work,project,warm,data,199,201,out/(kind+'-'+opt+'-own199'))
                previous=[json.loads(s) for s in read('O_'+kind+'_local/'+opt+'-full/daily.jsonl').decode().splitlines()]
                assert len(previous)==1096 and m.physical(data)==m.physical(previous[:201])
                record[opt]['all_prefix_rows_exact_to_admitted_full']=True
                print(key,opt,'ACTUAL_CANONICAL199_TO201_NATIVE_EXACT',flush=True);save()
            # Extract only declared input files and the comparison CSV from the
            # immutable complete worker: never copy swap.ok or other outputs.
            full=out/(kind+'-admitted-full');worker=full/'original';worker.mkdir(parents=True)
            prefix='O_'+kind+'_local/O2-full/'
            meta=json.loads(read(prefix+'BUILD.json'))
            deck=out/(kind+'-executed-inputs');deck.mkdir();hashes={}
            for name in meta['inputs']:
                raw=read(prefix+'original/'+name);(deck/name).write_bytes(raw);hashes[name]=hashlib.sha256(raw).hexdigest()
            assert 'SWENDTYPE = 2' in (deck/'swap.swp').read_text(encoding='cp1252')
            (worker/'result_output.csv').write_bytes(read(prefix+'original/result_output.csv'))
            original=out/(kind+'-original431');record['reference']=m.reference_run(deck,a.reference_work,original,full,20)
            assert record['reference']['status']=='COMPLETE_DIAGNOSTIC_REFERENCE' and record['reference']['original_rows']==record['reference']['swap5_rows']==1097
            assert record['reference']['identical_executed_inputs']==hashes and all(m.sha(original/name)==v for name,v in hashes.items())
            record['literal_executed_inputs_exact']=True;record['native_output_mode']=2;save()
            print(key,'LITERAL_CANONICAL_WORKER_REFERENCE1096_COMPLETE',flush=True)
    result['status']='ACTUAL_ADMITTED_POND_OWNER_NATIVE_AND_LITERAL_REFERENCE_PASS';save()


if __name__=='__main__':main()
