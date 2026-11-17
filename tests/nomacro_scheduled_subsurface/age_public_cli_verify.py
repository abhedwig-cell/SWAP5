"""Read-only comparison of actual public CLI run/restart artifacts."""
import argparse
import importlib.util
import json
from pathlib import Path

spec=importlib.util.spec_from_file_location('age_runtime',Path(__file__).with_name('age_runtime.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q);m=q.m


def verify(warm,cold,full):
    data=m.rows(warm);actual=m.rows(cold)
    assert len(data)==5 and len(actual)==2
    assert m.physical(actual)==m.physical(data[2:4])
    assert m.physical(data)==m.physical(m.rows(full)[:5])
    for name in ('result_output.csv','result.ageProfile.csv','result.ageeffluent.csv','result.ageeffluentqdrain.csv','result.ageeffluentwater.csv'):
        start=4 if name=='result_output.csv' else 3
        assert m.csvlines(cold/'original'/name)[-2:]==m.csvlines(warm/'original'/name)[start:start+2],name
    return dict(status='PUBLIC_ORIGINAL_AGE_BUILD_BUNDLE_RUN_RESTART_PASS',days=5,window=[2,4],
        all_physical_and_age_budgets_exact=True,all_five_csv_windows_exact=True)


if __name__=='__main__':
    p=argparse.ArgumentParser()
    for key in ('warm','cold','full','report'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();r=verify(a.warm,a.cold,a.full);a.report.write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
