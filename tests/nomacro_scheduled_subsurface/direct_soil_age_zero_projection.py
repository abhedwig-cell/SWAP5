"""Compare actual zero-source output with immutable qualified young-water bytes."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import zipfile
import direct_soil_age_matrix as matrix

m=matrix.m;ROOT=matrix.ROOT


def main():
    ap=argparse.ArgumentParser()
    for key in ('matrix-root','output'):ap.add_argument('--'+key,type=Path,required=True)
    ap.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=ap.parse_args();a.output.mkdir();cohort=json.loads((a.matrix_root/'RESULT.json').read_text());current=Path(cohort['cases']['interval-zero']['short_root'])/'trajectory'
    p=ROOT/'integration/f-ci/nomacro-complete01';record=json.loads((p/'AGE_FIXED_WINDOWS_RAW_ARCHIVE.json').read_text());archive=p/record['archive']
    assert archive.stat().st_size==record['bytes'] and hashlib.sha256(archive.read_bytes()).hexdigest()==record['sha256']
    rows=m.rows(current);projected=[]
    for row in rows:
        value=dict(row);assert value.pop('age_direct_soil_input_cm_day')==value['age_state_cm_day'][-1]==value['age_ledger_cm_day'][-1]==0.
        value['age_state_cm_day']=value['age_state_cm_day'][:-1];value['age_ledger_cm_day']=value['age_ledger_cm_day'][:-1];projected.append(value)
    endpoints=[]
    with zipfile.ZipFile(archive) as z:
        prefix='age-fixed/subsurface-interval-'+a.optimization
        old=[json.loads(s) for s in z.read(prefix+'-full/daily.jsonl').splitlines()][:10]
        assert m.physical(projected)==m.physical(old)
        for day in (2,4,8):
            name=prefix+('-short' if day==8 else '-full')+f'/accepted-column-1-day-{day}.zip'
            with zipfile.ZipFile(io.BytesIO(z.read(name))) as before,zipfile.ZipFile(current/f'accepted-column-1-day-{day}.zip') as after:
                assert before.read('result.end')==after.read('result.end')
                previous=before.read('macro.bin');actual=after.read('macro.bin')
                assert previous[:8]==b'S5AGE002' and actual[:8]==b'S5DI0002' and actual[8:-80]==previous[8:]
            endpoints.append(day)
    q=dict(status='ACTUAL_ZERO_DIRECT_SOIL_SOURCE_IMMUTABLE_YOUNG_PHYSICAL_AND_NATIVE_PROJECTION_PASS',optimization=a.optimization,prior_archive_sha256=record['sha256'],prior_raw_unchanged=True,all_ten_physical_days_exact=True,complete_old_payload_exact=endpoints,projection='only new explicit codec,56byte source domain,24byte direct owner and zero appended protocol fields; no checkpoint conversion/adoption/rebinding')
    (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'],a.optimization,flush=True)


if __name__=='__main__':main()
