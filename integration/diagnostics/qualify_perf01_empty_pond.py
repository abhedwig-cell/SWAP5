"""Current opt-in production and unchanged original application assertions."""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import resource
import runpy
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--builds',type=Path,required=True)
    ap.add_argument('--experiment',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--phase',choices=['default','enabled','controls'],required=True)
    a = ap.parse_args()
    builds,experiment,out = a.builds.resolve(),a.experiment.resolve(),a.output.resolve()
    out.mkdir(parents=True,exist_ok=False)
    report = dict(status='RUNNING',phase=a.phase,events=[],inputs={})
    for opt in ['O0','O2']:
        b = json.loads((builds/('build-'+opt)/'build-complete.json').read_text())
        assert all(sha(ROOT/p)==h for p,h in b['input_sha256'].items())
        report.setdefault('builds',{})[opt] = b
    def save():
        (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    def run(command,label):
        start = time.monotonic()
        p = subprocess.run(list(map(str,command)),cwd=ROOT,capture_output=True)
        i = len(report['events'])
        for stream in ['stdout','stderr']:
            (out/f'{i:04d}.{stream}').write_bytes(getattr(p,stream))
        report['events'].append(dict(command=list(map(str,command)),label=label,returncode=p.returncode,
            seconds=time.monotonic()-start))
        save();p.check_returncode()
        print(label+'=PASS',flush=True)
    if a.phase=='default':
        common = ['--build-O0',builds/'build-O0','--build-O2',builds/'build-O2']
        run(['python','-B',ROOT/'tests/nut-sol/test_column_input.py',*common,'--output',out/'column'],'original86')
        run(['python','-B',ROOT/'tests/nut-sol/qualify_swp_reader.py',*common,'--output',out/'swp'],'original_swp172')
        old = runpy.run_path(str(ROOT/'integration/audits/verify_swp_reader.py'))['capsule']()
        comparison = json.loads(old['incumbent-comparison.json'])
        assert comparison['count']==160 and comparison['all_exact']
        for p,h in comparison['artifacts'].items():
            assert sha(out/'column'/p)==h and (out/'column'/p).read_bytes()==old['column/'+p],p
        (out/'incumbent-comparison.json').write_bytes(old['incumbent-comparison.json'])
        for p,raw in old.items():
            if p.startswith('native/') and (p.endswith('/full/state.csv') or p.endswith('/full/endpoint.csv') or p.endswith('/full/restart.bin')):
                assert (out/'swp'/p[len('native/'):]).read_bytes()==raw,p
        run(['python','-B',ROOT/'tests/nut-sol/qualify_thermal_pond_application.py',*common,
             '--output',out/'annual','--days','365'],'original_annual18')
        annual = json.loads((out/'annual/result.json').read_text())
        for key in annual['runs']:
            for name in ['restart.bin','state.csv','endpoint.csv','temperature.csv','budget.csv']:
                assert (out/'annual'/key/'full'/name).read_bytes()==old['annual/'+key+'/full/'+name],(key,name)
        report['status']='CURRENT_DEFAULT_ORIGINAL86_SWP172_AND_18_ANNUAL_CASES_EXACT_PASS'
    elif a.phase=='controls':
        opt='O2';base=builds/'build-O2';b=report['builds'][opt];exe=base/'swap5_solute_column'
        text=(ROOT/'examples/solute_column/dry32_implicit_pond.nml').read_text()
        cases=[('temperature',' dynamic_temperature=.true.','implicit pond combination not qualified'),
               ('proposal',' retain_accepted_step_proposal=.true.','implicit pond combination not qualified'),
               ('nonlinear',' freundlich_exponent=2','implicit pond combination not qualified')]
        for label,line,marker in cases:
            directory=out/label;directory.mkdir();inp=directory/'input.nml'
            inp.write_text(text.replace('&column\n','&column\n'+line+'\n',1))
            p=subprocess.run([str(exe),str(inp),'-','1'],cwd=directory,capture_output=True)
            for stream in ['stdout','stderr']:(directory/stream).write_bytes(getattr(p,stream))
            assert p.returncode!=0 and marker.encode() in p.stdout and not (directory/'budget.csv').exists(),label
            report.setdefault('controls',[]).append(dict(label=label,returncode=p.returncode,input_sha256=sha(inp)))
            save()
        directory=out/'imported-nonlinear';directory.mkdir();inp=directory/'input.nml'
        inp.write_text((ROOT/'examples/solute_column/positive_pond.nml').read_text().replace('&column\n',
            '&column\n implicit_pond_evaporation=.true.\n',1))
        swp=out.parent/'default/swp/O2/layered/source.swp'
        assert swp.is_file(),'complete original SWP gate before imported-mode controls'
        (directory/'source.swp').write_bytes(swp.read_bytes())
        p=subprocess.run([str(exe),str(inp),'-','1','source.swp'],cwd=directory,capture_output=True)
        for stream in ['stdout','stderr']:(directory/stream).write_bytes(getattr(p,stream))
        assert p.returncode!=0 and b'implicit pond imported chemistry not qualified' in p.stdout
        assert not (directory/'budget.csv').exists()
        report['controls'].append(dict(label='imported-nonlinear',returncode=p.returncode,input_sha256=sha(inp),swp_sha256=sha(swp)))
        project=runpy.run_path(str(ROOT/'integration/diagnostics/qualify_trace_scope.py'))['observer_source']
        projected=project((ROOT/'app/solute_column/main.f90').read_text())
        needle='    supply%implicit_pond_evaporation=implicit_pond_evaporation'
        assert projected.count(needle)==1
        for label,replacement in [('mismatched-policy','    supply%implicit_pond_evaporation=.not.implicit_pond_evaporation'),
                                  ('missing-water-policy',needle+'\n    deallocate(forcing%pond_input)')]:
            directory=out/label;directory.mkdir();source=directory/'main.f90'
            source.write_text(projected.replace(needle,replacement,1))
            inp=directory/'input.nml';inp.write_text(text.replace('runon_cm_day=64*.5','runon_cm_day=64*0',1)
                if label=='missing-water-policy' else text)
            flags=[f for f in b['flags'] if not f.startswith(('-I','-J'))]+['-J'+str(directory),'-I'+str(directory),'-I'+str(base)]
            objects=[e['command'][e['command'].index('-o')+1]for e in b['events']if e['category']=='compile'
                     and not e['command'][e['command'].index('-c')+1].endswith('/app/solute_column/main.f90')]
            run(b['compiler_command']+flags+['-c',source,'-o',directory/'main.o'],label+'_observer_compile')
            run(b['compiler_command']+flags+objects+[directory/'main.o',base/'libttutil.a','-o',directory/'column'],label+'_observer_link')
            p=subprocess.run([str(directory/'column'),str(inp),'-','1'],cwd=directory,capture_output=True)
            for stream in ['stdout','stderr']:(directory/stream).write_bytes(getattr(p,stream))
            assert p.returncode!=0 and b'joint interval rejected' in p.stdout
            rows=list(csv.DictReader((directory/'work.csv').read_text().splitlines()))
            assert len(rows)==1 and all(int(v)==0 for k,v in rows[0].items()if k not in {'window','cpu'})
            assert len((directory/'budget.csv').read_text().splitlines())==1
            report['controls'].append(dict(label=label,returncode=p.returncode,zero_water_work=True,
                observing_main_sha256=sha(source),input_sha256=sha(inp),no_external_reporting_row=True))
        report['status']='UNSUPPORTED_IMPORTED_COMBINATIONS_AND_MISMATCHED_POLICY_FAIL_CLOSED_PASS'
    else:
        example = ROOT/'examples/solute_column/dry32_implicit_pond.nml'
        report['inputs'][str(example.relative_to(ROOT))]=sha(example)
        project = runpy.run_path(str(ROOT/'integration/diagnostics/qualify_trace_scope.py'))['observer_source']
        observers = {}
        for opt in ['O0','O2']:
            base = builds/('build-'+opt)
            b = report['builds'][opt]
            target = out/('observer-'+opt);target.mkdir()
            source = target/'main.f90';source.write_text(project((ROOT/'app/solute_column/main.f90').read_text()))
            flags = [f for f in b['flags'] if not f.startswith(('-I','-J'))]+['-J'+str(target),'-I'+str(target),'-I'+str(base)]
            objects = [e['command'][e['command'].index('-o')+1] for e in b['events'] if e['category']=='compile'
                       and not e['command'][e['command'].index('-c')+1].endswith('/app/solute_column/main.f90')]
            fc = b['compiler_command']
            run(fc+flags+['-c',source,'-o',target/'main.o'],'observe_compile_'+opt)
            run(fc+flags+objects+[target/'main.o',base/'libttutil.a','-o',target/'column'],'observe_link_'+opt)
            observers[opt] = dict(main_sha256=sha(source),executable_sha256=sha(target/'column'),
                linked_objects={p:sha(Path(p)) for p in objects+[str(base/'libttutil.a')]})
        report['observers']=observers
        def bounded(exe,label,windows,timeout):
            directory = out/label;directory.mkdir()
            (directory/'input.nml').write_bytes(example.read_bytes())
            command = [str(exe),str(directory/'input.nml'),'-',str(windows)]
            def limit():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
            start = time.monotonic()
            with (directory/'stdout').open('wb') as so,(directory/'stderr').open('wb') as se:
                p = subprocess.Popen(command,cwd=directory,stdout=so,stderr=se,preexec_fn=limit)
                timed_out = False
                while True:
                    pid,status,usage = os.wait4(p.pid,os.WNOHANG)
                    if pid:break
                    if time.monotonic()-start>=timeout:
                        timed_out=True;p.kill();pid,status,usage=os.wait4(p.pid,0);break
                    time.sleep(.02)
                p.returncode=os.waitstatus_to_exitcode(status)
            result = dict(returncode=p.returncode,timed_out=timed_out,max_rss_kib=usage.ru_maxrss,seconds=time.monotonic()-start)
            (directory/'RESOURCE.json').write_text(json.dumps(result,indent=2)+'\n')
            report.setdefault('native',[]).append(dict(label=label,command=command,timeout=timeout,address_space_mib=512,
                resource=result,raw_sha256={p.name:sha(p) for p in directory.iterdir() if p.is_file()}))
            save()
            assert p.returncode==0 and not timed_out,(label,result)
            print(label+'=PASS',flush=True)
            return directory
        o0 = bounded(out/'observer-O0/column','O0-six',6,90)
        for name in ['state.csv','endpoint.csv','restart.bin','budget.csv','trajectory.csv']:
            assert (o0/name).read_bytes()==(experiment/'coupled-O2/native'/name).read_bytes(),name
        base = bounded(builds/'build-O2/swap5_solute_column','O2-unobserved-six',6,90)
        for name in ['state.csv','endpoint.csv','restart.bin','budget.csv']:
            assert (base/name).read_bytes()==(o0/name).read_bytes(),name
        day = bounded(out/'observer-O2/column','O2-day',64,180)
        for name in ['state.csv','endpoint.csv','restart.bin','budget.csv','trajectory.csv']:
            assert (day/name).read_bytes()==(experiment/'uninterrupted-O2/native'/name).read_bytes(),name
        def deterministic(path):
            return [{k:v for k,v in row.items() if k!='cpu'} for row in csv.DictReader(path.read_text().splitlines())]
        assert deterministic(day/'work.csv')==deterministic(experiment/'uninterrupted-O2/native/work.csv')
        assert deterministic(o0/'work.csv')==deterministic(experiment/'coupled-O2/native/work.csv')
        report['status']='ACTUAL_PRODUCTION_OPTION_O0_O2_AND_FULL_DAY_EXACT_GENERATED_CANDIDATE_PASS'
    save()


if __name__=='__main__':
    main()
