#!/usr/bin/env python3
"""Run measured historical wet-heath retention with explicit external priors.

Ecotope scenarios, not automatically assigned to present-day map cells.
Original SWAP431 executable and numerical acceptance settings stay unchanged.
"""
import argparse
import calendar
import csv
import datetime as dt
import hashlib
import itertools
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import time

from run_local_soil_scenarios import update


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def balance(case):
    with (case / 'result_output.csv').open() as handle:
        rows = list(csv.DictReader(line for line in handle if not line.startswith('*')))
    assert len(rows) == 1006
    assert all(dt.date.fromisoformat(r['DATE']) == dt.date(2023, 12, 31) + dt.timedelta(days=i) for i, r in enumerate(rows))
    settings = (case / 'swap.swp').read_text()
    assert re.search(r'(?m)^\s*SWRUNON\s*=\s*0\b', settings)
    assert re.search(r'(?m)^\s*SWDRA\s*=\s*0\b', settings)
    inactive = {'RUNON', 'DRN'}
    if re.search(r'(?m)^\s*SWBOTB\s*=\s*6\b', settings):
        inactive.add('BOT')
    def val(row, key):
        if key not in row:
            assert key in inactive, 'Missing active output: ' + key
            return 0.
        value = float(row[key])
        assert math.isfinite(value)
        return value
    # Include the active canopy reservoir, unlike the earlier bare-soil ledger.
    storage = [sum(val(r, k) for k in ['WTOT', 'PD_VOL', 'IC_VOL']) for r in rows]
    incoming = ['RAIN', 'IRRIG', 'RUNON', 'SSDI', 'BOT']
    outgoing = ['RUNOFF', 'EACT', 'EPD', 'TACT', 'EIC', 'DRN']
    totals = {key: math.fsum(val(r, key) for r in rows[1:]) for key in incoming + outgoing}
    assert abs(totals['RAIN'] - 221.66) < 1e-5
    native = max(abs(val(r, 'BALDEV')) for r in rows[1:])
    residual = [sum(val(r, k) for k in incoming) - sum(val(r, k) for k in outgoing) - (b-a)
                for r, a, b in zip(rows[1:], storage, storage[1:])]
    # Printed-component uncertainty, not a changed solver tolerance.
    assert max(abs(x) for x in residual) <= native + 20 * .0000051
    assert all(val(r, 'IC_VOL') >= 0 and val(r, 'PD_VOL') >= 0 for r in rows)
    contract = json.loads((case / 'case_manifest.json').read_text())
    lower = sum((h['bottom_cm']-h['top_cm'])*h['swap_mvg'][0] for h in contract['layers'])
    upper = sum((h['bottom_cm']-h['top_cm'])*h['swap_mvg'][1] for h in contract['layers'])
    for row in rows[1:]:
        assert lower-1e-4 <= val(row,'WTOT') <= upper+1e-4
        assert val(row,'IC_VOL') <= contract['canopy_capacity_cm_per_lai']*val(row,'LAI') + 1e-5
        assert abs(val(row,'RD')-contract['root_depth_cm']) < 1e-5
        assert val(row,'TACT') <= val(row,'TPOT')+1e-5
    return {'water_unit': 'cm', 'days': 1005, 'totals': totals,
            'initial_soil_pond_canopy_storage': storage[0], 'final_soil_pond_canopy_storage': storage[-1],
            'storage_change': storage[-1]-storage[0],
            'period_closure': sum(totals[k] for k in incoming)-sum(totals[k] for k in outgoing)-storage[-1]+storage[0],
            'max_daily_native_baldev': native, 'max_daily_printed_component_closure': max(abs(x) for x in residual),
            'physical_daily_states_checked':len(rows)-1,'soil_storage_limits_cm':[lower,upper],
            'year_boundary_days': [{k: r[k] for k in ['DATE', 'IC_VOL', 'EIC', 'BALDEV']}
                                   for r in rows if r['DATE'][5:] in ['12-31', '01-01']],
            'eic_contract': 'Native interception term includes canopy-capacity loss at annual crop reset; not pure measured evaporation.'}


