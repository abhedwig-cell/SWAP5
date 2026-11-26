"""Bounded original analytical Frost public authority; actual merge owns admission."""
import io,json,re,zipfile
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from frost_boundary_git_archive import GitArchiveSource
from frost_analytical_source_custody import ROOT,source,git,BASE,PREFIX
from frost_analytical_inherited_custody import inherited_evidence
from frost_analytical_parent_admission import parent_admission
from frost_analytical_archive_science import portable,local
import frost_undrained_verify as previous
SEALED='48139db00b22d2f04c744c56aafe0e4118971043'

def data_source():return GitArchiveSource(ROOT,git('rev-parse','HEAD').decode().strip())

def frozen(name):
    raw=(data_source()/(name+'.json')).read_bytes();assert raw==git('show',SEALED+':'+PREFIX+name+'.json');return json.loads(raw)

def raw_custody():
    data=data_source();result=[]
    for path in git('ls-tree','-r','--name-only',SEALED,'--',PREFIX).decode().splitlines():
        name=Path(path).name
        if not name.startswith('FROST_ANALYTICAL_COMPOSITION09_') or not name.endswith('.json'):continue
        record=frozen(name[:-5])
        if not isinstance(record,dict) or not {'archive','bytes','sha256'}<=record.keys():continue
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
    rows=[]
    for platform in ['UBUNTU','WINDOWS']:
        for opt in ['O0','O2']:
            name='FROST_UNDRAINED_STATE08_INDEPENDENT_'+platform+'_'+opt+'_V2.json'
            raw=(data/name).read_bytes();assert raw==git('show',BASE+':'+PREFIX+name)
            q=json.loads(raw);assert q['actual_observer']=='5cdaef81cf68f034534779cdb29bcfdd74ca6103'
            audit=q['audit'];assert len(audit['contexts'])==16 and audit['compiler_executions']==audit['model_executions']==0
            rows.extend(audit['contexts'])
    assert len(rows)==64 and sum(x['case']['days'] for x in rows)==1872
    assert sum(x['native_samples'] for x in rows)==400 and sum(x['exact_cold_windows'] for x in rows)==176
    return dict(status='ACTUAL_CANONICAL712_ORIGINAL_SCIENTIFIC_AUTHORITY_FROZEN_WITH_CURRENT_MODEL1_POSTIMAGES',actual_qualified_canonical=BASE,original_scientific_producer='127af752c5519e7f9d9a6894c61137f0ee7f3920',original_independent_observer='5cdaef81cf68f034534779cdb29bcfdd74ca6103',model_periods_replayed=0,scientific_producer_rebound=False)


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
            observed=portable(data,platform,opt);expected=frozen(f'FROST_ANALYTICAL_COMPOSITION09_INDEPENDENT_{platform.upper()}_{opt}_V1')
            assert expected['actual_observer']==('a99b39b806ffe607f8af805ef34515495ec0ce39' if platform=='Ubuntu' else 'e911ae07bd67b151d86be4be3d6056515c226c28') and observed==expected['audit'];results.append(observed)
    local_science=local(data);expected=frozen('FROST_ANALYTICAL_COMPOSITION09_LOCAL_INDEPENDENT_V4')
    assert expected['actual_observer']=='f8976e0398056295152899178cbc49eef159ed0f' and local_science==expected['audit']
    contexts=[c for item in results for c in item['contexts']];postimages=[c for item in results for c in item['inherited_postimages']]
    assert (len(contexts),sum(c['case']['days'] for c in contexts),sum(c['native_samples'] for c in contexts),sum(c['exact_cold_windows'] for c in contexts))==(48,1312,288,128)
    assert sum(c.get('controls',{}).get('actual_compiled_refusals',0) for c in contexts)==4728
    assert sum(len(c.get('controls',{}).get('transactions',[])) for c in contexts)==80
    assert len(postimages)==32 and sum(c['whole_objects'] for c in postimages)==848
    coadmission=dict(parent['receipt']['coadmission']);assert coadmission['contexts']==712
    coadmission.update(contexts=760,short35_contexts=coadmission['short35_contexts']+32,native_calendar_samples=coadmission['native_calendar_samples']+288,exact_cold_windows=coadmission['exact_cold_windows']+128,new_frost_analytical_contexts=48,new_frost_analytical_year12_contexts=16,new_frost_analytical_model1_postimages=32,new_frost_analytical_whole_object_comparisons=848,previous_canonical=BASE)
    return dict(status='BOUNDED_ORIGINAL_ANALYTICAL_FROST_EXPLICIT58_NO_VAPOR_MODELS3_TO11_MIXED_NATIVE_COLD_AND_ACTIVE_TRANSACTIONS_PASS',actual_current_source=current,fresh_inherited_evidence=inherited,parent_historical_admission=parent,inherited_original_scientific_authority=old_science,actual_raw_custody=raw,new_original_portable_science=results,additional_actual_local_science=local_science,coadmission=coadmission,scientific_change_class='B_COMPOSITION_OF_EXISTING_UNCHANGED_PROCESSES',local_eight_contexts_counted_again=False,original_scientific_water_limit_cm='1e-10',original_scientific_cde_limit_mg_cm2='1e-10',divdra_selected_for_undrained_frost=False,new_physical_state=False,physical_equations_changed=False,inventory_or_flux_correction=False,original_dates_or_native_counters_normalized=False,automatic_fallback=False,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)

if __name__=='__main__':print(json.dumps(verify(),indent=2))
