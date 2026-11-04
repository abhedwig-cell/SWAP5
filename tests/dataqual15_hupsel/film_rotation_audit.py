"""Independent full1096 ledger, typed profiles and unchanged original science."""
import argparse,collections,copy,json,math,tarfile
from pathlib import Path,PurePosixPath
import film_rotation as runner
from film_runtime_profiles import profile4
from film_runtime_audit import rows
from audit_corrected_rotation import ledger
from scientific_followup import features,distance,rows as raw_rows

ROOT=runner.ROOT;BASE=runner.BASE;sha=runner.sha


def native_binding(folder,opt,platform):
    files,origin=runner.closure_files(opt,platform)
    for observed in ([False,True]if opt=='O2'else[False]):
        original=runner.inherited.source_binding(files,opt,observed);variant='build-observed'if observed else'build';build=folder/'native'/variant
        receipt=json.loads((build/'MATERIALIZATION.json').read_text());assert all(receipt[k]==v for k,v in origin.items()if k!='manifest_sha256')
        manifest=(folder/'native/INHERITED_MANIFEST.json').read_bytes();assert sha(manifest)==receipt['manifest_sha256']and json.loads(manifest)==json.loads((BASE/origin['manifest']).read_text())
        prefix=opt+'/'+variant+'/';assert(build/'ORIGINAL_BUILD.json').read_bytes()==files[prefix+'BUILD.json']
        metadata=json.loads((build/'BUILD.json').read_text());links=receipt['source_relocation'];assert len(links)==236
        assert [(x['original'],x['sha256'])for x in links]==list(original['source_sha256'].items())
        assert metadata['source_sha256']=={x['materialized']:x['sha256']for x in links}
        assert {k:v for k,v in metadata.items()if k!='source_sha256'}=={k:v for k,v in original.items()if k!='source_sha256'}
        for i,link in enumerate(links):
            name=PurePosixPath(link['materialized'].replace('\\','/')).name
            assert name==str(i)+'-'+PurePosixPath(link['original'].replace('\\','/')).name
            assert sha((build/'providers'/name).read_bytes())==link['sha256']
        name='swap5_hupsel_germination.exe'if platform=='windows'else'swap5_hupsel_germination'
        assert sha((build/name).read_bytes())==receipt['executable_sha256']==original['executable_sha256']
    return files


def daily_data(case):
    windows=[{k:float(v)for k,v in row.items()}for row in rows(case/'budget.csv')]
    assert windows[0]['t0_day']==0 and windows[-1]['t1_day']==1096
    assert all(a['t1_day']==b['t0_day']for a,b in zip(windows,windows[1:]))
    grouped=collections.defaultdict(list);interval={}
    for r in windows:
        assert r['t1_day']>r['t0_day']and all(math.isfinite(v)for v in r.values())
        grouped[int(math.ceil(r['t1_day']-1e-9))].append(r)
    assert sorted(grouped)==list(range(1,1097))
    for p,u in [('water','cm'),('solute','mg_cm2')]:
        defect=max(abs(r[p+'_end_'+u]-r[p+'_start_'+u]-r[p+'_in_'+u]+r[p+'_out_'+u])for r in windows)
        reported=max(abs(r[p+'_residual_'+u])for r in windows)
        continuity=max(abs(a[p+'_end_'+u]-b[p+'_start_'+u])for a,b in zip(windows,windows[1:]))
        assert max(defect,reported,continuity)<=1e-10
        interval[p]=dict(maximum_independent_defect=defect,maximum_reported=reported,maximum_continuity=continuity)
    daily=[]
    for day,parts in sorted(grouped.items()):
        assert parts[0]['t0_day']==day-1 and parts[-1]['t1_day']==day
        row={k:math.fsum(p[k]for p in parts)for k in parts[0]};row['t0_day']=day-1;row['t1_day']=day
        for p,u in [('water','cm'),('solute','mg_cm2')]:row[p+'_start_'+u]=parts[0][p+'_start_'+u];row[p+'_end_'+u]=parts[-1][p+'_end_'+u]
        daily.append(row)
    return windows,daily,interval


