"""Proposed bounded undrained Frost owner; not installed or qualified."""
import hashlib,re
from pathlib import Path

POLICY='original-frost-undrained-boundary58-state-calendar-v1'
FIXED=dict(SWMACRO=0,SWFROST=1,SWSNOW=1,SWHEA=1,SWCALT=2,SWSOPHY=0,
           SWDRA=0,SWBR=0,SWBBCFILE=0,SWMETDETAIL=0,NPRINTDAY=1,SWTOPBHEA=2)


def input_domain(selectors,boundary,original_output):
    return bool(original_output is not False and boundary.get('SWBOTB') in (5,6,8)
                and selectors.get('SWKIMPL') in (0,1) and selectors.get('SWSOLU') in (0,1)
                and selectors.get('SWHYST') in (0,1,2) and selectors.get('SWINCO') in (1,2)
                and all(selectors.get(k)==v for k,v in FIXED.items() if k!='NPRINTDAY'))


def selection(directory,original_output=True):
    if not directory or original_output is False:return None
    from experimental_project import switches
    folder=Path(directory);text=(folder/'swap.swp').read_text(encoding='cp1252');selectors=switches(text)
    if not input_domain(selectors,selectors,original_output):return None
    active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
    domains={k:{v} for k,v in FIXED.items()}
    domains.update(SWBOTB={5,6,8},SWSOLU={0,1},SWKIMPL={0,1},SWHYST={0,1,2},SWINCO={1,2},
                   SWMONTH={0,1},SWODAT={0,1},SWRES={0,1},PERIOD=set(range(367)))
    values={}
    for key,domain in domains.items():
        rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active)
        if len(rows)!=1 or re.fullmatch(r'[+-]?[0-9]+[ \t]*',rows[0]) is None:return None
        value=int(rows[0])
        if value not in domain:return None
        values[key]=value
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^\r\n]*)',active)
    if len(flags)>1 or flags and flags[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F'):return None
    if re.search(r'(?i)\bSWAP_SOILS_DB\b',active):return None
    models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
    rest=re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*','',active)
    if re.search(r'(?i)\bIHWCKMODEL\b',rest) or len(models)>1:return None
    analytical=None;implicit_analytical=None
    if values['SWBOTB']==6:
        if values['SWKIMPL']==values['SWHYST']==0:
            from frost_analytical_composition import model_domain
            analytical=model_domain(active,values,allow_model1=True)
            if analytical is None:return None
        elif models and re.fullmatch(r'\+?0*1(?:[ \t]+\+?0*1)*[ \t]*',models[0]) is None:
            if values['SWKIMPL']!=1 or values['SWHYST']!=0:return None
            from implicit_hydraulic_state import input_models
            implicit_analytical=input_models(text,values,values,original_output)
            if implicit_analytical is None:return None
    elif models and re.fullmatch(r'\+?0*1(?:[ \t]+\+?0*1)*[ \t]*',models[0]) is None:
        if values['SWKIMPL']==1:
            from implicit_hydraulic_state import input_models
            implicit_analytical=input_models(text,values,values,original_output)
            if implicit_analytical is None:return None
        else:
            from frost_analytical_composition import model_domain
            analytical=model_domain(active,values)
            if analytical is None:return None
    monthly=values['SWMONTH']
    calendar=monthly!=0 or values['SWODAT']!=0 or values['PERIOD']!=1 or values['SWRES']!=1
    result=dict(undrained_frost=True,boundary_state_calendar=True,frost_calendar=True,
                dense_daily_requested=not calendar,policy=POLICY,bottom=values['SWBOTB'],
                kind='cde' if values['SWSOLU'] else 'water',implicit=values['SWKIMPL'],
                hysteresis=values['SWHYST'],initial=values['SWINCO'],drainage=0,
                swmonth=monthly,swodat=0 if monthly else values['SWODAT'],
                swres=0 if monthly else values['SWRES'],requested_period=0 if monthly else values['PERIOD'],
                physical_equations_changed=False,requires_divdra=False)
    if analytical is not None:
        from frost_analytical_composition import POLICY as analytical_policy
        if values['SWBOTB']==6:
            from frost_analytical_composition import BOUNDARY_POLICY
            analytical_policy=BOUNDARY_POLICY
        result.update(analytical_frost_models=analytical,policy=analytical_policy)
    if implicit_analytical is not None:result['implicit_hydraulic_models']=implicit_analytical
    return result


def selected(project):
    if not project.input_directory or not project.original_output or project.macro or project.age:return None
    return selection(project.input_directory,project.original_output)


def codec(item):
    if not item.get('undrained_frost') or item.get('drainage')!=0:raise ValueError('Foreign undrained Frost codec domain')
    if item.get('analytical_frost_models'):
        from frost_analytical_composition import codec as analytical_codec
        return analytical_codec(item)
    return {('water',0):b'S5UDW001',('cde',0):b'S5UDC001',
            ('water',1):b'S5UDW002',('cde',1):b'S5UDC002'}[(item['kind'],item['implicit'])]


def metadata(project):
    item=selected(project)
    if item is None:return None
    folder=Path(__file__).parent
    providers=['frost_undrained_state.py','frost_boundary_state_calendar.py',
               'frost_boundary_composition.py','frost_drainage_composition.py',
               'frost_calendar_output.py','frost_calendar_terminal_water.py',
               'frost_undrained_terminal_water.py']
    if item['implicit']:
        providers+=['implicit_frost_composition.py','implicit_frost_surface_conductivity.py',
                    'implicit_frost_source_guard.py','implicit_frost_root_state.py',
                    'implicit_snow_root_state.f90','frost_boundary_terminal_trial.py']
    if project.solute:providers.append('snow_undrained_cde_positive.py')
    result=dict(policy=POLICY,native_codec=codec(item).decode(),undrained_frost=True,
                providers={n:hashlib.sha256((folder/n).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for n in providers},
                fixed_SWKIMPL=item['implicit'],fixed_SWDRA=0,fixed_SWDIVD=None,
                correction='NONE_NO_DIVDRA_CALL_WITH_SWDRA0',divdra_source_changed=False,
                new_physical_state=False,physical_equations_changed=False,
                boundary_composition=item,
                chemical_positive_mass_policy='original-cde-preserve-positive-cell-mass-v1' if project.solute else None)
    if item.get('analytical_frost_models'):
        from frost_analytical_composition import metadata as analytical_metadata
        domain=analytical_metadata(item)
        result.update(policy=item['policy'],analytical_frost_models=item['analytical_frost_models'],analytical_frost_native=domain)
        result['providers'].update(domain['providers'])
    if item['implicit']:
        from implicit_frost_root_state import metadata as root_metadata
        result['root_diagnostic_carry']=root_metadata(project)
    return result


def apply_build(output,project,patched):
    item=selected(project)
    if item is None:raise ValueError('Missing bounded undrained Frost build domain')
    if 'divdra' in patched:raise ValueError('Drainage-off Frost must not select Divdra correction')
    if project.solute:
        from snow_undrained_cde_positive import source
        path=Path(output)/'solute.f90';path.write_text(source(path.read_text(encoding='cp1252')),encoding='cp1252')
    return patched


def validate(bundle,project,identity):
    if identity.get('frost_drainage_composition')!=metadata(project):
        raise ValueError('Foreign actual undrained Frost composition identity')
    if 'divdra.f90' in identity['donor_generated']:
        raise ValueError('Unexpected corrected Divdra under drainage-off Frost')
    if project.solute:
        text=(Path(bundle)/'solute.f90').read_text(encoding='cp1252')
        if text.count('               if (cmsy(i) <= 0d0) then')!=1 or '               if (cmsy(i) < vsmall) then' in text:
            raise ValueError('Foreign undrained Frost positive CDE cell-mass predicate')
    from implicit_frost_composition import validate as implicit_validate
    implicit_validate(bundle,project)
    from frost_analytical_composition import validate as analytical_validate
    analytical_validate(bundle,project)
