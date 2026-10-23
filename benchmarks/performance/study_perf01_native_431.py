"""Serial actual complete original-input application observations.

Wall/CPU measurements include each ordinary front end and its output. Numerical
controllers and compiler runtime checks differ; ratios are observed costs for
these configurations, not equivalent-accuracy or universal production speedups.
"""
import argparse,csv,datetime,hashlib,json,os,resource,statistics,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def original(folder):
    lines=(folder/'result_output.csv').read_text().splitlines()
    rows=list(csv.DictReader(l for l in lines if not l.startswith('*')))[1:]
    return [{k:(v if k=='DATE' else float(v))for k,v in r.items()}for r in rows]
def modern(folder):return [{k:float(v)for k,v in r.items()}for r in csv.DictReader((folder/'budget.csv').open())]
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--legacy-build',type=Path,required=True)
    ap.add_argument('--modern-build',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--repeat',type=int,default=3)
    ap.add_argument('--days',type=int,default=97)
    ap.add_argument('--surface-exfiltration',choices=['reject','historical_zero'],default='reject')
    a=ap.parse_args();assert 1<=a.repeat<=5 and 1<=a.days<=97
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    legacy=a.legacy_build.resolve();current=a.modern_build.resolve()
    lm=json.loads((legacy/'BUILD.json').read_text());cm=json.loads((current/'bundle.json').read_text())
    assert sha(legacy/'swap431')==lm['executable_sha256']
    for p,h in cm['executable_sha256'].items():assert sha(Path(p))==h,p
    core=min(os.sched_getaffinity(0));report=dict(status='RUNNING',baseline=subprocess.check_output(['git','rev-parse','origin/integration/f-ci-canonical'],cwd=ROOT,text=True).strip(),
        source_tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),
        core=core,days=a.days,repeat=a.repeat,runs=[],cases={},legacy_build=lm,modern_build=cm,
        surface_exfiltration=a.surface_exfiltration,
        timing_scope='Full original-input application/front-end process tree, input preparation and ordinary output included; compilation excluded',
        controller_note='Original adaptive iteration/pond controller versus current external full/half tolerance0.001; not equivalent accuracy',
        build_note='Original O2 GNU compatibility initialization versus admitted current checked O2 project; no universal production speed claim')
    def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    save()
    for rain in [1,4]:
        source=out/f'{rain}x-input'
        subprocess.run([sys.executable,'-B',str(ROOT/'benchmarks/performance/prepare_perf01_native_431.py'),
            '--output',str(source),'--rain',str(rain),'--days',str(a.days)],check=True,capture_output=True)
        fixed=json.loads((source/'INPUTS.json').read_text())
        first={}
        for repeat in range(a.repeat):
            for arm in (['legacy','current']if repeat%2==0 else['current','legacy']):
                label=f'{rain}x-{repeat}-{arm}';folder=out/label
                if arm=='legacy':
                    folder.mkdir()
                    for name in ['swap.swp','crop.crp','weather.999']:(folder/name).write_bytes((source/name).read_bytes())
                    cmd=[str(legacy/'swap431'),'swap.swp'];cwd=folder
                else:
                    cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_project.py'),str(source/'swap.swp'),
                        '--bundle',str(current),'--output',str(folder),'--temporal-tolerance','.001',
                        '--surface-exfiltration',a.surface_exfiltration]
                    cwd=ROOT
                command=['taskset','-c',str(core),*cmd]
                usage=resource.getrusage(resource.RUSAGE_CHILDREN);t=time.perf_counter()
                try:r=subprocess.run(command,cwd=cwd,capture_output=True,input=b'',timeout=120)
                except subprocess.TimeoutExpired as e:
                    report['status']='CENSORED_TIMEOUT';save();raise
                wall=time.perf_counter()-t;end=resource.getrusage(resource.RUSAGE_CHILDREN)
                for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(r,stream))
                row=dict(label=label,arm=arm,rain=rain,repeat=repeat,command=command,returncode=r.returncode,
                    wall_seconds=wall,user_seconds=end.ru_utime-usage.ru_utime,system_seconds=end.ru_stime-usage.ru_stime)
                report['runs'].append(row);save()
                valid=(r.returncode==100 and(folder/'swap.ok').is_file())if arm=='legacy'else r.returncode==0
                if not valid:
                    report['status']='FAILED_NATIVE_SEE_RETAINED_DIAGNOSTICS';save();raise RuntimeError(label)
                data=original(folder)if arm=='legacy'else modern(folder)
                assert len(data)==a.days
                for name,h in fixed['files'].items():assert sha(source/name)==h,name
                if arm=='legacy':
                    for name,h in fixed['files'].items():assert sha(folder/name)==h,name
                    assert max(abs(x['DSTOR']-x['RAIN']+x['RUNOFF']+x['EACT']+x['EPD']+x['TACT']-x['BOT']+x['BALDEV'])for x in data)<1e-10
                else:
                    assert sha(folder/'input.swp')==fixed['files']['swap.swp']
                    assert max(abs(x['water_end_cm']-x['water_start_cm']-x['water_in_cm']+x['water_out_cm'])for x in data)<1e-10
                    assert max(abs(x['water_residual_cm'])for x in data)<1e-10
                    assert all(x['solute_start_mg_cm2']==x['solute_end_mg_cm2']==0. for x in data)
                if repeat:assert data==first[arm],'nondeterministic complete daily physical output'
                else:first[arm]=data
                row['physical_output_sha256']=sha(folder/('result_output.csv'if arm=='legacy'else'budget.csv'))
                save();print(label,wall,row['user_seconds'],flush=True)
        old,new=first['legacy'],first['current'];mappings={'runoff':('RUNOFF','runoff_cm'),'soil_evaporation':('EACT','soil_evaporation_cm'),
            'pond_evaporation':('EPD','pond_evaporation_cm'),
            'potential_transpiration':('TPOT','potential_transpiration_cm'),'actual_transpiration':('TACT','actual_transpiration_cm')}
        result=dict(inputs=fixed,totals_mm={},max_daily_difference_mm={})
        gross=max(abs(y['water_end_cm']-y['water_start_cm']-x['RAIN']+y['runoff_cm']+
            y['soil_evaporation_cm']+y['pond_evaporation_cm']+y['actual_transpiration_cm']-x['BOT'])for x,y in zip(old,new))
        assert gross<1e-10,'independent gross current water balance'
        assert max(abs(x['TPOT']-y['potential_transpiration_cm'])for x,y in zip(old,new))<1e-10
        result['current_max_independent_gross_balance_mm']=10*gross
        for name,(o,n)in mappings.items():
            result['totals_mm'][name]={arm:10*sum(r[k]for r in rows)for arm,rows,k in [('legacy',old,o),('current',new,n)]}
            result['max_daily_difference_mm'][name]=10*max(abs(x[o]-y[n])for x,y in zip(old,new))
        result['rain_total_mm']=10*sum(x['RAIN']for x in old)
        result['legacy_total_storage_change_mm']=10*sum(x['DSTOR']for x in old)
        result['current_total_storage_change_mm']=10*(new[-1]['water_end_cm']-new[0]['water_start_cm'])
        result['legacy_max_daily_balance_deviation_mm']=10*max(abs(x['BALDEV'])for x in old)
        result['current_max_daily_balance_deviation_mm']=10*max(abs(x['water_residual_cm'])for x in new)
        result['current_accepted_substeps']=sum(x['accepted_substeps']for x in new)
        result['max_daily_total_evaporation_difference_mm']=10*max(abs(x['EACT']+x['EPD']-y['soil_evaporation_cm']-y['pond_evaporation_cm'])for x,y in zip(old,new))
        result['max_daily_total_storage_difference_mm']=10*max(abs(x['WTOT']+x['PD_VOL']-y['water_end_cm'])for x,y in zip(old,new))
        result['timing']={arm:{key:statistics.median(r[key]for r in report['runs']if r['arm']==arm and r['rain']==rain)
            for key in ['wall_seconds','user_seconds','system_seconds']}for arm in ['legacy','current']}
        result['observed_end_to_end_wall_ratio']=result['timing']['current']['wall_seconds']/result['timing']['legacy']['wall_seconds']
        report['cases'][str(rain)]=result;save()
    report['status']='COMPLETE_ACTUAL_COMMON_INPUT_APPLICATION_OBSERVATIONS';save();print(report['status'])
if __name__=='__main__':main()
