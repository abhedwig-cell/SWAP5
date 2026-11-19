"""Independent actual H water/CDE and complete hourly root carry evidence reader.

Historical H water acceptance is1e-10 per accepted day (the unchanged daily
kernel and check_hupsel51_repair.check). Integrated water drift is reported;
it is not relabelled as whole-model scientific equivalence. The existing
integrated CDE inventory guard remains1e-10. No production renderer is called.
"""
from datetime import date
import hashlib
import io
import json
import math
import struct
import zipfile

from implicit_conductivity_forensics import require, finite, original_observations, sequential_records
from cde_clock_verify import ledger as original_cde_ledger


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def rows(z, prefix):
    return [json.loads(v) for v in z.read(prefix+'daily.jsonl').splitlines()]


def physical(data):
    return [{k:v for k, v in row.items() if k not in ('column', 'revision')} for row in data]


def ledger(data):
    require(bool(data), 'Empty actual weather trajectory')
    first = data[0]['day'];previous = None
    for i, row in enumerate(data):
        require(row['committed'] is True and row['day'] == first+i, 'Censored weather accepted day sequence')
        start, end, flow = (row[k] for k in ('stock_start_cm', 'stock_end_cm', 'external_flux_cm'))
        require(len(start) == len(end) == 6 and len(flow) == 16, 'Malformed weather stock/flux receipt')
        require(finite([*start, *end, *flow, *row['pressure_head_cm']]) and min(start+end) >= 0, 'Invalid actual weather physical values')
        if previous is not None:require(previous == start, 'Discontinuous actual weather stocks')
        residual = math.fsum([*flow[:7], *(-v for v in flow[7:]), *start, *(-v for v in end)])
        require(residual == row['independent_residual_cm'], 'Weather independent water receipt changed')
        require(finite([residual, row['kernel_residual_cm'], row['integrated_guard_residual_cm']])
                and max(abs(residual), abs(row['kernel_residual_cm']), abs(row['integrated_guard_residual_cm'])) <= 1e-10,
                'Historical daily weather water guard exceeded')
        previous = end
    original_cde_ledger(data, len(data))
    total = math.fsum([*data[0]['stock_start_cm'], *(-v for v in data[-1]['stock_end_cm']),
                      *(v for row in data for v in row['external_flux_cm'][:7]),
                      *(-v for row in data for v in row['external_flux_cm'][7:])])
    return dict(days=len(data), maximum_daily_water_cm=max(abs(r['independent_residual_cm']) for r in data),
                measured_integrated_water_residual_cm=total,
                water_acceptance='UNCHANGED_H_DAILY_1E-10_CM; INTEGRATED_DRIFT_REPORTED_WITHOUT_EQUIVALENCE_CLAIM',
                integrated_cde_guard_mg_cm2=1e-10)


def root_native(raw, row, n, epoch):
    require(len(raw) > 156 and raw[:8] == b'S5WRH001', 'Foreign actual hourly root carry codec')
    domain = [1, n, 0, 1, 0, 0, 6, 1]
    first = struct.unpack_from('<8i', raw, len(raw)-108)
    second = struct.unpack_from('<8i', raw, len(raw)-76)
    require(list(first) == domain and first == second, 'Actual hourly root carry domain differs')
    clock, wet, dry, wet_copy, dry_copy, count = struct.unpack_from('<5di', raw, len(raw)-44)
    expected = (date.fromisoformat(epoch)-date(1900, 1, 1)).days+1+row['day']
    require(count == 108 and finite([clock, wet, dry]) and clock == expected, 'Actual hourly root carry clock/size differs')
    require(0 <= wet <= 1 and 0 <= dry <= 1 and [wet, dry] == [wet_copy, dry_copy]
            and [wet, dry] == row['weather_root_memory'], 'Actual hourly root stress/receipt differs')
    return [wet, dry]


