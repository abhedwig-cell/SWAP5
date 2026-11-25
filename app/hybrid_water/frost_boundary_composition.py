"""Bounded existing Frost with original pressure-head and lysimeter boundaries."""
import hashlib
import re
from pathlib import Path

POLICY = 'original-frost-boundary58-dense-state-composition-v1'
FIXED = dict(SWMACRO=0, SWFROST=1, SWSNOW=1, SWHEA=1, SWCALT=2,
             SWSOPHY=0, SWDRA=1, SWBR=0, SWBBCFILE=0, SWMETDETAIL=0,
             SWHYST=2, SWINCO=2, NPRINTDAY=1, PERIOD=1, SWMONTH=0,
             SWODAT=0, SWRES=1, SWTOPBHEA=2)


def input_domain(selectors, boundary, original_output):
    return bool(original_output is not False
                and boundary.get('SWBOTB') in (5, 8)
                and not (boundary.get('SWBOTB')==8 and selectors.get('SWKIMPL')==1)
                and selectors.get('SWSOLU') in (0, 1)
                and selectors.get('SWKIMPL') in (0, 1)
                and all(selectors.get(key) == value for key, value in FIXED.items()
                        if key not in ('NPRINTDAY', 'PERIOD')))


def selection(directory, original_output=True):
    if not directory or original_output is False:
        return None
    from experimental_project import switches, one
    folder = Path(directory)
    text = (folder/'swap.swp').read_text(encoding='cp1252')
    selected = switches(text)
    if not input_domain(selected, selected, original_output):
        return None
    active = '\n'.join(line.split('!', 1)[0] for line in text.splitlines()
                       if not line.lstrip().startswith('*'))
    domains = {key: {value} for key, value in FIXED.items()}
    domains.update(SWBOTB={5, 8}, SWSOLU={0, 1}, SWKIMPL={0, 1})
    for key, domain in domains.items():
        values = re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)', active)
        if (len(values) != 1 or re.fullmatch(r'[+-]?[0-9]+[ \t]*', values[0]) is None
                or int(values[0]) not in domain):
            return None
    flags = re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^\r\n]*)', active)
    if len(flags) > 1 or flags and flags[0].strip().upper() not in ('.FALSE.', 'FALSE', '.F.', 'F'):
        return None
    if re.search(r'(?i)\bSWAP_SOILS_DB\b', active):
        return None
    models = re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)', active)
    rest = re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*', '', active)
    if (re.search(r'(?i)\bIHWCKMODEL\b', rest) or len(models) > 1
            or models and re.fullmatch(r'\+?0*1(?:[ \t]+\+?0*1)*[ \t]*', models[0]) is None):
        return None
    name = one(text, 'DRFIL', r"'[^']+'").strip("'")
    prefix = one(text, 'PATHDRAIN', r"'[^']*'").strip("'").strip()
    drain = folder/(prefix+name+'.dra')
    if not drain.is_file() or switches(drain.read_text(encoding='cp1252')).get('SWDIVD') != 1:
        return None
    return dict(policy=POLICY, bottom=selected['SWBOTB'], implicit=selected['SWKIMPL'],
                kind='cde' if selected['SWSOLU'] else 'water', hysteresis=2, initial=2,
                physical_equations_changed=False)


def codec(selected):
    return {('water', 0): b'S5FBW001', ('cde', 0): b'S5FBC001',
            ('water', 1): b'S5FBW002', ('cde', 1): b'S5FBC002'}[(selected['kind'], selected['implicit'])]


def metadata(project):
    selected = selection(project.input_directory, project.original_output)
    if selected is None:
        return None
    return dict(selected, source_sha256=hashlib.sha256(
        Path(__file__).read_bytes().replace(b'\r\n', b'\n')).hexdigest(),
        native_codec=codec(selected).decode())
