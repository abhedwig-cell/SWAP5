"""Bound the original RIA12 process to a separately witnessed native domain."""
import hashlib
import math
from pathlib import Path
import re

POLICY = 'original-ria12-daily-primary-native-domain-v1'
CODECS = {'water': b'S5RIW001', 'cde': b'S5RIC001'}
PROVIDER = Path(__file__).with_name('original_ria12_native.f90')


def selection(directory, original_output=True):
    if not directory:
        return None
    text = (Path(directory) / 'swap.swp').read_text(encoding='cp1252')
    active = '\n'.join(line.split('!', 1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
    def tokens(key):
        return re.findall(r'(?mi)^[ \t]*' + re.escape(key) + r'[ \t]*=[ \t]*([^\r\n]*)', active)
    rows = tokens('IHWCKMODEL')
    if not any(re.search(r'(?<![\w.])[+]?0*12(?![\w.])', row) for row in rows):
        return None
    if original_output is False:
        raise ValueError('RIA12 requires explicit original-output native state')
    if len(rows) != 1 or re.fullmatch(r'[+-]?[0-9]+(?:[ \t]+[+-]?[0-9]+)*[ \t]*', rows[0]) is None:
        raise ValueError('Missing/ambiguous original RIA12 model selectors')
    models = list(map(int, rows[0].split()))
    if not models or any(model != 12 for model in models):
        raise ValueError('RIA12 native domain requires model12 in every layer')
    from experimental_project import switches
    s = switches(active)
    fixed = dict(SWMACRO=0, SWKIMPL=0, SWSOPHY=0, SWHYST=0, SWSNOW=0, SWFROST=0,
                 SWDRA=1, SWBOTB=6, SWHEA=0, SWCALT=1, SWBR=0, SWMETDETAIL=0,
                 SWMONTH=0, SWODAT=0, SWRES=1)
    if any(s.get(key) != value for key, value in fixed.items()) or s.get('SWSOLU') not in (0, 1) or s.get('SWINCO') not in (1, 2):
        raise ValueError('RIA12 native domain requires bounded explicit daily primary water/CDE without heat, Snow, hysteresis or aquifer')
    for key in ('NPRINTDAY', 'PERIOD'):
        values = tokens(key)
        if len(values) != 1 or re.fullmatch(r'[+]?[0]*1[ \t]*', values[0]) is None:
            raise ValueError('RIA12 native domain requires daily ' + key + '=1')
    for key in ('HeatOn', 'VaporCond'):
        values = tokens(key)
        if len(values) != 1 or values[0].strip().upper() not in ('.FALSE.', 'FALSE', '.F.', 'F'):
            raise ValueError('RIA12 native domain requires inactive ' + key)
    flags = tokens('FLPRINTDT')
    if len(flags) > 1 or flags and flags[0].strip().upper() not in ('.FALSE.', 'FALSE', '.F.', 'F'):
        raise ValueError('RIA12 native domain requires original daily output')
    values = tokens('RIA_SWRC_wcsat')
    if len(values) != 1:
        raise ValueError('Missing/ambiguous original RIA12 soil parameters')
    try:
        saturation = [float(value.replace('D', 'e').replace('d', 'e')) for value in values[0].split()]
    except ValueError:
        raise ValueError('Invalid original RIA12 saturation parameters') from None
    layers = len(saturation)
    if not layers or any(not math.isfinite(value) or not 0 < value <= 1 for value in saturation) or len(models) not in (1, layers):
        raise ValueError('Foreign original RIA12 layer domain')
    table = re.search(r'(?mi)^\s*ISUBLAY\s+ISOILLAY\s+HSUBLAY\s+NCOMP\s*\n(.*?)^\* End of table', text, re.S)
    if table is None:
        raise ValueError('Missing original RIA12 soil geometry')
    physical_layers = {int(line.split('!')[0].split()[1]) for line in table[1].splitlines() if line.split('!')[0].strip()}
    if physical_layers != set(range(1, layers + 1)):
        raise ValueError('RIA12 parameter and physical layer counts differ')
    return dict(policy=POLICY, models=[12] * layers, kind='cde' if s['SWSOLU'] else 'water',
                nodes_domain='actual original grid', immutable_parameters_per_layer=11,
                physical_equations_changed=False, new_physical_state=False)


def metadata(project):
    selected = selection(project.input_directory, project.original_output)
    if selected is None:
        return None
    sha = lambda path: hashlib.sha256(path.read_bytes().replace(b'\r\n', b'\n')).hexdigest()
    return dict(**selected, native_codec=CODECS[selected['kind']].decode(), source_sha256=sha(Path(__file__)),
                native_provider_sha256=sha(PROVIDER), parameter_precision='actual original DoublePrec.DP')


def render_macro(text, project):
    selected = selection(project.input_directory, project.original_output)
    if selected is None:
        return text
    begin, end = '    subroutine hybrid_macro_checkpoint(', '    end subroutine hybrid_macro_checkpoint'
    if text.count(begin) != 1 or text.count(end) != 1:
        raise ValueError('Ambiguous original RIA12 native owner')
    low = text.index(begin)
    high = text.index(end, low) + len(end)
    body = text[low:high]
    anchor = '      use MOD_grid, only: numnod'
    if body.count(anchor) != 1:
        raise ValueError('Foreign original RIA12 grid owner')
    body = body.replace(anchor, '      use hybrid_original_ria12_native,only:ria12_domain_checkpoint\n' + anchor, 1)
    for restoring, anchor in (('.true.', '        read(unit,iostat=ios) trailing'), ('.false.', '      end if\n      close(unit)')):
        if body.count(anchor) != 1:
            raise ValueError('Foreign original RIA12 native closure')
        body = body.replace(anchor, '        call ria12_domain_checkpoint(unit,' + restoring + ')\n' + anchor, 1)
    return PROVIDER.read_text(encoding='cp1252') + '\n' + text[:low] + body + text[high:]
