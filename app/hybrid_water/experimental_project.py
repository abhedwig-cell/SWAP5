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


def inspect(directory, *, original_output=None):
    """Describe physical inputs; load() selects the executable output contract.

    None is descriptor-only and exposes original output selectors to process
    helpers. Executions must select False (compatibility) or True (original).
    """
    directory = Path(directory).resolve()
    inputs = inventory(directory)
    text = (directory/'swap.swp').read_text(encoding='cp1252')
    check_paths(text, 'swap.swp')
    selected = switches(text)
    from original_ria12 import selection as ria12_selection
    from original_ria12_boundary import selection as ria12_boundary_selection
    from original_ria12_thermal import selection as ria12_thermal_selection
    from original_ria12_corrected import selection as ria12_corrected_selection
    ria12 = ria12_thermal_selection(directory, original_output) or ria12_corrected_selection(directory, original_output) or ria12_boundary_selection(directory, original_output) or ria12_selection(directory, original_output)
    # Descriptor-only helper calls accept the historical output domain. Actual
    # executions use load() with an explicit compatibility/original choice.
    if original_output is not False and 'SWCSV' not in selected:selected['SWCSV']=0
    from hydraulic_vapor import selection as vapor_selection
    vapor_selection(directory,selected,original_output)
    hydraulic_rows=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^!\r\n]+)',text)
    original_model3=any(int(token)==3 for row in hydraulic_rows for token in row.split() if re.fullmatch(r'[+-]?\d+',token))
    crop_files=set();crop_types={}
    if selected.get('SWCROP')==1:
        entries=crop_entries(text)
        if not entries:raise ValueError('Missing/unsupported original crop rotation')
        for name,crop_type in entries:
            path=directory/(name if name.lower().endswith('.crp') else name+'.crp')
            if not path.is_file():raise ValueError('Missing original crop input: '+name)
            crop_files.add(path.resolve())
            crop_types.setdefault(path.resolve(),set()).add(int(crop_type))
    mandatory = {'SWMACRO': {0}, 'SWSOLU': {0, 1, 2}, 'SWHYST': {0, 1, 2},
                 'SWSNOW': {0, 1}, 'SWFROST': {0, 1}, 'SWHEA': {0, 1}, 'SWCALT': {1, 2},
                 'SWTOPBHEA': {1, 2, 3, 4}, 'SWBOTBHEA': {1, 2}, 'SWCROP': {0, 1},
                 'SWMETDETAIL': {0,1}, 'SWRUNON': {0,1}, 'SWKIMPL': {0,1},
                 'SWPONDMX': {0,1}, 'SWIRFIX': {0, 1}, 'SWCSV': ({1} if original_output is False else {0,1,2,3})}
    mandatory.update(SWSOPHY={0, 1}, SWDRA={0, 1}, SWETR={0, 1},
                     SWDIVIDE={0,1}, SWRAIN={0,1,2,3}, SWCFBS={0,1}, SWREDU={0, 1, 2},
                     SWKMEAN=set(range(1,7)), SWINCO={1, 2, 3}, SWBBCFILE={0, 1})
    from extended_drainage import describe as describe_extended_drainage
    extended=describe_extended_drainage(directory,selected,original_output)
    if extended is not None:mandatory['SWDRA']={2}
    for name, allowed in mandatory.items():
        if selected.get(name) not in allowed:
            raise ValueError('Unsupported experimental process/state: '+name)
    if selected['SWSOLU']==2 and (selected['SWSNOW'] or selected.get('SWBR')!=0):
        raise ValueError('Original age qualification currently requires no snow/aquifer')
    if selected['SWSOLU']==1:
        for name in ('SWSP', 'SWDC', 'SWBR'):
            if selected.get(name) not in {0, 1}:
                raise ValueError('Solute ledger/state does not support '+name)
    if selected['SWIRFIX'] and selected.get('SWIRGFIL') not in (0,1):
        raise ValueError('Unsupported/missing original fixed irrigation input selector')
    if selected['SWETR']==1 and (selected['SWMETDETAIL'] or selected['SWDIVIDE']):
        raise ValueError('Original prescribed reference ET requires daily weather and factor partition0')
    if selected['SWMETDETAIL'] and (selected['SWETR'] or selected['SWRAIN'] or selected['SWSNOW']):
        raise ValueError('Original detailed weather requires ET0, rain0 and no snow')

    originals = ROOT/'reference/swap-4.3.1/projects'
    roots = [originals/n for n in ('1.hupselbrook', '2.grassgrowth', '4.salinitystress-04dS')]
    allowed = {}
    for root in roots:
        for name, value in switches((root/'swap.swp').read_text(encoding='cp1252')).items():
            allowed.setdefault(name, set()).add(value)
    # Original dispatches and their explicit process/state adapters. Additional
    # coupling domains remain excluded until their owning contracts are present.
    allowed.update(SWSOLU={0,1,2}, SWBOTB=set(range(1, 9)), SWDRA={0, 1}, SWSOPHY={0, 1},
                   SWETR={0, 1}, SWCROP={0, 1}, SWHYST={0, 1, 2}, SWSNOW={0, 1},
                   SWSP={0, 1}, SWDC={0, 1}, SWBR={0,1}, SWHEA={0, 1}, SWCALT={1,2},
                   SWTOPBHEA={1,2,3,4}, SWBOTBHEA={1,2}, SW2={1, 2}, SW3={1, 2},
                   SWKIMPL={0,1}, SWKMEAN=set(range(1,7)), SWREDU={0,1,2},
                   SWMETDETAIL={0,1}, SWDIVIDE={0,1}, SWRAIN={0,1,2,3}, SWCFBS={0,1}, SWVAPOR={0,1},
                   SWRUNON={0,1}, SWPONDMX={0,1}, SWIRGFIL={0,1}, SWFROST={0,1})
    from prescribed_head_flux_boundary import selection as paired_boundary_selection
    paired_boundary=paired_boundary_selection(directory,original_output)
    if paired_boundary is None:
        from prescribed_history_boundary import selection as paired_history_selection
        paired_boundary=paired_history_selection(directory,original_output)
    if paired_boundary is None:
        from prescribed_snow_boundary import selection as snow_paired_selection
        paired_boundary=snow_paired_selection(directory,original_output)
    if paired_boundary is not None:allowed['SWBOTB'].add(9)
    if extended is not None:allowed['SWDRA']={2}
    if selected.get('SWINCO') == 1:
        # Original HTB and legacy ZI/H already initialize the real SoilWater
        # state. Select only the bounded unchanged-process composition; the
        # original reader still owns table ordering, bounds and saturation.
        domain={'SWMACRO':{0},'SWSOLU':{0,1},'SWHYST':{0,1,2},'SWSNOW':{0,1},
                'SWFROST':{0},'SWHEA':{1},'SWCALT':{2},'SWKIMPL':{0,1},
                'SWDRA':{0,1},'SWBOTB':{5,6,8},'SWBBCFILE':{0},
                'SWMETDETAIL':{0},'SWBR':{0}}
        from initial_profile_frost import selection as initial_frost_selection
        initial_frost=initial_frost_selection(directory,original_output)
        from initial_profile_age import selection as initial_age_selection
        initial_age=initial_age_selection(directory,original_output)
        from initial_profile_groundwater import selection as initial_groundwater_selection
        initial_groundwater=initial_groundwater_selection(directory,original_output)
        if (original_output is False or any(selected.get(key) not in values for key,values in domain.items())) and initial_frost is None and initial_age is None and initial_groundwater is None and paired_boundary is None and ria12 is None:
            raise ValueError('Original pressure-profile initialization requires bounded daily water/CDE without Frost/aquifer')
        history,snow,implicit=selected['SWHYST'],selected['SWSNOW'],selected['SWKIMPL']
        boundary_pair=(selected['SWDRA'],selected['SWBOTB'])
        if history:state_supported=not snow and not implicit and boundary_pair==(1,6)
        elif snow:state_supported=boundary_pair==((1,5) if implicit else (1,6))
        elif implicit:state_supported=boundary_pair==(1,5)
        else:state_supported=True
        from initial_profile_calendar import selection as initial_calendar_selection
        initial_calendar=initial_calendar_selection(directory,original_output)
        from analytical_snow_undrained import selection as initial_analytical_snow_selection
        initial_analytical_snow=initial_analytical_snow_selection(directory,original_output)
        if not state_supported and initial_calendar is None and initial_frost is None and initial_groundwater is None and paired_boundary is None and initial_analytical_snow is None:
            raise ValueError('Unqualified original pressure-profile state-owner cross composition')
        flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
        if (int(one(text,'NPRINTDAY',r'[+-]?\d+'))!=1 or int(one(text,'PERIOD',r'[+-]?\d+'))!=1
                or selected.get('SWMONTH')!=0 or selected.get('SWODAT')!=0 or selected.get('SWRES')!=1
                or len(flags)>1 or flags and flags[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F')) and initial_calendar is None and initial_age is None and initial_groundwater is None and paired_boundary is None and initial_analytical_snow is None:
            raise ValueError('Original pressure-profile initialization requires dense original daily output')
        allowed['SWINCO']={1,2,3}
    if (selected['SWSOLU']==2 and selected.get('SWMONTH')==0 and selected.get('SWODAT')==0
            and int(one(text,'PERIOD',r'[+-]?\d+'))>1
            and int(one(text,'NPRINTDAY',r'[+-]?\d+'))==1):
        allowed['SWRES']={0,1} # explicit regular age output/calendar owner
    if (selected['SWSOLU']==2 and int(one(text,'NPRINTDAY',r'[+-]?\d+'))==1
            and (selected.get('SWMONTH')==1 or selected.get('SWODAT')==1)):
        allowed.update(SWMONTH={0,1},SWODAT={0,1},SWRES={0,1})
    if (selected['SWSOLU']==2 and selected.get('SWMONTH')==0 and selected.get('SWODAT')==0
            and (int(one(text,'NPRINTDAY',r'[+-]?\d+'))>1 or int(one(text,'PERIOD',r'[+-]?\d+'))==0)):
        allowed['SWRES']={0,1}
    if selected['SWSNOW'] and selected['SWHEA'] == 0:
        raise ValueError('Original snow requires soil heat transport')
    frost_drain_file=None
    if selected['SWFROST']:
        from frost_hysteresis_composition import selection as frost_history_selection
        frost_history=frost_history_selection(directory,original_output)
        if (selected['SWHEA']!=1 or selected['SWCALT']!=2 or selected['SWSNOW']!=1
                or selected['SWHYST']!=2 and frost_history is None):
            raise ValueError('Bounded original frost requires numeric heat, snow, hysteresis2 and SWDIVD0')
        if selected['SWDRA']==1:
            # The original reader owns SWDIVD in DRFIL.dra, not the main deck.
            name=one(text,'DRFIL',r"'[^']+'").strip("'")
            prefix=one(text,'PATHDRAIN',r"'[^']*'").strip("'").strip()
            frost_drain_file=(directory/(prefix+name+'.dra')).resolve()
            if not frost_drain_file.is_file():raise ValueError('Missing original frost drainage input')
            frost_divd=switches(frost_drain_file.read_text(encoding='cp1252')).get('SWDIVD')
            if frost_divd==1:
                if (original_output is False or selected['SWKIMPL'] not in (0,1) or selected['SWSOLU'] not in (0,1)
                        or selected.get('SWBR')!=0 or selected['SWMETDETAIL']!=0 or selected['SWSOPHY']!=0):
                    raise ValueError('Candidate Frost SWDIVD1 requires bounded original daily analytical water/CDE without aquifer')
            elif frost_divd!=0:
                raise ValueError('Invalid original Frost vertical drainage selector')
            elif selected['SWKIMPL'] == 1:
                raise ValueError('Candidate implicit Frost requires effective SWDIVD1')
            if selected['SWSOLU'] and frost_divd==0:
                raise ValueError('Original drainage reader refuses SWDIVD0 with solute transport')
        limits=[]
        for name in ('TFROSTSTA','TFROSTEND'):
            values=re.findall(r'(?mi)^[ \t]*'+name+r'[ \t]*=[ \t]*([^!\r\n]+)',text)
            if len(values)!=1:raise ValueError('Missing/ambiguous original frost limit')
            try:value=float(values[0].strip().replace('D','e').replace('d','e'))
            except ValueError:raise ValueError('Invalid original frost limit') from None
            if not -10<=value<=5:raise ValueError('Nonfinite/outside original frost limit')
            limits.append(value)
        if limits[0]<=limits[1]:raise ValueError('Unordered original frost temperature limits')
    if selected['SWSNOW'] and selected['SWCALT'] != 2:
        raise ValueError('Snow requires numerical thermal history integration')
    if selected['SWHYST'] and selected['SWSOPHY'] != 0:
        raise ValueError('Original hysteresis requires the analytical hydraulic family')
    if original_output is not False:allowed.update(SWCSV={0,1,2,3},SWMONTH={0,1},SWODAT={0,1},SWRES={0,1})
    for name, value in selected.items():
        if value not in allowed.get(name, set()):
            raise ValueError('Unimplemented experimental selector: '+name+'='+str(value))
    if selected.get('SWBBCFILE') == 1:
        # Resolve the actual original boundary file, never assume swap.bbc.
        name = one(text, 'BBCFIL', r"'[^']+'").strip("'")
        boundary = switches((directory/(name if name.lower().endswith('.bbc') else name+'.bbc')).read_text(encoding='cp1252'))
    else:
        boundary = selected
    if boundary.get('SWBOTB') not in range(1, 9) and paired_boundary is None:
        raise ValueError('Unsupported/missing original lower boundary')
    if selected['SWFROST']:
        expected_bottom=7 if selected['SWDRA']==0 else 6
        if boundary['SWBOTB']!=expected_bottom or selected['SWTOPBHEA']!=2:
            raise ValueError('Bounded frost qualification requires prescribed surface temperature and free bottom7 or drained bottom6')
    if selected['SWSOLU'] and boundary['SWBOTB']==1:
        age_groundwater=(original_output is not False and selected['SWSOLU']==2
                         and selected['SWSNOW']==0 and selected['SWHEA']==1
                         and selected['SWCALT']==2)
        if ((selected['SWSOLU']!=1 and not age_groundwater) or selected['SWSOPHY']!=0
                or selected['SWFROST']!=0 or selected['SWBR']!=0
                or selected['SWMETDETAIL']!=0):
            raise ValueError('Prescribed groundwater CDE trial receipt requires analytical daily no-frost/no-aquifer process history')
    for name, value in boundary.items():
        if value not in allowed.get(name, set()):
            raise ValueError('Unsupported boundary selector: '+name)

    crop_signatures = [switches(p.read_text(encoding='cp1252')) for root in roots for p in root.glob('*.crp')]
    root_controls={'SWINTER':{0,1,2,3},'SWOXYGEN':{0,1,2},'SWDROUGHT':{1,2,3},
                   'SWSALINITY':{0,1},'SWCOMPENSATE':{0,1,2},'SWWRTNONOX':{0,1},'SWCF':{1,2}}
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
            if selected['SWFROST'] and sig['SWDROUGHT']!=1:
                raise ValueError('Original microscopic root extraction does not implement frost: '+path.name)
            if sig['SWDROUGHT']>1 and sig['SWCOMPENSATE']>0:
                raise ValueError('Original microscopic root uptake cannot be combined with additional compensation')
            if sig.get('SWINTER')==2 and crop_types[path.resolve()] != {1}:
                raise ValueError('Original Gash interception requires simple crop type1 for every referenced occurrence')
            if (selected['SWMETDETAIL'] or selected['SWRAIN']==3) and sig.get('SWINTER') in (1,2):
                raise ValueError('Original detailed weather/rain cannot use interception1/2 in any future crop')
            if selected['SWETR']==1 and sig.get('SWCF')!=1:
                raise ValueError('Original prescribed reference ET requires crop factors1 for every referenced future crop')
            if selected['SWSOLU']!=1 and sig.get('SWSALINITY')==1:
                raise ValueError('Original salinity stress requires active solute transport')
            if selected['SWCROP'] and sig.get('SWOXYGEN')==2 and (selected['SWHEA']!=1 or selected['SWCALT']!=2):
                raise ValueError('Original physical oxygen stress requires numerical soil heat for every future crop')
            if selected['SWSOPHY']==0 and original_model3 and sig.get('SWOXYGEN')==2:
                raise ValueError('Original hydraulic model3 with physical oxygen stress2 is explicitly not implemented: '+path.name)
        if extended is not None and path.resolve()==(directory/extended['file']).resolve():continue
        if path.suffix.lower() == '.dra' and sig not in drain_signatures:
            original_structure=lambda s:{k:v for k,v in s.items() if k!='SWDIVD'}
            paired_last_node_water=(paired_boundary is not None and selected['SWSOLU']==0
                and selected['SWDRA']==1 and sig.get('SWDIVD')==0
                and path.resolve()==(directory/(one(text,'PATHDRAIN',r"'[^']*'").strip("'").strip()
                    +one(text,'DRFIL',r"'[^']+'").strip("'")+'.dra')).resolve())
            if ((path.resolve()!=frost_drain_file and not paired_last_node_water) or sig.get('SWDIVD') not in (0,1)
                    or original_structure(sig) not in list(map(original_structure,drain_signatures))):
                raise ValueError('Drainage process/state combination is not implemented: '+path.name)
        if path.suffix.lower() == '.dra':
            if one(body, 'DRAMET', r'[+-]?\d+') not in ('1', '2', '3'):
                raise ValueError('Unqualified drainage method')
        if path.suffix.lower() == '.crp' and schedule == '1':
            method = one(body, 'ISUAS', r'[+-]?\d+')
            if method not in ('0', '1', '2'):
                raise ValueError('Unsupported original scheduled irrigation method')
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
    report=dict(inputs=inputs, start_date=start, end_date=end, nodes=nodes,
                solute=selected['SWSOLU']==1, selectors=selected, boundary=boundary)
    if extended is not None:report['extended_drainage']=extended
    if selected['SWSOLU']==2:report['age']=True
    from implicit_conductivity import selection as implicit_selection
    implicit = implicit_selection(text, selected, boundary,original_output=original_output)
    if implicit is not None:report['implicit_conductivity']=implicit
    return report


def load(directory, *, time_step_policy=None, solute_step_policy=None, soil_table_policy=None, water_polish_policy=None, original_output=False, age_irrigation_source=False, age_direct_soil_source=False):
    from daily_host import HybridProject, ORIGINAL_TIME_POLICY, TIME_POLICIES
    from solute_step_policy import LEGACY_SOLUTE_STEP_POLICY, SOLUTE_STEP_POLICIES
    policy=ORIGINAL_TIME_POLICY if time_step_policy is None else time_step_policy
    if policy not in TIME_POLICIES:raise ValueError("Unknown experimental time-step policy")
    chemical=LEGACY_SOLUTE_STEP_POLICY if solute_step_policy is None else solute_step_policy
    if chemical not in SOLUTE_STEP_POLICIES:raise ValueError('Unknown experimental chemical substep policy')
    if not isinstance(original_output,bool):raise ValueError('Original output mode must be boolean')
    if not isinstance(age_irrigation_source,bool):raise ValueError('Fixed age source mode must be boolean')
    if not isinstance(age_direct_soil_source,bool):raise ValueError('Direct soil age source mode must be boolean')
    if age_direct_soil_source and age_irrigation_source:raise ValueError('Select one explicit incoming-age source policy')
    if age_irrigation_source or age_direct_soil_source:
        from initial_profile_age import selection as initial_age_selection
        if initial_age_selection(directory,original_output) is not None:
            raise ValueError('Original pressure AGE qualification excludes explicit incoming-age source policies')
    report = inspect(directory,original_output=original_output)
    if report.get('extended_drainage',{}).get('swhyst') and not original_output:
        raise ValueError('Extended drainage hydraulic history requires explicit original-output state')
    if report.get('implicit_conductivity') and not original_output:
        raise ValueError('Original implicit conductivity requires explicit --original-output daily trial and state qualification')
    from time_event_closure import POLICY as EVENT_POLICY
    implicit_frost = report.get('implicit_conductivity', {}).get('implicit_frost_composition', False)
    implicit_policy = EVENT_POLICY if implicit_frost else ORIGINAL_TIME_POLICY
    if report.get('implicit_conductivity') and policy!=implicit_policy:
        raise ValueError('Original implicit conductivity requires the original time-step policy')
    if report.get('age') and report['boundary']['SWBOTB']==1 and (age_irrigation_source or age_direct_soil_source):
        raise ValueError('Original AGE groundwater currently requires historical young-water source policy')
    if original_output:report={**report,'original_output_policy':'original-user-output-controls-v1'}
    else:
        text=(Path(directory)/'swap.swp').read_text(encoding='cp1252')
        flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
        if len(flags)>1 or flags and flags[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F'):
            raise ValueError('FLPRINTDT requires separately selected --original-output state qualification')
    from irrigation_pulse_time import POLICY as PULSE_POLICY
    from local_wetting_time import POLICY as WETTING_POLICY
    if policy==WETTING_POLICY and (report['selectors']['SWFROST']!=0 or report['selectors']['SWSNOW']!=0):
        raise ValueError('Local wetting policy requires absent frost/snow')
    if policy==PULSE_POLICY and (report['selectors']['SWFROST']!=0 or report['selectors']['SWSNOW']!=0 or report['selectors']['SWIRFIX']!=1):
        raise ValueError('Irrigation pulse policy requires fixed irrigation without frost/snow')
    drained_frost = report['selectors']['SWFROST']==1 and report['selectors']['SWDRA']==1
    if drained_frost and policy != EVENT_POLICY:
        raise ValueError('Integrated frost drainage requires explicit corrected TimeControl event closure')
    if policy == EVENT_POLICY and not drained_frost:
        raise ValueError('Corrected event closure is bounded to original water frost drainage')
    from daily_host import ORIGINAL_SOIL_TABLE_POLICY, SOIL_TABLE_POLICIES
    soil=ORIGINAL_SOIL_TABLE_POLICY if soil_table_policy is None else soil_table_policy
    if soil not in SOIL_TABLE_POLICIES:raise ValueError('Unknown original soil-table interpolation policy')
    if soil!=ORIGINAL_SOIL_TABLE_POLICY and report['selectors']['SWSOPHY']!=1:
        raise ValueError('Soil-table policy requires active SWSOPHY1')
    if chemical!=LEGACY_SOLUTE_STEP_POLICY and not report['solute']:
        raise ValueError('Chemical substep policy requires active SWSOLU1')
    if age_irrigation_source:report={**report,'age_irrigation_source_policy':'original-fixed-current-irrigation-age-days-v1'}
    if age_direct_soil_source:report={**report,'age_direct_soil_source_policy':'original-fixed-direct-soil-age-transport-then-input-v1'}
    from daily_host import ALWAYS_WATER_POLISH, RIA12_WATER_POLISH
    polish = ALWAYS_WATER_POLISH if water_polish_policy is None else water_polish_policy
    if polish not in (ALWAYS_WATER_POLISH, RIA12_WATER_POLISH):
        raise ValueError('Unknown experimental water polishing policy')
    if polish == RIA12_WATER_POLISH:
        from ria12_water_polish import selection as polish_selection
        polish_selection(directory, original_output)
        from ria12_water_polish import TIME_POLICY as RIA_POLISH_TIME_POLICY
        if policy != RIA_POLISH_TIME_POLICY:
            raise ValueError('RIA water polishing requires physical-iteration growth v2')
    key = hashlib.sha256(json.dumps(report, sort_keys=True).encode()).hexdigest()
    project=HybridProject('experimental-'+key, MODEL, report['start_date'], report['nodes'], 1e-10,
                         solute=report['solute'], age=report.get('age',False), end_date=report['end_date'],
                         input_directory=str(Path(directory).resolve()), input_inventory=report['inputs'],time_step_policy=policy,solute_step_policy=chemical,soil_table_policy=soil,original_output=original_output,age_irrigation_source=age_irrigation_source,age_direct_soil_source=age_direct_soil_source,water_polish_policy=polish)
    if age_irrigation_source or age_direct_soil_source:
        from age_direct_soil_source import selection
        selection(project)
    return project


def validate(project):
    if not project.input_directory or load(project.input_directory,time_step_policy=project.time_step_policy,solute_step_policy=project.solute_step_policy,soil_table_policy=project.soil_table_policy,water_polish_policy=project.water_polish_policy,original_output=project.original_output,age_irrigation_source=project.age_irrigation_source,age_direct_soil_source=project.age_direct_soil_source) != project:
        raise ValueError('Experimental input, process configuration or metadata differs')
    return Path(project.input_directory)


def auxiliary_magic(project):
    from snow_undrained import selection as undrained_selection,codec as undrained_codec
    undrained=undrained_selection(project)
    if undrained is not None:return undrained_codec(undrained)
    from extended_drainage import enabled as extended_drainage_enabled,magic as extended_drainage_magic
    if extended_drainage_enabled(project):return extended_drainage_magic(project)
    from weather_root_state import enabled as weather_root_enabled,MAGIC as WEATHER_ROOT_MAGIC
    if weather_root_enabled(project):return WEATHER_ROOT_MAGIC
    from implicit_groundwater_state import enabled as implicit_groundwater,magic as implicit_magic
    if implicit_groundwater(project):return implicit_magic(project)
    from age_groundwater_output import native_enabled as groundwater_native,native_magic as groundwater_magic
    if groundwater_native(project):return groundwater_magic(project)
    from age_groundwater_output import selection as thermal_output,magic as thermal_output_magic
    if thermal_output(project) is not None:return thermal_output_magic(project)
    from original_output_aquifer import selection as aquifer_output,magic as aquifer_output_magic
    if aquifer_output(project) is not None:return aquifer_output_magic(project)
    from age_direct_soil_source import enabled as direct_age_source,magic as direct_age_magic
    if direct_age_source(project):return direct_age_magic(project)
    from age_irrigation_source import enabled as current_age_source,magic as current_age_magic
    if current_age_source(project):return current_age_magic(project)
    from original_output_hysteresis import selection as hysteresis_output_selection,magic as hysteresis_output_magic
    if hysteresis_output_selection(project) is not None:return hysteresis_output_magic(project)
    from original_output import selection as original_selection,magic as original_magic
    if original_selection(project) is not None:return original_magic(project)
    if project.age:
        from age_output_clock import selection as clock,MAGIC as CLOCK_MAGIC
        if clock(project) is not None:return CLOCK_MAGIC
        from age_output_schedule import selection as scheduled,MAGIC as SCHEDULE_MAGIC
        if scheduled(project) is not None:return SCHEDULE_MAGIC
        from age_output_calendar import selection,MAGIC as CALENDAR_MAGIC
        if selection(project) is not None:return CALENDAR_MAGIC
        from conserved_original_age import MAGIC
        return MAGIC
    selected = inspect(project.input_directory)['selectors']
    history = int(selected['SWHYST']>0)+2*selected['SWSNOW']
    if history:
        from micro_lookup_state import MAGICS
        if selected['SWPONDMX']==1:
            from scheduled_pond_state import MAGICS
        return MAGICS[(project.solute,bool(selected['SWCFBS']))][history-1].encode()
    if selected['SWCFBS']:
        return ((b'S5ETC016',b'S5EHC017',b'S5ESC018',b'S5EMC019') if project.solute else
                (b'S5ETW020',b'S5EHW021',b'S5ESW022',b'S5EMW023'))[history]
    formats = (b'S5HUP012',b'S5SHS013',b'S5SSN014',b'S5SMX015') if project.solute else (
               b'S5WAT007',b'S5WHS008',b'S5WSN009',b'S5WMX010')
    return formats[history]
