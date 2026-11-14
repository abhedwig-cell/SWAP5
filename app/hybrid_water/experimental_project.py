"""Explicit, source-bound input adapter for implemented no-macro process families.

This is experimental admission, never production or scientific qualification.
Original TTUTIL still owns numeric/physical input validation. This preflight
rejects process families whose day-state/ledger integration is not implemented.
"""
from datetime import date
import hashlib
import json
from pathlib import Path, PureWindowsPath
import re

MODEL = 'HYBRID_NOMACRO_WATER'
ROOT = Path(__file__).resolve().parents[2]
ASSIGN = re.compile(r'(?mi)^[ \t]*(SW\w+)[ \t]*=[ \t]*([^\s!]+)')


def switches(text):
    result = {}
    for name, value in ASSIGN.findall(text):
        name = name.upper()
        if name in result or not re.fullmatch(r'[+-]?\d+', value):
            raise ValueError('Ambiguous/noninteger process selector: '+name)
        result[name] = int(value)
    return result


def one(text, name, pattern):
    values = re.findall(r'(?mi)^[ \t]*'+name+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$', text)
    if len(values) != 1:
        raise ValueError('Missing/ambiguous original input: '+name)
    return values[0]


def inventory(directory):
    directory = Path(directory)
    paths = list(directory.rglob('*'))
    if not paths or any(p.is_symlink() for p in paths):
        raise ValueError('Experimental input must be a nonempty regular directory')
    # Relative original input folders are copied with the private worker.
    if any(not (p.is_file() or p.is_dir()) for p in paths):
        raise ValueError('Experimental project requires regular input files/directories')
    reserved = {'restart.end', 'macro-origin.bin', 'macro.bin', 'result.end', 'swap.ok', 'swap.err', 'hybrid-irrigation-day.in'}
    if any(p.name.lower() in reserved for p in paths):
        raise ValueError('Experimental input collides with a worker output/restart name')
    return tuple(sorted((p.relative_to(directory).as_posix(), hashlib.sha256(p.read_bytes()).hexdigest())
                        for p in paths if p.is_file()))


def check_paths(body, name):
    active = '\n'.join(line.split('!', 1)[0] for line in body.splitlines()
                       if line.strip() and not line.lstrip().startswith('*'))
    for token in re.findall(r"'([^'\n]*)'", active):
        path = PureWindowsPath(token)
        if path.drive or path.root or '..' in path.parts:
            raise ValueError('External/parent path in original input: '+name)


def crop_entries(text):
    return re.findall(r"(?m)^[ \t]*\d{4}-\d{2}-\d{2}[ \t]+\d{4}-\d{2}-\d{2}[ \t]+'([^'\n]+)'[ \t]+([12])[ \t]*(?:!.*)?$",text)


def inspect(directory):
    directory = Path(directory).resolve()
    inputs = inventory(directory)
    text = (directory/'swap.swp').read_text(encoding='cp1252')
    check_paths(text, 'swap.swp')
    selected = switches(text)
    crop_files=set();crop_types={}
    if selected.get('SWCROP')==1:
        entries=crop_entries(text)
        if not entries:raise ValueError('Missing/unsupported original crop rotation')
        for name,crop_type in entries:
            path=directory/(name if name.lower().endswith('.crp') else name+'.crp')
            if not path.is_file():raise ValueError('Missing original crop input: '+name)
            crop_files.add(path.resolve())
            crop_types.setdefault(path.resolve(),set()).add(int(crop_type))
    mandatory = {'SWMACRO': {0}, 'SWSOLU': {0, 1}, 'SWHYST': {0, 1, 2},
                 'SWSNOW': {0, 1}, 'SWFROST': {0}, 'SWHEA': {0, 1}, 'SWCALT': {1, 2},
                 'SWTOPBHEA': {1, 2, 3, 4}, 'SWBOTBHEA': {1, 2}, 'SWCROP': {0, 1},
                 'SWMETDETAIL': {0}, 'SWRUNON': {0}, 'SWKIMPL': {0},
                 'SWPONDMX': {0}, 'SWIRFIX': {0, 1}, 'SWCSV': {1}}
    mandatory.update(SWSOPHY={0, 1}, SWDRA={0, 1}, SWETR={0, 1},
                     SWDIVIDE={1}, SWRAIN={0, 2}, SWCFBS={0}, SWREDU={0, 1, 2},
                     SWKMEAN=set(range(1,7)), SWINCO={1, 2, 3}, SWBBCFILE={0, 1})
    for name, allowed in mandatory.items():
        if selected.get(name) not in allowed:
            raise ValueError('Unsupported experimental process/state: '+name)
    if selected['SWSOLU']:
        for name in ('SWSP', 'SWDC', 'SWBR'):
            if selected.get(name) not in ({0} if name == 'SWBR' else {0, 1}):
                raise ValueError('Solute ledger/state does not support '+name)
    if selected['SWIRFIX'] and selected.get('SWIRGFIL') != 0:
        raise ValueError('Experimental fixed irrigation must be embedded in SWP')

    originals = ROOT/'reference/swap-4.3.1/projects'
    roots = [originals/n for n in ('1.hupselbrook', '2.grassgrowth', '4.salinitystress-04dS')]
    allowed = {}
    for root in roots:
        for name, value in switches((root/'swap.swp').read_text(encoding='cp1252')).items():
            allowed.setdefault(name, set()).add(value)
    # Stateless original dispatches; complete original Fortran bodies are kept.
    # Other bottom variants (8/9), frost and stateful surfacewater remain
    # excluded until their complete process/state combinations are qualified.
    allowed.update(SWBOTB=set(range(1, 8)), SWDRA={0, 1}, SWSOPHY={0, 1},
                   SWETR={0, 1}, SWCROP={0, 1}, SWHYST={0, 1, 2}, SWSNOW={0, 1},
                   SWSP={0, 1}, SWDC={0, 1}, SWHEA={0, 1}, SWCALT={1,2},
                   SWTOPBHEA={1,2,3,4}, SWBOTBHEA={1,2}, SW2={1, 2}, SW3={1, 2},
                   SWKMEAN=set(range(1,7)), SWREDU={0,1,2})
    if not selected['SWSOLU'] and (selected['SWHYST'] or selected['SWSNOW']):
        raise ValueError('Water-only hydraulic/snow history requires complete original restart integration')
    if selected['SWSNOW'] and selected['SWHEA'] == 0:
        raise ValueError('Original snow requires soil heat transport')
    if selected['SWSNOW'] and selected['SWCALT'] != 2:
        raise ValueError('Snow requires numerical thermal history integration')
    if selected['SWHYST'] and selected['SWSOPHY'] != 0:
        raise ValueError('Original hysteresis requires the analytical hydraulic family')
    for name, value in selected.items():
        if value not in allowed.get(name, set()):
            raise ValueError('Unimplemented experimental selector: '+name+'='+str(value))
    if selected.get('SWBBCFILE') == 1:
        # Resolve the actual original boundary file, never assume swap.bbc.
        name = one(text, 'BBCFIL', r"'[^']+'").strip("'")
        boundary = switches((directory/(name if name.lower().endswith('.bbc') else name+'.bbc')).read_text(encoding='cp1252'))
    else:
        boundary = selected
    if boundary.get('SWBOTB') not in range(1, 8):
        raise ValueError('Unsupported/missing original lower boundary')
    if selected['SWSOLU'] and boundary['SWBOTB'] in (1, 5):
        raise ValueError('Reconstructed bottom flux requires a separate strict substep receipt')
    for name, value in boundary.items():
        if value not in allowed.get(name, set()):
            raise ValueError('Unsupported boundary selector: '+name)

    crop_signatures = [switches(p.read_text(encoding='cp1252')) for root in roots for p in root.glob('*.crp')]
    root_controls={'SWINTER':{0,1,2,3},'SWOXYGEN':{0,1,2},'SWDROUGHT':{1,2,3},
                   'SWSALINITY':{0,1},'SWCOMPENSATE':{0,1,2},'SWWRTNONOX':{0,1}}
    structure=lambda sig:{k:v for k,v in sig.items() if k not in root_controls}
    crop_structures=list(map(structure,crop_signatures))
    drain_signatures = [switches(p.read_text(encoding='cp1252')) for root in roots for p in root.glob('*.dra')]
    for path in directory.rglob('*'):
        if path.suffix.lower() not in ('.swp', '.crp', '.dra', '.bbc', '.ini'):
            continue
        body = path.read_text(encoding='cp1252')
        check_paths(body, path.name)
        sig = switches(body)
        if path.suffix.lower() == '.crp':
            # An unused file remains hash-bound input data, but cannot activate
            # a process. Validate the actual complete future rotation instead.
            if path.resolve() not in crop_files:continue
            schedule = one(body, 'SCHEDULE', r'[+-]?\d+')
            if schedule not in ('0','1'):
                raise ValueError('Unsupported original irrigation schedule')
            if structure(sig) not in crop_structures or any(sig.get(k) not in values for k,values in root_controls.items()):
                raise ValueError('Crop process/state combination is not implemented: '+path.name)
            if sig['SWDROUGHT']>1 and sig['SWCOMPENSATE']>0:
                raise ValueError('Original microscopic root uptake cannot be combined with additional compensation')
            if sig.get('SWINTER')==2 and crop_types[path.resolve()] != {1}:
                raise ValueError('Original Gash interception requires simple crop type1 for every referenced occurrence')
            if not selected['SWSOLU'] and sig.get('SWSALINITY')==1:
                raise ValueError('Original salinity stress requires active solute transport')
            if selected['SWCROP'] and sig.get('SWOXYGEN')==2 and (selected['SWHEA']!=1 or selected['SWCALT']!=2):
                raise ValueError('Original physical oxygen stress requires numerical soil heat for every future crop')
        if path.suffix.lower() == '.dra' and sig not in drain_signatures:
            raise ValueError('Drainage process/state combination is not implemented: '+path.name)
        if path.suffix.lower() == '.dra':
            if one(body, 'DRAMET', r'[+-]?\d+') not in ('2', '3'):
                raise ValueError('Unqualified drainage method')
        if path.suffix.lower() == '.crp' and schedule == '1':
            if one(body, 'ISUAS', r'[+-]?\d+') not in ('0', '1'):
                raise ValueError('Subsurface scheduled irrigation is not integrated')
    start = one(text, 'TSTART', r'\d{4}-\d{2}-\d{2}')
    end = one(text, 'TEND', r'\d{4}-\d{2}-\d{2}')
    if date.fromisoformat(end) < date.fromisoformat(start):
        raise ValueError('Invalid original project period')
    table = re.findall(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)', text)
    if len(table) != 1:
        raise ValueError('Missing/ambiguous original grid')
    rows = [line.split() for line in table[0].splitlines()]
    if any(len(row) != 4 or not row[3].isdigit() or int(row[3]) < 1 for row in rows):
        raise ValueError('Invalid original grid row')
    nodes = sum(int(row[3]) for row in rows)
    if not 1 <= nodes <= 1000:
        raise ValueError('Unsupported original grid size')
    return dict(inputs=inputs, start_date=start, end_date=end, nodes=nodes,
                solute=bool(selected['SWSOLU']), selectors=selected, boundary=boundary)


def load(directory, *, time_step_policy=None, solute_step_policy=None, soil_table_policy=None):
    from daily_host import HybridProject, ORIGINAL_TIME_POLICY, TIME_POLICIES
    from solute_step_policy import LEGACY_SOLUTE_STEP_POLICY, SOLUTE_STEP_POLICIES
    policy=ORIGINAL_TIME_POLICY if time_step_policy is None else time_step_policy
    if policy not in TIME_POLICIES:raise ValueError("Unknown experimental time-step policy")
    chemical=LEGACY_SOLUTE_STEP_POLICY if solute_step_policy is None else solute_step_policy
    if chemical not in SOLUTE_STEP_POLICIES:raise ValueError('Unknown experimental chemical substep policy')
    report = inspect(directory)
    from daily_host import ORIGINAL_SOIL_TABLE_POLICY, SOIL_TABLE_POLICIES
    soil=ORIGINAL_SOIL_TABLE_POLICY if soil_table_policy is None else soil_table_policy
    if soil not in SOIL_TABLE_POLICIES:raise ValueError('Unknown original soil-table interpolation policy')
    if soil!=ORIGINAL_SOIL_TABLE_POLICY and report['selectors']['SWSOPHY']!=1:
        raise ValueError('Soil-table policy requires active SWSOPHY1')
    if chemical!=LEGACY_SOLUTE_STEP_POLICY and not report['solute']:
        raise ValueError('Chemical substep policy requires active SWSOLU1')
    key = hashlib.sha256(json.dumps(report, sort_keys=True).encode()).hexdigest()
    return HybridProject('experimental-'+key, MODEL, report['start_date'], report['nodes'], 1e-10,
                         solute=report['solute'], end_date=report['end_date'],
                         input_directory=str(Path(directory).resolve()), input_inventory=report['inputs'],time_step_policy=policy,solute_step_policy=chemical,soil_table_policy=soil)


def validate(project):
    if not project.input_directory or load(project.input_directory,time_step_policy=project.time_step_policy,solute_step_policy=project.solute_step_policy,soil_table_policy=project.soil_table_policy) != project:
        raise ValueError('Experimental input, process configuration or metadata differs')
    return Path(project.input_directory)


def auxiliary_magic(project):
    selected = inspect(project.input_directory)['selectors']
    history = int(selected['SWHYST']>0)+2*selected['SWSNOW']
    formats = (b'S5HUP012',b'S5SHS013',b'S5SSN014',b'S5SMX015') if project.solute else (
               b'S5WAT007',b'S5WHS008',b'S5WSN009',b'S5WMX010')
    return formats[history]
