"""Print-only native observers for the day-35 wet4 failure; no guard changes.

Reuse an exact, source-validated weather build. Recompile only three observer
modules and relink the original driver. Compiler command is explicit, not inferred.
"""
import argparse
from decimal import Decimal
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time
import re

ROOT = Path(__file__).resolve().parents[2]
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def replace_once(raw, anchor, replacement):
    assert raw.count(anchor) == 1, anchor
    return raw.replace(anchor, replacement)


def build(base, out, fc, max_retries=None, rain_on_feb23=None):
    base, out = base.resolve(), out.resolve()
    b = json.loads((base / 'BUILD.json').read_text())
    assert b['status'] == 'BUILT' and sha(base / 'weather') == b['executable_sha256']
    overrides = {
        'tests/fsi/fsi04_real_headcalc_stubs.f90': 'grid_stubs.f90',
        'src/runtime/mod_fmr_serialized_multiswap_runtime.f90': 'observed_serial_runtime.f90',
        'src/runtime/mod_fmr_production_application_bootstrap.f90': 'observed_bootstrap.f90',
    }
    for p, h in b['sources'].items():
        src = base / overrides[p] if p in overrides else ROOT / p
        assert sha(src) == h, p
    assert sha(ROOT/'src/runtime/mod_fmr_serialized_multiswap_runtime.f90') == b['observer_original_sha256']
    assert sha(ROOT/'src/runtime/mod_fmr_production_application_bootstrap.f90') == b['surface_observer_original_sha256']
    out.mkdir(parents=True, exist_ok=False)
    for p in base.glob('*.mod'):
        shutil.copy2(p, out/p.name)
    flags = [x for x in b['flags'] if not x.startswith(('-J', '-I'))] + ['-J'+str(out), '-I'+str(out)]
    report = dict(status='BUILDING', parent_build=str(base), parent_executable_sha256=b['executable_sha256'],
                  compiler_command=fc, flags=flags, events=[], observer_sources={}, production_changed=False)
    def run(cmd):
        start = time.monotonic()
        p = subprocess.run(list(map(str,cmd)), cwd=out, capture_output=True)
        i=len(report['events'])
        for name in ('stdout','stderr'):
            (out/f'{i:02d}.{name}').write_bytes(getattr(p,name))
        report['events'].append(dict(command=list(map(str,cmd)), returncode=p.returncode, seconds=time.monotonic()-start))
        (out/'BUILD.json').write_text(json.dumps(report,indent=2)+'\n')
        p.check_returncode()
    patches={}
    path='src/transaction/mod_transaction_reference.f90'
    raw=(ROOT/path).read_text()
    start=raw.index('  subroutine execute_model_certificate_interval(')
    end=raw.index('  end subroutine execute_model_certificate_interval',start)
    body=raw[start:end]
    anchor='      if (.not. outcome%solver_ok) then\n'
    body=replace_once(body,anchor,"      if(t0>=34d0.and.t0<34.02d0) print *, 'D4_TRIAL',t0,attempt_t1,attempt_dt,retry_index,outcome%solver_ok\n"+anchor)
    anchor='      if (.not. mass_ok) then\n'
    body=replace_once(body,anchor,"      if(t0>=34d0.and.t0<34.02d0) print *, 'D4_MASS',storage0,storage_candidate, &\n        outcome%mass_in,outcome%mass_out,mass_residual,policy%mass_tolerance,accepted_missing_mask,mass_ok, &\n        outcome%temporal_indicator,outcome%temporal_certificate_available\n"+anchor)
    patches[path]=raw[:start]+body+raw[end:]
    path='src/runtime/mod_canonical_interval_runtime.f90'
    raw=(ROOT/path).read_text()
    anchor='      call accumulate_transaction(result, tx)\n'
    patches[path]=replace_once(raw,anchor,anchor+"      if(cursor>=34d0.and.cursor<34.02d0) print *, 'D4_TRANSACTION',cursor,transaction_t1,tx%status, &\n        tx%accepted_t1,tx%attempts,tx%solver_rejections,tx%mass_rejections,tx%temporal_rejections\n")
    path='src/runtime/mod_fmr_serialized_reference_backend.f90'
    raw=(ROOT/path).read_text()
    anchor='    self%last_observation%solver_status = solve_result%status\n'
    patches[path]=replace_once(raw,anchor,anchor+"    if(t0>=34d0.and.t0<34.02d0) then\n      print *, 'D4_SOLVER',t0,t1,solve_result%status,solve_result%top_flux,solve_result%bottom_flux, &\n        solve_result%native_balance_rate_residual_cm_per_day\n      print *, 'D4_BASE_HEAD',request%base_state%pressure_head\n      print *, 'D4_CAND_HEAD',solve_result%candidate_state%pressure_head\n      print *, 'D4_CAND_THETA',solve_result%candidate_state%water_content\n    end if\n")
    objects=[]
    for i,path in enumerate(b['sources']):
        if path in patches:
            src=out/Path(path).name;src.write_text(patches[path])
            report['observer_sources'][path]=sha(src)
            obj=out/f'{i:04d}.o'
            run(fc+flags+['-c',src,'-o',obj])
        else:
            obj=base/f'{i:04d}.o'
        objects.append(obj)
    driver=(base/'driver.f90').read_text()
    snapshot="""        call ta%copy_committed_for_crop(1,ss,j)
        call ss%snapshot(ps,ok)
        select type(ps)
        type is(fmr_b110_temporal_indicator_state_t)
          print *, 'D4_EXTERNAL_STATE',ps%pressure_head,ps%water_content,ps%ponding_depth
        end select
"""
    # The public state snapshot is read-only. Preserve the original st for require.
    anchor='    do q=0,windows-1\n'
    driver=replace_once(driver,anchor,anchor+"      if(d==34.and.q==0)then\n"+snapshot+"      end if\n")
    anchor="      call require(st==FMR_APP_BOOT_OK,'live weather hydrology')\n"
    driver=replace_once(driver,anchor,"      if(st/=FMR_APP_BOOT_OK)then\n        print *, 'D4_EXTERNAL_FAILURE',d,q,st,rr(1)%kernel_status,rr(1)%commit_status, &\n          rr(1)%accepted_substeps,rr(1)%solver_rejections,rr(1)%temporal_rejections,rr(1)%mass_rejections\n"+snapshot+"      end if\n"+anchor)
    if max_retries is not None:
        assert max_retries>32
        driver=replace_once(driver,'config%numerical%transaction%max_retries=32',
                            f'config%numerical%transaction%max_retries={max_retries}')
        report['controlled_retry_variant']=max_retries
    (out/'driver.f90').write_text(driver)
    path='src/legacy/b1_10_port/headcalc.f90'
    raw=(ROOT/path).read_text()
    anchor='!  Convergence could not been reached\n'
    raw=replace_once(raw,anchor,anchor+"   if(abs(state%qtop+4.8064754301850261d0)<1d-8) then\n      print *, 'D4_HEADCALC_FAILURE',dt,NN,solver_numbit,sum1,CritDevBalTot,CritDevBalCp, &\n        CritDevh2Cp,CritDevh1Cp,flnonconv,flnonconv3\n      print *, 'D4_FINAL_RESIDUAL',fsi_ws%residual(1:NN)\n      print *, 'D4_FINAL_HEAD',state%h(1:numnod)\n      print *, 'D4_FINAL_HEAD_INCREMENT',state%h(1:NN)-fsi_ws%old_head(1:NN)\n   end if\n")
    (out/'headcalc.f90').write_text(raw)
    report['observer_sources'][path]=sha(out/'headcalc.f90')
    run(fc+flags+[out/'driver.f90',out/'headcalc.f90',*objects,'-o',out/'weather'])
    original=(base/'weather.999').read_bytes()
    authority=gzip.decompress((ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-andelst_meteo.999.gz').read_bytes())
    assert original==authority
    lines=original.decode().splitlines(keepends=True)
    count=0
    for i,line in enumerate(lines):
        spans=list(re.finditer(r'\S+',line));v=[m[0] for m in spans]
        if len(v)!=12 or v[0]!="'ANDE-M'": continue
        rain=Decimal(v[9])*4
        if v[1:4]==['23','2','1999'] and rain_on_feb23 is not None:
            assert Decimal(0)<=rain_on_feb23<=rain
            rain=rain_on_feb23
        m=spans[9];lines[i]=line[:m.start()]+str(rain)+line[m.end():];count+=1
    assert count==116
    (out/'weather.999').write_text(''.join(lines))
    report['forcing_variant']=dict(rain_multiplier=4,feb23_override_mm=str(rain_on_feb23),weather_sha256=sha(out/'weather.999'))
    report.update(status='BUILT',executable_sha256=sha(out/'weather'),generated_driver_sha256=sha(out/'driver.f90'))
    (out/'BUILD.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(dict(status=report['status'], seconds=sum(x['seconds'] for x in report['events']))))


if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--base',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--compiler',required=True)
    ap.add_argument('--max-retries',type=int)
    ap.add_argument('--rain-on-feb23',type=Decimal)
    a=ap.parse_args()
    build(a.base,a.output,[a.compiler],a.max_retries,a.rain_on_feb23)
