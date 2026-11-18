"""Read-only actual old missing Snow totals and corrected sparse user output."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile
import thermal_calendar_runtime as runtime
from original_output_files import records

def main():
    p=argparse.ArgumentParser()
    for key in ('prior-root','corrected-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();old=json.loads((a.prior_root/'RESULT.json').read_text());new=json.loads((a.corrected_root/'RESULT.json').read_text())
    assert old['status']=='FAILED' and new['status']=='ACTUAL_WATER_SNOW_CALENDAR_SHORT_NATIVE_USER_OUTPUT_PASS'
    assert old['original_output']['native_codec']=='S5CTW001' and new['original_output']['native_codec']=='S5CTW002'
    def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
    q=dict(status='RUNNING',mode='READ_ONLY_ACTUAL_PRODUCER_DIAGNOSTIC_NO_MODELS_OR_REBINDING',original_legacy_equation_defect=False,checks={})
    oldrows=runtime.m.rows(a.prior_root/'trajectory');newrows=runtime.m.rows(a.corrected_root/'trajectory')
    assert runtime.m.physical(oldrows)==runtime.m.physical(newrows)
    assert records(a.prior_root/'trajectory/original/result_output.bin')==records(a.corrected_root/'trajectory/original/result_output.bin')
    q['actual_warm_physical_and_user_output_unchanged']=True
    for label,root in (('before',a.prior_root),('corrected',a.corrected_root)):
        warm=root/'trajectory';cold=root/'own-30';rows=runtime.m.rows(warm)
        assert runtime.m.physical(runtime.m.rows(cold))==runtime.m.physical(rows[30:34])
        source=warm/'accepted-column-1-day-30.zip';source_sha=digest(source)
        with zipfile.ZipFile(warm/'accepted-column-1-day-34.zip') as w,zipfile.ZipFile(cold/'accepted-column-1-day-34.zip') as c:
            assert all(w.read(name)==c.read(name) for name in ('result.end','macro.bin'))
        w=records(warm/'original/result_output.bin');c=records(cold/'original/result_output.bin')
        expected=[v for v in w[1:] if b'2002-01-31' in v];actual=c[1:]
        assert len(expected)==len(actual)==1
        exact=expected==actual;assert exact==(label=='corrected')
        with zipfile.ZipFile(source) as z:raw=z.read('macro.bin')
        n=len(rows[0]['pressure_head_cm']);header=struct.pack('<4i',1,n,0,7)
        assert (raw.count(header+header)==1)==(label=='corrected')
        q['checks'][label]=dict(physical_exact=True,complete_native_exact=True,january31_user_output_exact=exact,
            original_source_checkpoint_sha256=source_sha,source_unchanged=digest(source)==source_sha,
            actual_seven_totals_domain_present=label=='corrected',build_sha256=digest(root/'build/BUILD.json'))
    q['status']='ACTUAL_SPARSE_SNOW_NATIVE_OUTPUT_GAP_AND_CORRECTION_CONFIRMED'
    (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8');print(q['status'],flush=True)

if __name__=='__main__':main()
