"""Small actual typed-solver closure before selected shared production builds."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--output',type=Path,required=True)
a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
fc=os.environ.get('FC','gfortran');sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
original=ROOT/'tests/fsi/test_weather_surface_warm_start.f90'
text=original.read_text();prefix=text.split(' call prepare(.001d0)',1)[0]
prefix=prefix.replace('program test_weather_surface_warm_start','program test_weather_line_search_retry',1)
prefix=prefix.replace(' implicit none',' implicit none\n type,extends(b110_root_sink_provider_t)::unsupported_root_t\n end type\n type(unsupported_root_t),target::other_root',1)
assert prefix.count('logical ::')==0
driver=out/'driver.f90'
driver.write_text(prefix+(ROOT/'benchmarks/performance/perf01_line_search_retry_controls.inc').read_text()+
                  '\ncontains\n'+text.split('\ncontains\n',1)[1])
warm=out/'warm_on.f90'
anchor=' r%numerical%consistent_provider_conductivity=.true.;r%numerical%reuse_trial_head=.true.'
assert text.count(anchor)==1
warm.write_text(text.replace(anchor,anchor+'\n r%numerical%abort_failed_line_search=.true.',1))
sources=subprocess.check_output([sys.executable,str(ROOT/'tests/support/augment_bartholomeus_backend_sources.py'),'--all',
    'tests/fsi/fsi04_real_headcalc_stubs.f90','src/adapter/mod_reference_richards_legacy_binding.f90',
    'src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90','src/legacy/b1_10_port/headcalc.f90'],text=True,cwd=ROOT).splitlines()
grid=(ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90').read_text()
for before,after in {
    '[-0.25d0, -0.75d0, -1.50d0, -2.50d0]':'[-2.5d0, -7.5d0, -15.0d0, -25.0d0]',
    '[0.50d0, 0.50d0, 1.00d0, 1.00d0]':'[5.0d0, 5.0d0, 10.0d0, 10.0d0]',
    'disnod(numnod+1) = 1.0d0':'disnod(numnod+1) = [2.5d0, 5.0d0, 7.5d0, 10.0d0, 5.0d0]'
}.items():
    assert grid.count(before)==1
    grid=grid.replace(before,after,1)
(out/'grid_stubs.f90').write_text(grid)
record=dict(status='RUNNING',events=[],provider_count=len(sources),input_sha256={p:sha(ROOT/p)for p in sources},
    generated_driver_sha256=sha(driver),combined_warm_driver_sha256=sha(warm),generated_grid_sha256=sha(out/'grid_stubs.f90'))
def run(cmd,opt,label):
    started=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=out/opt,capture_output=True,timeout=120)
    name=f'{opt}-{len(record["events"]):04d}-{label}'
    for stream in ['stdout','stderr']:(out/(name+'.'+stream)).write_bytes(getattr(r,stream))
    record['events'].append(dict(command=list(map(str,cmd)),optimization=opt,label=label,returncode=r.returncode,seconds=time.monotonic()-started,stdout=name+'.stdout',stderr=name+'.stderr'))
    (out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');r.check_returncode();return r.stdout
for opt in ['O0','O2']:
    b=out/opt;b.mkdir();flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-'+opt,'-J'+str(b),'-I'+str(b)]
    objects=[]
    for i,p in enumerate(sources):
        source=out/'grid_stubs.f90'if p=='tests/fsi/fsi04_real_headcalc_stubs.f90'else ROOT/p
        obj=b/f'{i:04d}.o';run([fc,*flags,'-c',source,'-o',obj],opt,'compile');objects.append(obj)
    tests={'typed':driver,'warm-on':warm,**{n:ROOT/('tests/fsi/test_weather_surface_'+n+'.f90')for n in ['retry','desaturation','top_derivative','warm_start']}}
    for name,p in tests.items():
        run([fc,*flags,p,*objects,'-o',b/name],opt,'link-'+name)
        raw=run([b/name],opt,'native-'+name)
        if name=='typed':assert b'WEATHER_LINE_SEARCH_RETRY_TYPED_CONTRACT_PASS'in raw
record['status']='TYPED_LINE_SEARCH_OFF_ON_UNSUPPORTED_AND_ORIGINAL_O0_O2_PASS'
(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
print(record['status'],record['provider_count'])