def science(daily,crops,points):
    manifest=json.loads((BASE/'SPRINT03_SCIENCE_MANIFEST.json').read_text());archive=BASE/manifest['archive'];assert sha(archive.read_bytes())==manifest['archive_sha256']
    with tarfile.open(archive)as t:
        def get(name):
            raw=t.extractfile(name).read();assert sha(raw)==manifest['members'][name];return raw
        frozen=get('science/FROZEN_BOUNDS_BEFORE_HOLDOUT.json');bounds=json.loads(frozen)
        reference=raw_rows(get('original/dtmax-0.0003125/result_output.csv'));profiles=collections.defaultdict(list)
        for row in raw_rows(get('original/dtmax-0.0003125/hupsel_profiles.csv')):profiles[int(row['day'])].append(row)
    selected={d:points[d]for d in json.loads((BASE/runner.REG).read_text())['profile_days']}
    for day,p in selected.items():
        donor=sorted(profiles[day],key=lambda r:int(r['node']));assert len(donor)==34
        for key in ('z_cm','dz_cm'):assert p[key]==[float(r[key])for r in donor]
    native,donor,_,_=features(reference,profiles,daily,crops,selected);assert set(native)==set(bounds)and len(bounds)==37
    assessment={k:dict(error=distance(k,native[k],donor[k]),limit=bounds[k]['limit'],inside_frozen_bound=distance(k,native[k],donor[k])<=bounds[k]['limit'])for k in native}
    for key in ('potential_transpiration','actual_transpiration','drought','oxygen','salinity','water_global','solute_stock'):
        errors=[distance(key,[a],[b])for a,b in zip(native[key],donor[key])];index=max(range(len(errors)),key=errors.__getitem__)
        assessment[key]['worst_day']=index+1
    oxygen584=dict(day=584,native=daily[583]['oxygen_reduction_cm'],original=float(reference[584]['TREDWET']),limit=bounds['oxygen']['limit'])
    oxygen584['absolute_error']=abs(oxygen584['native']-oxygen584['original'])
    return dict(reference_archive_sha256=manifest['archive_sha256'],frozen_bounds_sha256=sha(frozen),assessment=assessment,oxygen_day584=oxygen584,passing=sum(v['inside_frozen_bound']for v in assessment.values()),total=37,whole_scientific_admission=False)


def profile_checks(points,daily,state):
    registration=json.loads((BASE/runner.REG).read_text());assert sorted(points)==sorted(set(registration['profile_days']+registration['additional_capture_days']))
    geometry=points[1096]
    for day,p in points.items():
        assert p['day']==day
        for key in ('z_cm','dz_cm'):assert p[key]==geometry[key]
        assert abs(p['water_stock_cm']-daily[day-1]['water_end_cm'])<=1e-10 and abs(p['solute_stock_mg_cm2']-daily[day-1]['solute_end_mg_cm2'])<=1e-10
        if day<495:assert p['canopy_cm']==0
    assert len(state)==34
    for key in ('z_cm','dz_cm','head_cm','theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'):assert points[1096][key]==[float(r[key])for r in state]


