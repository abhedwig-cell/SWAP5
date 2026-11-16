"""Finish only the missing M verification on the unchanged executed artifacts.

This is a bounded continuation of run43864567262, not a capsule rebinding or
general admission/resume service. All physical/native runs are reconsumed and
the remaining standalone/input checks execute against their actual binaries.
"""
import csv,hashlib,json,math,re,shutil,stat,subprocess,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
import experimental_project as e
from daily_coupling import validate_bundle
from surface_input_cases import PULSES_MM
EXECUTED='166d4b7b5fe9ba0f6ea3aa8af6f5d55d66a904ad'


def rows(path):return [json.loads(s) for s in (path/'daily.jsonl').read_text().splitlines()]
def physical(r):return {k:v for k,v in r.items() if k not in ('column','revision')}
def payload(path):
    with zipfile.ZipFile(path) as z:return {n:z.read(n) for n in ('result.end','macro.bin')}


def event_witness(full,selected,reference):
    original=(reference/'build/swap-selected/timecontrol.f90').read_text(encoding='cp1252')
    anchor='real(8), parameter   :: dtCrit = 1.0d-8'
    assert original.count(anchor)==1,'Changed original runon event clock contract'
    records=[]
    for day,amount in PULSES_MM.items():
        expected=amount*.1 if selected['SWRUNON'] else 0.0
        actual=full[day-1]['external_flux_cm'][4]
        # Each one-day fixture interval has endpoint uncertainty <= dtCrit.
        # This is the original event clock (days) times rate (cm/day), NOT the
        # independent mass guard. Preserve the stricter nominal diagnostic.
        bound=2e-8*expected+8*math.ulp(expected)
        assert math.isfinite(actual) and abs(actual-expected)<=bound,(day,actual,expected,bound)
        records.append(dict(day=day,nominal_cm=expected,actual_integrated_cm=actual,
            difference_cm=actual-expected,original_event_clock_bound_cm=bound,
            strict_nominal_1e10_diagnostic_pass=abs(actual-expected)<=1e-10))
    assert all(abs(r['external_flux_cm'][4])<=1e-14 for r in full if r['day'] not in PULSES_MM)
    return dict(original_timecontrol_sha256=h.sha(reference/'build/swap-selected/timecontrol.f90'),original_dtCrit_days=1e-8,
        original_clock_contract_pass=True,records=records,scope='Original integrated runon event application; nominal quantity accuracy at1e-10 is a retained separate diagnostic, not a physical mass-guard relaxation')


