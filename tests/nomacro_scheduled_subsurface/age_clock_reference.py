"""Fresh clock inputs on exact qualified unchanged original executables."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import time
import age_calendar_reference as old
import age_clock as clock
from age_runtime import output_values_from_directory
from datetime import datetime,timedelta
import csv

ROOT=old.ROOT


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','prior-reference','matrix-O0','matrix-O2','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True);a=p.parse_args();a.output.mkdir()
    parent=json.loads((ROOT/'integration/f-ci/nomacro-complete01/AGE_CALENDAR_QUALIFICATION.json').read_text())
    matrix={'profiles':{}}
    for folder in (a.matrix_O0,a.matrix_O2):matrix['profiles'].update(json.loads((folder/'RESULT.json').read_text())['profiles'])
    prior=parent['original_reference'][a.platform]
    compiler=subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0]
    assert compiler==next(iter(parent['builds'][a.platform].values()))['identity']['compiler'],'Fresh original reference compiler qualification required'
    assert old.calendar.INTEGRAL_SHA==parent['builds'][a.platform][next(iter(parent['builds'][a.platform]))]['identity']['conserved_original_age']['output_calendar']['original_integral_sha256']
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    canon=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    assert canon(Path(old.calendar.__file__))==parent['calendar_source_canonical_sha256']
    assert canon(ROOT/'src/process/mod_original_output_receipt.f90')==parent['receipt_provider_canonical_sha256']
    for name,digest in parent['physical_age_providers'].items():assert canon(ROOT/'src/process'/(name+'.f90'))==digest
    result=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),profiles={},builds=prior['builds'],compiler=compiler,fresh_compile=False,reference_parent=parent['runtime'],whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    try:
        for opt in ('O0','O2'):
            build=a.prior_reference/opt;exe=build/'swap_age_calendar.exe'
            assert sha(exe)==prior['builds'][opt]['executable_sha256']
            for name,digest in prior['builds'][opt]['generated_sha256'].items():assert sha(build/name)==digest
            if a.platform=='Ubuntu':exe.chmod(exe.stat().st_mode|0o111)
            for name,profile in matrix['profiles'].items():
                if profile['optimization']!=opt:continue
                inputs=Path(profile['input_path']);case=a.output/name;shutil.copytree(inputs,case)
                hashes={p.relative_to(case).as_posix():sha(p) for p in case.rglob('*') if p.is_file()}
                started=time.monotonic();r=subprocess.run([str(exe),'./swap.swp'],cwd=case,capture_output=True,text=True,timeout=90)
                (case/'reference.stdout').write_text(r.stdout);(case/'reference.stderr').write_text(r.stderr)
                assert r.returncode in (0,100) and (case/'swap.ok').exists(),r.stderr
                initial,data=old.packets(r.stdout)
                budget=old.r.validate('\n'.join('AGE_CUMULATIVE '+' '.join(map(repr,v)) for v in [initial,*[row['age_state_cm_day'] for row in data]]))
                project=old.c.m.e.load(inputs)
                if profile['mode']=='annual':budget['output']=old.c.output_values(case,data,project)
                else:
                    output=output_values_from_directory(case,data)
                    primary=old.c.records(case/'result_output.csv');nprint=profile['nprint']
                    stamps=[clock.original_timestamp(next(csv.reader([line]))[0]) for line in primary]
                    first=datetime.fromisoformat(project.start_date)
                    assert stamps==[first+timedelta(hours=24*i/nprint) for i in range(1096*nprint+1)]
                    assert len(old.c.records(case/'result.ageProfile.csv'))==1096
                    output.update(original_primary_rows=len(primary),original_age_rows=1096,original_seconds60_formatter_rows=sum(':60' in next(csv.reader([line]))[0] for line in primary),original_age_interval_days=1./nprint)
                    budget['output']=output
                warm=Path(profile['input_path']).parent/'full'
                if (warm/'daily.jsonl').exists():
                    migrated=old.c.m.rows(warm);assert len(migrated)==1096
                    budget['maximum_original_migrated_combined_age_inventory_difference_cm_day']=max(abs(x['age_state_cm_day'][2]-y['age_state_cm_day'][2]) for x,y in zip(data,migrated))
                    budget['maximum_original_migrated_soil_water_inventory_difference_cm']=max(abs(x['stocks'][0]-y['stock_end_cm'][0]) for x,y in zip(data,migrated))
                errors=[]
                for row in data:
                    stock,flow=row['stocks'],row['flow'];delta=math.fsum([*stock[:6],*[-v for v in stock[6:]]]);external=math.fsum([*[flow[i] for i in (0,3,4,5,6)],*[-flow[i] for i in range(7,16)]])
                    errors.append(abs(math.fsum([delta,-external])))
                residual=max(errors);budget.update(input_sha256=hashes,executable_sha256=sha(exe),returncode=r.returncode,seconds=time.monotonic()-started,maximum_observed_water_residual_cm=residual,original_water_balance_status='PASS' if residual<=1e-10 else 'NOT_QUALIFIED',whole_scientific_equivalence='NOT_QUALIFIED')
                (case/'daily-observation.jsonl').write_text(''.join(json.dumps(row)+'\n' for row in data));result['profiles'][name]=budget;save();print(name,'ACTUAL_ORIGINAL_CLOCK_LEDGER_OUTPUT_PASS',flush=True)
        result['status']='SIXTEEN_ORIGINAL_AGE_CLOCK_FULL_REFERENCE_EXECUTIONS_PASS'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
