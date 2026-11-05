"""Read-only actual-prefix provenance, mass, own-restart and temporal sensitivity."""
import collections,copy,io,json,math,tarfile
from pathlib import Path
import composed_temporal as run
from film_runtime_audit import ledger,rows
from film_runtime_profiles import profile4
from scientific_followup import rows as raw_rows

BASE=run.BASE;sha=run.sha


def daily(windows):
    grouped=collections.defaultdict(list)
    for r in windows:grouped[int(math.ceil(r['t1_day']-1e-9))].append(r)
    assert sorted(grouped)==list(range(1,585));result=[]
    for day,parts in sorted(grouped.items()):
        assert parts[0]['t0_day']==day-1 and parts[-1]['t1_day']==day
        row={k:math.fsum(r[k]for r in parts)for k in parts[0]};row.update(t0_day=day-1,t1_day=day)
        for p,u in [('water','cm'),('solute','mg_cm2')]:
            row[p+'_start_'+u]=parts[0][p+'_start_'+u];row[p+'_end_'+u]=parts[-1][p+'_end_'+u]
        result.append(row)
    return result


def reference():
    manifest=json.loads((BASE/'SPRINT03_SCIENCE_MANIFEST.json').read_text());raw=(BASE/manifest['archive']).read_bytes();assert sha(raw)==manifest['archive_sha256']
    with tarfile.open(fileobj=io.BytesIO(raw))as t:
        def get(n):
            b=t.extractfile(n).read();assert sha(b)==manifest['members'][n];return b
        frozen=get('science/FROZEN_BOUNDS_BEFORE_HOLDOUT.json');bounds=json.loads(frozen)
        original=raw_rows(get('original/dtmax-0.0003125/result_output.csv'))
    return original,bounds,dict(reference_archive_sha256=sha(raw),frozen_bounds_sha256=sha(frozen))


def science(actual,baseline):
    original,bounds,pins=reference();report={}
    mapping={'water_global':('water_end_cm',None),'solute_stock':('solute_end_mg_cm2','S_STOT'),'potential_transpiration':('potential_transpiration_cm','TPOT'),'actual_transpiration':('actual_transpiration_cm','TACT'),'drought':('drought_reduction_cm','TREDDRY'),'oxygen':('oxygen_reduction_cm','TREDWET'),'salinity':('salinity_reduction_cm','TREDSOL')}
    for key,(field,old)in mapping.items():
        donor=[sum(float(r[x])for x in ('WTOT','PD_VOL','IC_VOL'))if old is None else float(r[old])for r in original[1:585]]
        a=[r[field]for r in actual];b=[r[field]for r in baseline];assert len(a)==len(b)==len(donor)==584
        errors=[abs(x-y)for x,y in zip(a,donor)];worst=max(range(584),key=errors.__getitem__)
        report[key]=dict(prefix_maximum_original_error=errors[worst],worst_day=worst+1,unchanged_original_limit=bounds[key]['limit'],inside_original_limit_on_prefix=errors[worst]<=bounds[key]['limit'],maximum_change_from_qualified_cap001=max(abs(x-y)for x,y in zip(a,b)))
    a=actual[583]['oxygen_reduction_cm'];b=baseline[583]['oxygen_reduction_cm'];o=float(original[584]['TREDWET'])
    return dict(pins,scope='SEVEN_DAILY_SERIES_PREFIX_ONLY_NOT_FULL37_SCIENCE_ADMISSION',series=report,oxygen584=dict(native=a,qualified_cap001=b,original=o,change_from_cap001=a-b,absolute_original_error=abs(a-o),unchanged_limit=bounds['oxygen']['limit']),whole_scientific_admission=False)


