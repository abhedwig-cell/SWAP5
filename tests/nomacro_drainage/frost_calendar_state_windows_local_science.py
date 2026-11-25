"""Fresh original local calendar source/data/default postimages, no model replay."""
from pathlib import Path
from contextlib import ExitStack
from decimal import Decimal,localcontext
import sys,json,hashlib,subprocess,io,zipfile
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from frost_history_state_archives import Locations,OriginalProviderArchive
from frost_calendar_state_archive_science import read,native,checkpoint,controls,physical
from frost_calendar_state_probe import budgets
from original_output_files import compare
from frost_history_state_central import generated,compiled
from frost_calendar_state_parent_archive import CanonicalLogicalArchive
BASE='8dbe3db7c7832dd6a1f86c4275cd43f054552df3'
def git(*args):return subprocess.check_output(['git',*args],cwd=R)
class LogicalArchive:
    def __init__(self,proof,name,stack):
        self.physical=Archive(proof,name,stack);self.record=self.physical.record;self.names=json.loads(self.physical.get('LOGICAL_FILE_INVENTORY_V1.json'))
        assert len(self.names)==self.record['logical_files'] and all('objects/'+v['sha256'] in self.physical.names for v in self.names.values())
    def get(self,name):
        item=self.names[name];raw=self.physical.get('objects/'+item['sha256']);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'];return raw
    def view(self,name):return ReadView(self,name)

def case_audit(store,loc,provider,item):
    case=item['case'];profile=loc.resolve(item['profile']);q=read(profile/'RESULT.json');bundle=loc.resolve(q['build_root']);inputs=loc.resolve(q['input_root']);meta=read(bundle/'BUILD.json');identity=meta['identity'];warm=profile/'trajectory'
    assert q['status']=='ACTUAL_FROST_CALENDAR_ORIGINAL_BUDGETS_NATIVE_HISTORY_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED' and q['duration_days']==case['days'] and q['kind']==case['kind']
    assert meta['project']['start_date']==case['start'] and meta['project']['water_tolerance']==1e-10 and meta['project']['nodes']==34
    assert not git('diff',q['source'],store.record['actual_source'],'--','app','src','tools','reference')
    actual_inputs=sorted((p.relative_to(inputs).as_posix(),SHA(p.read_bytes())) for p in inputs.rglob('*'));assert actual_inputs==[tuple(x) for x in item['input_inventory']]
    assert SHA((bundle/'BUILD.json').read_bytes())==q['trajectory']['build_sha256']
    for name,digest in identity['donor_generated'].items():assert SHA((bundle/name).read_bytes())==digest
    for name,digest in identity['donor_objects'].items():assert SHA(provider.get('original-provider/build/swap-obj/'+name))==digest
    for role,digest in meta['executable_sha256'].items():assert SHA((bundle/('day_'+role+'.exe')).read_bytes())==digest
    assert '-'+item['optimization'] in identity['donor_flags'] and '-'+item['optimization'] in identity['kernel_flags'] and '-ffp-contract=off' in identity['donor_flags'] and '-ffp-contract=off' in identity['kernel_flags']
    from frost_calendar_terminal_water import source as terminal
    assert (bundle/'terminal_water_receipt.f90').read_text(encoding='cp1252')==terminal()
    original=provider.get('original-provider/build/swap-selected/divdra.f90').decode('cp1252').replace('\r\n','\n');actual=(bundle/'divdra.f90').read_text(encoding='cp1252').replace('\r\n','\n');old='               if (icpbotdislay(idr) == icpwlev) dzcpbotdislay(idr) = dzcpwlevsat';new='               ! FROST-DIVDRA-OVERLAP-01: retain the actual Lev2Comp above-bottom extent.';assert actual.count(new)==1 and actual.replace(new,old,1)==original
    assert (bundle/'frozencond.f90').read_bytes()==(R/'reference/swap-4.3.1/frost-corrections/FROST-GEOMETRY-01/frozencond.f90').read_bytes()
    science=budgets(warm,case['kind'],case['days']);assert science==q['independent_original_budgets']
    data=[json.loads(x) for x in (warm/'daily.jsonl').read_text().splitlines()];windows=[(2,4),(19,23),(30,34)] if case['days']==35 else [(2,case['days'])]
    if case['start'][5:7]=='12' and case['days']==35:windows.append((15,19))
    assert [(x['start'],x['end']) for x in q['own']]==windows;cuts={case['days']}|{x for pair in windows for x in pair};assert {int(p.stem.rsplit('-',1)[1]) for p in warm.glob('accepted-column-1-day-*.zip')}==cuts
    for day in cuts:checkpoint(warm/f'accepted-column-1-day-{day}.zip',meta,case,data[day-1])
    for start,end in windows:
        cold=profile/('own-'+str(start));rows=[json.loads(x) for x in (cold/'daily.jsonl').read_text().splitlines()];assert [physical(x) for x in rows]==[physical(x) for x in data[start:end]]
        assert checkpoint(cold/f'accepted-column-1-day-{end}.zip',meta,case,rows[-1])==checkpoint(warm/f'accepted-column-1-day-{end}.zip',meta,case,data[end-1]);compare(warm/'original',cold/'original',identity['original_output'],start,end,case['start'])
    result=dict(case=case,optimization=item['optimization'],actual_compiler_source=q['source'],science=science,native_samples=len(cuts),exact_cold_windows=len(windows))
    if case['days']==35:
        result['controls']=controls(store.view('profiles/frost-calendar-state02-'+case['name']+'-'+item['optimization']+'-controls-daily-v2'),warm,data,meta,case)
    return result


