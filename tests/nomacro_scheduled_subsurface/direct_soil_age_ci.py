"""Direct-age source selected state/output cohort; no generic qualification layer."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
import direct_soil_age_matrix as probe

# kind, calendar, format, hysteresis, original-output, inline, age, events, full
CASES={
 'point-daily':('subsurface','daily',1,0,False,False,20.,'varying',True),
 'interval-daily':('subsurface-interval','daily',1,0,False,False,20.,'varying',True),
 'interval-zero':('subsurface-interval','daily',1,0,False,False,0.,'single',False),
 'point-upper':('subsurface','daily',1,0,False,False,1000.,'single',False),
 'point-regular':('subsurface','regular',1,0,False,False,20.,'varying',True),
 'interval-monthly':('subsurface-interval','monthly',1,0,False,False,20.,'varying',True),
 'point-np3':('subsurface','np3',1,0,False,False,20.,'varying',True),
 'interval-annual':('subsurface-interval','annual',1,0,False,False,20.,'varying',True),
 'point-output0':('subsurface','daily',0,0,True,False,20.,'varying',True),
 'point-output3':('subsurface','daily',3,0,True,False,20.,'varying',True),
 'interval-inline-output3':('subsurface-interval','daily',3,0,True,True,20.,'varying',False),
 'interval-perstep-monthly':('subsurface-interval','perstep-monthly',2,0,True,False,20.,'varying',True),
 'point-hys1-output3':('subsurface','daily',3,1,True,False,20.,'varying',True),
 'interval-hys2-output0':('subsurface-interval','daily',0,2,True,False,20.,'varying',True),
 'point-inline-daily':('subsurface','daily',1,0,False,True,20.,'varying',False),
 'surface-current':('surface','daily',1,0,False,False,20.,'varying',False),
 'sprinkler-current':('sprinkler','daily',1,0,False,False,20.,'varying',False)}
CONTROLS=('point-daily','interval-daily','point-regular','interval-monthly','point-np3','point-output3','point-hys1-output3','interval-hys2-output0')


def arguments(case):
    kind,calendar,fmt,hys,original,inline,age,events=case[:8]
    args=['--kind',kind,'--calendar',calendar,'--format',str(fmt),'--hysteresis',str(hys),'--age-day',str(age),'--events',events]
    if original:args+=['--original-output']
    if inline:args+=['--inline']
    return args


def main():
    ap=argparse.ArgumentParser()
    for key in ('reference-work','output'):ap.add_argument('--'+key,type=Path,required=True)
    ap.add_argument('--optimization',choices=('O0','O2'),required=True);ap.add_argument('--resume',action='store_true');ap.add_argument('--short-only',action='store_true')
    a=ap.parse_args();a.output=a.output.resolve();a.output.mkdir(exist_ok=a.resume)
    sys.path.insert(0,str(probe.ROOT/'tools/solute'));import user_prepare
    if not (a.reference_work/'PREPARED.json').exists():user_prepare.prepare(a.reference_work)
    user_prepare.validate(a.reference_work);shutil.copyfile(a.reference_work/'PREPARED.json',a.output/'PROVIDER.json')
    q=dict(status='RUNNING',optimization=a.optimization,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=probe.ROOT,text=True).strip(),cases={},controls={},functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    if a.resume:
        q=json.loads((a.output/'RESULT.json').read_text());q.setdefault('retained_failures',[]).append(dict(status=q['status'],error=q.pop('error',None)));q['status']='RUNNING'
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def run(script,*args):subprocess.run([sys.executable,'-B',str(Path(__file__).with_name(script)),*map(str,args)],cwd=probe.ROOT,check=True,timeout=1200)
    save()
    try:
        for key,case in CASES.items():
            short=a.output/('short-'+key)
            if not (short/'RESULT.json').exists():run('direct_soil_age_matrix.py','--reference-work',a.reference_work,'--output',short,'--optimization',a.optimization,'--phase','short',*arguments(case))
            report=json.loads((short/'RESULT.json').read_text());assert report['status']=='DIRECT_SOIL_AGE_SOURCE_SHORT_CURRENT_FORCING_NATIVE_OUTPUT_PASS'
            build=Path(report['build_root']);inputs=Path(report['input_root']);project=probe.m.e.load(inputs,original_output=case[4],age_direct_soil_source=True);meta,_=probe.m.validate_bundle(build,a.reference_work,project)
            assert report['age_direct_soil_source']==probe.metadata(project)==meta['identity']['original_age_fixed_irrigation']
            assert (report['kind'],report['calendar'],report['output_format'],report['hysteresis'],report['original_output'],report['inline'],report['age_day'],report['events'])==case[:8]
            q['cases'][key]=dict(short_root=str(short),build_root=str(build),input_root=str(inputs),short=report);save()
        for key in CONTROLS:
            out=a.output/('controls-'+key);short=Path(q['cases'][key]['short_root'])
            if not (out/'RESULT.json').exists():run('direct_soil_age_controls.py','--reference-work',a.reference_work,'--profile-root',short,'--output',out)
            report=json.loads((out/'RESULT.json').read_text());assert report['status']=='DIRECT_SOIL_AGE_NATIVE_EXTERNAL_ROLLBACK_AND_ALTERED_LEDGER_REFUSALS_PASS';q['controls'][key]=report;save()
        if not a.short_only:
            for key,case in CASES.items():
                if not case[8]:continue
                build=Path(q['cases'][key]['build_root']);inputs=Path(q['cases'][key]['input_root']);full=a.output/('full-'+key)
                if not (full/'RESULT.json').exists():run('direct_soil_age_matrix.py','--reference-work',a.reference_work,'--output',full,'--optimization',a.optimization,'--phase','full','--reuse-build',build,'--existing-input',inputs,*arguments(case))
                report=json.loads((full/'RESULT.json').read_text());assert report['status']=='DIRECT_SOIL_AGE_SOURCE_FULL_CURRENT_FORCING_NATIVE_OUTPUT_PASS' and report['trajectory']['build_sha256']==probe.m.sha(build/'BUILD.json');q['cases'][key]['full']=report;save()
            plain=a.output/'full-point-output0/trajectory';binary=a.output/'full-point-output3/trajectory'
            assert probe.m.physical(probe.m.rows(plain))==probe.m.physical(probe.m.rows(binary))
            for day in (4,8,10,201,367,532,1096):
                with zipfile.ZipFile(plain/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(binary/f'accepted-column-1-day-{day}.zip') as y:
                    for member in ('result.end','macro.bin'):assert x.read(member)==y.read(member),(day,member)
            q['format_independence']=dict(all1096_physical_exact=True,seven_complete_native_endpoints_exact=True)
        q['status']='SEVENTEEN_DIRECT_SOIL_AGE_SHORT_AND_'+('NO_FULL_SELECTED' if a.short_only else 'ELEVEN_FULL')+'_NATIVE_STATE_USER_OUTPUT_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
