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


def native(raw, row, build, original_parameter_dump=None):
    """Independent typed outer witness only; full thermal/calendar audit pending."""
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
    return dict(status='TYPED_OUTER_RIA_DOMAIN_AND_ORIGINAL_PARAMETER_BYTES_PASS_INNER_THERMAL_CALENDAR_NOT_YET_AUDITED', parameter_offset=at, snow=snow, precision_bytes=16)
