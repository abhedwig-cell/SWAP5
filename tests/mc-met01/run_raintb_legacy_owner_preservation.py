#!/usr/bin/env python3
"""Execute incumbent MC-MET01 owner composition with one controlled O0/O2 build.

This does not authorize admission, replace full F-CI or select highest low-air.
All incumbent drivers, source assertions, native cases and flags are retained.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]
FLAGS=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']
PINS={'tests/fmig431/run_crop_file_weather_production.sh':'b4cfeedb9a09339ef095005243168978d1376956',
      'tests/fmig431/test_crop_file_weather_production.f90':'5350f175cccda6f01c9812afb7c231a1cb118cc8'}


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def write(path,data):Path(path).write_text(json.dumps(data,indent=2)+'\n')


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args()
    spec=importlib.util.spec_from_file_location('modular_feedback',ROOT/'tests/modularity/run_modular_tests.py')
    feedback=importlib.util.module_from_spec(spec);spec.loader.exec_module(feedback)
    output=Path(args.output).resolve();session=feedback.Session(output)
    start=time.perf_counter();head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    for path,pin in PINS.items():
        raw=(ROOT/path).read_bytes()
        assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==pin,path
    fixture=output/'fixture';fixture.mkdir()
    original=(ROOT/'tests/fmig431/run_crop_file_weather_production.sh').read_text()
    prefix=original.split('mapfile -t SOURCES',1)[0]
    assert 'COMMON=('+' '.join(FLAGS)+')' in original
    prefix=prefix.replace('ROOT="$(cd "$(dirname "$0")/../.." && pwd)"','ROOT="$MC_MET01_OWNER_ROOT"')
    prefix=prefix.replace('BUILD="$(mktemp -d)"','BUILD="$MC_MET01_OWNER_FIXTURE"')
    prefix=prefix.replace('trap \'rm -rf "$BUILD"\' EXIT','# Retain authentic inputs and generated source oracles.')
    script=output/'prepare_fixture.sh';script.write_text(prefix)
    # No fixture or physics change; original exact shell extracts byte-pinned donors.
    environment_keys=['MC_MET01_OWNER_ROOT','MC_MET01_OWNER_FIXTURE']
    assert not any(key in os.environ for key in environment_keys)
    os.environ['MC_MET01_OWNER_ROOT']=str(ROOT);os.environ['MC_MET01_OWNER_FIXTURE']=str(fixture)
    # These fixture-only environment variables are fixed for the whole session.
    session.identity=session.toolchain_identity()
    session.command(['bash',str(script)],ROOT,'fixture')
    providers_raw,_=session.command(['python','-B',str(ROOT/'tests/support/augment_bartholomeus_backend_sources.py'),'--all',
           'tests/fsi/fsi04_real_headcalc_stubs.f90','src/runtime/mod_fmr_production_application_bootstrap.f90',
           'src/kernel/mod_kernel_committed_persistence.f90'],ROOT,'closure')
    providers=providers_raw.decode().splitlines()
    assert len(providers)==len(set(providers))
    base=(ROOT/'tests/fmig431/test_crop_file_weather_production.f90').read_text()
    drivers={'weather':ROOT/'tests/fmig431/test_crop_file_weather_production.f90'}
    inputs={p:sha(ROOT/p) for p in providers}
    for name,include,call in [('daily_demand','test_daily_demand_production.inc','test_daily_demand_production'),
                              ('raintb','test_raintb_production.inc','test_raintb_production')]:
        source=base;first=source.index('  call test_rooted_weather_production()');boundary=source.index('\ncontains\n')
        source=source[:first]+f'  call {call}()\n'+source[boundary:]
        path=ROOT/'tests/mc-met01'/include
        source=source.replace('\ncontains\n','\ncontains\n'+path.read_text(),1)
        target=output/f'{name}_driver.f90';target.write_text(source);drivers[name]=target
        inputs[str(path.relative_to(ROOT))]=sha(path)
    inputs.update({p:sha(ROOT/p) for p in PINS})
    inputs['tests/mc-met01/run_raintb_legacy_owner_preservation.py']=sha(Path(__file__))
    inputs['tests/modularity/run_modular_tests.py']=sha(ROOT/'tests/modularity/run_modular_tests.py')
    oracle_names=['astro_oracle.f90','daily_meteo_oracle.f90','crop_germination_oracle.f90','initial_owner_oracle.f90',
                  'task2_oracle.f90','preparation_oracle.f90','sowing_oracle.f90']
    externals=[ROOT/'src/legacy/b1_10_port/headcalc.f90',*[fixture/p for p in oracle_names]]
    inputs['src/legacy/b1_10_port/headcalc.f90']=sha(externals[0])
    generated={str(path.relative_to(output)):sha(path) for path in [*drivers.values(),*externals[1:],fixture/'grid_stubs.f90'] if path.is_relative_to(output)}
    write(output/'INPUTS.json',{'head':head,'inputs':inputs,'generated':generated,'providers':providers,'flags':FLAGS,
                              'compiler':session.identity,'owning_scope':'fresh incumbent MC-MET01 weather/demand/RAINTB composition; full highest/F-CI still pending'})
    results=[];output_hashes={}
    for opt in (0,2):
        build=output/f'o{opt}';build.mkdir();flags=[*FLAGS,f'-O{opt}'];objects=[]
        compile_seconds=link_seconds=native_seconds=0.
        for index,path in enumerate(providers):
            source=fixture/'grid_stubs.f90' if path=='tests/fsi/fsi04_real_headcalc_stubs.f90' else ROOT/path
            obj=build/f'provider-{index:03d}.o'
            _,event=session.command([session.compiler,*flags,'-J',str(build),'-I',str(build),'-c',str(source),'-o',str(obj)],build,'provider-compile')
            objects.append(obj);compile_seconds+=event['wall_seconds']
        for index,source in enumerate(externals):
            obj=build/f'oracle-{index:02d}.o'
            _,event=session.command([session.compiler,*flags,'-J',str(build),'-I',str(build),'-c',str(source),'-o',str(obj)],build,'external-compile')
            objects.append(obj);compile_seconds+=event['wall_seconds']
        artifacts={p:sha(p) for p in build.iterdir() if p.suffix in ('.o','.mod')}
        for name,driver in drivers.items():
            if session.toolchain_identity()!=session.identity:raise RuntimeError('toolchain/environment drift')
            if any(sha(ROOT/p)!=digest for p,digest in inputs.items()):raise RuntimeError('source drift')
            if any(sha(output/p)!=digest for p,digest in generated.items()):raise RuntimeError('generated input drift')
            if any(sha(p)!=digest for p,digest in artifacts.items()):raise RuntimeError('shared artifact drift')
            obj=build/f'driver-{name}.o';exe=build/f'test-{name}'
            _,event=session.command([session.compiler,*flags,'-J',str(build),'-I',str(build),'-c',str(driver),'-o',str(obj)],build,'driver-compile')
            compile_seconds+=event['wall_seconds']
            _,event=session.command([session.compiler,*flags,str(obj),*map(str,objects),'-o',str(exe)],build,'link')
            link_seconds+=event['wall_seconds'];exe_hash=sha(exe)
            moistures=['neutral','dry','hydraulic'] if name=='weather' else ['neutral']
            for moisture in moistures:
                pair=[]
                for mode in ['continuous','restart']:
                    if sha(exe)!=exe_hash or any(sha(p)!=digest for p,digest in artifacts.items()):raise RuntimeError('artifact drift before native')
                    raw,event=session.command([str(exe),*[str(fixture/p) for p in ['weather.999','altered.999','bad.999','backup.999']],mode,moisture],build,f'native-{name}-{moisture}-{mode}')
                    marker={'weather':b'CROP_FILE_WEATHER_PRODUCTION=PASS','daily_demand':b'MC_MET01_AUTHENTIC_DAILY_DEMAND_RETRY_RESTART_MASS=PASS','raintb':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS'}[name]
                    if marker not in raw:raise RuntimeError(f'missing incumbent marker {name}')
                    digest=hashlib.sha256(raw).hexdigest();pair.append(digest);native_seconds+=event['wall_seconds']
                    output_hashes[(opt,name,moisture,mode)]=digest
                    results.append({'opt':opt,'driver':name,'moisture':moisture,'mode':mode,'stdout_sha256':digest,'wall_seconds':event['wall_seconds'],'returncode':event['returncode']})
                    write(output/'PROGRESS.json',{'results':results,'events':session.events})
                if pair[0]!=pair[1]:raise RuntimeError('continuous/restart drift')
            if any(sha(p)!=digest for p,digest in artifacts.items()):raise RuntimeError('artifact drift after native')
        write(output/f'COST_O{opt}.json',{'compile_seconds':compile_seconds,'link_seconds':link_seconds,'native_seconds':native_seconds,
                'providers':len(providers),'provider_compiles':len(providers),'external_compiles':len(externals),'driver_compiles':len(drivers),'links':len(drivers),'shared_provider_hashes':{str(p.relative_to(output)):h for p,h in artifacts.items()}})
    for key,digest in output_hashes.items():
        opt,*rest=key
        if digest!=output_hashes[(2-opt,*rest)]:raise RuntimeError('O0/O2 output drift')
    if any(sha(ROOT/p)!=digest for p,digest in inputs.items()):raise RuntimeError('source drift at terminal')
    write(output/'RESULTS.json',{'status':'PASS','head':head,'wall_seconds':time.perf_counter()-start,'results':results,'events':session.events,
          'costs':[json.loads((output/f'COST_O{opt}.json').read_text()) for opt in (0,2)],'source_inputs':inputs,'generated_inputs':generated})
    print('MC_MET01_INCUMBENT_WEATHER_DAILY_DEMAND_RAINTB_O0_O2=PASS',flush=True)

if __name__=='__main__':main()
