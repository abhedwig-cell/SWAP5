"""Selected original output platform cohort; unchanged physics owners reused."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import original_output_matrix as matrix

ROOT=matrix.ROOT
CASES=('cde-solbal-csv3','age-csv3','water-nprint2','water-csv2','water-csv3','water-default-precision','water-csv0-omitted','water-nprint3','water-monthly','age-perstep-monthly','age-perstep-explicit','cde-csv0','cde-solbal-csv1','cde-solbal-csv2','age-csv0','age-csv2')


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--reuse-short-prefix');a=p.parse_args();a.output.mkdir()
    sys.path.insert(0,str(ROOT/'tools/solute'));import user_prepare
    if not (a.reference_work/'PREPARED.json').exists():user_prepare.prepare(a.reference_work)
    user_prepare.validate(a.reference_work);shutil.copyfile(a.reference_work/'PREPARED.json',a.output/'PROVIDER.json')
    def run(script,*args):subprocess.run([sys.executable,'-B',str(ROOT/'tests/nomacro_scheduled_subsurface'/script),*map(str,args)],cwd=ROOT,check=True)
    q=dict(status='RUNNING',optimization=a.optimization,cases={},source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    try:
        for case in CASES:
            short=Path(a.reuse_short_prefix+case+'-'+a.optimization) if a.reuse_short_prefix else a.output/('short-'+case+'-'+a.optimization)
            if not a.reuse_short_prefix:run('original_output_matrix.py','--reference-work',a.reference_work,'--output',short,'--case',case,'--optimization',a.optimization)
            previous=json.loads((short/'RESULT.json').read_text());assert previous['status']=='ORIGINAL_OUTPUT_SHORT_NATIVE_SOURCE_PASS'
            full=a.output/('full-'+case+'-'+a.optimization)
            run('original_output_matrix.py','--reference-work',a.reference_work,'--output',full,'--case',case,'--optimization',a.optimization,'--phase','full','--reuse-build',short/'build','--existing-input',short/'input')
            q['cases'][case]=dict(short=previous,full=json.loads((full/'RESULT.json').read_text()));save()
        short=Path(a.reuse_short_prefix+'water-nprint3-'+a.optimization) if a.reuse_short_prefix else a.output/('short-water-nprint3-'+a.optimization)
        run('age_clock_receipt_component.py','--reference-work',a.reference_work,'--build',short/'build','--optimization',a.optimization,'--output',a.output/'actual-integral-component')
        prefix=a.reuse_short_prefix or str(a.output/'short-')
        run('original_output_controls.py','--reference-work',a.reference_work,'--matrix-prefix',prefix,'--output',a.output/'controls','--optimization',a.optimization)
        if not a.reuse_short_prefix and a.optimization=='O0':
            baseline=a.output/'binary-input';baseline.mkdir();matrix.baseline.fixture(baseline/'water-csv3/input','water-csv3')
            run('original_binary_output.py','--reference-work',a.reference_work,'--baseline',baseline,'--output',a.output/'binary-component')
            run('original_vector_output.py','--reference-work',a.reference_work,'--output',a.output/'vector-component')
            run('original_cde_output_component.py','--reference-work',a.reference_work,'--output',a.output/'cde-output-component')
        q['status']='SIXTEEN_ORIGINAL_OUTPUT_FULL_SOURCE_NATIVE_USER_OUTPUT_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
