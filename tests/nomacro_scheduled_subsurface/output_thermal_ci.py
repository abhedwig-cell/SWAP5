"""Persisted representative snow/thermal source/output/native qualification."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
import output_thermal_runtime as probe

# original physical profile, format, selected groups, precision, full
CASES={
 'water-hys2-csv3':('water-hys2',3,None,12,True),
 'chemical-csv2':('chemical-snow',2,None,12,True),
 'frost-free-csv1':('water-frost-free',1,None,12,True),
 'frost-drained-csv1':('water-frost-drained',1,None,12,True),
 'water-csv0':('water-snow',0,None,12,True),
 'water-csv3':('water-snow',3,None,12,True),
 'water-hys1-csv1':('water-hys1',1,None,12,True),
 'chemical-csv0':('chemical-snow',0,None,12,True),
 'chemical-csv3':('chemical-snow',3,None,12,True),
 'frost-drained-csv0':('water-frost-drained',0,None,12,True),
 'frost-drained-csv3':('water-frost-drained',3,None,12,True),
 'frost-free-csv3':('water-frost-free',3,None,12,True),
 'chemical-point-csv3':('chemical-snow-point',3,None,12,True),
 'chemical-interval-csv3':('chemical-snow-interval',3,None,12,True),
 'water-csv2':('water-snow',2,None,12,False),
 'water-watbal-precision5':('water-hys2',1,'WATBAL',5,False),
 'chemical-gwl-precision8':('chemical-snow',1,'GWL',8,False)}
CONTROLS=('water-hys2-csv3','chemical-csv2','frost-free-csv1','frost-drained-csv1','water-csv0','chemical-point-csv3','chemical-interval-csv3','chemical-gwl-precision8')


def arguments(case):
    kind,fmt,groups,precision=case[:4];args=['--kind',kind,'--format',str(fmt),'--precision',str(precision)]
    if groups is not None:args+=['--groups',groups]
    return args


def main():
    ap=argparse.ArgumentParser()
    for key in ('reference-work','output'):ap.add_argument('--'+key,type=Path,required=True)
    ap.add_argument('--optimization',choices=('O0','O2'),required=True);ap.add_argument('--resume',action='store_true');ap.add_argument('--short-only',action='store_true');ap.add_argument('--reuse-pilots',type=Path)
    a=ap.parse_args();a.output=a.output.resolve();a.output.mkdir(exist_ok=a.resume)
    sys.path.insert(0,str(probe.ROOT/'tools/solute'));import user_prepare
    if not (a.reference_work/'PREPARED.json').exists():user_prepare.prepare(a.reference_work)
    user_prepare.validate(a.reference_work);shutil.copyfile(a.reference_work/'PREPARED.json',a.output/'PROVIDER.json')
    q=dict(status='RUNNING',optimization=a.optimization,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=probe.ROOT,text=True).strip(),cases={},controls={},functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    if a.resume:q=json.loads((a.output/'RESULT.json').read_text());q.setdefault('retained_failures',[]).append(dict(status=q['status'],error=q.pop('error',None)));q['status']='RUNNING'
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def run(script,*args):subprocess.run([sys.executable,'-B',str(Path(__file__).with_name(script)),*map(str,args)],cwd=probe.ROOT,check=True,timeout=1800)
    reuse={'water-hys2-csv3':'pilot-'+a.optimization+'-v2','chemical-csv2':'chemical-'+a.optimization+'-v1','frost-free-csv1':'water-frost-free-'+a.optimization+'-v1','frost-drained-csv1':'water-frost-drained-'+a.optimization+'-v1'}
    if a.optimization=='O0':reuse['chemical-point-csv3']='fixed-O0-v2'
    if a.optimization=='O2':reuse['chemical-interval-csv3']='fixed-O2-v2'
    save()
    try:
        for key,case in CASES.items():
            short=a.output/('short-'+key)
            if a.reuse_pilots and key in reuse:short=a.reuse_pilots/('output-thermal-'+reuse[key])
            if not (short/'RESULT.json').exists():run('output_thermal_runtime.py','--reference-work',a.reference_work,'--output',short,'--optimization',a.optimization,*arguments(case))
            report=json.loads((short/'RESULT.json').read_text());assert report['status']=='ORIGINAL_OUTPUT_THERMAL_SHORT_SNOW_COMPOUND_NATIVE_USER_FILES_PASS' and (report['kind'],report['output_format'],report['groups'],report['precision'])==case[:4]
            build=Path(report['build_root']);inputs=Path(report['input_root']);policy='original-adaptive-event-closure-v1' if case[0]=='water-frost-drained' else 'original-adaptive-day-seed-v1';project=probe.m.e.load(inputs,original_output=True,time_step_policy=policy);meta,_=probe.m.validate_bundle(build,a.reference_work,project);assert meta['identity']['original_output']==report['output']==probe.metadata(project)
            assert report['snow_observation']['maximum_stock_cm']>0 and report['snow_observation']['sublimation_cm']>0
            q['cases'][key]=dict(short_root=str(short),input_root=str(inputs),build_root=str(build),short=report);save()
        for key in CONTROLS:
            out=a.output/('controls-'+key);short=Path(q['cases'][key]['short_root'])
            if not (out/'RESULT.json').exists():run('output_thermal_controls.py','--reference-work',a.reference_work,'--profile-root',short,'--output',out)
            report=json.loads((out/'RESULT.json').read_text());assert report['status']=='ORIGINAL_OUTPUT_THERMAL_ACTUAL_NATIVE_ACTIVE_AND_POLICY_REFUSALS_PASS' and report['build_sha256']==probe.m.sha(Path(q['cases'][key]['build_root'])/'BUILD.json');q['controls'][key]=report;save()
        if not a.short_only:
            for key,case in CASES.items():
                if not case[4]:continue
                short=q['cases'][key];full=a.output/('full-'+key)
                if not (full/'RESULT.json').exists():run('output_thermal_runtime.py','--reference-work',a.reference_work,'--output',full,'--optimization',a.optimization,'--phase','full','--reuse-build',short['build_root'],'--existing-input',short['input_root'],*arguments(case))
                report=json.loads((full/'RESULT.json').read_text());assert report['status']=='ORIGINAL_OUTPUT_THERMAL_FULL_SNOW_COMPOUND_NATIVE_USER_FILES_PASS' and report['trajectory']['build_sha256']==probe.m.sha(Path(short['build_root'])/'BUILD.json');q['cases'][key]['full']=report;save()
            q['format_independence']={}
            for kind,left,right in [('water','water-csv0','water-csv3'),('chemical','chemical-csv0','chemical-csv3'),('frost-drained','frost-drained-csv0','frost-drained-csv3')]:
                a0=a.output/('full-'+left)/'trajectory';a3=a.output/('full-'+right)/'trajectory';assert probe.m.physical(probe.m.rows(a0))==probe.m.physical(probe.m.rows(a3))
                for day in (4,8,23,34,35,201,367,532,1096):
                    with zipfile.ZipFile(a0/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(a3/f'accepted-column-1-day-{day}.zip') as y:
                        for name in ('result.end','macro.bin'):assert x.read(name)==y.read(name),(kind,day,name)
                q['format_independence'][kind]=dict(all1096_physical_exact=True,nine_complete_native_endpoints_exact=True)
        q['status']='SEVENTEEN_THERMAL_OUTPUT_SHORT_AND_'+('NO_FULL_SELECTED' if a.short_only else 'FOURTEEN_FULL')+'_SNOW_NATIVE_USER_FILES_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