def terminal_causal_negative(store,loc):
    old=store.view('profiles/frost-calendar-state02-water-explicit-regular-noreset-year-hys1-initial2-O0-science-v1')
    dense=store.view('profiles/frost-calendar-state02-real-canonical-dense-year-O0-control-v1')
    corrected=store.view('profiles/frost-calendar-state02-corrected-same-failed-year-O0-science-v2')
    rows=lambda folder:[json.loads(line) for line in (folder/'trajectory/daily.jsonl').read_text().splitlines()]
    a,b,c=rows(old),rows(dense),rows(corrected)
    assert len(a)==7 and sum(row['committed'] for row in a)==6 and a[-1]['committed'] is False
    assert len(b)==35 and len(c)==12 and all(row['committed'] for row in b+c)
    fields=('stock_start_cm','stock_end_cm','external_flux_cm','pressure_head_cm','groundwater_cm','drainage_outward_cm','bottom_outward_cm')
    prior={key:all(x[key]==y[key] for x,y in zip(a[:6],b[:6])) for key in fields}
    assert prior['pressure_head_cm']
    assert all(all(x[key]==y[key] for key in fields) for x,y in zip(c,b[:12]))
    with localcontext() as context:
        context.prec=80
        row=json.loads((old/'trajectory/daily.jsonl').read_text().splitlines()[-1],parse_float=Decimal)
        residual=sum(row['stock_start_cm'])-sum(row['stock_end_cm'])+sum(row['external_flux_cm'][:7])-sum(row['external_flux_cm'][7:])
        assert abs(residual)>Decimal('1e-10') and abs(row['kernel_residual_cm'])>Decimal('1e-10')
    old_report=read(old/'RESULT.json');dense_report=read(dense/'RESULT.json');modules={}
    assert dense_report['source']==BASE
    for name in ('headcalc.f90','timecontrol.f90','boundtop.f90','frozencond.f90','divdra.f90','terminal_water_receipt.f90'):
        left=(loc.resolve(old_report['build_root'])/name).read_bytes().replace(b'\r\n',b'\n')
        right=(loc.resolve(dense_report['build_root'])/name).read_bytes().replace(b'\r\n',b'\n')
        assert left==right;modules[name]=SHA(left)
    return dict(status='ORIGINAL_TERMINAL_INTERVAL_DAY7_REFUSAL_AND_DENSE_CONTROL_AND_CORRECTED_EXACT12_FRESH_ARCHIVE_PROOF_PASS',
        raw_archive_sha256=store.record['sha256'],original_accepted_days=6,original_refused_day=7,
        original_refused_water_residual_cm=str(residual),unchanged_owning_limit_cm='1e-10',actual_dense_source=dense_report['source'],
        actual_dense35_budgets=budgets(dense/'trajectory','water',35),six_complete_original_generated_modules_equal=modules,
        prior_six_days_field_equality_diagnostics=prior,corrected_all_twelve_physical_fields_exact_to_actual_canonical_dense=True,
        old_failure_retained_not_relabelled=True,compiler_executions=0,model_executions=0,canonical_admission=False)