def audit(folder,files,origin):
    reg=json.loads((folder/'REGISTRATION.json').read_text());assert reg==json.loads((BASE/run.REG).read_text())and not reg['production_admission']and not reg['whole_scientific_admission']
    record=json.loads((folder/'ORIGIN.json').read_text());cap=record['cap'];assert cap in run.CAPS
    assert all(record[k]==v for k,v in origin.items())and record['production_admission']is False and record['whole_scientific_admission']is False
    expected=json.loads((BASE/'PRESSURE_DIAGNOSTIC_INPUTS_20261104.json').read_text())['files_sha256']
    inputs={n:run.cap_input(files['O2/full1096/'+n],cap)if n=='swap.swp'else files['O2/full1096/'+n]for n in expected}
    for n,pin in expected.items():assert sha(files['O2/full1096/'+n])==pin
    pins={n:sha(b)for n,b in inputs.items()};case=folder/'prefix584';strict=folder/'strict584'
    build=json.loads(files['O2/build/BUILD.json']);assert record['executable_sha256']==build['executable_sha256']
    exe=folder/'native'/('model.exe'if origin['platform']=='windows'else'model');assert sha(exe.read_bytes())==record['executable_sha256']
    for place in (folder/'native/inputs',case,strict):assert {p.name:sha(p.read_bytes())for p in place.iterdir()if p.name in expected}==pins
    full=run.parent.audit.rotation.run_record(case);tail=run.parent.audit.rotation.run_record(strict)
    for r in (full,tail):assert r['returncode']==0 and r['inputs']==pins and not r['diagnostic_override']and r['executable_sha256']==record['executable_sha256']
    assert full['scope']=='ORIGINAL_INPUT_INITIALIZATION'and full['restart_sha256']is None
    seed=case/'checkpoint-583.bin';assert tail['scope']=='STRICT_OWN_BUILD_RESTART'and tail['restart_sha256']==sha(seed.read_bytes())
    run.runner.exact_window(case,strict,584)
    windows=[{k:float(v)for k,v in r.items()}for r in rows(case/'budget.csv')];point=profile4((case/'checkpoint.bin').read_bytes())
    proof=ledger(windows,rows(case/'crop.csv'),point,rows(case/'state.csv'));d=daily(windows)
    for day in run.DAYS:
        p=profile4((case/f'checkpoint-{day}.bin').read_bytes());assert p['day']==day
        for key in ('z_cm','dz_cm'):assert p[key]==point[key]
        assert abs(p['water_stock_cm']-d[day-1]['water_end_cm'])<=1e-10 and abs(p['solute_stock_mg_cm2']-d[day-1]['solute_end_mg_cm2'])<=1e-10
    refuse=folder/'cross-cap-refusal';r=json.loads((refuse/'RESULT.json').read_text());assert r['returncode']==1 and r['seed_sha256']==sha(seed.read_bytes())and r['cap']==cap and r['changed_cap']==next(x for x in run.CAPS if x!=cap)and r['executable_sha256']==record['executable_sha256']and not r['diagnostic_override']
    # Retained commands carry their original absolute paths. Bind the seed
    # to the case recorded in the successful strict-own invocation instead
    # of rebinding or rewriting any numeric checkpoint during relocation.
    assert r['command']==tail['command'] and r['command'][2].replace('\\','/').endswith('/prefix584/checkpoint-583.bin')
    assert b'source rotation envelope rejected before publication'in(refuse/'stdout').read_bytes()+(refuse/'stderr').read_bytes()
    for n,b in inputs.items():
        wanted=b if n!='swap.swp'else run.re.sub(run.PATTERN,lambda m:m[1]+str(r['changed_cap']).encode(),b)
        assert(refuse/n).read_bytes()==wanted
    assert not any((refuse/n).exists()for n in ('budget.csv','checkpoint.bin','crop.csv','state.csv'))
    baseline=daily([{k:float(v)for k,v in r.items()}for r in raw_rows(files['O2/full1096/budget.csv'])if float(r['t1_day'])<=584])
    return dict(status='ACTUAL_CAP_SPECIFIC_ORIGINAL_INITIALIZATION584_LEDGER_TYPED_OWN_RESTART_AND_CROSS_CAP_REFUSAL_PASS',platform=origin['platform'],optimization='O2',cap=cap,proof=proof,science=science(d,baseline),production_admission=False,whole_scientific_admission=False,migration_complete=False)
