"""Selected original output/aquifer state and actual source compositions."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
import output_aquifer_runtime as probe

# physical profile, format, hysteresis, irrigation, inline, salinity, groups, precision, full
CASES={
 'soil-csv1':('soil-transfer',1,0,'none',False,False,None,12,True),
 'box-csv3':('box-release',3,0,'none',False,False,None,12,True),
 'sorption-hys2-csv2':('sorption-decay',2,2,'none',False,False,None,12,True),
 'stiff-hys1-csv0':('stiff-loss',0,1,'none',False,False,None,12,True),
 'soil-csv0':('soil-transfer',0,0,'none',False,False,None,12,True),
 'soil-csv3':('soil-transfer',3,0,'none',False,False,None,12,True),
 'sorption-csv1':('sorption-decay',1,0,'none',False,False,None,12,True),
 'stiff-csv1':('stiff-loss',1,0,'none',False,False,None,12,True),
 'box-hys2-csv0':('box-release',0,2,'none',False,False,None,12,True),
 'chemical-point-csv3':('soil-transfer',3,0,'subsurface',False,False,None,12,True),
 'chemical-interval-csv3':('soil-transfer',3,0,'subsurface-interval',False,False,None,12,True),
 'chemical-salinity-csv1':('sorption-decay',1,0,'subsurface-interval',False,True,None,12,True),
 'box-csv2':('box-release',2,0,'none',False,False,None,12,False),
 'chemical-interval-inline-csv3':('soil-transfer',3,0,'subsurface-interval',True,False,None,12,False),
 'solbal-only-csv1':('soil-transfer',1,0,'none',False,False,'SOLBAL',5,False),
 'no-solbal-csv1':('box-release',1,0,'none',False,False,'GWL',8,False),
 'chemical-surface-csv1':('soil-transfer',1,0,'surface',False,False,None,12,False),
 'chemical-sprinkler-csv1':('soil-transfer',1,0,'sprinkler',False,False,None,12,False),
 'loss-limit-active-csv1':('loss-limit-active',1,0,'none',False,False,None,12,False)}
CONTROLS=('soil-csv1','box-csv3','sorption-hys2-csv2','stiff-hys1-csv0','chemical-point-csv3','chemical-interval-csv3','chemical-salinity-csv1','no-solbal-csv1')


def arguments(case):
    kind,fmt,hys,irrig,inline,salinity,groups,precision=case[:8]
    args=['--kind',kind,'--format',str(fmt),'--hysteresis',str(hys),'--irrigation',irrig,'--precision',str(precision)]
    if inline:args+=['--inline']
    if salinity:args+=['--salinity']
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
    if a.resume:
        q=json.loads((a.output/'RESULT.json').read_text());q.setdefault('retained_failures',[]).append(dict(status=q['status'],error=q.pop('error',None)));q['status']='RUNNING'
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def run(script,*args):subprocess.run([sys.executable,'-B',str(Path(__file__).with_name(script)),*map(str,args)],cwd=probe.ROOT,check=True,timeout=1200)
    reuse={'box-csv3':'output-aquifer-pilot-','stiff-hys1-csv0':'output-aquifer-hys1-','sorption-hys2-csv2':'output-aquifer-hys2-','chemical-interval-csv3':'output-aquifer-chemical-interval-','loss-limit-active-csv1':'output-aquifer-loss-limit-active-'}
    save()
    try:
        for key,case in CASES.items():
            short=a.output/('short-'+key)
            if a.reuse_pilots and key in reuse:
                prior=a.reuse_pilots/(reuse[key]+a.optimization+'-v1')
                if (prior/'RESULT.json').exists():
                    short=prior
                    if key not in q['cases']:run('output_aquifer_runtime.py','--reference-work',a.reference_work,'--output',short,'--optimization',a.optimization,'--phase','short','--resume',*arguments(case))
            if not (short/'RESULT.json').exists():run('output_aquifer_runtime.py','--reference-work',a.reference_work,'--output',short,'--optimization',a.optimization,'--phase','short',*arguments(case))
            report=json.loads((short/'RESULT.json').read_text());assert report['status']=='ORIGINAL_OUTPUT_AQUIFER_SHORT_COMPOUND_SOURCE_NATIVE_USER_FILES_PASS'
            assert (report['kind'],report['output_format'],report['hysteresis'],report['irrigation'],report['inline'],report['salinity'],report['groups'],report['precision'])==case[:8]
            build=Path(report['build_root']);inputs=Path(report['input_root']);project=probe.m.e.load(inputs,original_output=True);meta,_=probe.m.validate_bundle(build,a.reference_work,project);assert meta['identity']['original_output']==report['output']==probe.metadata(project)
            q['cases'][key]=dict(short_root=str(short),input_root=str(inputs),build_root=str(build),short=report);save()
        for key in CONTROLS:
            out=a.output/('controls-'+key);short=Path(q['cases'][key]['short_root'])
            if not (out/'RESULT.json').exists():run('output_aquifer_controls.py','--reference-work',a.reference_work,'--profile-root',short,'--output',out)
            report=json.loads((out/'RESULT.json').read_text());assert report['status']=='ORIGINAL_OUTPUT_AQUIFER_ACTUAL_NATIVE_ACTIVE_AND_POLICY_REFUSALS_PASS' and report['build_sha256']==probe.m.sha(Path(q['cases'][key]['build_root'])/'BUILD.json');q['controls'][key]=report;save()
        if not a.short_only:
            for key,case in CASES.items():
                if not case[8]:continue
                short=q['cases'][key];full=a.output/('full-'+key)
                if not (full/'RESULT.json').exists():run('output_aquifer_runtime.py','--reference-work',a.reference_work,'--output',full,'--optimization',a.optimization,'--phase','full','--reuse-build',short['build_root'],'--existing-input',short['input_root'],*arguments(case))
                report=json.loads((full/'RESULT.json').read_text());assert report['status']=='ORIGINAL_OUTPUT_AQUIFER_FULL_COMPOUND_SOURCE_NATIVE_USER_FILES_PASS' and report['trajectory']['build_sha256']==probe.m.sha(Path(short['build_root'])/'BUILD.json');q['cases'][key]['full']=report;save()
            a0=a.output/'full-soil-csv0/trajectory';a3=a.output/'full-soil-csv3/trajectory'
            assert probe.m.physical(probe.m.rows(a0))==probe.m.physical(probe.m.rows(a3))
            for day in (4,8,10,201,367,532,1096):
                with zipfile.ZipFile(a0/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(a3/f'accepted-column-1-day-{day}.zip') as y:
                    for name in ('result.end','macro.bin'):assert x.read(name)==y.read(name),(day,name)
            q['format_independence']=dict(all1096_physical_exact=True,seven_complete_native_endpoints_exact=True)
        inline=Path(q['cases']['chemical-interval-inline-csv3']['short_root'])/'trajectory';file=Path(q['cases']['chemical-interval-csv3']['short_root'])/'trajectory'
        assert probe.m.physical(probe.m.rows(inline))==probe.m.physical(probe.m.rows(file))
        for day in (2,4,8,10):
            with zipfile.ZipFile(inline/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(file/f'accepted-column-1-day-{day}.zip') as y:
                for name in ('result.end','macro.bin'):assert x.read(name)==y.read(name),(day,name)
        q['inline_independence']=dict(ten_physical_days_exact=True,four_complete_native_endpoints_exact=True)
        q['status']='NINETEEN_AQUIFER_OUTPUT_SHORT_AND_'+('NO_FULL_SELECTED' if a.short_only else 'TWELVE_FULL')+'_COMPOUND_SOURCE_NATIVE_USER_FILES_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
