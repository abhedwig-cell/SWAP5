"""Bounded original undrained Frost public authority; actual merge owns admission."""
import io,json,zipfile
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from frost_boundary_git_archive import GitArchiveSource
from frost_undrained_source_custody import ROOT,source,git,BASE,PREFIX
from frost_undrained_inherited_custody import inherited_evidence
from frost_undrained_parent_admission import parent_admission
from frost_undrained_archive_science import portable,local
import ci_checkout_scope07_verify as previous
SEALED='9d80f1e7c320967360036e62bc31fd2a69bc458f'

def data_source():return GitArchiveSource(ROOT,git('rev-parse','HEAD').decode().strip())

def frozen(name):
    raw=(data_source()/(name+'.json')).read_bytes();assert raw==git('show',SEALED+':'+PREFIX+name+'.json');return json.loads(raw)

def raw_custody():
    data=data_source();result=[]
    for path in git('ls-tree','-r','--name-only',SEALED,'--',PREFIX).decode().splitlines():
        name=Path(path).name
        if not name.startswith('FROST_UNDRAINED_STATE08_') or not name.endswith('.json'):continue
        record=frozen(name[:-5])
        if not {'archive','bytes','sha256'}<=record.keys():continue
        if record.get('parts'):
            raw=[]
            for part in record['parts']:
                value=(data/part['file']).read_bytes();assert len(value)==part['bytes'] and SHA(value)==part['sha256'];raw.append(value)
            value=b''.join(raw)
        else:value=(data/record['archive']).read_bytes()
        assert len(value)==record['bytes'] and SHA(value)==record['sha256']
        with zipfile.ZipFile(io.BytesIO(value)) as z:
            assert len(z.namelist())==len(set(z.namelist()))
            if isinstance(record.get('members'),dict):
                assert set(z.namelist())==set(record['members'])
                for n,item in record['members'].items():
                    raw=z.read(n);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
            else:assert z.testzip() is None
            count=len(z.namelist())
        result.append(dict(archive=record['archive'],bytes=record['bytes'],sha256=record['sha256'],members=count))
    assert len(result)>=10
    return result

def inherited_science(data):
    name='FROST_IMPLICIT_HYS2_YEAR06_COMPLETE64_CENTRAL_V1'
    raw=(data/(name+'.json')).read_bytes();assert raw==git('show',BASE+':'+PREFIX+name+'.json')
    science=json.loads(raw);assert (science['contexts'],science['primary_days'],science['native_samples'],science['exact_cold_windows'],science['actual_compiled_refusals'],science['transaction_contexts'])==(64,1872,368,160,4672,96)
    assert len(science['actual_current_inherited_compiled_postimages'])==32 and sum(x['whole_object_count'] for x in science['actual_current_inherited_compiled_postimages'])==916
    return dict(status='EXACT_ORIGINAL648_EVIDENCE_AND_ACCEPTED_SCIENCE_WITH_CURRENT_UNCHANGED_DRAINED_POSTIMAGES',actual_qualified_canonical=BASE,original_scientific_producer='a4f24f74f3b5b82b2673f2695d15fe7ba3990fd6',original_independent_observer='9b4efb16a4c29bc5713e6861d10de41e130742eb',original_summary=name+'.json',model_periods_replayed=0,scientific_producer_rebound=False)

def guard_previous_source():
    source(SEALED);inherited_evidence();parent_admission();inherited_science(data_source());raw_custody();return True

def strip_current_evidence(text):return previous.strip_current_evidence(text)

def publication_dependencies_unchanged():
    guard_previous_source();return True

def verify():
    current=source(SEALED);inherited=inherited_evidence();parent=parent_admission();old_science=inherited_science(data_source());raw=raw_custody();data=data_source()
    results=[]
    for platform in ['Ubuntu','Windows']:
        for opt in ['O0','O2']:
            observed=portable(data,platform,opt);expected=frozen(f'FROST_UNDRAINED_STATE08_INDEPENDENT_{platform.upper()}_{opt}_V2')
            assert expected['actual_observer']=='5cdaef81cf68f034534779cdb29bcfdd74ca6103' and observed==expected['audit'];results.append(observed)
    local_science=local(data);expected=frozen('FROST_UNDRAINED_STATE08_LOCAL_INDEPENDENT_V2')
    assert expected['actual_observer']=='c4f2ef462b4e3311c22863c804eb49a5c86278b5' and local_science==expected['audit']
    contexts=[c for item in results for c in item['contexts']];postimages=[c for item in results for c in item['inherited_postimages']]
    assert (len(contexts),sum(c['case']['days'] for c in contexts),sum(c['native_samples'] for c in contexts),sum(c['exact_cold_windows'] for c in contexts))==(64,1872,400,176)
    assert sum(c.get('controls',{}).get('actual_compiled_refusals',0) for c in contexts)==4460
    assert sum(len(c.get('controls',{}).get('transactions',[])) for c in contexts)==96
    assert len(postimages)==32 and sum(c['whole_objects'] for c in postimages)==932
    coadmission=dict(parent['receipt']['coadmission']);assert coadmission['contexts']==648
    coadmission.update(contexts=712,short35_contexts=coadmission['short35_contexts']+48,native_calendar_samples=coadmission['native_calendar_samples']+400,exact_cold_windows=coadmission['exact_cold_windows']+176,new_frost_undrained_contexts=64,new_frost_undrained_year12_contexts=16,new_frost_undrained_unchanged_drained_postimages=32,new_frost_undrained_whole_object_comparisons=932,previous_canonical=BASE)
    return dict(status='BOUNDED_ORIGINAL_UNDRAINED_FROST_EXPLICIT_IMPLICIT58_HYSTERESIS_CALENDARS_NATIVE_COLD_AND_ACTIVE_TRANSACTIONS_PASS',actual_current_source=current,fresh_inherited_evidence=inherited,parent_historical_admission=parent,inherited_original_scientific_authority=old_science,actual_raw_custody=raw,new_original_portable_science=results,additional_actual_local_science=local_science,coadmission=coadmission,scientific_change_class='B_COMPOSITION_OF_EXISTING_UNCHANGED_PROCESSES',local_four_contexts_counted_again=False,original_scientific_water_limit_cm='1e-10',original_scientific_cde_limit_mg_cm2='1e-10',divdra_selected_for_undrained_frost=False,new_physical_state=False,physical_equations_changed=False,inventory_or_flux_correction=False,original_dates_or_native_counters_normalized=False,automatic_fallback=False,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)

if __name__=='__main__':print(json.dumps(verify(),indent=2))
