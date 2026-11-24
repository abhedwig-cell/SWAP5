"""Decode actual RIA12 native model, original parameters and unchanged calendar."""
from datetime import date
import math
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tests/nomacro_scheduled_subsurface'))

from implicit_conductivity_forensics import output_calendar


def parameter_bytes(original_dump, layers):
    """Map original SWRC/UHCC arrays, without reproducing reader arithmetic."""
    count, width = struct.unpack_from('<2i', original_dump)
    assert count == layers and width == 16 and len(original_dump) == 8 + layers * 11 * width
    swrc = original_dump[8:8 + layers * 5 * width]
    uhcc = original_dump[8 + layers * 5 * width:]
    result = b''
    for layer in range(layers):
        for values, columns in ((swrc, 5), (uhcc, 6)):
            for column in range(columns):
                at = (column * layers + layer) * width
                result += values[at:at + width]
    return result


def physical_restart(raw, row, build):
    """Read original SWAP unformatted restart fields in original writer order."""
    records, cursor = [], 0
    while cursor < len(raw):
        size = struct.unpack_from('<i', raw, cursor)[0]
        assert size > 0 and cursor + size + 8 <= len(raw)
        assert struct.unpack_from('<i', raw, cursor + size + 4)[0] == size
        records.append(raw[cursor + 4:cursor + size + 4])
        cursor += size + 8
    assert cursor == len(raw)
    integer = lambda i: struct.unpack('<i', records[i])[0]
    real = lambda i: struct.unpack('<d', records[i])[0]
    n = build['project']['nodes']
    selected = build['identity']['original_output']['original_ria12_thermal']
    assert integer(0) == 1 and integer(1) == 0 and integer(2) == n
    assert list(struct.unpack('<' + str(n) + 'd', records[3])) == row['pressure_head_cm']
    assert real(4) == row['stock_end_cm'][1]
    snow = integer(5)
    assert snow == selected['snow']
    i = 6
    if snow:
        assert real(i) == row['stock_end_cm'][2] >= 0 and math.isfinite(real(i + 1)) and real(i + 1) >= 0
        i += 2
    evaporation = integer(i)
    assert evaporation in (0, 1, 2)
    i += 1
    for _ in range(evaporation):
        assert math.isfinite(real(i)) and real(i) >= 0
        i += 1
    assert integer(i) == 0 and integer(i + 1) == 1  # No hysteresis; heat active.
    temperatures = struct.unpack('<' + str(n) + 'd', records[i + 2])
    assert all(math.isfinite(v) and v > -273.15 for v in temperatures)
    assert integer(i + 3) == int(selected['kind'] == 'cde')
    return dict(original_temperature_nodes=n, minimum_temperature_C=min(temperatures),
                maximum_temperature_C=max(temperatures), original_sequential_records=len(records))