def checkpoint(raw, build, row, hourly):
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        require(set(z.namelist()) == {'result.end', 'macro.bin', 'checkpoint.json'}, 'Foreign actual weather checkpoint inventory')
        manifest = json.loads(z.read('checkpoint.json'))
        require(manifest['schema'] == 'swap5-hybrid-water-checkpoint-3' and manifest['binding'] == build['binding']
                and manifest['receipt'] == row, 'Actual weather native origin/receipt binding differs')
        require(set(manifest['files']) == {'result.end', 'macro.bin'}, 'Incomplete actual weather native member hashes')
        for name, value in manifest['files'].items():require(digest(z.read(name)) == value, 'Actual weather native member changed')
        aux = z.read('macro.bin');n = build['project']['nodes'];epoch = build['project']['start_date']
        require(aux[:8] == (b'S5WRH001' if hourly else b'S5HUP012'), 'Wrong actual weather codec family')
        nodes, clock, step, canopy = struct.unpack_from('<i3d', aux, 8)
        expected = (date.fromisoformat(epoch)-date(1900, 1, 1)).days+1+row['day']
        require(nodes == n and finite([clock, step, canopy]) and clock == expected and 0 < step <= 1
                and canopy == row['stock_end_cm'][3], 'Actual weather original prefix differs from receipt')
        conserved = struct.unpack_from('<'+str(n+2)+'d', aux, 48)
        require(finite(conserved) and min(conserved) >= 0 and conserved[-1] == row['solute_end_mg_cm2'],
                'Actual weather CDE native total differs from original ledger')
        if hourly:root_native(aux, row, n, epoch)
        return dict(original_record_lengths=sequential_records(z.read('result.end')),
                    macro_bytes=len(aux), macro_sha256=digest(aux), result_sha256=digest(z.read('result.end')))


def root_observations(raw, data, epoch):
    memory = None;seen = []
    base = (date.fromisoformat(epoch)-date(1900, 1, 1)).days+1
    for line in raw.decode('utf8').splitlines():
        if line.startswith('HYBRID_WEATHER_ROOT_MEMORY '):memory = list(map(float, line.split()[1:]))
        elif line.startswith('HYBRID_DAY_RETURN '):
            i = len(seen);require(i < len(data) and memory == [base+data[i]['day'], *data[i]['weather_root_memory']],
                                    'Actual original hourly stress witness differs from receipt')
            seen.append(data[i]['day']);memory = None
    require(len(seen) == len(data), 'Actual original hourly stress witness omitted')


def trajectory(z, prefix, build, days, hourly):
    data = rows(z, prefix)
    require(len(data) == days, 'Actual weather full/short period truncated')
    result = ledger(data)
    original_observations(z.read(prefix+'original/donor.stdout'), data, build['project']['start_date'])
    if hourly:root_observations(z.read(prefix+'original/donor.stdout'), data, build['project']['start_date'])
    return result, data


def cold(z, warm_prefix, cold_prefix, build, warm, low, high, hourly):
    data = rows(z, cold_prefix);ledger(data)
    require(len(data) == high-low and physical(data) == physical(warm[low:high]), 'Actual weather cold physical/CDE suffix differs')
    original_observations(z.read(cold_prefix+'original/donor.stdout'), data, build['project']['start_date'])
    if hourly:root_observations(z.read(cold_prefix+'original/donor.stdout'), data, build['project']['start_date'])
    for prefix, row in [(warm_prefix, warm[high-1]), (cold_prefix, data[-1])]:
        checkpoint(z.read(prefix+f'accepted-column-1-day-{high}.zip'), build, row, hourly)
    with zipfile.ZipFile(io.BytesIO(z.read(warm_prefix+f'accepted-column-1-day-{high}.zip'))) as a, zipfile.ZipFile(io.BytesIO(z.read(cold_prefix+f'accepted-column-1-day-{high}.zip'))) as b:
        require(all(a.read(n) == b.read(n) for n in ('result.end', 'macro.bin')), 'Actual complete weather original native differs')
    def csv(prefix):
        return [s for s in z.read(prefix+'original/result_output.csv').decode('cp1252').splitlines()
                if s and not s.startswith('*')]
    require(csv(cold_prefix)[-(high-low):] == csv(warm_prefix)[low+2:high+2], 'Actual weather original CSV continuation differs')
    return dict(start=low, end=high, actual_complete_native_exact=True, actual_physical_chemical_csv_exact=True)
