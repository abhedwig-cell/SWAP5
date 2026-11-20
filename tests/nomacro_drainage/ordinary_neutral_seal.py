"""Freeze recomputed ordinary scientific observations, without admission claims."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--evidence',type=Path,required=True);a=p.parse_args()
    proof=ROOT/'integration/f-ci/nomacro-complete01'
    windows=json.loads((a.evidence/'ORDINARY_SEALED_WINDOWS_INDEPENDENT_V1.json').read_text())
    ubuntu=json.loads((a.evidence/'ORDINARY_SEALED_UBUNTU_INDEPENDENT_V1.json').read_text())
    assert windows['status']=='INDEPENDENT_WINDOWS_ORDINARY_RAW_SCIENCE_PASS' and len(ubuntu)==4
    assert all(v['status']=='INDEPENDENT_UBUNTU_ORDINARY_RAW_SCIENCE_PASS' for v in ubuntu.values())
    archives={}
    for p in sorted(proof.glob('ORDINARY_IMPLICIT_POND_*_RAW_ARCHIVE.json')):
        raw=p.read_bytes();q=json.loads(raw);path=proof/q['archive']
        assert path.stat().st_size==q['bytes'] and hashlib.sha256(path.read_bytes()).hexdigest()==q['sha256']
        archives[p.stem]=dict(record=p.name,record_lf_sha256=hashlib.sha256(raw.replace(b'\r\n',b'\n')).hexdigest())
    assert len(archives)==7
    q=dict(status='NEUTRAL_ORDINARY_IMPLICIT_POND_RAW_SCIENCE_PASS_PENDING_ADMISSION',
           runtime='614e1c5a5ce383222d6febb9d183aac14bf4a625',numeric_runtime='b96f69a397615d24f7af4fc1cdf28bf591957a04',
           predecessor='d785e2c3c415122b8e391d3979f1fbceb81ce5b5',independent_readers='69f03573043fcd5bf6fe6c9b323bcccb176c485a',
           sealer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
           archives=archives,Windows=windows,Ubuntu=ubuntu,
           baseline_lf_sha256=hashlib.sha256((proof/'ORDINARY_NONSELECTED_ACTUAL_BASELINE_BINDINGS_V1.json').read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
           actual_full_periods=8,actual_days_per_full_period=1096,actual_full_cold_windows=64,
           actual_short_contexts=24,actual_short_cold_windows=72,actual_source_policy_refusals=320,
           actual_current_native_postimages=18,actual_current_transactions=4,actual_nonselected_contexts=6,
           original_reference_defects=['Positive pond branch1e-6cm discontinuity','Missing conductivity/pond chain rule','Original nonlinear pond root stopped at1e-6cm'],
           daily_water_guard_cm=1e-10,integrated_water_guard_cm=1e-10,daily_CDE_guard_mg_cm2=1e-10,integrated_CDE_guard_mg_cm2=1e-10,
           new_native_format=False,new_physical_state=False,convergence_clock_mass_rollback_limits_changed=False,
           resource_budget_role='Explicit600s full weighted water resource budget; original180s censored runs retained; CDEfull180s unchanged; no numerical tolerance change',
           original_initial_Ubuntu_job_conclusion='FAILURE_AFTER_FULL_WATER_AND_THREE_SHORTS',
           followup_Ubuntu_job_conclusion='SUCCESS_MISSING_ONLY_THREE_SHORTS_AND_FULL_CDE',
           ordinary_implicit_admitted=False,AGE_admitted=False,CDE_groundwater_subdaily_admitted=False,
           functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
    out=proof/'ORDINARY_IMPLICIT_POND_QUALIFICATION.json';assert not out.exists()
    out.write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(q['status'])


if __name__=='__main__':main()