def native(raw, row, build, original_parameter_dump=None):
    """Read actual outer parameters and literal preceding thermal/calendar state."""
    selected = build['identity']['original_output']
    ria = selected['original_ria12_thermal']
    layers = len(ria['models'])
    chemical = ria['kind'] == 'cde'
    snow = ria['snow']
    codec = {(0, False): b'S5RHW001', (0, True): b'S5RHC001', (1, False): b'S5RSW001', (1, True): b'S5RSC001'}[snow, chemical]
    assert raw[:8] == codec and ria['models'] == [12] * layers
    expected = (1, build['project']['nodes'], layers, int(chemical), 6, 1, 1, 2, snow, 16, *ria['models'])
    footer = 8 * len(expected)
    size = 11 * layers * 16
    at = len(raw) - footer - 2 * size
    assert at > 36 and struct.unpack_from('<' + str(2 * len(expected)) + 'i', raw, len(raw) - footer) == expected + expected
    values = raw[at:at + size]
    assert values == raw[at + size:at + 2 * size]
    assert all((int.from_bytes(values[i:i + 16], 'little') >> 112) & 32767 != 32767 for i in range(0, size, 16))
    if original_parameter_dump is not None:
        assert values == parameter_bytes(original_parameter_dump, layers)
    nodes, clock, step, canopy = struct.unpack_from('<i3d', raw, 8)
    epoch = (date.fromisoformat(build['project']['start_date']) - date(1900, 1, 1)).days + 1
    assert nodes == build['project']['nodes'] and clock == epoch + row['day'] and 0 < step <= 1 and canopy == row['stock_end_cm'][3] >= 0
    assert all(map(math.isfinite, (clock, step, canopy)))
    calendar = output_calendar(raw[:at], nodes, row, selected, build['project']['start_date'], chemical)
    result = dict(status='ACTUAL_RIA_ORIGINAL_PARAMETERS_CALENDAR_AND_SELECTED_THERMAL_CARRY_PASS',
                  parameter_offset=at, snow=snow, precision_bytes=16, calendar=calendar)
    if snow:
        end = calendar['calendar_offset']
        thermal_domain = (1, nodes, 0, int(chemical), 0, 1, 0, 1, 1, 2)
        domain = struct.pack('<10i', *thermal_domain)
        assert raw[end-80:end] == domain + domain and raw.count(domain + domain) == 1
        # Parse the actual preceding microscopic block from its size trailer.
        # No transport header, model number, producer metadata or bytes change.
        micro_end = end - 80
        micro_size = struct.unpack_from('<i', raw, micro_end - 4)[0]
        assert micro_size in (44, 44 + 8 * 862 * layers)
        micro_at = micro_end - micro_size
        h = struct.unpack_from('<8id', raw, micro_at)
        version, active, crop, drought, model, nl, nm, nk, saved_clock = h
        assert version == 2 and active in (0, 1) and saved_clock == clock
        if active:
            assert 1 <= crop <= 5 and (drought, model) in ((2, 2), (3, 1))
            assert (nl, nm, nk) == (layers, 431, 431) and micro_size == 44 + 8 * 862 * layers
            lookup = struct.unpack_from('<' + str(862 * layers) + 'd', raw, micro_at + 40)
            assert all(math.isfinite(v) and v >= 0 for v in lookup)
        else:
            assert (crop, drought, model, nl, nm, nk) == (0,) * 6 and micro_size == 44
        top_at = micro_at - 72
        version, saved_clock, *top = struct.unpack_from('<id6d3i', raw, top_at)
        assert version == 1 and saved_clock == clock and top[-1] == 72
        assert all(map(math.isfinite, top[:6])) and min(top[:4]) >= 0 and top[0] <= 1
        assert all(v in (0, 1) for v in top[6:8])
        # Oxygen's own flag distinguishes initialized arrays from no arrays.
        candidates = []
        for initialized in (0, 1):
            size = 24 + 48 * nodes * initialized
            oxygen_at = top_at - size
            if oxygen_at < 36:
                continue
            if struct.unpack_from('<3id', raw, oxygen_at) == (1, initialized, nodes, clock) and struct.unpack_from('<i', raw, top_at - 4)[0] == size:
                candidates.append((oxygen_at, initialized))
        assert len(candidates) == 1
        oxygen_at, initialized = candidates[0]
        if initialized:
            oxygen = struct.unpack_from('<' + str(6 * nodes) + 'd', raw, oxygen_at + 20)
            assert all(math.isfinite(v) and v >= 0 for v in oxygen) and min(oxygen[5 * nodes:]) >= 1
        heat_at = oxygen_at - 8 * (2 * nodes + 2)
        heat = struct.unpack_from('<' + str(2 * nodes + 2) + 'd', raw, heat_at)
        assert all(map(math.isfinite, heat)) and min(heat[:2 * nodes]) > 0
        crop_at = heat_at - 404
        emerged = struct.unpack_from('<i', raw, crop_at)[0]
        rates = struct.unpack_from('<50d', raw, crop_at + 4)
        assert emerged in (0, 1) and all(map(math.isfinite, rates))
        result.update(thermal_domain_offset=end-80, microscopic_offset=micro_at, top_offset=top_at,
                      oxygen_offset=oxygen_at, thermal_history_offset=heat_at, crop_rates_offset=crop_at,
                      complete_original_thermal_fields=['heacon', 'heacap', 'tetop', 'tebot'],
                      minimum_top_maximum_conductivity_cm_day=top[3],
                      thermal_conductivity_range=[min(heat[:nodes]), max(heat[:nodes])],
                      thermal_capacity_range=[min(heat[nodes:2 * nodes]), max(heat[nodes:2 * nodes])])
    return result
