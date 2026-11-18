"""Selected fixed-age source state domains; short/native gates precede fulls."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import age_irrigation_source_matrix as probe

# kind, calendar, format, hysteresis, original-output, inline, age, events, full
CASES={
 'surface-daily':('surface','daily',1,0,False,False,20.,'varying',True),
 'sprinkler-zero':('sprinkler','daily',1,0,False,False,0.,'single',False),
 'sprinkler-upper':('sprinkler','daily',1,0,False,False,1000.,'single',False),
 'surface-regular':('surface','regular',1,0,False,False,20.,'varying',True),
 'sprinkler-monthly':('sprinkler','monthly',1,0,False,False,20.,'varying',True),
 'surface-np3':('surface','np3',1,0,False,False,20.,'varying',True),
 'sprinkler-annual':('sprinkler','annual',1,0,False,False,20.,'varying',True),
 'surface-output0':('surface','daily',0,0,True,False,20.,'varying',True),
 'surface-output3':('surface','daily',3,0,True,False,20.,'varying',True),
 'sprinkler-inline-output3':('sprinkler','daily',3,0,True,True,20.,'varying',False),
 'sprinkler-perstep-monthly':('sprinkler','perstep-monthly',2,0,True,False,20.,'varying',True),
 'surface-hys1-output3':('surface','daily',3,1,True,False,20.,'varying',True),
 'sprinkler-hys2-output0':('sprinkler','daily',0,2,True,False,20.,'varying',True),
 'surface-inline-daily':('surface','daily',1,0,False,True,20.,'varying',False)}
CONTROLS=('surface-daily','surface-regular','sprinkler-monthly','surface-np3','surface-output3','surface-hys1-output3','sprinkler-hys2-output0')


def arguments(case):
    kind,calendar,fmt,hys,original,inline,age,events=case[:8]
    args=['--kind',kind,'--calendar',calendar,'--format',str(fmt),'--hysteresis',str(hys),'--age-day',str(age),'--events',events]
    if original:args+=['--original-output']
    if inline:args+=['--inline']
    return args


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--reuse-regular-root',type=Path);p.add_argument('--resume',action='store_true');p.add_argument('--short-only',action='store_true');a=p.parse_args();a.output=a.output.resolve();a.output.mkdir(exist_ok=a.resume)
    sys.path.insert(0,str(probe.ROOT/'tools/solute'));import user_prepare
    if not (a.reference_work/'PREPARED.json').exists():user_prepare.prepare(a.reference_work)
    user_prepare.validate(a.reference_work);shutil.copyfile(a.reference_work/'PREPARED.json',a.output/'PROVIDER.json')
    q=dict(status='RUNNING',optimization=a.optimization,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),cases={},controls={},functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    if a.resume:
        q=json.loads((a.output/'RESULT.json').read_text());q.setdefault('retained_failures',[]).append(dict(status=q['status'],error=q.pop('error',None)));q['status']='RUNNING'
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def run(script,*args):subprocess.run([sys.executable,'-B',str(Path(__file__).with_name(script)),*map(str,args)],cwd=probe.ROOT,check=True)
    try:
        for key,case in CASES.items():
            short=a.output/('short-'+key)
            reuse=['--reuse-build',a.reuse_regular_root/'build','--existing-input',a.reuse_regular_root/'input'] if key=='surface-regular' and a.reuse_regular_root else []
            if not (short/'RESULT.json').exists():run('age_irrigation_source_matrix.py','--reference-work',a.reference_work,'--output',short,'--optimization',a.optimization,*arguments(case),*reuse)
            report=json.loads((short/'RESULT.json').read_text());assert report['status']=='AGE_IRRIGATION_SOURCE_SHORT_CURRENT_FORCING_NATIVE_OUTPUT_PASS'
            inputs=Path(report['input_root']);build=Path(report['build_root']);project=probe.m.e.load(inputs,original_output=case[4],age_irrigation_source=True);meta,_=probe.m.validate_bundle(build,a.reference_work,project)
            assert report['age_irrigation_source']==probe.metadata(project)==meta['identity']['original_age_fixed_irrigation']
            assert (report['kind'],report['calendar'],report['output_format'],report['hysteresis'],report['original_output'],report['inline'],report['age_day'],report['events'])==case[:8]
            q['cases'].setdefault(key,{}).update(short_root=str(short),build_root=str(build),input_root=str(inputs),short=report);save()
        for key in CONTROLS:
            out=a.output/('controls-'+key);short=Path(q['cases'][key]['short_root'])
            if not (out/'RESULT.json').exists():run('age_irrigation_source_controls.py','--reference-work',a.reference_work,'--profile-root',short,'--output',out)
            r=json.loads((out/'RESULT.json').read_text());assert r['status']=='FIXED_CURRENT_AGE_NATIVE_INPUT_IDENTITY_AND_VARYING_EXTERNAL_TRANSACTIONS_PASS' and r['build_sha256']==probe.m.sha(Path(q['cases'][key]['build_root'])/'BUILD.json');q['controls'][key]=r;save()
        if not a.short_only:
            for key,case in CASES.items():
                if not case[8]:continue
                build=Path(q['cases'][key]['build_root']);inputs=Path(q['cases'][key]['input_root']);full=a.output/('full-'+key)
                if not (full/'RESULT.json').exists():run('age_irrigation_source_matrix.py','--reference-work',a.reference_work,'--output',full,'--optimization',a.optimization,'--phase','full','--reuse-build',build,'--existing-input',inputs,*arguments(case))
                r=json.loads((full/'RESULT.json').read_text());assert r['status']=='AGE_IRRIGATION_SOURCE_FULL_CURRENT_FORCING_NATIVE_OUTPUT_PASS' and r['trajectory']['build_sha256']==probe.m.sha(build/'BUILD.json');q['cases'][key]['full']=r;save()
        q['status']='FOURTEEN_CURRENT_AGE_SOURCE_SHORT_AND_'+('NO_FULL_SELECTED' if a.short_only else 'TEN_FULL')+'_NATIVE_STATE_USER_OUTPUT_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
