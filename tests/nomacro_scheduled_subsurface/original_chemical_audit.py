"""Original-source concentration perturbation for the refused chemical SSDI gap.

This is a legacy defect discriminator, not a SWAP5 admission or a new oracle.
The positive surface control must actually respond to the same concentration.
"""
import argparse
import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tools/solute'),str(ROOT/'app/hybrid_water')]
from fixed_irrigation_cases import create
import daily_host as h
import user_prepare
spec=importlib.util.spec_from_file_location('ssdi',ROOT/'tests/nomacro_scheduled_subsurface/run.py')
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--reference-work',type=Path,required=True);a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);reference=a.reference_work.resolve();user_prepare.validate(reference)
    executable=h.executable(reference/'build','swap_b0_gfortran');sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest();reports={};rows={}
    for kind in ('surface','subsurface'):
        for concentration in (0.,20.):
            key=kind+'-'+str(int(concentration));case=create(out/key,'water-file-'+kind)
            control=case/'swap.swp';body=control.read_text(encoding='cp1252')
            for name,value in dict(SWSOLU=1,SWMONTH=0,INLIST_CSV="'WATBAL,SOLBAL,GWL'").items():body=q.assignment(body,name,value)
            body+='\nNUM_DECIMALS = 12\n';control.write_text(body,encoding='cp1252')
            irrigation=case/'fixed-irrigation.irg';body=irrigation.read_text();assert '24.0 20.0 ' in body
            irrigation.write_text(body.replace('24.0 20.0 ','24.0 '+repr(concentration)+' '))
            inputs={path.relative_to(case).as_posix():sha(path) for path in case.rglob('*') if path.is_file()}
            started=time.perf_counter()
            with (case/'standalone.stdout').open('wb') as log:r=subprocess.run([str(executable),'./swap.swp'],cwd=case,stdout=log,stderr=subprocess.STDOUT,timeout=30)
            elapsed=time.perf_counter()-started
            lines=[line for line in (case/'result_output.csv').read_text().splitlines() if line.strip() and not line.startswith('*')]
            data=list(csv.DictReader(lines));assert (case/'swap.ok').exists() and len(data)==1097
            rows[key]=data
            reports[key]=dict(returncode=r.returncode,rows=len(data),complete_original_period=True,seconds=elapsed,input_sha256=inputs,
                              actual_ssdi_cm=sum(float(row['SSDI']) for row in data),maximum_reported_solute_storage=float(max(float(row['S_STOT']) for row in data)))
            print(key,'ORIGINAL_COMPLETE',flush=True)
    assert reports['subsurface-20']['actual_ssdi_cm']>0
    assert rows['subsurface-0']==rows['subsurface-20'], 'Original chemical SSDI responds; do not classify missing source without further analysis'
    assert rows['surface-0']!=rows['surface-20'], 'Invalid concentration perturbation: positive surface control did not respond'
    solute_fields=[name for name in rows['surface-20'][0] if name.startswith('S_')]
    differences={name:max(abs(float(x[name])-float(y[name])) for x,y in zip(rows['surface-0'],rows['surface-20'])) for name in solute_fields}
    assert any(value>0 for value in differences.values())
    result=dict(status='ORIGINAL_CHEMICAL_SSDI_CONCENTRATION_INVARIANCE_WITH_POSITIVE_SURFACE_CONTROL',classification='INHERITED_DEFECT',
                source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),executable_sha256=sha(executable),profiles=reports,
                subsurface_all_output_rows_exact_across_concentration=True,surface_solute_maximum_differences=differences,
                original_source_qssdi_references_in_CDE=0,scientific_equivalence='NOT_QUALIFIED',production_change=False,
                next='Qualify an explicit corrected-reference nodal solute source and conserved irrigation ledger before enabling chemical subsurface transport; retain present refusal.')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],flush=True)


if __name__=='__main__':main()