def audit(folder,opt,platform):
    registration=json.loads((folder/'REGISTRATION.json').read_text());assert registration==json.loads((BASE/runner.REG).read_text())
    assert registration['production_admission']is False and registration['whole_scientific_admission']is False
    inherited=native_binding(folder,opt,platform);case=folder/'unobserved1096';build=json.loads((folder/'native/build/BUILD.json').read_text())
    original_inputs=json.loads((BASE/'PRESSURE_DIAGNOSTIC_INPUTS_20261104.json').read_text())['files_sha256']
    run=json.loads((case/'RESULT.json').read_text());assert run['scope']=='ORIGINAL_INPUT_INITIALIZATION'and run['returncode']==0 and run['restart_sha256']is None and not run['diagnostic_override']and run['inputs']==original_inputs
    assert run['executable_sha256']==build['executable_sha256']and all(sha((case/n).read_bytes())==pin for n,pin in original_inputs.items())
    windows,daily,interval=daily_data(case);crops=rows(case/'crop.csv');days=sorted(set(registration['profile_days']+registration['additional_capture_days']))
    points={d:profile4((case/f'checkpoint-{d}.bin').read_bytes())for d in days}
    assert(case/'checkpoint-1096.bin').read_bytes()==(case/'checkpoint.bin').read_bytes()
    proof=ledger(daily,crops,{d:p for d,p in points.items()if d>=495},1096)
    profile_checks(points,daily,rows(case/'state.csv'))
    assert(case/'checkpoint-584.bin').read_bytes()==inherited[opt+'/unobserved584/checkpoint.bin']
    for name in ('budget.csv','crop.csv'):
        old=raw_rows(inherited[opt+'/unobserved584/'+name]);assert rows(case/name)[:len(old)]==old
    pairs=[p for cut in registration['wet_cuts']for p in ((cut-1,cut),(cut,cut+1))]+[(1095,1096)]
    for first,last in pairs:
        strict=folder/'restarts'/f'{first}-to-{last}';rr=json.loads((strict/'RESULT.json').read_text())
        assert rr['returncode']==0 and rr['scope']=='STRICT_OWN_BUILD_RESTART'and rr['restart_sha256']==sha((case/f'checkpoint-{first}.bin').read_bytes())and rr['executable_sha256']==run['executable_sha256']and not rr['diagnostic_override']and rr['inputs']==original_inputs
        assert all(sha((strict/n).read_bytes())==pin for n,pin in original_inputs.items());runner.exact_window(case,strict,last)
    result=dict(status='COMPLETE_PRIVATE_DEFAULT1096_LEDGER_WET_CUTS_PROFILES_AND_STRICT_OWN_RESTARTS_PASS',optimization=opt,platform=platform,days=1096,intervals=len(windows),interval_ledger=interval,proof=proof,selected_profiles=days,strict_windows=len(pairs),science=science(daily,crops,points),production_admission=False,whole_scientific_admission=False)
    if opt=='O2':
        observed=folder/'observed1096';rr=json.loads((observed/'RESULT.json').read_text());ob=json.loads((folder/'native/build-observed/BUILD.json').read_text())
        assert rr['scope']=='ORIGINAL_INPUT_INITIALIZATION'and rr['returncode']==0 and rr['restart_sha256']is None and rr['executable_sha256']==ob['executable_sha256']and rr['inputs']==original_inputs and not rr['diagnostic_override']
        for name in ('checkpoint.bin','budget.csv','crop.csv','state.csv'):assert(case/name).read_bytes()==(observed/name).read_bytes()
        receipts=rows(observed/'film_runtime_receipts.csv');last=receipts[-1];assert float(last['time_day'])==1096 and int(last['calls'])>0 and int(last['max_level'])<=24 and int(last['refinements'])<=23*int(last['calls'])
        assert all(int(b['calls'])>=int(a['calls'])for a,b in zip(receipts,receipts[1:]))
        result['attempted_counter_observation']=dict(physical_outputs_exact=True,scope='ATTEMPTED_CALLS_INCLUDE_REJECTED_TRIALS_NOT_ACCEPTED_FLUX',final=last)
    owner=json.loads((folder/'owner-controls/RESULT.json').read_text());app=json.loads((folder/'app-refusals/RESULT.json').read_text())
    assert owner['executable_sha256']==run['executable_sha256']and owner['checkpoint_sha256']==sha((case/'checkpoint.bin').read_bytes())and owner['clock']==1096
    assert len(owner['events'])==37 and all(e['status']=='PASS'and e['returncode']==1 for e in owner['events'])and len(app['events'])==11 and all(e['returncode']==1 for e in app['events'])
    result['real_mature_controls']=dict(owner=37,app=11,public_writer='EXACT_UNCHANGED_EXECUTABLE_PREFIX_BOUNDARY_EVIDENCE_INHERITED')
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runtime',type=Path,required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--platform',choices=['windows','posix'],required=True);a=p.parse_args()
    result=audit(a.runtime.resolve(),a.optimization,a.platform);(a.runtime/'AUDIT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status']);print(json.dumps(result['science']))
