"""Build a bounded live weather/crop driver from the existing production seam.

No source provider or owning scientific test is modified. Geometry and crop
parameters are the explicit existing qualification site, not Andelst calibration.
"""
import os
import shutil
import gzip
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(sys.argv[1]).resolve()
relink = '--relink' in sys.argv[2:]
observe = '--observe' in sys.argv[2:]
rebuild_bodies = '--rebuild-bodies' in sys.argv[2:]
checked = '--checked' in sys.argv[2:]
OUT.mkdir(parents=True, exist_ok=relink)
SOURCE = ROOT/'tests/fmig431/test_crop_file_weather_production.f90'
text = SOURCE.read_text()
header = text.split('  implicit none')[0].replace('program test_crop_file_weather_production','program perf01_weather')
header += '  use mod_fmr_wofost_accepted_window_lineage, only: prepare_wofost_crop_event_delivery, fmr_wofost_crop_event_token_t\n'
header += '  use mod_fmr_production_application_bootstrap, only: fmr_weather_crop_native_view_t, export_weather_crop_native_view\n'
helpers = []
for name in ['initialize_application_config','initialize_parameters','initialize_state_and_forcing',
             'initialize_crop','make_bundle','constant_table','require']:
    m = re.search(r'^  subroutine '+name+r'\(.*?^  end subroutine[^\n]*',text,re.M|re.S)
    assert m, name
    helpers.append(m[0])
setup = text.split('    call make_bundle(bundle);update%leaf_lifespan=40.0_real64',1)[1].split('    bad_tc=tc;',1)[0]
main = (ROOT/'benchmarks/performance/perf01_weather_main.inc').read_text()
main = main.replace('! ROOTED_SETUP',setup)
(OUT/'driver.f90').write_text(header+'  implicit none\n'+main+'\ncontains\n'+'\n'.join(helpers)+'\nend program\n')
stub = (ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90').read_text()
for a,b in {'[-0.25d0, -0.75d0, -1.50d0, -2.50d0]':'[-2.5d0, -7.5d0, -15.0d0, -25.0d0]',
            '[0.50d0, 0.50d0, 1.00d0, 1.00d0]':'[5.0d0, 5.0d0, 10.0d0, 10.0d0]',
            'disnod(numnod+1) = 1.0d0':'disnod(numnod+1) = [2.5d0, 5.0d0, 7.5d0, 10.0d0, 5.0d0]'}.items():
    assert stub.count(a)==1
    stub=stub.replace(a,b)
(OUT/'grid_stubs.f90').write_text(stub)
(OUT/'weather.999').write_bytes(gzip.decompress((ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-andelst_meteo.999.gz').read_bytes()))
sources = subprocess.check_output([sys.executable,str(ROOT/'tests/support/augment_bartholomeus_backend_sources.py'),'--all',
    'tests/fsi/fsi04_real_headcalc_stubs.f90','src/runtime/mod_fmr_production_application_bootstrap.f90',
    'src/kernel/mod_kernel_committed_persistence.f90'],cwd=ROOT,text=True).splitlines()
fc=[os.environ.get('FC') or shutil.which('gfortran') or 'gfortran']
flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fbacktrace',
       '-ffpe-trap=invalid,zero,overflow','-O2','-J'+str(OUT),'-I'+str(OUT)]
if checked:
    flags[flags.index('-O2')]='-O0'
    flags.append('-fcheck=all')
report=json.loads((OUT/'BUILD.json').read_text()) if relink else {'status':'BUILDING','sources':{},'events':[],'compiler_command':fc,'flags':flags}
report['status']='BUILDING'
(OUT/'BUILD.json').write_text(json.dumps(report,indent=2)+'\n')
def run(command):
    start=time.monotonic()
    p=subprocess.run(list(map(str,command)),cwd=OUT,capture_output=True)
    i=len(report['events'])
    for stream in ('stdout','stderr'):(OUT/f'{i:04d}.{stream}').write_bytes(getattr(p,stream))
    report['events'].append({'command':list(map(str,command)),'returncode':p.returncode,'seconds':time.monotonic()-start})
    (OUT/'BUILD.json').write_text(json.dumps(report,indent=2)+'\n')
    p.check_returncode()
objects=[]
for i,source in enumerate(sources):
    src=OUT/'grid_stubs.f90' if source=='tests/fsi/fsi04_real_headcalc_stubs.f90' else ROOT/source
    changed_observer=False
    if observe and source=='src/runtime/mod_fmr_serialized_multiswap_runtime.f90':
        raw=src.read_text();anchor='    output%completed = .true.\n    output%committed = .true.\n'
        assert raw.count(anchor)==1
        overlay=raw.replace(anchor,"    write(*,'(a,3(1x,es25.17e3))') 'PERF01_BOTTOM',t0,t1,kernel_result%bottom_outward_exchange_native\n"+anchor)
        report['observer_original_sha256']=hashlib.sha256(src.read_bytes()).hexdigest()
        src=OUT/'observed_serial_runtime.f90';src.write_text(overlay)
        changed_observer=True
    if observe and source=='src/runtime/mod_fmr_production_application_bootstrap.f90':
        raw=src.read_text()
        anchor="    if(s/=FMR_WOFOST_LINEAGE_OK) error stop 'MC-CROP01 prevalidated accepted window admission failed'\n"
        assert raw.count(anchor)==1
        overlay=raw.replace(anchor,anchor+"    write(*,'(a,7(1x,es25.17e3))') 'PERF01_SURFACE',t0,t1, &\n"
            "      results(1)%bare_soil_evaporation_cm,results(1)%pond_evaporation_cm, &\n"
            "      results(1)%runoff_cm,-results(1)%surface_to_soil_cm,ptra*(t1-t0)\n")
        report['surface_observer_original_sha256']=hashlib.sha256(src.read_bytes()).hexdigest()
        src=OUT/'observed_bootstrap.f90';src.write_text(overlay)
        changed_observer=True
    h=hashlib.sha256(src.read_bytes()).hexdigest()
    obj=OUT/f'{i:04d}.o'
    if relink and not changed_observer:
        if h!=report['sources'][source] and rebuild_bodies:
            before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.mod')}
            run(fc+flags+['-c',src,'-o',obj])
            after={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.mod')}
            assert before==after,'Public interface changed; full rebuild required: '+source
            report['sources'][source]=h
            report['events'][-1]['reuse_proof']='All exported .mod bytes exact; body-only provider rebuild'
        assert h==report['sources'][source] and obj.is_file(), source
    else:
        report['sources'][source]=h
        run(fc+flags+['-c',src,'-o',obj])
    objects.append(obj)
run(fc+flags+[OUT/'driver.f90',ROOT/'src/legacy/b1_10_port/headcalc.f90',*objects,'-o',OUT/'weather'])
report.update(status='BUILT',provider_count=len(sources),executable_sha256=hashlib.sha256((OUT/'weather').read_bytes()).hexdigest(),
    generated_driver_sha256=hashlib.sha256((OUT/'driver.f90').read_bytes()).hexdigest(),
    headcalc_sha256=hashlib.sha256((ROOT/'src/legacy/b1_10_port/headcalc.f90').read_bytes()).hexdigest(),
    weather_sha256=hashlib.sha256((OUT/'weather.999').read_bytes()).hexdigest())
(OUT/'BUILD.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'status':'BUILT','providers':len(sources),'seconds':sum(x['seconds'] for x in report['events'])}),flush=True)
