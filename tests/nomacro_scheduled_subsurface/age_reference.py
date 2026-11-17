"""Execute exact original age option with retained original bounds executables.

This is an original-reference diagnostic, not SWAP5 admission or a chemical
mass comparison. Age has units water depth times days.
"""
import argparse
import csv
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tools/solute'),str(ROOT/'app/hybrid_water')]
from fixed_irrigation_cases import create
spec=importlib.util.spec_from_file_location('aq_reference',ROOT/'reference/swap-4.3.1/patches/NOMACRO-AQUIFER-SOLUTE-01/run.py')
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def fixture(case,initial):
    create(case,'water-file-surface');path=case/'swap.swp';text=path.read_text(encoding='cp1252')
    for key,value in dict(SWSOLU=2,SWBR=0,SWSNOW=0,SWIRFIX=0,SWMONTH=0,INLIST_CSV="'WATBAL,GWL'").items():
        text=q.assignment(text,key,value)
    text+='\nAGEMLTB =\n -10.0 '+repr(initial)+'\n -95.0 '+repr(initial)+'\n* End of table\nNUM_DECIMALS = 12\n'
    path.write_text(text,encoding='cp1252')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--checked-original-root',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir();report=dict(status='RUNNING',profiles={},science='NOT_QUALIFIED',SWAP5_activation=False)
    identity=json.loads((ROOT/'integration/f-ci/nomacro-complete01/AQUIFER_ORIGINAL_BOUNDS.json').read_text())
    def save():(a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    save()
    try:
        for opt in ('O0','O2'):
            build=a.checked_original_root/opt;exe=build/'swap_bounds.exe'
            assert sha(exe)==identity['profiles'][opt]['executable_sha256']
            assert sha(build/'solute.f90')==identity['original_source_sha256']
            for initial in (0.,100.):
                key=opt+'-'+str(int(initial));case=a.output/key;fixture(case,initial)
                inputs={p.relative_to(case).as_posix():sha(p) for p in case.rglob('*') if p.is_file()}
                start=time.perf_counter();run=subprocess.run([str(exe),'./swap.swp'],cwd=case,capture_output=True,timeout=45)
                (case/'original.stdout').write_bytes(run.stdout);(case/'original.stderr').write_bytes(run.stderr)
                result=dict(returncode=run.returncode,seconds=time.perf_counter()-start,executable_sha256=sha(exe),original_solute_sha256=sha(build/'solute.f90'),input_sha256=inputs,swap_ok=(case/'swap.ok').exists(),outputs={})
                for path in sorted(case.glob('*.csv')):
                    rows=list(csv.reader([s for s in path.read_text(encoding='cp1252').splitlines() if s.strip() and not s.startswith('*')]))
                    nonfinite=[]
                    for index,row in enumerate(rows[1:],1):
                        for value in row:
                            try:finite=math.isfinite(float(value))
                            except ValueError:continue
                            if not finite:nonfinite.append((index,value))
                    result['outputs'][path.name]=dict(rows=max(0,len(rows)-1),nonfinite=len(nonfinite),sha256=sha(path))
                result['diagnostic']=run.stderr.decode(errors='replace')
                result['status']='ORIGINAL_BOUNDS_FAILURE' if 'Fortran runtime error: Index' in result['diagnostic'] else 'ORIGINAL_COMPLETE_DIAGNOSTIC' if result['swap_ok'] else 'ORIGINAL_REFUSED_DIAGNOSTIC'
                report['profiles'][key]=result;save();print(key,result['status'],result['diagnostic'][:300],flush=True)
        report['status']='ORIGINAL_AGE_DIAGNOSTICS_RECORDED'
    except Exception as error:report.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
