"""Bounded native crop preparation against complete original fixed.f90."""
import argparse
import base64
import csv
from datetime import date, timedelta
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile
import time

ROOT = Path(__file__).resolve().parents[2]


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def oracle():
    p = ROOT / 'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(p.read_bytes())), mode='r:gz') as t:
        fixed = t.extractfile('SWAP/fixed.f90').read()
        functions = t.extractfile('SWAP/functions.f90').read().decode('latin1')
        meteo = t.extractfile('SWAP/MOD_meteo.f90').read().decode('latin1')
    assert digest(fixed) == '1d57e86f0bf067e8432da69f46cd19e0df6768b9c6bcf560d2221248f3b12f75'
    helpers = ''
    for kind, name in [('subroutine', 'rdadortb'), ('subroutine', 'afgen_2'), ('function', 'afgen')]:
        pattern = (r'^\s*(?:real\(8\)\s+)?' + kind + ' ' + name +
                   r'\b.*?^\s*end ' + kind + ' ' + name + r'\b')
        helpers += re.search(pattern, functions, re.M | re.I | re.S).group() + '\n'
    a = meteo.index('   subroutine ETpot')
    b = meteo.index('   end subroutine ETpot', a) + len('   end subroutine ETpot')
    source = '''module MOD_arrays
 integer,parameter::macroptb=1000
end module
module MOD_swap_base
 integer::unit_err=0
end module
module plant_interface
 implicit none
 integer::unit_crp=75,icrop=1,swrdc=0,sw_drought=1,sw_oxygen=0,swcf=1
 character(1024)::crpfilnam
 logical::fl_start_cropemergence=.true.,fl_cropemergence=.false.,fl_cropharvest=.false.
 real(8)::cropend(1),kdir,kdif,sicact,dvs,tsum,lai,wrt,grrt,drrt,grrtpot,max_resp_factor
 real(8)::wroottb(1000),mrftb(1000),fco2tra=1d0,cf=1d0,vcover=0d0
 real(8)::dt_interc_event,crsflx_in,crsflx_out
end module
module variables
 real(8)::t1900,cfbs=1d0,rsoil=0d0
 integer::swcfbs=0,daynr=1
end module
module atmosphere_interface
 real(8)::tav
end module
''' + fixed.decode('latin1') + '''
module original_et
 implicit none
 integer,parameter::swmetdetail=0,swetr=1,swdivide=0
 real(8)::etr,cfevappond,es0,ep0,et0,ew0,epond,peva,ptra_dry,ptra_wet,eintc,wfrac
contains
''' + meteo[a:b] + '''
end module
program original_native
 use MOD_fixed
 use plant_interface
 use variables
 use atmosphere_interface
 use original_et
 implicit none
 integer::n,i,j,u,first,last,datea(6)
 integer,allocatable::dd(:),mm(:),yyyy(:)
 real(8)::tstart,tend,cropstart(1),rdmax,depth,cf_table(1000),depth_table(1000)
 real(8),allocatable::tmin(:),tmax(:),etref(:),times(:)
 character(1024)::swp,met
 real(8)::afgen
 call get_command_argument(1,swp);call get_command_argument(2,crpfilnam);call get_command_argument(3,met)
 call rdinit(74,0,trim(swp))
 call rdstim('tstart',tstart);call rdstim('tend',tend)
 call rdatim('cropstart',cropstart,1,j);call rdftim('cropend',cropend,1,j)
 call rdsdor('rds',1d0,5000d0,rdmax);call rdsdor('cfevappond',0d0,10d0,cfevappond)
 close(74)
 call cropfixed(1)
 ! IDEV=1 leaves TBASE unassigned in original. Only its DVS/LAI is compared.
 if(idev==1)tbase=0d0
 call cropfixed(2)
 call rdinit(74,0,trim(crpfilnam))
 call rdadortb('cftb',0d0,2d0,0d0,2d0,cf_table,1000,.false.)
 call rdadortb('rdtb',0d0,3d0,0d0,1000d0,depth_table,1000,.false.)
 close(74)
 call rdinit(74,0,trim(met))
 call rdinne('yyyy',n)
 allocate(dd(n),mm(n),yyyy(n),tmin(n),tmax(n),etref(n),times(n))
 call rdfinr('dd',1,31,dd,n,n);call rdfinr('mm',1,12,mm,n,n);call rdfint('yyyy',yyyy,n,n)
 call rdfdor('tmin',-1d5,1d5,tmin,n,n);call rdfdor('tmax',-1d5,1d5,tmax,n,n)
 call rdfdor('etref',0d0,100d0,etref,n,n)
 close(74)
 do i=1,n
 datea=0;datea(1:3)=[yyyy(i),mm(i),dd(i)];call dtardp(datea,0.0,times(i))
 end do
 first=nint(tstart-times(1))+1;last=nint(tend-times(1))+1
 open(newunit=u,file='original.csv',status='new')
 write(u,'(A)')'t1900,active,dvs,lai,cover,root_depth_cm,transpiration_cm_day,soil_evaporation_cm_day,pond_evaporation_cm_day'
 do i=first,last
 t1900=times(i)
 fl_cropemergence=t1900>=cropstart(1).and.t1900<=cropend(1).and..not.fl_cropharvest
 if(fl_cropemergence)then
 vcover=1d0-exp(-kdir*kdif*lai)
 cf=afgen(cf_table,1000,dvs);depth=min(afgen(depth_table,1000,dvs),rdmax)
 else
 vcover=0d0;cf=0d0;depth=0d0
 end if
 etr=etref(i);call ETpot()
 write(u,'(ES25.16E3,8(A,ES25.16E3))')t1900,',',merge(1d0,0d0,fl_cropemergence), &
 ',',merge(dvs,0d0,fl_cropemergence),',',merge(lai,0d0,fl_cropemergence),',',vcover,',',depth, &
 ',',ptra_dry,',',peva,',',epond
 if(fl_cropemergence)then
 tav=.5d0*(tmin(i)+tmax(i));call cropfixed(3)
 ! Original end-of-day time and task4 precede the next day's ET demand.
 t1900=t1900+1d0;call cropfixed(4)
 end if
 end do
 close(u)
 print '(A)','ORIGINAL_NATIVE_FIXED_CROP_PASS'
end program
subroutine swap_error(where,message)
 character(*)::where,message
 print *,where,message
 error stop 1
end subroutine
subroutine swap_warning(where,message)
 character(*)::where,message
 print *,where,message
end subroutine
''' + helpers
    return source, digest(fixed)


