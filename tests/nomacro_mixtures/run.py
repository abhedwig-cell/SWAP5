"""Four explicit history/boundary compositions, using existing native APIs.

No physical equation or acceptance threshold is implemented here. Short real
executions precede full trajectories; failed/censored observations are retained.
"""
import argparse, contextlib, csv, hashlib, json, re, shutil, subprocess, sys, time, zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'app/hybrid_water'))
sys.path.insert(0, str(ROOT/'tools/solute'))
import daily_host as h
import experimental_project as e
import user_prepare
from daily_coupling import validate_bundle
from check_hupsel51_repair import bounded, check, physical, rows, csvlines
from surface_input_cases import create as surface_inputs

sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
KEYS = ('water-plate-history', 'chemical-plate-history', 'water-surface-history', 'chemical-surface-history')


def fixtures(out):
    inventory = {}
    for key in KEYS:
        case = out/key
        if 'surface' in key:
            surface_inputs(case, key.split('-')[0]+'-surface-combined')
        else:
            shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook', case)
        changes = dict(SWMACRO=0, SWSOLU=int(key.startswith('chemical')), SWHYST=2,
                       SWSNOW=int('plate' in key))
        if 'plate' in key:
            changes.update(SWBOTB=8, SWBBCFILE=0)
        path = case/'swap.swp'; text = path.read_text(encoding='cp1252')
        for name, value in changes.items():
            text, n = re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)\d+', lambda m:m[1]+str(value), text)
            assert n == 1, name
        if 'plate' in key:
            text += '\nHPLATE = -50.0\n'
        # Use the already documented output-only original CSV vocabulary in BOTH
        # executables, rather than comparing different executed input decks.
        text, n = re.subn(r"(?mi)^([ \t]*INLIST_CSV[ \t]*=[ \t]*)'[^']*'", r"\1'WATBAL,ETTERMS,SOLBAL,GWL,CROP,WOFOST,GRASS'", text)
        assert n == 1
        text = re.sub(r'(?m)^([ \t]*SWMONTH[ \t]*=[ \t]*)1', r'\g<1>0', text)
        text += '\nNUM_DECIMALS = 12\n'
        path.write_text(text, encoding='cp1252')
        if key.startswith('water'):
            for crop in case.glob('*.crp'):
                body, n = re.subn(r'(?m)^([ \t]*SWSALINITY[ \t]*=[ \t]*)[01]', r'\g<1>0', crop.read_text(encoding='cp1252'))
                assert n == 1
                crop.write_text(body, encoding='cp1252')
        descriptor = e.inspect(case)
        inventory[key] = dict(selectors=descriptor['selectors'], input_sha256={p.relative_to(case).as_posix():sha(p) for p in sorted(case.rglob('*')) if p.is_file()},
                              changed_physical_controls=changes, original_project='1.hupselbrook',
                              output_only_changes=['INLIST_CSV existing original groups', 'SWMONTH=0', 'NUM_DECIMALS=12'])
    return inventory


def trajectory(build, reference, project, out, last, cuts, cap):
    meta, case = validate_bundle(build, reference, project)
    donor, kernel = h.executable(build, 'day_donor'), h.executable(build, 'day_kernel')
    out.mkdir(); (out/'BUILD.json').write_text(json.dumps(meta, indent=2))
    def warm():
        with contextlib.ExitStack() as stack:
            host = h.DailyHost(stack, donor, kernel, case, out, [h.ColumnStart('original',0,None,None)], checkpoint_enabled=True, runtime=True, binding=meta['binding'], model=project.model, project=project)
            with (out/'daily.jsonl').open('w') as journal:
                for day in range(1,last+1):
                    row = host.step(1, checkpoint=day in cuts)
                    journal.write(json.dumps(row)+'\n'); journal.flush()
                    if not row['committed']: raise ValueError('Rejected day '+str(day))
            host.close()
    _, seconds = bounded(cap, warm)
    data = rows(out); budgets = check(data)
    assert len(data) == last
    return dict(status='FULL_PASS' if last==1096 else 'SHORT_PASS', days=last, budgets=budgets, model_seconds=seconds, build_sha256=sha(build/'BUILD.json')), data


def own(build, reference, project, full, data, start, end, out):
    meta, case = validate_bundle(build, reference, project)
    source = full/f'accepted-column-1-day-{start}.zip'; digest = sha(source)
    origin = out.with_name(out.name+'-origin'); receipt = h.verify_checkpoint(source,start,meta['binding'],origin)
    out.mkdir()
    def cold():
        return h.run(h.executable(build,'day_donor'),h.executable(build,'day_kernel'),case,out,end,
                     checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,
                     checkpoint_binding=meta['binding'],model=project.model,project=project)
    result, seconds = bounded(30, cold)
    assert result['first_refusal'] is None
    actual = rows(out); check(actual)
    assert physical(actual) == physical(data[start:end])
    assert csvlines(out/'original/result_output.csv')[-(end-start):] == csvlines(full/'original/result_output.csv')[start+2:end+2]
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a, zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        for name in ('result.end','macro.bin'): assert a.read(name)==b.read(name), name
    assert sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_csv=True,exact_native=True,origin_unchanged=True,seconds=seconds)


