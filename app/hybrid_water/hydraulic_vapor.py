"""Original per-layer vapor conductivity with a separately bound Kelvin sign fix."""
import hashlib
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
NAME='WC_K_models_04_11'
FOLDER=ROOT/'reference/swap-4.3.1/hydraulic-corrections/VAPOR-KELVIN-SIGN01'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def selection(directory,selected,original_output):
    text=(Path(directory)/'swap.swp').read_text(encoding='cp1252')
    active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
    values=re.findall(r'(?mi)^[ \t]*SWVAPOR[ \t]*=[ \t]*([^\r\n]+)',active)
    if not values:return None
    if len(values)!=1 or not all(re.fullmatch(r'[+-]?\d+',v) for v in values[0].split()):raise ValueError('Ambiguous/noninteger original per-layer SWVAPOR')
    flags=tuple(map(int,values[0].split()))
    if not flags or any(v not in (0,1) for v in flags):raise ValueError('Original SWVAPOR must contain only0/1')
    if not any(flags) or selected.get('SWSOPHY')!=0:return None
    rows=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]+)',active)
    if not rows:return None # Original default model1 ignores SWVAPOR.
    if len(rows)!=1 or not all(re.fullmatch(r'[+-]?\d+',v) for v in rows[0].split()):raise ValueError('Ambiguous original per-layer hydraulic selectors')
    models=tuple(map(int,rows[0].split()))
    if not any(m in (8,9,10,11) for m in models):return None
    grid=re.findall(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',active)
    if len(grid)!=1:raise ValueError('Vapor requires an unambiguous original soil-layer grid')
    layers=[line.split()[1] for line in grid[0].splitlines()]
    if not layers or not all(v.isdigit() and int(v)>0 for v in layers):raise ValueError('Invalid original physical soil-layer indices')
    count=max(map(int,layers))
    if len(models)==1:models=models*count # Literal original scalar hydraulic selection.
    if len(models)!=count or len(flags)!=count:raise ValueError('Original per-layer vapor and hydraulic array counts differ from soil layers')
    if any(m not in range(1,12) for m in models):raise ValueError('Original vapor excludes unqualified hydraulic model12')
    enabled=tuple(i+1 for i,(m,f) in enumerate(zip(models,flags)) if m in (8,9,10,11) and f)
    if not enabled:return None
    required=dict(SWKIMPL=0,SWSOPHY=0,SWHYST=0,SWFROST=0,SWMACRO=0,SWSNOW=0,SWDRA=1,SWBOTB=6,SWBR=0,SWMETDETAIL=0,SWHEA=1,SWCALT=2)
    if original_output is False or any(selected.get(k)!=v for k,v in required.items()) or selected.get('SWSOLU') not in (0,1):
        raise ValueError('Active original vapor requires qualified explicit daily water/CDE, numerical heat, NoSnow/NoFrost/hysteresis0 primarydrainage bottom6')
    return dict(models=list(models),SWVAPOR=list(flags),active_layers=list(enabled),numlay=count)


def describe(project):
    if not project.input_directory:return None
    from experimental_project import switches
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    selected=selection(project.input_directory,switches(text),project.original_output)
    if selected is not None and (project.age or project.macro or project.time_step_policy!='original-adaptive-day-seed-v1'):
        raise ValueError('Active original vapor requires its bounded original day policy without AGE/macropores')
    return selected


def source(original,capacity7=False):
    raw=original.encode('cp1252') if isinstance(original,str) else original
    raw=raw.replace(b'\r\n',b'\n');q=json.loads((FOLDER/'manifest.json').read_text())
    if SHA(raw)!=q['base_lf_sha256']:raise ValueError('Foreign complete original vapor source')
    if capacity7:
        from model7_capacity import source as capacity_source
        parent=capacity_source(raw).encode('cp1252')
        assert SHA(parent)==q['capacity7_parent_lf_sha256']
    else:parent=raw
    edit=q['edits'];assert len(edit)==1;before=edit[0]['before'].encode();after=edit[0]['after'].encode()
    if parent.count(before)!=1:raise ValueError('Foreign original Kelvin sign seam')
    target=parent.replace(before,after,1)
    name=NAME+('.capacity7' if capacity7 else '')+'.f90'
    expected=(FOLDER/name).read_bytes().replace(b'\r\n',b'\n')
    if target!=expected or SHA(target)!=q['with_capacity7_lf_sha256' if capacity7 else 'target_lf_sha256'] or target.replace(after,before,1)!=parent:
        raise ValueError('Foreign complete corrected Kelvin source')
    return target.decode('cp1252')


def metadata(project):
    selected=describe(project)
    if selected is None:return None
    capacity7=7 in selected['models'];q=json.loads((FOLDER/'manifest.json').read_text())
    return dict(policy='original-per-layer-isothermal-vapor-kelvin-sign-v1',**selected,
        source_sha256=SHA(Path(__file__).read_bytes().replace(b'\r\n',b'\n')),
        manifest_sha256=SHA((FOLDER/'manifest.json').read_bytes().replace(b'\r\n',b'\n')),
        original_lf_sha256=q['base_lf_sha256'],corrected_lf_sha256=q['with_capacity7_lf_sha256' if capacity7 else 'target_lf_sha256'],
        existing_model7_capacity_composed=capacity7,reference_defect_corrected='Original absolute-suction Kelvin exponent sign',
        physical_equation_changed=True,new_physical_water_store=False,native_interface_changed=True,tolerance_changed=False,native_codec=native_magic(project).decode(),
        hydraulic_history_carry=True,thermal_history_carry=True,additional_native_doubles=7*project.nodes+6,
        native_domain_source_sha256=SHA(Path(__file__).with_name('hydraulic_vapor_native.f90').read_bytes().replace(b'\r\n',b'\n')))


def native_magic(project):
    if describe(project) is None:return None
    return b'S5HVC002' if project.solute else b'S5HVW002'


def native_source(source,project):
    if describe(project) is None:return source
    anchor='      use MOD_grid, only: numnod,dz'
    if source.count(anchor)!=1:raise ValueError('Missing complete original vapor hydraulic history import')
    source=source.replace(anchor,anchor+'\n      use hydraulic_vapor_native,only:vapor_native_domain_checkpoint',1)
    anchor="        if(iyear<1.or.iyear>9999) error stop 'Invalid nonmacro calendar year'"
    if source.count(anchor)!=1:raise ValueError('Missing original vapor restore clock')
    source=source.replace(anchor,anchor+'\n        call vapor_native_domain_checkpoint(unit,.true.)',1)
    anchor='        write(unit) t,iyear'
    if source.count(anchor)!=1:raise ValueError('Missing original vapor capture clock')
    return source.replace(anchor,anchor+'\n        call vapor_native_domain_checkpoint(unit,.false.)',1)


def apply_build(output,reference,project,patched):
    selected=describe(project)
    if selected is None:return patched
    original=(reference/'swap-selected'/(NAME+'.f90')).read_bytes();target=output/(NAME+'.f90');capacity7=7 in selected['models']
    if capacity7:
        from model7_capacity import source as capacity_source
        if patched.count(NAME)!=1 or target.read_text(encoding='cp1252')!=capacity_source(original):raise ValueError('Foreign joint model7/vapor source ownership')
    elif NAME in patched or target.exists():raise ValueError('Multiple original vapor source owners')
    target.write_text(source(original,capacity7),encoding='cp1252')
    native='hydraulic_vapor_native';(output/(native+'.f90')).write_bytes(Path(__file__).with_name(native+'.f90').read_bytes())
    macro=output/'macropore.f90';macro.write_text(native_source(macro.read_text(encoding='cp1252'),project),encoding='cp1252')
    if native in patched:raise ValueError('Multiple vapor native history owners')
    patched.insert(0,native)
    if NAME not in patched:patched.insert(0,NAME)
    return patched


def validate(bundle,reference,project,identity):
    expected=metadata(project)
    if identity.get('hydraulic_vapor')!=expected:raise ValueError('Foreign original vapor selection/source policy')
    if expected is None:return
    original=(reference/'build/swap-selected'/(NAME+'.f90')).read_bytes()
    if (bundle/(NAME+'.f90')).read_text(encoding='cp1252')!=source(original,expected['existing_model7_capacity_composed']):raise ValueError('Foreign complete joint original vapor/capacity source')
    if NAME+'.o' in identity['donor_objects']:raise ValueError('Uncorrected original vapor object retained')