def compress_table(values):
    """Approximate source LAI within0.05m2/m2, below native20-pair capacity."""
    keep = {0, len(values)-1}
    def split(a, b):
        if b <= a+1:
            return
        error, i = max((abs(values[j] - (values[a] + (values[b]-values[a])*(j-a)/(b-a))), j)
                       for j in range(a+1, b))
        if error > .05:
            keep.add(i)
            split(a, i)
            split(i, b)
    split(0, len(values)-1)
    assert len(keep) <= 20
    return sorted(keep)


def crop(lai, year, root, capacity):
    nday = 366 if calendar.isleap(year) else 365
    # Gregorian day number preserved, without inventing a 29 February in other years.
    indices = compress_table(lai[:nday])
    laitable = '\n'.join(f'{2*i/nday:.12e} {lai[i]:.12e}' for i in indices)
    if indices[-1] * 2 / nday < 2:
        laitable += f'\n2.000000000000e+00 {lai[nday-1]:.12e}'
    assert len(indices)+1 <= 20
    return f"""* Historical wet-heath scenario; documented local observations and NHI priors.
SWPREP = 0
SWSOW = 0
SWGERM = 0
SWHARV = 0
IDEV = 1
LCC = {nday}
SWCF = 2
CHTB =
0.0 4.000000000000e+01
2.0 4.000000000000e+01
ALBEDO = 3.000000000000e-01
RSC = 2.888400000000e+02
RSW = 0.000000000000e+00
KDIF = 6.000000000000e-01
KDIR = 7.500000000000e-01
LAITB =
{laitable}
SWRD = 2
RDI = {root:.12e}
RRI = 0.000000000000e+00
RDC = {root:.12e}
SWDMI2RD = 0
SWRDC = 0
RDCTB =
0.0 1.000000000000e+00
1.0 0.000000000000e+00
SWDROUGHT = 1
HLIM3H = -2.000000000000e+02
HLIM3L = -8.000000000000e+02
HLIM4 = -8.000000000000e+03
ADCRH = 5.000000000000e-01
ADCRL = 1.000000000000e-01
SWOXYGEN = 0
SWWRTNONOX = 0
SWSALINITY = 0
SWCOMPENSATE = 0
SWINTER = 3
SICCAPLAI = {capacity:.12e}
SICACT = 0.000000000000e+00
SCHEDULE = 0
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('executable', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--first-only', action='store_true')
    args = parser.parse_args()
    root, out, exe = args.root.resolve(), args.output.resolve(), args.executable.resolve()
    out.mkdir(parents=True, exist_ok=True)
    weather = root / 'results/weather_aligned.csv'
    rows = list(csv.DictReader(weather.open()))
    assert len(rows) == 24120
    shared = out / 'forcing'
    shared.mkdir(exist_ok=True)
    # The recovered native detail reader expects a date and record1..24.
    with (shared / 'hourly.met').open('w') as handle:
        handle.write('* Original aligned ERA5 reanalysis, UTC interval starts; not station data\nDATE RECORD RAD TEMP HUM WIND RAIN\n')
        for i, r in enumerate(rows):
            date = dt.datetime.fromisoformat(r['time'])
            assert date == dt.datetime(2024, 1, 1) + dt.timedelta(hours=i)
            dew = float(r['dew_c'])
            vapour = .61078 * math.exp(17.27 * dew / (dew + 237.3))
            values = [float(r['shortwave_mj_m2_hour'])*1000, float(r['temp_c']), vapour,
                      float(r['wind10_m_s']), float(r['precip_mm_hour'])]
            assert all(math.isfinite(v) for v in values) and values[0] >= 0 and values[-1] >= 0
            handle.write(f'{date.date().isoformat()} {date.hour+1} ' + ' '.join(f'{v:.12e}' for v in values) + '\n')
    daily = root / 'results/swap431_grid_soil_scenarios/forcing'
    shutil.copyfile(daily / 'kalmthout.rain', shared / 'kalmthout.rain')
    template = (daily / 'swap.swp').read_text()
    fits = json.loads((root / 'results/local_studies/historical_retention_fits.json').read_text())['fits']
    ksource = Path(__file__).resolve().parent.parent/'local_sources/staring2018_parameters.csv'
    staring = {r['code']:r for r in csv.DictReader(ksource.open())}
    source_lai = root / 'results/nhi_ecosystem_priors/selected/Basisdata/msw_templates/fact_svat.inp'
    facts = [l.split() for l in source_lai.read_text().splitlines() if l.split() and l.split()[0] == '14']
    assert len(facts) == 366 and [int(r[1]) for r in facts] == list(range(1,367))
    lai = [float(r[3]) for r in facts]
    assert 0 < min(lai) <= max(lai) <= 12
    horizons = [('A1',0,10), ('A2',10,21), ('B21h',21,27), ('B22h',27,47),
                ('B31',47,72), ('B32',72,87), ('B33m',87,106)]
    results = []
    for variant, root_depth, capacity, bottom in itertools.product([1,2], [35.,50.], [.05,.1], [6,7]):
        name = f'wetheath_a{variant}_r{int(root_depth)}_ic{int(capacity*100):02}_bot{bottom}'
        case = out / name
        case.mkdir(exist_ok=True)
        for filename in ['hourly.met','kalmthout.rain']:
            shutil.copyfile(shared / filename, case / filename)
        for year in [2024,2025,2026]:
            (case / f'heath{year}.crp').write_text(crop(lai, year, root_depth, capacity))
        text = template
        for key, value in [('PROJECT', "'" + name + "'"), ('SWCROP','1'), ('SWCSV','1'), ('SWMONTH','0'),
                           ('SWSOLU','0'), ('SWHEA','0'), ('SWEND','1'), ('RDS','106.0'), ('SWBOTB',str(bottom)),
                           ('SWMETDETAIL','1'), ('METFIL',"'hourly.met'"), ('ALTW','10.0'), ('ALTH','2.0'),
                           ('SWETR','0'), ('SWDIVIDE','1'), ('RSOIL','150.0'), ('SWRAIN','0'),
                           ('INLIST_CSV',"'WATBAL,ETTERMS,CROP,GWL'")]:
            text = update(text, key, value)
        # Native detailed-met contract: SWRAIN0 consumes the actual hourly
        # amounts from hourly.met. It is not daily or simplified rainfall.
        crop_rows = '\n'.join(f"{year}-01-01 {year}-12-31 'heath{year}' 1" for year in [2024,2025,2026])
        text = re.sub(r'(  CROPSTART    CROPEND  CROPFIL CROPTYPE\n).*?(\* End of table)',
                      lambda m:m[1]+crop_rows+'\n'+m[2], text, flags=re.S)
        grids, hydraulics, layers = [], [], []
        for i, (horizon, top, bot) in enumerate(horizons, 1):
            f = next(f for f in fits if f['profile']=='2' and f['horizon']==horizon and
                     f['row_variant']==str(variant if horizon=='A1' else 1))
            # External fitted class-scale K prior, not a measurement of the iron pan.
            ksat = float(staring['B01' if horizon=='A1' else 'O01']['Ksat_fit_cm_day'])
            values = [f['theta_r'],f['theta_s'],f['alpha_per_cm'],f['alpha_per_cm'],f['n'],.5,ksat,ksat,0,1500]
            grids.append(f'{i} {i} {bot-top:.8f} {math.ceil((bot-top)/(1 if top<10 else 5))}')
            hydraulics.append(' '.join(f'{v:.12e}' for v in values))
            layers.append({'horizon':horizon,'top_cm':top,'bottom_cm':bot,'retention_fit':f,'swap_mvg':values})
        text = re.sub(r'( ISUBLAY ISOILLAY HSUBLAY NCOMP\n).*?(\* End of table)',
                      lambda m:m[1]+'\n'.join(grids)+'\n'+m[2], text, flags=re.S)
        text = re.sub(r'( ORES\s+OSAT[^\n]*\n).*?(\* End of table)',
                      lambda m:m[1]+'\n'.join(hydraulics)+'\n'+m[2], text, flags=re.S)
        text = re.sub(r'(?m)^ -200\.0 -75\.0$', ' -106.0 -75.0', text)
        (case / 'swap.swp').write_text(text)
        contract = {'case':name,'executable_sha256':sha(exe),'weather_sha256':sha(weather),'lai_source_sha256':sha(source_lai),
                    'conductivity_source_sha256':sha(ksource),
                    'layers':layers,'root_depth_cm':root_depth,'canopy_capacity_cm_per_lai':capacity,'bottom_mode':bottom,
                    'status':'PROVISIONAL_HISTORICAL_WET_HEATH_ECOTOPE_NOT_VALIDATED_GRID_CELL',
                    'assumptions':['Profile2 Wilgenduinen 1980, retention from1981 tables; column truncated at106cm.',
                                   'NHI hourly1991-2020 RSC288.84s/m, LAI1..2.5, albedo0.3, Kdif0.6, Kdir0.75, Rsoil150.',
                                   'Seasonal LAI table approximates the366 source values within0.05m2/m2 to fit the native table capacity.',
                                   'Crop height40cm is an explicit scenario assumption, not a local measurement.',
                                   'Root35/50cm brackets two historical wet-heath observations; linear density is assumed.',
                                   'Rutter capacity0.5/1mm per LAI sensitivity; NHI constant1mm capacity is not identical.',
                                   'Annual static crop cycles reset canopy, with native capacity-loss accounting; no artificial root growth.',
                                   'No oxygen stress, consistent with NHI p1/p2=99m; wet-heath physiological validity unqualified.',
                                   'Staring2018 fitted Ksat B01/O01, lambda0.5 assumption; iron-pan resistance unmeasured.',
                                   'Uniform initial h=-75cm; zero/free lower-boundary scenarios; no local calibration.',
                                   'SWMETDETAIL1 and SWRAIN0 use actual hourly rain from hourly.met; rainfile is a retained unused reference.',
                                   'No current cell assignment and no assimilation of mixed-pixel MODIS LAI.']}
        (case / 'case_manifest.json').write_text(json.dumps(contract,indent=2)+'\n')
        inputs = {p.name:sha(p) for p in case.iterdir() if p.suffix in ['.swp','.crp','.met','.rain']}
        receipt = case / 'run_receipt.json'
        if args.prepare_only:
            result = {'case':name,'status':'PREPARED','input_sha256':inputs}
        elif receipt.exists() and (old:=json.loads(receipt.read_text())).get('input_sha256')==inputs and old.get('executable_sha256')==sha(exe) and all(
                sha(case / p)==v for p,v in old['output_sha256'].items()):
            result = dict(old,reused=True)
            result['water_balance'] = balance(case)
        else:
            start = time.perf_counter()
            with (case / 'stdout.log').open('w') as stdout,(case / 'stderr.log').open('w') as stderr:
                try:
                    run = subprocess.run([str(exe)],cwd=case,stdout=stdout,stderr=stderr,timeout=120)
                    code = run.returncode
                except subprocess.TimeoutExpired:
                    code = -124
            log = (case / 'swap.log').read_text() if (case / 'swap.log').exists() else ''
            success = code==100 and 'Swap simulation okay!' in log
            result = {'case':name,'input_sha256':inputs,'executable_sha256':sha(exe),'returncode':code,
                      'wall_seconds':time.perf_counter()-start,'native_success':success,'reused':False,
                      'output_sha256':{p.name:sha(p) for p in case.iterdir() if p.name in ['result_output.csv','swap.log','stdout.log','stderr.log']}}
            if success:
                result['water_balance'] = balance(case)
                receipt.write_text(json.dumps(result,indent=2)+'\n')
        results.append(result)
        (out / 'batch_results.json').write_text(json.dumps({'runs':results,'status':'PROVISIONAL_ECOTOPE_SCENARIOS'},indent=2)+'\n')
        print(name,result.get('native_success',result.get('status')),flush=True)
        if args.first_only:
            break


if __name__ == '__main__':
    main()
