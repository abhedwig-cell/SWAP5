"""Bounded next-batch original initialization versus actual current public reader."""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,sys,time
E=Path(__file__).resolve().parent;W=E.parent;R=Path('C:/Users/Veldh012/swap5-nomacro-scheduled-chemical01')
D=W/'frost-analytical-composition09-reader-discovery-v1';J=Path('C:/Users/Veldh012/swap5-coverage-evidence/J_windows_provider')
build=W/'frost-undrained-state08-initialization-probe-O0-v1/corrected-module-import-v2';exe=build/'original_initialization_probe.exe'
sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from frost_undrained_state_inputs import prepare
from original_output_baseline import assignment
from experimental_project import load
from frost_boundary_git_archive import GitArchiveSource
SHA=lambda raw:hashlib.sha256(raw).hexdigest();git=lambda *a:subprocess.check_output(['git',*a],cwd=R).decode().strip()
actor=git('rev-parse','HEAD');assert actor=='f3faeaa540e7fd81686802414d53ff6686f3ce7b'
assert not git('status','--porcelain=v1','--untracked-files=all','--ignored') and not list(D.iterdir())
metadata=json.loads((build/'BUILD_DIAGNOSTIC.json').read_text());original=json.loads((GitArchiveSource(R,actor)/'FROST_UNDRAINED_STATE08_ORIGINAL_DIAGNOSTIC_RAW_V1.json').read_text());hashes={item['sha256'] for item in original['members'].values()}
for path in [exe,build/'probe.f90',build/'BUILD_DIAGNOSTIC.json']:assert SHA(path.read_bytes()) in hashes
compiler=Path('C:/msys64/ucrt64/bin/gfortran.exe');assert SHA(compiler.read_bytes())==metadata['compiler_sha256']=='d818d364c3f0a422fc195f80539554d4ea38fdcd719046771233dbac294bc371'
for n,digest in metadata['original_objects'].items():assert SHA((J/'build/swap-obj'/n).read_bytes())==digest
assert SHA((J/'build/ttutil-obj/libttutil.a').read_bytes())==metadata['original_library_sha256']
env=dict(os.environ,OMP_NUM_THREADS='1',PYTHONDONTWRITEBYTECODE='1');env['PATH']='C:/msys64/ucrt64/bin;'+env['PATH']
q=dict(status='RUNNING_ORIGINAL_ANALYTICAL_FROST_READER_DISCOVERY_NOT_QUALIFIED',actual_observer=actor,actual_original_probe=metadata['actual_controller_source'],actual_probe_sha256=SHA(exe.read_bytes()),actual_driver_sha256=SHA((build/'probe.f90').read_bytes()),actual_original_objects=metadata['original_objects'],actual_original_library_sha256=metadata['original_library_sha256'],actual_compiler_sha256=metadata['compiler_sha256'],actual_compiler_matches_original_provider=True,old_mixed_compiler_flag_is_historical_and_not_rebound=True,compiler_executions=0,model_days_executed=0,new_scientific_qualification=False,contexts=[])
save=lambda:(D/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
save()
try:
    for models,kind,bottom,initial in [('3 3','water',5,2),('7 7','cde',8,1),('11 11','water',8,2),('7 3','cde',5,1)]:
        name='model'+models.replace(' ','-')+'-'+kind+'-b'+str(bottom)+'-p'+str(initial);folder=D/name;folder.mkdir();inputs=folder/'inputs'
        case=dict(kind=kind,bottom=bottom,implicit=0,hysteresis=0,initial=initial,calendar='dense',reset=1,start=None,days=35,drainage=0)
        prepare(case,inputs);path=inputs/'swap.swp';text=path.read_text(encoding='cp1252')
        parameters=dict(iHWCKmodel=models,SWVAPOR='0 0',ALFA_2='.005 .003',NPAR_2='1.5 1.6',OMEGA_1='.8 .8',H0='-1e6 -1e6',HA='-10.0 -10.0',APAR='-1.5 -1.5',OMEGA_K='.01 .01')
        for key,value in parameters.items():text=assignment(text,key,value) if re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text) else text+'\n'+key+' = '+value+'\n'
        path.write_text(text,encoding='cp1252')
        for crop in inputs.glob('*.crp'):crop.write_text(assignment(crop.read_text(encoding='cp1252'),'SWSALINITY',0),encoding='cp1252')
        inventory={p.relative_to(inputs).as_posix():SHA(p.read_bytes()) for p in inputs.rglob('*') if p.is_file()}
        public=dict(actual_source=actor,entry='app/hybrid_water/experimental_project.py:load',model_builds=0,model_days=0)
        try:
            load(inputs,original_output=True,time_step_policy='original-adaptive-event-closure-v1');public['status']='PUBLIC_READER_ACCEPTED_NOT_RUNTIME_QUALIFIED'
        except ValueError as exc:public.update(status='ACTUAL_CURRENT_PUBLIC_READER_REFUSED',error=repr(exc))
        (folder/'PUBLIC_READER.json').write_text(json.dumps(public,indent=2)+'\n',encoding='utf8')
        worker=folder/'original-worker';shutil.copytree(inputs,worker)
        started=time.perf_counter()
        with (folder/'original-init.stdout').open('xb') as out,(folder/'original-init.stderr').open('xb') as err:
            result=subprocess.run([str(exe)],cwd=worker,env=env,stdout=out,stderr=err,timeout=45)
        raw=(folder/'original-init.stdout').read_bytes();phases=[line for line in raw.decode('cp1252',errors='replace').splitlines() if line.startswith('ORIGINAL_INIT_PHASE ')]
        initialized=result.returncode==0 and 'ORIGINAL_INIT_PHASE AFTER_SOLUTE_INITIALIZATION_ZERO_MODEL_DAYS' in phases
        assert not any(p.name.startswith('accepted-') for p in worker.rglob('*'))
        item=dict(case=case,actual_models=models.split(),name=name,input_inventory=inventory,public_reader=public,original_returncode=result.returncode,original_phases=phases,original_reader_and_initialization_complete=initialized,original_stdout_sha256=SHA(raw),original_stderr_sha256=SHA((folder/'original-init.stderr').read_bytes()),original_seconds=time.perf_counter()-started,model_days=0)
        q['contexts'].append(item);save();assert {p.relative_to(inputs).as_posix():SHA(p.read_bytes()) for p in inputs.rglob('*') if p.is_file()}==inventory
        print('ACTUAL_ANALYTICAL_FROST_ORIGINAL_READER_DISCOVERY',name,result.returncode,initialized,public['status'],flush=True)
    assert git('rev-parse','HEAD')==actor
    q['status']='FOUR_ORIGINAL_ANALYTICAL_FROST_READER_AND_CURRENT_PUBLIC_DOMAIN_OBSERVATIONS_PRESERVED_NOT_SCIENTIFICALLY_QUALIFIED'
except Exception as exc:q.update(status='FAILED_ORIGINAL_ANALYTICAL_FROST_READER_DISCOVERY_NOT_QUALIFIED',error=repr(exc));raise
finally:save()
with (E/'FROST_ANALYTICAL_COMPOSITION09_ORIGINAL_READER_DISCOVERY_V1.json').open('x',encoding='utf8') as out:json.dump(q,out,indent=2);out.write('\n')
print(q['status'],flush=True)
