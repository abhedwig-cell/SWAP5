"""Decode actual RIA12 native model, original parameters and unchanged calendar."""
from datetime import date
import math
import struct

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
    selected = build['identity']['original_output']
    ria = selected['original_ria12']
    models = ria['models']
    layers = len(models)
    nodes = build['project']['nodes']
    chemical = ria['kind'] == 'cde'
    codec = b'S5RIC001' if chemical else b'S5RIW001'
    assert layers > 0 and models == [12] * layers
    assert raw[:8] == codec and selected['native_codec'] == ria['native_codec'] == codec.decode()
    expected = (1, nodes, layers, int(chemical), 6, 1, 0, 0, 16, *models)
    footer = 8 * len(expected)
    size = 11 * layers * 16
    parameter_at = len(raw) - footer - 2 * size
    assert parameter_at > 36
    assert struct.unpack_from('<' + str(2 * len(expected)) + 'i', raw, len(raw) - footer) == expected + expected
    parameters = raw[parameter_at:parameter_at + size]
    assert parameters == raw[parameter_at + size:parameter_at + 2 * size]
    assert all((int.from_bytes(parameters[i:i + 16], 'little') >> 112) & 32767 != 32767 for i in range(0, size, 16))
    if original_parameter_dump is not None:
        assert parameters == parameter_bytes(original_parameter_dump, layers)
    nn, clock, step, canopy = struct.unpack_from('<i3d', raw, 8)
    epoch = (date.fromisoformat(build['project']['start_date']) - date(1900, 1, 1)).days + 1
    assert nn == nodes and all(map(math.isfinite, (clock, step, canopy)))
    assert clock == epoch + row['day'] and 0 < step <= 1 and canopy == row['stock_end_cm'][3] >= 0
    # This is the literal preceding format segment. No header or original bytes
    # are rewritten to make an old transport identity appear to apply.
    calendar = output_calendar(raw[:parameter_at], nodes, row, selected, build['project']['start_date'], chemical)
    return dict(models=models, parameter_offset=parameter_at, original_parameter_bytes=size,
                actual_precision_bytes=16, calendar=calendar)