def finish(out,key):
    assert sys.platform=='linux','Consume original Ubuntu artifacts on their owning platform'
    assert key in {m+'-'+k for m in ('water','chemical') for k in ('runon-file','surface-combined')}
    assert not subprocess.check_output(['git','diff',EXECUTED,'HEAD','--','app','src','reference','tools/solute/run_water.py','tools/solute/surface_input_cases.py','tools/solute/qualify_surface_schedule.py'])
    reports=json.loads((out/'PROFILES.json').read_text());assert len(reports)==2 and {r['optimization'] for r in reports}=={'O0','O2'}
    assert not (out/'RESULT.json').exists(),'Cannot overwrite a completed qualification'
    shutil.copyfile(out/'PROFILES.json',out/'PRECOMPLETION_PROFILES.json')
    reference=out/'provider';case=out/('input-'+key);project=e.load(case)
    # GitHub ZIP download preserves bytes but resets executable permission bits.
    for path in [h.executable(reference/'build','swap_b0_gfortran')]+[h.executable(out/(key+'-'+opt+'-build'),role) for opt in ('O0','O2') for role in ('day_donor','day_kernel')]:
        path.chmod(path.stat().st_mode|stat.S_IXUSR)
    events=[]
    def call(label,args,refuse=False,absent=None):
        cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),*map(str,args)];r=subprocess.run(cmd,capture_output=True,text=True,timeout=180)
        (out/(label+'.log')).write_text(r.stdout+r.stderr);events.append(dict(label=label,command=cmd,returncode=r.returncode,expected_refusal=refuse))
        assert (r.returncode!=0)==refuse,(label,r.stdout,r.stderr)
        if absent is not None:assert not absent.exists()
    for opt in ('O0','O2'):
        bundle=out/(key+'-'+opt+'-build');meta,_=validate_bundle(bundle,reference,project)
        report=next(r for r in reports if r['optimization']==opt)
        assert report['exact_day_suffix'] and report['exact_native_auxiliary'] and report['active_crop_exact_native_window']==[530,532]
        prefix=key+'-'+opt+'-';control=rows(out/(prefix+'control'));active=rows(out/(prefix+'active-prefix'))
        expected_days=5 if opt=='O0' else 1096
        assert len(control)==expected_days and len(active)==532
        for r in control+active:
            assert r['committed'] and abs(r['independent_residual_cm'])<=1e-10 and abs(r['kernel_residual_cm'])<=1e-10 and abs(r.get('solute_independent_residual_mg_cm2',0))<=1e-10
        cut=2 if opt=='O0' else 365
        for before,after,expected,start in [('control','resumed',control,cut),('active-prefix','active-restart',active,530)]:
            origin=out/(prefix+before)/f'accepted-column-1-day-{start}.zip'
            h.verify_checkpoint(origin,start,meta['binding'],out/('completion-verify-'+opt+'-'+str(start)))
            assert list(map(physical,rows(out/(prefix+after))))==list(map(physical,expected[start:start+2]))
            endpoint=out/(prefix+('endpoint' if start==cut else 'active-end'))/f'accepted-column-1-day-{start+2}.zip'
            assert payload(out/(prefix+after)/f'accepted-column-1-day-{start+2}.zip')==payload(endpoint)
        natural=out/(prefix+'surface-windows');w=json.loads((natural/'RESULT.json').read_text())
        assert w['physical_exact'] and w['native_exact'] and w['origins_unchanged'] and w['windows']==[[199,201],[529,531]]
        warm=[json.loads(s) for s in (natural/'warm.jsonl').read_text().splitlines()];assert len(warm)==531
        for start,end in w['windows']:
            cold=natural/('cold-'+str(start))
            assert list(map(physical,rows(cold)))==list(map(physical,warm[start:end]))
            assert payload(cold/f'accepted-column-1-day-{end}.zip')==payload(natural/'warm'/f'accepted-column-1-day-{end}.zip')
        report['surface_event_exact_native_windows']=w
        if opt=='O2':
            assert report['full_period_pass'] and report['completed_days']==1096
            assert all(report[k] for k in ('foreign_surface_schedule_refused_before_output','independent_distinct_origins','external_discard_replay_exact','external_disk_recovery','inconsistent_mass_refused_without_commit'))
            report['original_runon_event_witness']=event_witness(control,e.inspect(case)['selectors'],reference)
            report['max_pond_cm']=max(r['stock_end_cm'][1] for r in control);report['total_runoff_cm']=math.fsum(r['external_flux_cm'][8] for r in control)
    # Execute the original standalone diagnostic which the earlier assertion
    # prevented; it does not become a scientific acceptance oracle.
    donor=h.executable(reference/'build','swap_b0_gfortran');comparisons={}
    for kind in ('literal','csv'):
        work=out/(key+'-completion-reference-'+kind);shutil.copytree(case,work)
        if kind=='csv':
            path=work/'swap.swp';text,n=re.subn(r"(?mi)^([ \t]*INLIST_CSV[ \t]*=[ \t]*)'[^']*'",r"\1'WATBAL,ETTERMS,SOLBAL,GWL,CROP,WOFOST,GRASS'",path.read_text(encoding='cp1252'));assert n==1
            text=re.sub(r'(?m)^([ \t]*SWMONTH[ \t]*=[ \t]*)1',r'\g<1>0',text);path.write_text(text+'\nNUM_DECIMALS = 12\n',encoding='cp1252')
        with (work/'stdout.log').open('wb') as log:r=subprocess.run([str(donor),'./swap.swp'],cwd=work,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        error=(work/'swap.err').read_text(encoding='cp1252') if (work/'swap.err').exists() else ''
        comparisons[kind]=dict(returncode=r.returncode,swap_ok=(work/'swap.ok').exists(),error=error,science='NOT_QUALIFIED',original_executable_sha256=h.sha(donor))
        if kind=='literal' and not comparisons[kind]['swap_ok']:
            # Same original diagnostic policy as the existing full harness.
            # Preserve the distributed unknown S_CONC output-field failure.
            assert 'Item S_CONC in userlist not known' in error
            comparisons[kind]['retained_original_output_failure']=True
        else:assert comparisons[kind]['swap_ok'] and not error.strip() and r.returncode in (0,100)
    def csv_rows(path):
        return list(csv.DictReader(line for line in path.read_text(encoding='cp1252').splitlines() if line.strip() and not line.startswith('*')))
    original_rows=csv_rows(out/(key+'-completion-reference-csv')/'result_output.csv')
    hybrid_rows=csv_rows(out/(key+'-O2-control')/'original/result_output.csv')
    comparisons['csv']['original_output_rows']=len(original_rows);comparisons['csv']['hybrid_output_rows']=len(hybrid_rows)
    if len(original_rows)==len(hybrid_rows):
        deltas={}
        for field in original_rows[0]:
            try:deltas[field]=max(abs(float(a[field])-float(b[field])) for a,b in zip(original_rows,hybrid_rows,strict=True))
            except (ValueError,KeyError,TypeError):pass
        comparisons['csv']['maximum_numeric_csv_differences']=deltas
    base=['--model',e.MODEL,'--experimental-project',case,'--reference-work',reference,'--build-bundle',out/(key+'-O2-build')]
    path=case/'swap.swp';saved=path.read_bytes()
    bad=[('macro','SWMACRO',1),('snow','SWSNOW',2),('frost','SWFROST',1),('hysteresis','SWHYST',3),('solute','SWSOLU',2),('adsorption','SWSP',2),('decay','SWDC',2),('reservoir','SWBR',1),('surfacewater','SWDRA',2),('heat','SWHEA',2),('other-bottom','SWBOTB',9),('reconstructed-groundwater','SWBOTB',1),('foreign-head','SWBOTB',5)]
    for label,name,value in bad:
        target=out/('completion-refused-'+label)
        try:
            text,n=re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)\d+',lambda m:m[1]+str(value),saved.decode('cp1252'));assert n==1;path.write_text(text,encoding='cp1252');call('completion-negative-'+label,base+['--days',1,'--output',target],True,target)
        finally:path.write_bytes(saved)
    for label,suffix in [('duplicate',b'\nSWMACRO = 0\n'),('changed-input',b'\n! changed input binding\n')]:
        target=out/('completion-refused-'+label)
        try:path.write_bytes(saved+suffix);call('completion-negative-'+label,base+['--days',1,'--output',target],True,target)
        finally:path.write_bytes(saved)
    target=out/'completion-refused-release';call('completion-negative-release',base+['--no-macro-release','--output',target],True,target)
    result=dict(status='EXPERIMENTAL_SURFACE_INPUT_OPTIONS_PASS',executed_runtime_source=EXECUTED,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),resumed_exact_run=43864567262,configurations=reports,completed_physics_reexecuted=False,original_references=comparisons,events=events,independent_new_historical_projects=0,science='NOT_QUALIFIED; original clock-integral nominal1e-10 diagnostic failure retained')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],key,flush=True)
