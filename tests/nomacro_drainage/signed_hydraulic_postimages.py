"""Check signed-literal builds against sealed unsigned full trajectories."""
import argparse
from contextlib import ExitStack
import io
import json
from pathlib import Path
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from analytical_hydraulic_archives import Archive,SHA
from analytical_interface_reuse import compare
from calendar_evidence import differences
from model7_unselected_science import physical,rows
from frost_cde_drainage_portable_forensics import binary
from vapor_hydraulic_forensics import audit
from vapor_windows_science import mapped
from signed_hydraulic_source_inverse import complete_inverse,RUNTIME


def read(evidence,reference):
    complete_inverse();observations=[]
    with ExitStack() as stack:
        for kind in ('water','cde'):
            old=Archive(ROOT/'integration/f-ci/nomacro-complete01','HYDRAULIC_VAPOR_WINDOWS_'+kind.upper()+'_RAW_V1',stack)
            projection=json.loads(old.get('COMPILED_PROJECTION_V1.json'))
            for opt in ('O0','O2'):
                profile=evidence/f'signed-hydraulic-mixed-7-8-{kind}-{opt}-v1'
                q=json.loads((profile/'RESULT.json').read_text())
                assert q['source'].startswith(RUNTIME) and q['status']==f'CANDIDATE_ACTUAL_VAPOR_FAMILY_8_{kind.upper()}_SHORT_PASS_NOT_ADMITTED'
                assert q['layer_models']==[7,8] and q['vapor_flags']==[1,1]
                build=Path(q['build_root']);inputs=Path(q['input_root'])
                role=next(v for v in old.record['roles'] if v['case']=='mixed-7-8' and v['optimization']==opt)
                baseline=old.view(role['profile']);prior=json.loads((baseline/'RESULT.json').read_text())
                oldbuild=old.view(projection[prior['build_root']]['archive_prefix']);oldinputs=mapped(old,prior['input_root'])
                interface=compare(build,oldbuild,[7,8])
                meta=json.loads((build/'BUILD.json').read_text());oldmeta=json.loads((oldbuild/'BUILD.json').read_text())
                delta=differences(oldmeta['identity'],meta['identity'])
                assert set(delta)=={'model7_capacity.source_sha256'},delta
                oldraw=(oldinputs/'swap.swp').read_text(encoding='cp1252')
                raw=(inputs/'swap.swp').read_text(encoding='cp1252')
                from original_output_baseline import assignment
                assert assignment(raw,'iHWCKmodel','7 8')==oldraw
                for name,digest in q['inventory'].items():
                    assert SHA((inputs/name).read_bytes())==digest
                    if name!='swap.swp':assert (inputs/name).read_bytes()==(oldinputs/name).read_bytes()
                warm=profile/'trajectory';oldwarm=baseline/'trajectory'
                assert physical(rows(warm))==physical(rows(oldwarm)[:35])
                for day in (2,4,19,23,30,34):
                    name=f'accepted-column-1-day-{day}.zip'
                    with zipfile.ZipFile(warm/name) as a,zipfile.ZipFile(io.BytesIO((oldwarm/name).read_bytes())) as b:
                        for member in ('macro.bin','result.end'):assert a.read(member)==b.read(member)
                current=binary((warm/'original/result_output.bin').read_bytes())
                assert current==binary((oldwarm/'original/result_output.bin').read_bytes())[:len(current)]
                independent=audit(profile,reference)
                assert independent['days']==35 and independent['cold_windows']==3
                observations.append(dict(kind=kind,optimization=opt,independent=independent,interface=interface,
                    actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),identity_changes=delta,
                    whole_generated_Fortran_provider_flags_exact=True,physical_native_REAL4_prefix_exact=True,
                    original_unsigned_full_source=prior['source'],signed_literal='+7 +8',parsed_vector=[7,8]))
    assert len(observations)==4
    return dict(status='SIGNED_ORIGINAL_HYDRAULIC_COMPILED_SHORT_NATIVE_POSTIMAGES_EXACT_UNSIGNED_FULL_PREFIX_PASS',
        runtime=RUNTIME,short35_contexts=4,exact_cold_windows=12,observations=observations,
        fresh_full_periods=0,compiler_executions=0,model_executions=0,canonical_admission=False)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('evidence','reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();assert not a.output.exists();result=read(a.evidence,a.reference_work)
    a.output.write_text(json.dumps(result,indent=2)+'\n');print(result['status'])


if __name__=='__main__':main()