def reference_run(case, reference, output, full, cap):
    shutil.copytree(case, output)
    inventory = {p.relative_to(case).as_posix():sha(p) for p in case.rglob('*') if p.is_file()}
    assert all(sha(output/p)==v for p,v in inventory.items())
    executable = h.executable(reference/'build','swap_b0_gfortran')
    command = [str(executable),'./swap.swp']; started=time.perf_counter(); timed_out=False
    with (output/'standalone.stdout').open('wb') as log:
        try: r=subprocess.run(command,cwd=output,stdout=log,stderr=subprocess.STDOUT,timeout=cap); code=r.returncode
        except subprocess.TimeoutExpired: timed_out=True; code=None
    result=dict(command=command,executable_sha256=sha(executable),identical_executed_inputs=inventory,
                seconds=time.perf_counter()-started,timeout=timed_out,returncode=code,swap_ok=(output/'swap.ok').exists(),
                error=(output/'swap.err').read_text(encoding='cp1252') if (output/'swap.err').exists() else '',
                scientific_equivalence='NOT_QUALIFIED',tolerances_changed=False)
    def read(path):
        if not path.exists():return []
        return list(csv.DictReader([s for s in path.read_text(encoding='cp1252').splitlines() if s.strip() and not s.startswith('*')]))
    left,right=read(output/'result_output.csv'),read(full/'original/result_output.csv')
    common=min(len(left),len(right)); result.update(original_rows=len(left),swap5_rows=len(right),compared_rows=common)
    result['maximum_numeric_csv_differences']={}
    for field in ('GWL','WTOT','BALDEV','S_STOT','S_BALDEV','POND','QBOT','QDRAIN','TA','TSUM'):
        if common and field in left[0] and field in right[0]:
            try: result['maximum_numeric_csv_differences'][field]=max(abs(float(a[field])-float(b[field])) for a,b in zip(left[:common],right[:common]))
            except ValueError:pass
    result['status']='COMPLETE_DIAGNOSTIC_REFERENCE' if result['swap_ok'] and common==1097 and not timed_out else 'INCOMPLETE_OR_REFUSED_REFERENCE'
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,required=True);p.add_argument('--reference-work',type=Path,required=True)
    p.add_argument('--prepare-only',action='store_true');p.add_argument('--model-cap',type=float,default=60);p.add_argument('--reference-cap',type=float,default=20)
    a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    inventory=fixtures(out);(out/'INPUTS.json').write_text(json.dumps(inventory,indent=2))
    if a.prepare_only:return
    user_prepare.validate(a.reference_work)
    results={};events=[]
    def save(): (out/'RESULT.json').write_text(json.dumps(dict(source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),cases=results,events=events,science='NOT_QUALIFIED',water_guard_cm=1e-10,solute_guard_mg_cm2=1e-10),indent=2))
    # Each case must pass short real O0 plus native2to4 before either full run.
    for key in KEYS:
        item=results[key]={};case=out/key;project=e.load(case)
        try:
            for opt in ('O0','O2'):
                build=out/(key+'-'+opt+'-build')
                command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',e.MODEL,'--experimental-project',str(case),'--reference-work',str(a.reference_work),'--build-only','--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
                t=time.perf_counter();r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
                (out/(key+'-'+opt+'-build.stdout')).write_text(r.stdout);(out/(key+'-'+opt+'-build.stderr')).write_text(r.stderr)
                events.append(dict(command=command,seconds=time.perf_counter()-t,returncode=r.returncode));assert r.returncode==0,r.stderr
                if opt=='O0':
                    short=out/(key+'-short');item['short'],data=trajectory(build,a.reference_work,project,short,5,{2,4},30)
                    item['short']['own']=own(build,a.reference_work,project,short,data,2,4,out/(key+'-short-own'))
                    print(key,'SHORT_AND_EXACT_NATIVE_PASS',flush=True);save()
                full=out/(key+'-'+opt+'-full')
                item[opt],data=trajectory(build,a.reference_work,project,full,1096,{2,4,199,201,365,367,530,532,1096},a.model_cap)
                item[opt]['own']=[own(build,a.reference_work,project,full,data,start,end,out/(key+'-'+opt+f'-own{start}')) for start,end in ((2,4),(199,201),(365,367),(530,532))]
                print(key,opt,'FULL_AND_EXACT_NATIVE_PASS',flush=True);save()
            item['reference']=reference_run(case,a.reference_work,out/(key+'-original431'),out/(key+'-O2-full'),a.reference_cap)
            item['status']='FULL_FUNCTIONAL_PASS_SCIENCE_NOT_QUALIFIED'
        except Exception as error:
            item['status']='FAILED_OR_CENSORED';item['error']=repr(error)
            print(key,item['status'],str(error),flush=True)
        save()
    assert all(r['status']=='FULL_FUNCTIONAL_PASS_SCIENCE_NOT_QUALIFIED' for r in results.values()),'Retained failure/censor; inspect RESULT.json'


if __name__=='__main__':main()
