"""Immutable original implicit-conductivity policy; no physical equations."""
import hashlib
import math
from pathlib import Path
import re

POLICY = 'original-headcalc-implicit-mualem-strict-retry-v1'


def selection(text, selectors, boundary):
    if selectors['SWKIMPL'] == 0:
        return None
    required = dict(SWMACRO=0, SWSOPHY=0, SWSNOW=0, SWFROST=0,
                    SWHEA=1, SWCALT=2, SWMETDETAIL=0)
    if (selectors['SWKIMPL'] != 1 or any(selectors.get(k) != v for k, v in required.items())
            or selectors.get('SWBR', 0) != 0 or boundary['SWBOTB'] not in (1, 5, 8)):
        raise ValueError('Original implicit conductivity requires bounded analytical daily no-snow/no-frost/no-aquifer inputs')
    active = '\n'.join(line.split('!', 1)[0].strip() for line in text.splitlines()
                       if line.strip() and not line.lstrip().startswith('*'))
    if selectors['SWSOLU']==0 and boundary['SWBOTB']==1:
        steps=re.findall(r'(?mi)^FLPRINTDT[ \t]*=[ \t]*([^\r\n]+)',active)
        prints=re.findall(r'(?mi)^NPRINTDAY[ \t]*=[ \t]*([+-]?\d+)[ \t]*$',active)
        if (len(steps)>1 or steps and steps[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F')
                or prints!=['1']):
            raise ValueError('Implicit water groundwater subdaily output requires separate original trial-calendar composition')
    if re.search(r'(?i)\bSWAP_SOILS_DB\b', active):
        raise ValueError('Implicit conductivity soil database requires separate parameter-domain qualification')
    models = re.findall(r'(?mi)^IHWCKMODEL\s*=\s*(.*)$', active)
    remainder = re.sub(r'(?mi)^IHWCKMODEL\s*=\s*[^\r\n]*$', '', active)
    if (re.search(r'(?i)\bIHWCKMODEL\b', remainder) or len(models) > 1
            or models and not re.fullmatch(r'1(?:[ \t]+1)*[ \t]*', models[0])):
        raise ValueError('Original implicit conductivity requires default Mualem model1')
    # Read the actual original named parameter table. Original TTUTIL remains
    # authoritative for numeric ranges; this guard excludes its unsupported
    # examined-Ksat derivative branch before starting a worker.
    tables = re.findall(r'(?mi)^\s*(ORES\s+OSAT[^\r\n]*)\r?\n((?:\s*[+\-.\d][^\r\n]*\r?\n)+)', active+'\n')
    if len(tables) != 1:
        raise ValueError('Implicit conductivity requires one explicit original Mualem parameter table')
    header, body = tables[0]
    names = header.upper().split()
    if len(set(names)) != len(names) or not {'ORES','OSAT','ALFA','ALFAW','NPAR','LEXP','H_ENPR'} <= set(names):
        raise ValueError('Ambiguous implicit conductivity parameter columns')
    fitted = 'KSATFIT' if 'KSATFIT' in names else 'KSAT'
    if fitted not in names:
        raise ValueError('Missing original fitted conductivity')
    rows = []
    for line in body.splitlines():
        values = [float(v.replace('D','e').replace('d','e')) for v in line.split()]
        if len(values) != len(names) or not all(math.isfinite(v) for v in values):
            raise ValueError('Invalid implicit conductivity parameter row')
        row = dict(zip(names, values))
        if 'KSATEXM' in row and row['KSATEXM'] > row[fitted]:
            raise ValueError('Original implicit derivative does not implement examined-Ksat interpolation')
        rows.append(row)
    if not rows:
        raise ValueError('Missing implicit conductivity parameter rows')
    return dict(policy=POLICY, SWKIMPL=1, SWKMEAN=selectors['SWKMEAN'],
                hydraulic_model=1, original_parameter_rows=rows,
                examined_ksat_interpolation=False, physical_state_owner='existing-selected-owner',
                newton_failure_policy='original-implicit-nonconverged-trial-retry-v1',
                dtmin_retry_policy='below-input-minimum-only-after-actual-nonconvergence',clock_ulp_floor=8)


def metadata(project):
    if not project.input_directory:
        return None
    from experimental_project import inspect
    selected = inspect(project.input_directory).get('implicit_conductivity')
    if selected is None:
        return None
    return dict(selected, source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
