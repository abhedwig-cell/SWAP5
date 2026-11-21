"""Read actual unchanged compiled Fortran and short native postimages from archives."""
from contextlib import ExitStack
from datetime import date,timedelta
import io
import json
from pathlib import Path
import types
import zipfile
from model7_search_science import Store,SHA
from frost_cde_drainage_portable_forensics import binary
from calendar_publisher import publisher_equivalence
from calendar_evidence import differences


def mapped(store,path):return store.view('profiles/'+path.replace('\\','/').split('/evidence/',1)[1])
def rows(folder):return [json.loads(line) for line in (folder/'daily.jsonl').read_text().splitlines()]


def physical(data):
    fields=('day','committed','stock_start_cm','stock_end_cm','external_flux_cm','pressure_head_cm','groundwater_cm','drainage_outward_cm','bottom_outward_cm',
        'solute_start_mg_cm2','solute_end_mg_cm2','solute_ledger_mg_cm2')
    return [{key:row[key] for key in fields if key in row} for row in data]


def read(proof):
    result=[]
    with ExitStack() as stack:
        current=Store(proof,'HYDRAULIC_MODEL7_UNSELECTED_WINDOWS_RAW_V1',stack)
        projection=json.loads(current.get('COMPILED_PROJECTION_V1.json'));inputs=json.loads(current.get('INPUT_PROJECTION_V1.json'))
        support=Store(proof,'FROST_IMPLICIT_WINDOWS_SUPPORT_RAW_ARCHIVE',stack)
        publisher=types.FunctionType(publisher_equivalence.__code__,dict(publisher_equivalence.__globals__,Path=lambda value:value))
        failures=[]
        for opt in ('O0','O2'):
            old=Store(proof,'FROST_IMPLICIT_WINDOWS_UNSELECTED_'+opt+'_RAW_ARCHIVE',stack)
            frost=Store(proof,'FROST_IMPLICIT_WINDOWS_'+opt+'_SCIENCE_RAW_ARCHIVE',stack)
            prefix=f'profiles/model7-unselected-postimages-{opt}-v4';cohort=json.loads(current.get(prefix+'/RESULT.json'))
            assert cohort['status']=='ACTUAL_FOUR_TARGETED_UNSELECTED_MODEL7_DEPENDENCY_POSTIMAGES_PASS' and len(cohort['profiles'])==4
            for variant in (1,2,3):
                previous=json.loads(current.get(f'profiles/model7-unselected-postimages-{opt}-v{variant}/RESULT.json'));assert previous['status']=='FAILED';failures.append(previous['error'])
            for name,item in cohort['profiles'].items():
                assert item['status']=='UNSELECTED_COMPLETE_COMPILED_FORTRAN_35DAY_NATIVE_REAL4_COLD_EXACT_PASS'
                key=projection[item['build_root']];build=current.view(key['archive_prefix']);assert SHA((build/'BUILD.json').read_bytes())==key['actual_BUILD_sha256']
                base=item['baseline'];is_frost=name.startswith('implicit-frost-');prior=frost if is_frost else old
                prior_projection=json.loads((support if is_frost else old).get('COMPILED_PROJECTION_V1.json' if is_frost else 'UNSELECTED_COMPILED_PROJECTION_V1.json'))
                oldkey=prior_projection[base['build_root']];oldbuild=prior.view(oldkey['prefix']);assert SHA((oldbuild/'BUILD.json').read_bytes())==oldkey['actual_BUILD_sha256']
                before={path.name:path.read_bytes() for path in oldbuild.glob('*.f90')};after={path.name:path.read_bytes() for path in build.glob('*.f90')}
                assert before==after and {key:SHA(value) for key,value in after.items()}==item['unchanged_complete_Fortran']
                meta=json.loads((build/'BUILD.json').read_text());oldmeta=json.loads((oldbuild/'BUILD.json').read_text());identity=meta['identity']
                assert not identity.get('model7_capacity') and not identity.get('model7_terminal_water')
                delta=differences(oldmeta['identity'],identity);assert delta==item['identity_changes'] and set(delta)<={'host','original_output.composition_build_sha256','restart_publisher.library_sha256'}
                if 'restart_publisher.library_sha256' in delta:
                    actual=publisher(oldbuild/'restart_publish.dll',build/'restart_publish.dll');assert actual==item['publisher_equivalence']
                for filename,digest in identity['donor_generated'].items():assert SHA((build/filename).read_bytes())==digest
                for filename,digest in identity['donor_objects'].items():assert SHA(support.get('original-provider-build/swap-obj/'+filename))==digest
                for role,digest in meta['executable_sha256'].items():assert SHA((build/('day_'+role+'.exe')).read_bytes())==digest
                for filename,digest in inputs[item['input_root']]['files'].items():assert SHA(current.get(inputs[item['input_root']]['archive_prefix']+'/'+filename))==digest
                warm=mapped(current,item['trajectory_root']);data=rows(warm);oldwarm=mapped(prior,base['trajectory_root']);assert len(data)==35 and physical(data)==physical(rows(oldwarm)[:35])
                for day in (2,4,30,34,35):
                    with zipfile.ZipFile(io.BytesIO((warm/f'accepted-column-1-day-{day}.zip').read_bytes())) as x,zipfile.ZipFile(io.BytesIO((oldwarm/f'accepted-column-1-day-{day}.zip').read_bytes())) as y:
                        assert all(x.read(key)==y.read(key) for key in ('macro.bin','result.end'))
                actual_output=binary((warm/'original/result_output.bin').read_bytes())
                assert actual_output==binary((oldwarm/'original/result_output.bin').read_bytes())[:len(actual_output)]
                cold=mapped(current,item['retained_cold_actual_root']) if item.get('retained_cold_actual_root') else current.view(prefix+'/'+name+'/own-30')
                assert physical(rows(cold))==physical(data[30:34])
                with zipfile.ZipFile(io.BytesIO((warm/'accepted-column-1-day-34.zip').read_bytes())) as x,zipfile.ZipFile(io.BytesIO((cold/'accepted-column-1-day-34.zip').read_bytes())) as y:
                    assert all(x.read(key)==y.read(key) for key in ('macro.bin','result.end'))
                first=date.fromisoformat(meta['project']['start_date']);low,high=str(first+timedelta(days=30)),str(first+timedelta(days=34))
                output=binary((warm/'original/result_output.bin').read_bytes());selected=identity['original_output']
                clock=selected['flprintdt'] or selected['nprintday']>1
                if clock:low+=' 00:00:00';high+=' 00:00:00'
                expected=[row for row in output[1:] if (low<row[:19].decode().strip()<=high if clock else low<=row[:19].decode().strip()<high)]
                assert binary((cold/'original/result_output.bin').read_bytes())[1:]==expected
                result.append(dict(name=name,optimization=opt,days=35,cold_window=[30,34],complete_compiled_Fortran_exact=True,physical_native_REAL4_exact=True,publisher_code_and_data_exact=True))
    assert len(result)==8
    return dict(status='ACTUAL_EIGHT_UNSELECTED_MODEL7_DEPENDENCY_POSTIMAGES_INDEPENDENT_PASS',contexts=result,unaffected_full_periods_replayed=0,
        original_observer_failures_retained=failures,compiler_executions=0,model_executions=0,public_admission=False)


if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
    result=read(a.proof);a.output.write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
