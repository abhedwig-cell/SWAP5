"""Selected original-output hysteresis cohort, with source-bound short reuse."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import output_hysteresis as probe

CASES=[(kind,mode,fmt,'daily') for kind in ('water','cde','age') for mode in (1,2) for fmt in (0,3)]+[
    ('water',2,3,'np3'),('age',1,1,'np3'),('water',1,1,'monthly'),('age',2,2,'perstep-monthly')]


def name(case):
    kind,mode,fmt,calendar=case
    return f'{kind}-hys{mode}-csv{fmt}'+('' if calendar=='daily' else '-'+calendar)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--reuse-pilot-prefix');p.add_argument('--short-only',action='store_true')
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir()
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),optimization=a.optimization,cases={},functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def run(case,out,*extra):
        kind,mode,fmt,calendar=case
        subprocess.run([sys.executable,'-B',str(Path(__file__).with_name('output_hysteresis.py')),'--reference-work',str(a.reference_work),'--output',str(out),'--kind',kind,'--hysteresis-mode',str(mode),'--output-format',str(fmt),'--calendar',calendar,'--optimization',a.optimization,*map(str,extra)],cwd=probe.ROOT,check=True)
    try:
        # Complete all discriminating short cases before starting any full run.
        for case in CASES:
            key=name(case);short=Path(a.reuse_pilot_prefix+key+'-'+a.optimization) if a.reuse_pilot_prefix else a.output/('short-'+key)
            if not (short/'RESULT.json').exists():
                short=a.output/('short-'+key);run(case,short)
            actual=json.loads((short/'RESULT.json').read_text());assert actual['status']=='ORIGINAL_OUTPUT_HYSTERESIS_SHORT_SOURCE_NATIVE_PASS'
            project=probe.m.e.load(short/'input',original_output=True)
            assert actual['original_output']==probe.metadata(project)
            probe.m.validate_bundle(short/'build',a.reference_work,project)
            assert (actual['kind'],actual['hysteresis_mode'],actual['output_format'],actual['calendar'],actual['optimization'])==(*case,a.optimization)
            q['cases'][key]=dict(short_root=str(short),short=actual);save()
        if not a.short_only:
            for case in CASES:
                key=name(case);short=Path(q['cases'][key]['short_root']);full=a.output/('full-'+key)
                run(case,full,'--phase','full','--reuse-build',short/'build','--existing-input',short/'input')
                q['cases'][key]['full']=json.loads((full/'RESULT.json').read_text());save()
        q['status']='SIXTEEN_HYSTERESIS_ORIGINAL_OUTPUT_'+('SHORT' if a.short_only else 'FULL')+'_SOURCE_NATIVE_USER_OUTPUT_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
