"""Bounded composite original Frost authority with genuine independent sources."""
import io,json,zipfile
from pathlib import Path
from frost_boundary_git_archive import GitArchiveSource
from analytical_hydraulic_archives import SHA
from frost_analytical_boundary_source_custody import ROOT,source,git,BASE,PREFIX
from frost_analytical_boundary_inherited_custody import inherited_evidence
from frost_analytical_boundary_parent_admission import parent_admission
from frost_analytical_boundary_composite_science import composite
from frost_analytical_boundary_local_science import local
import frost_analytical_verify as previous
SEALED='0000000000000000000000000000000000000000'


def data_source():return GitArchiveSource(ROOT,git('rev-parse','HEAD').decode().strip())


def frozen(name):
    raw=(data_source()/(name+'.json')).read_bytes();assert raw==git('show',SEALED+':'+PREFIX+name+'.json');return json.loads(raw)


def raw_custody():
    data=data_source();result=[]
    for path in git('ls-tree','-r','--name-only',SEALED,'--',PREFIX).decode().splitlines():
        name=Path(path).name
        if not name.startswith('FROST_ANALYTICAL_BOUNDARY10_') or not name.endswith('.json'):continue
        record=frozen(name[:-5])
        if not isinstance(record,dict) or not {'archive','bytes','sha256'}<=record.keys():continue
        parts=record.get('parts');raw=[]
        if parts:
            for part in parts:
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
    assert len(result)>=14
    return result


def inherited_science(data):
    contexts=[]
    for platform in ['UBUNTU','WINDOWS']:
        for opt in ['O0','O2']:
            name=f'FROST_ANALYTICAL_COMPOSITION09_INDEPENDENT_{platform}_{opt}_V1.json'
            raw=(data/name).read_bytes();assert raw==git('show',BASE+':'+PREFIX+name)
            q=json.loads(raw);assert q['actual_observer']==('a99b39b806ffe607f8af805ef34515495ec0ce39' if platform=='UBUNTU' else 'e911ae07bd67b151d86be4be3d6056515c226c28')
            assert q['audit']['compiler_executions']==q['audit']['model_executions']==0
            contexts.extend(q['audit']['contexts'])
    assert len(contexts)==48 and sum(c['case']['days'] for c in contexts)==1312
    assert sum(c['native_samples'] for c in contexts)==288 and sum(c['exact_cold_windows'] for c in contexts)==128
    return dict(status='CANONICAL760_ORIGINAL_SCIENTIFIC_AUTHORITY_PRESERVED_WITH_CURRENT_UNAFFECTED_OBJECTS',actual_qualified_canonical=BASE,original_scientific_producer='a2df828cf19dea76a9012c7cb13f14db0cdbbe08',model_periods_replayed=0,scientific_producer_rebound=False)


def guard_previous_source():
    source(SEALED);inherited_evidence();parent_admission();inherited_science(data_source());raw_custody();return True


def strip_current_evidence(text):return previous.strip_current_evidence(text)


def publication_dependencies_unchanged():
    guard_previous_source();return True


def verify():
    current=source(SEALED);inherited=inherited_evidence();parent=parent_admission();authority=inherited_science(data_source());raw=raw_custody();data=data_source();results=[]
    for platform in ['Ubuntu','Windows']:
        for opt in ['O0','O2']:
            observed=composite(data,platform,opt);expected=frozen(f'FROST_ANALYTICAL_BOUNDARY10_COMPOSITE_INDEPENDENT_{platform.upper()}_{opt}_V1')
            assert expected['actual_observer']=='597033a2109c8377a28e42ac5f947ca5cff78793' and observed==expected['audit'];results.append(observed)
    observed_local=local(data);expected=frozen('FROST_ANALYTICAL_BOUNDARY10_LOCAL_SEARCH_INDEPENDENT_V1')
    assert expected['actual_observer']=='e9092e4e4ed14b0e51c66b449e5ad8e6d8d840fc' and observed_local==expected['audit']
    contexts=[c for item in results for c in item['contexts']];postimages=[c for item in results for c in item['unaffected_postimages']]
    assert (len(contexts),sum(c['case']['days'] for c in contexts),sum(c['native_samples'] for c in contexts),sum(c['exact_cold_windows'] for c in contexts))==(64,1872,400,176)
    assert sum(c['controls']['actual_compiled_refusals'] for c in contexts)==1844 and sum(len(c['controls']['transactions']) for c in contexts)==88
    assert len(postimages)==32 and {c['current_compiler_source'] for c in postimages}=={'45bb6146f5800f4050e95feb5d1912ddfdd23d4d'}
    coadmission=dict(parent['receipt']['coadmission']);assert coadmission['contexts']==760
    coadmission.update(contexts=824,short35_contexts=coadmission['short35_contexts']+48,native_calendar_samples=coadmission['native_calendar_samples']+400,exact_cold_windows=coadmission['exact_cold_windows']+176,new_frost_analytical_boundary_contexts=64,new_frost_analytical_boundary_year12_contexts=16,new_frost_analytical_boundary_unaffected_postimages=32,new_frost_analytical_boundary_whole_object_comparisons=sum(c['whole_objects'] for c in postimages),previous_canonical=BASE)
    return dict(status='BOUNDED_ORIGINAL_ANALYTICAL_FROST_EXPLICIT_BOUNDARY568_DRAINAGE01_NATIVE_COLD_COMPOSITE_SCIENCE_PASS',actual_current_source=current,fresh_inherited_evidence=inherited,parent_historical_admission=parent,inherited_original_scientific_authority=authority,actual_raw_custody=raw,new_original_portable_science=results,additional_actual_local_science=observed_local,coadmission=coadmission,scientific_change_class='B_COMPOSITION_OF_EXISTING_UNCHANGED_PHYSICAL_PROCESSES_AND_EXISTING_NUMERICAL_SEARCH',additional_local_contexts_counted_again=False,unchanged_periods_replayed=False,original_scientific_producers_rebound=False,original_scientific_water_limit_cm='1e-10',original_scientific_cde_limit_mg_cm2='1e-10',new_physical_state=False,physical_equations_changed=False,inventory_or_flux_correction=False,original_dates_or_native_counters_normalized=False,automatic_fallback=False,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
