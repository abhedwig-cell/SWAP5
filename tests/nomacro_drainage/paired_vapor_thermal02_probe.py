"""One bounded original failed-input day; trace is diagnosis, never admission."""
import argparse,io,json,math,subprocess,sys,time,zipfile
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'tests/nomacro_scheduled_subsurface'),str(R/'app/hybrid_water')]
from paired_vapor_thermal02_source import check,git,SHA
from explicit_bottom9_runtime import m
def main():
    p=argparse.ArgumentParser()
    for name in ('input','reference-work','build-root','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();source=check();head=source['source'];project=m.e.load(a.input,original_output=True,time_step_policy='original-adaptive-day-seed-v1')
    from hydraulic_vapor import describe
    assert describe(project)['active_layers'] and m.e.auxiliary_magic(project)==b'S5HPW007'
    original_source=git('rev-parse','codex/nomacro-explicit-bottom9-vapor01').decode().strip()
    archived=git('show',original_source+':integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_VAPOR_THERMAL_DIAGNOSTIC_RAW_V1.zip')
    assert SHA(archived)=='b84a474e7670309421aa7292fa94f7332a74aad3eff789dfea2bee7ebeaa847f'
    with zipfile.ZipFile(io.BytesIO(archived)) as z:
        index=json.loads(z.read('LOGICAL_FILE_INVENTORY_V1.json'));item=index['profile/explicit-bottom9-vapor11-initial-consistent-O0-v1/RESULT.json']
        original_raw=z.read('objects/'+item['sha256']);assert SHA(original_raw)==item['sha256'];original=json.loads(original_raw)
    assert original['status']=='FAILED_ACTUAL_ACTIVE_VAPOR9_PREFLIGHT_NOT_QUALIFIED' and '300s' in original['error']
    assert dict(m.e.inventory(a.input))==dict(original['input_inventory'])
    a.output.mkdir();build=a.build_root/'bundle';started=time.perf_counter()
    q=dict(status='RUNNING_BOUNDED_ORIGINAL_THERMAL_DIAGNOSTIC_NOT_QUALIFIED',source=head,source_proof=source,input_root=str(a.input),input_inventory=m.e.inventory(a.input),build_root=str(build),optimization='O0',requested_days=1,model_wall_cap_seconds=30,original_300s_failed_input_unchanged=True,original_archive_source=original_source,original_failed_RESULT_sha256=SHA(original_raw),canonical_admission=False,scientific_PASS_claimed=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(a.input),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt','O0','--kernel-opt','O0','--output',str(build)]
        with (a.output/'build.stdout').open('xb') as out,(a.output/'build.stderr').open('xb') as err:r=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=240)
        q['build']=dict(command=command,returncode=r.returncode,actual_completion_head=git('rev-parse','HEAD').decode().strip());save();r.check_returncode();assert q['build']['actual_completion_head']==head
        q['actual_BUILD_sha256']=SHA((build/'BUILD.json').read_bytes());m.validate_bundle(build,a.reference_work,project)
        q['diagnostic_build']=json.loads((build/'PAIRED_VAPOR_THERMAL02_DIAGNOSTIC_BUILD_V1.json').read_text());assert q['diagnostic_build']['source_inverse_exact'] and not q['diagnostic_build']['physical_equations_changed'];save()
        try:
            q['trajectory'],data=m.trajectory(build,a.reference_work,project,a.output/'trajectory',1,{1},30)
            q['status']='ORIGINAL_INPUT_ONE_DAY_DIAGNOSTIC_COMPLETED_NOT_QUALIFIED'
        except TimeoutError as error:q.update(status='ORIGINAL_INPUT_DIAGNOSTIC_30S_CENSOR_NOT_QUALIFIED',error=repr(error))
    except Exception as error:q.update(status='DIAGNOSTIC_SETUP_OR_MODEL_REFUSAL_NOT_QUALIFIED',error=repr(error));raise
    finally:
        log=a.output/'trajectory/original/donor.stdout';witness=[]
        if log.is_file():
            for line in log.read_text().splitlines():
                if not line.startswith('PAIRED_VAPOR_THERMAL02_TRIAL_WITNESS '):continue
                fields=line.split();assert len(fields)==20,fields
                count,itry,numbit=map(int,fields[1:4]);assert fields[4] in ('T','F');values=list(map(float,fields[5:]));assert all(map(math.isfinite,values))
                names=('clock','dt','budget_start','budget_total','budget_step','head_last','head_previous_last','theta_last','theta_previous_last','temperature_last','qbot','qtop','pond','pond_previous','maximum_physical_F')
                row=dict(zip(names,values));limit=1e-10*(row['clock']-row['budget_start']+row['dt'])
                row.update(witness=count,retry=itry,newton_iterations=numbit,physical_flag_nonconverged=fields[4]=='T',mass_guard_limit_cm=limit,mass_guard_would_reject=abs(row['budget_total']+row['budget_step'])>limit);witness.append(row)
        q['witness']=witness;q['witness_rows']=len(witness)
        q['physical_converged_but_mass_guard_reject_rows']=sum(not row['physical_flag_nonconverged'] and row['mass_guard_would_reject'] for row in witness)
        daily=a.output/'trajectory/daily.jsonl';q['accepted_days']=len(daily.read_bytes().splitlines()) if daily.is_file() else 0
        q.update(actual_completion_head=git('rev-parse','HEAD').decode().strip(),seconds=time.perf_counter()-started);save()
    assert q['actual_completion_head']==head and m.e.inventory(a.input)==[tuple(row) for row in q['input_inventory']]
    print(q['status'],'days',q['accepted_days'],'witness',q['witness_rows'],'physical-converged-mass-refused',q['physical_converged_but_mass_guard_reject_rows'])
if __name__=='__main__':main()
