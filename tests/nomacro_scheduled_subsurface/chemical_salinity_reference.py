"""Paired pristine/corrected original response using already qualified objects."""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import time


def main():
    p=argparse.ArgumentParser()
    for name in ('reference-evidence','input','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();out=a.output.resolve();out.mkdir()
    prior=json.loads((a.reference_evidence/'RESULT.json').read_text())
    assert prior['status']=='CORRECTED_ORIGINAL_NODAL_CHEMICAL_SOURCE_O0_O2_AND_SOURCE_ABSENT_PRESERVATION_PASS'
    result=dict(status='RUNNING',profiles={},reference_source_commit=prior['source_commit'],b1_promotion=False)
    try:
        for opt in ('O0','O2'):
            for version in ('original','corrected'):
                name=version+'-'+opt;executable=(a.reference_evidence/name/'swap_reference.exe').resolve()
                digest=hashlib.sha256(executable.read_bytes()).hexdigest()
                assert digest==prior['profiles'][name]['executable_sha256']
                case=out/name;shutil.copytree(a.input,case)
                started=time.perf_counter();run=subprocess.run([str(executable),'./swap.swp'],cwd=case,capture_output=True,timeout=30)
                (case/'reference.stdout').write_bytes(run.stdout);(case/'reference.stderr').write_bytes(run.stderr)
                assert (case/'swap.ok').exists()
                lines=[s for s in (case/'result_output.csv').read_text().splitlines() if s.strip() and not s.startswith('*')]
                rows=list(csv.DictReader(lines));assert len(rows)==1097
                mass=math.fsum(float(row['S_IRRIG']) for row in rows)
                reduction=math.fsum(float(row['TREDSOL']) for row in rows)
                balance=max(abs(float(row['S_BALDEV'])) for row in rows);assert balance<=1e-10
                if version=='corrected':assert abs(mass-48)<1e-10 and reduction>0
                else:assert mass==0 and reduction==0
                result['profiles'][name]=dict(days=1096,executable_sha256=digest,input_mass_mg_cm2=mass,
                    salinity_reduction_cm=reduction,max_printed_solute_residual_mg_cm2=balance,seconds=time.perf_counter()-started)
        result['status']='CORRECTED_ORIGINAL_SOURCE_ACTIVATES_SALINITY_PRISTINE_SOURCE_ABSENT_PASS'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    print(result['status'],flush=True)


if __name__=='__main__':main()
