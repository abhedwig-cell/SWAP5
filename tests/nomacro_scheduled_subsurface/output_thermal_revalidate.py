"""Read-only recovery of actual completed thermal matrices after endpoint harness error."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import output_thermal_ci as matrix


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','matrix-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir(parents=True)
    original_bytes=(a.matrix_root/'RESULT.json').read_bytes();original=json.loads(original_bytes)
    assert original['status']=='FAILED' and 'accepted-column-1-day-35.zip' in original['error']
    assert set(original['cases'])==set(matrix.CASES) and set(original['controls'])==set(matrix.CONTROLS)
    for key,case in matrix.CASES.items():
        assert (a.matrix_root/('short-'+key)/'RESULT.json').is_file() and (a.matrix_root/('short-'+key)/'build/BUILD.json').is_file()
        if case[4]:assert original['cases'][key]['full']['status']=='ORIGINAL_OUTPUT_THERMAL_FULL_SNOW_COMPOUND_NATIVE_USER_FILES_PASS' and (a.matrix_root/('full-'+key)/'RESULT.json').is_file()
    for key in matrix.CONTROLS:assert original['controls'][key]['status']=='ORIGINAL_OUTPUT_THERMAL_ACTUAL_NATIVE_ACTIVE_AND_POLICY_REFUSALS_PASS' and (a.matrix_root/('controls-'+key)/'RESULT.json').is_file()
    def physical_files():
        return {f.relative_to(a.matrix_root).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in a.matrix_root.rglob('*') if f.is_file() and f.relative_to(a.matrix_root).as_posix() not in ('RESULT.json','PROVIDER.json')}
    before=physical_files();command=[sys.executable,'-B',str(Path(matrix.__file__)),'--reference-work',str(a.reference_work),'--output',str(a.matrix_root),'--optimization',a.optimization,'--resume']
    p=subprocess.run(command,capture_output=True,text=True,timeout=180);(a.output/'revalidate.stdout').write_text(p.stdout);(a.output/'revalidate.stderr').write_text(p.stderr);assert p.returncode==0,p.stderr
    after=physical_files();assert before==after,'Actual source/model/build/native/individual report bytes changed during format revalidation'
    actual_bytes=(a.matrix_root/'RESULT.json').read_bytes();actual=json.loads(actual_bytes)
    assert actual['status']=='SEVENTEEN_THERMAL_OUTPUT_SHORT_AND_FOURTEEN_FULL_SNOW_NATIVE_USER_FILES_PASS' and actual['cases']==original['cases'] and actual['controls']==original['controls'] and actual['source_commit']==original['source_commit']
    assert set(actual['format_independence'])=={'water','chemical','frost-drained'} and all(v==dict(all1096_physical_exact=True,eight_complete_native_endpoints_exact=True) for v in actual['format_independence'].values())
    (a.output/'ORIGINAL_MATRIX_RESULT.json').write_bytes(original_bytes);(a.output/'REVALIDATED_MATRIX_RESULT.json').write_bytes(actual_bytes)
    q=dict(status='ACTUAL_COMPLETE_THERMAL_MATRIX_READ_ONLY_FORMAT_REVALIDATION_PASS',optimization=a.optimization,model_executions=0,actual_unchanged_member_count=len(before),actual_unchanged_members=before,original_matrix_result_sha256=hashlib.sha256(original_bytes).hexdigest(),revalidated_matrix_result_sha256=hashlib.sha256(actual_bytes).hexdigest(),actual_model_source_commit=original['source_commit'],revalidation_controller_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=matrix.probe.ROOT,text=True).strip(),individual_builds_sources_days_native_and_reports_unchanged=True,actual_full_periods=14,actual_short_periods=17,actual_control_contexts=8,correction='Final comparison requests actual published days4/8/23/34/201/367/532/1096; short-only35 is not fabricated; original portable artifact ZIP bytes are retained separately')
    (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(a.optimization,q['status'],len(before),flush=True)


if __name__=='__main__':main()