def table(path):
    return [{k: float(v) for k, v in row.items()} for row in csv.DictReader(path.open())]


def main():
    ap = argparse.ArgumentParser()
    for opt in ['O0', 'O2']:
        ap.add_argument('--reader-' + opt, required=True, type=Path)
    ap.add_argument('--output', required=True, type=Path)
    args = ap.parse_args()
    out = args.output.resolve();out.mkdir(parents=True, exist_ok=False)
    paths = ['tests/nut-sol/qualify_native_simple_crop.py', 'tests/nut-sol/test_fixed_crop_phenology.f90']
    report = {'status': 'RUNNING', 'inputs': {p: digest((ROOT / p).read_bytes()) for p in paths},
              'builds': {}, 'events': [], 'cases': {}, 'invalid_cases': 0}

    def save():
        (out / 'result.json').write_text(json.dumps(report, indent=2) + '\n')

    def run(cmd, cwd, valid=True, marker=None):
        start = time.perf_counter()
        result = subprocess.run(list(map(str, cmd)), cwd=cwd, input=b'', capture_output=True, timeout=60)
        index = len(report['events'])
        for stream in ['stdout', 'stderr']:
            (out / f'{index:04d}.{stream}').write_bytes(getattr(result, stream))
        report['events'].append({'command': list(map(str, cmd)), 'cwd': str(cwd),
                                 'returncode': result.returncode, 'expected_success': valid,
                                 'seconds': time.perf_counter() - start, 'marker': marker})
        save()
        assert (result.returncode == 0) == valid, (cmd, result.stdout, result.stderr)
        if marker:assert marker.encode() in result.stdout
        return result

    original_source, original_sha = oracle()
    report['original_fixed_sha256'] = original_sha
    for opt in ['O0', 'O2']:
        folder = out / opt;folder.mkdir()
        reader = getattr(args, 'reader_' + opt).resolve()
        build = json.loads((reader.parent / 'build-complete.json').read_text())
        assert build['status'] == 'BUILT' and build['executable_sha256'] == digest(reader.read_bytes())
        assert all(digest((ROOT / p).read_bytes()) == h for p, h in build['input_sha256'].items())
        assert all(digest((reader.parent / p).read_bytes()) == h for p, h in build['generated_input_sha256'].items())
        report['builds'][opt] = build
        fc = build['compiler_command']
        flags = ['-' + opt, '-fcheck=all', '-ffpe-trap=invalid,zero,overflow', '-ffree-line-length-none',
                 '-J' + str(folder), '-I' + str(folder)]
        source = folder / 'original.f90';source.write_text(original_source)
        original_exe = folder / 'original'
        run(fc + flags + ['-std=legacy', source, reader.parent / 'libttutil.a', '-o', original_exe], folder)
        state_exe = folder / 'state_contract'
        run(fc + flags + ['-std=f2008', ROOT / 'src/crop/mod_crop_fixed_phenology.f90',
                           ROOT / paths[1], '-o', state_exe], folder)
        run([state_exe], folder, marker='FIXED_CROP_STATE_NONMUTATION_ABA_REJECTION_PASS')
        for name, development, harvest in [('fixed', 'IDEV=1\nLCC=4', 'SWHARV=0'),
                ('thermal', 'IDEV=2\nTSUMEA=10.\nTSUMAM=20.\nTBASE=0.', 'SWHARV=0'),
                ('maturity', 'IDEV=1\nLCC=4', 'SWHARV=1\nDVSEND=1.'),
                ('cold', 'IDEV=2\nTSUMEA=10.\nTSUMAM=20.\nTBASE=5.', 'SWHARV=1')]:
            case = folder / name;case.mkdir()
            swp = """TSTART=27-feb-2024
TEND=05-mar-2024
SWCROP=1
SWETR=1
METFIL='weather.met'
CROPSTART CROPEND CROPFIL CROPTYPE
28-feb-2024 03-mar-2024 'crop' 1
RDS=30.
CFEVAPPOND=1.3
SWCFBS=0
SWREDU=0
"""
            crp = development + '\n' + harvest + """
SWCF=1
SWINTER=0
SWCO2=0
SWPREP=0
SWSOW=0
SWGERM=0
SWRD=1
KDIR=.7
KDIF=.6
LAITB=0.,.2,1.,3.,2.,1.
CFTB=0.,.8,1.,1.2,2.,.9
RDTB=0.,10.,1.,20.,2.,40.
"""
            weather = 'DD MM YYYY TMIN TMAX RAIN ETREF\n'
            for i, temperature in enumerate([-2., 15., 5., -1., 20., 0., 10., 3.]):
                d = date(2024, 2, 27) + timedelta(days=i)
                if name == 'cold':temperature = -2.
                weather += f'{d.day} {d.month} {d.year} {temperature:.8f} {temperature:.8f} 0. 2.\n'
            for filename, text in [('input.swp', swp), ('crop.crp', crp), ('weather.met', weather)]:
                (case / filename).write_text(text)
            command = [reader, 'input.swp', 'crop.crp', 'weather.met']
            run(command, case, marker='SWP_NATIVE_SIMPLE_CROP_PREPARED')
            run([original_exe, 'input.swp', 'crop.crp', 'weather.met'], case, marker='ORIGINAL_NATIVE_FIXED_CROP_PASS')
            actual, expected = table(case / 'crop_daily.csv'), table(case / 'original.csv')
            assert len(actual) == len(expected) == 8
            for a, b in zip(actual, expected):
                assert set(a) == set(b)
                for key in a:
                    assert a[key] == b[key], (opt, name, key, a, b)
            # Repeat from the identical immutable inputs in a fresh process.
            again = case / 'again';again.mkdir()
            for filename in ['input.swp', 'crop.crp', 'weather.met']:
                (again / filename).write_bytes((case / filename).read_bytes())
            run(command, again, marker='SWP_NATIVE_SIMPLE_CROP_PREPARED')
            assert (again / 'crop_daily.csv').read_bytes() == (case / 'crop_daily.csv').read_bytes()
            report['cases'][opt + '-' + name] = {'days': actual, 'sha256': digest((case / 'crop_daily.csv').read_bytes())}
        base = folder / 'thermal'
        mutations = [('zero-tsum', 'crop.crp', 'TSUMEA=10.', 'TSUMEA=0.'),
                     ('crop-kind', 'input.swp', "'crop' 1", "'crop' 2"),
                     ('two-crops', 'input.swp', "28-feb-2024 03-mar-2024 'crop' 1", "28-feb-2024 03-mar-2024 'crop' 1\n01-apr-2024 01-may-2024 'crop' 1"),
                     ('mid-crop', 'input.swp', 'TSTART=27-feb-2024', 'TSTART=29-feb-2024'),
                     ('co2', 'crop.crp', 'SWCO2=0', 'SWCO2=1'),
                     ('interception', 'crop.crp', 'SWINTER=0', 'SWINTER=1'),
                     ('germination', 'crop.crp', 'SWGERM=0', 'SWGERM=1'),
                     ('table-order', 'crop.crp', 'LAITB=0.,.2,1.,3.,2.,1.', 'LAITB=0.,.2,0.,3.,2.,1.'),
                     ('missing-day', 'weather.met', '29 2 2024', '1 3 2024'),
                     ('filename', 'input.swp', "'crop'", "'../crop'"),
                     ('incomplete', 'input.swp', 'TEND=05-mar-2024', 'TEND=06-mar-2024')]
        for name, filename, old, new in mutations:
            case = folder / ('invalid-' + name);case.mkdir()
            for f in ['input.swp', 'crop.crp', 'weather.met']:
                (case / f).write_bytes((base / f).read_bytes())
            assert old in (case / filename).read_text()
            (case / filename).write_text((case / filename).read_text().replace(old, new))
            run([reader, 'input.swp', 'crop.crp', 'weather.met'], case, False)
            assert not (case / 'crop_daily.csv').exists()
            report['invalid_cases'] += 1
    report['status'] = 'NATIVE_SIMPLE_CROP_PREPARATION_O0_O2_PASS'
    report['full_historical_migration'] = False
    save()
    print(json.dumps({k: v for k, v in report.items() if k not in ['inputs', 'events', 'builds', 'cases']}))


if __name__ == '__main__':
    main()
