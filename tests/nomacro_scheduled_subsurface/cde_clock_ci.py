"""Actual original CDE calendar cohorts; all narrow gates precede full periods."""
import argparse,json,shutil,subprocess,sys,zipfile
from pathlib import Path
import cde_clock_runtime as runtime

# mode, hysteresis, format, reset, ET, Snow, source, rain, NPRINTDAY, perstep, full
CASES={
 'ordinary-explicit-hys0-binary':('explicit',0,3,1,0,0,'point',None,2,False,True),
 'ordinary-periodic-hys1-vector':('periodic',1,2,1,1,0,'surface',0.01,3,True,True),
 'ordinary-terminal-hys2-ascii':('terminal',2,1,0,0,0,'interval',None,3,False,True),
 'snow-monthly-hys2-binary':('monthly',2,3,1,0,1,'interval',None,3,True,True),
 'snow-explicit-hys0-vector':('explicit',0,2,1,0,1,'sprinkler',0.01,2,False,True),
 'snow-periodic-hys1-ascii':('periodic',1,1,1,0,1,'point',None,1,True,True),
 'ordinary-explicit-hys0-none':('explicit',0,0,1,0,0,'point',None,2,False,False),
 'snow-terminal-hys2-binary':('terminal',2,3,0,1,1,'surface',0.01,3,False,False),
 'ordinary-monthly-hys2-vector':('monthly',2,2,1,0,0,'sprinkler',None,1,True,False),
 'snow-periodic-hys0-none':('periodic',0,0,0,0,1,'interval',None,2,True,False),
}
LIMITS={
 'ordinary-subdaily':('explicit',0,3,1,0,0,'point',None,1440,False,False),
 'ordinary-perstep':('explicit',0,2,0,0,0,'surface',0.01,1440,True,False),
 'snow-subdaily':('monthly',2,3,1,0,1,'interval',None,1440,False,False),
 'snow-perstep':('explicit',2,1,1,0,1,'sprinkler',0.01,1440,True,False),
}
PILOTS={
 'ordinary-explicit-hys0-binary':'cde-clock-ordinary-{opt}-v2',
 'snow-monthly-hys2-binary':'cde-clock-snow-{opt}-v2',
}
CONTROLS=tuple(key for key,case in CASES.items() if case[-1])
PROVIDER_POISONS=('ordinary-explicit-hys0-binary','snow-monthly-hys2-binary')


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--reuse-pilots',type=Path);p.add_argument('--resume',action='store_true')
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir(exist_ok=a.resume)
    import user_prepare
    if not (a.reference_work/'PREPARED.json').exists():user_prepare.prepare(a.reference_work)
    user_prepare.validate(a.reference_work);shutil.copyfile(a.reference_work/'PREPARED.json',a.output/'PROVIDER.json')
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=runtime.ROOT,text=True).strip(),
        optimization=a.optimization,cases={},controls={},limits={},functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    if a.resume:q['retained_previous_report']=json.loads((a.output/'RESULT.json').read_text(encoding='utf8'))
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    def read(root):return json.loads((root/'RESULT.json').read_text(encoding='utf8'))
    def invoke(script,*options):subprocess.run([sys.executable,'-B',str(Path(__file__).with_name(script)),*map(str,options)],cwd=runtime.ROOT,check=True,timeout=600)
    def options(case):
        mode,hys,fmt,reset,et,snow,source,rain,npd,perstep,_=case
        result=['--reference-work',a.reference_work,'--mode',mode,'--hysteresis',hys,'--format',fmt,'--reset',reset,
            '--et',et,'--snow',snow,'--source',source,'--nprintday',npd,'--optimization',a.optimization]+(['--perstep'] if perstep else [])
        return result+(['--rain',rain] if rain is not None else [])
    save()
    try:
        for key,case in CASES.items():
            mode,hys,fmt,reset,et,snow,source,rain,npd,perstep,full=case;short=a.output/('short-'+key)
            if a.reuse_pilots and key in PILOTS:short=a.reuse_pilots/PILOTS[key].format(opt=a.optimization)
            if not (short/'RESULT.json').exists():invoke('cde_clock_runtime.py',*options(case),'--output',short)
            report=read(short);assert report['status']=='ACTUAL_CDE_CLOCK_SHORT_NATIVE_USER_OUTPUT_PASS',report
            assert (report['mode'],report['hysteresis'],report['format'],report['reset'],report['et'],report['snow'],report['source'],report.get('rain'),report['nprintday'],report['perstep'],report['optimization'])==(mode,hys,fmt,reset,et,snow,source,rain,npd,perstep,a.optimization)
            inputs=Path(report['input_root']);build=Path(report['build_root']);project=runtime.m.e.load(inputs,original_output=True)
            meta,_=runtime.m.validate_bundle(build,a.reference_work,project);assert meta['identity']['original_output']==report['original_output']
            q['cases'][key]=dict(short_root=str(short),input_root=str(inputs),build_root=str(build),short=report,
                daily_chemical_receipts=runtime.audit_daily(short/'trajectory',35,project.nodes));save()
            if key in CONTROLS:
                target=a.output/('controls-'+key)
                if a.reuse_pilots and key in PROVIDER_POISONS:
                    target=a.reuse_pilots/('cde-clock-controls-'+('snow' if snow else 'ordinary')+'-'+a.optimization+'-v1')
                extra=['--skip-provider-poison'] if key not in PROVIDER_POISONS else []
                if not (target/'RESULT.json').exists():invoke('cde_clock_controls.py','--reference-work',a.reference_work,'--profile-root',short,'--output',target,*extra)
                control=read(target);assert control['status']=='CDE_CLOCK_NATIVE_ACTIVE_POLICY_PROVIDER_PASS'
                assert control['build_sha256']==runtime.m.sha(build/'BUILD.json') and len(control['native_refusals'])==(80 if snow else 56 if hys else 50)
                assert len(control['actual_provider_refusals'])==((6 if snow else 5) if key in PROVIDER_POISONS else 0)
                q['controls'][key]=dict(root=str(target),report=control);save()
            print(key,a.optimization,'ACTUAL_SHORT_CDE_INTERVAL_SOURCE_NATIVE_PASS',flush=True)
        for key,case in LIMITS.items():
            target=a.output/('limit-'+key)
            if not (target/'RESULT.json').exists():invoke('cde_clock_runtime.py',*options(case),'--phase','limit','--output',target)
            report=read(target);assert report['status']=='ACTUAL_CDE_CLOCK_LIMIT_NATIVE_USER_OUTPUT_PASS' and report['nprintday']==1440 and report['trajectory']['days']==2
            q['limits'][key]=dict(root=str(target),report=report);save();print(key,a.optimization,'ACTUAL_TWO_DAY_1440_CHEMICAL_CLOCK_NATIVE_PASS',flush=True)
        q['all_short_native_limit_gates_precede_full']=True;save()
        for key,case in CASES.items():
            if not case[-1]:continue
            item=q['cases'][key];target=a.output/('full-'+key)
            if not (target/'RESULT.json').exists():invoke('cde_clock_runtime.py',*options(case),'--phase','full',
                '--reuse-build',item['build_root'],'--existing-input',item['input_root'],'--output',target)
            full=read(target);assert full['status']=='ACTUAL_CDE_CLOCK_FULL_NATIVE_USER_OUTPUT_PASS',full
            assert full['trajectory']['build_sha256']==runtime.m.sha(Path(item['build_root'])/'BUILD.json')
            for observed in full['user_output'].values():assert runtime.timestamp(observed['stamps'][-1])==runtime.datetime(2005,1,1),observed
            item.update(full_root=str(target),full=full);save();print(key,a.optimization,'ACTUAL_FULL_CDE_INTERVAL_SOURCE_NATIVE_PASS',flush=True)
        left=Path(q['cases']['ordinary-explicit-hys0-binary']['short_root'])/'trajectory'
        right=Path(q['cases']['ordinary-explicit-hys0-none']['short_root'])/'trajectory'
        assert runtime.m.physical(runtime.m.rows(left))==runtime.m.physical(runtime.m.rows(right))
        for day in (4,8,23,34,35):
            with zipfile.ZipFile(left/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(right/f'accepted-column-1-day-{day}.zip') as y:
                for name in ('result.end','macro.bin'):assert x.read(name)==y.read(name),name
        q['format_independence']=dict(all35_physical_chemical_days_exact=True,five_complete_native_payloads_exact=True)
        q['status']='TEN_CDE_CLOCK_SHORT_SIX_FULL_SIX_NATIVE_FOUR_LIMIT_CONTEXTS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