def audit(proof):
    from frost_boundary_git_archive import GitArchiveSource
    E=proof if isinstance(proof,GitArchiveSource) else Path(proof)
    with ExitStack() as stack:
        store=LogicalArchive(E,'FROST_CALENDAR_STATE02_WINDOWS_LOCAL_RAW_V1',stack);loc=Locations(store,json.loads(store.get('ACTUAL_ARCHIVE_LOCATIONS_V1.json')));provider=OriginalProviderArchive(stack)
        for name in store.physical.names:store.physical.get(name)
        custody=json.loads(store.get('SOURCE_CUSTODY_V1.json'));sources=[]
        for epoch,items in custody['actual_source_catalog'].items():
            commit=store.get('source/'+epoch+'/actual-commit.bin');assert hashlib.sha1(b'commit '+str(len(commit)).encode()+b'\0'+commit).hexdigest()==epoch==git('rev-parse',epoch).decode().strip()
            tree={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in git('ls-tree','-r',epoch).decode().splitlines()}
            for item in items:
                raw=store.get('source/'+epoch+'/'+item['path']);assert SHA(raw)==item['sha256'] and hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==item['git_blob']==tree[item['path']]
            sources.append(dict(actual_source=epoch,actual_git_source_blobs=len(items)))
        batch=read(store.view('profiles/frost-calendar-state02-windows-batch-daily-v2/BATCH.json'));assert batch['status']=='FAILED_ACTUAL_WINDOWS_FROST_CALENDAR_BATCH_NOT_QUALIFIED' and len(batch['contexts'])==4
        results=[case_audit(store,loc,provider,item) for item in batch['contexts']]
        split=read(R/'integration/f-ci/nomacro-complete01/FROST_CALENDAR_STATE02_SPLIT_WINDOWS_EXECUTION_V1.json');contract=read(R/'integration/f-ci/nomacro-complete01/FROST_CALENDAR_STATE02_CONTRACT_V1.json');case=next(x for x in contract['representative_cases'] if x['name']=='water-explicit-regular-noreset-year-hys1-initial2')
        results.append(case_audit(store,loc,provider,dict(case=case,profile=split['year12_profile'],optimization='O0',input_inventory=split['year12_input_inventory'])))
        parent=CanonicalLogicalArchive('FROST_HYSTERESIS_STATE01_WINDOWS_RAW_V1');oldloc=Locations(parent,json.loads(parent.get('ACTUAL_ARCHIVE_LOCATIONS_V1.json')));record=read(store.view('profiles/frost-calendar-state02-unselected-dense-preservation-v2/RESULT.json'));assert len(record['builds'])==4 and record['model_executions']==0;defaults=[]
        assert not git('diff',record['old_actual_compiler'],BASE,'--','app','src','tools','reference')
        for item in record['builds']:
            before=oldloc.resolve(item['actual_old_build_record']['build_root']);after=loc.resolve(item['actual_new_build_record']['build_root']);a=generated(before,after);b=compiled(before,after);assert a==item['generated'] and b==item['compiled'];defaults.append(dict(stem=item['stem'],generated=a,compiled=b))
        negative=terminal_causal_negative(store,loc)
        assert negative==read(R/'integration/f-ci/nomacro-complete01/FROST_CALENDAR_STATE02_LOCAL_TERMINAL_CAUSAL_ARCHIVE_V1.json')
        q=dict(status='FRESH_ACTUAL_LOCAL_WINDOWS_FOUR_FULL35_YEAR12_NATIVE_COLD_SOURCE_CONTROLS_AND_DENSE4_PASS',actual_source=store.record['actual_source'],raw_archive_sha256=store.record['sha256'],logical_files=len(store.names),physical_payloads=len(store.physical.names),source_custody=sources,contexts=results,current_dense_preservation=defaults,terminal_causal_negative=negative,remaining_required_original_windows_CI_contexts=9,compiler_executions=0,model_executions=0,canonical_admission=False)
        return q
if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists();q=audit(a.proof);a.output.write_text(json.dumps(q,indent=2)+'\n');print(q['status'],len(q['contexts']))
