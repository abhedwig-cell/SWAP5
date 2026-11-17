"""Original NPRINTDAY1 monthly/explicit-date age calendar specialization.

All physical receipt, state packing and age rendering belongs to the admitted
regular-calendar owner. Only the original zero-period counter domain differs.
"""
from pathlib import Path
import hashlib
import re
import age_output_calendar as regular

POLICY='original-monthly-explicit-date-age-output-v1'
MAGIC=b'S5AGE004'


def selection(project):
    if not project.age or not project.input_directory or project.macro:return None
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    def one(key,pattern=r'[+-]?\d+'):
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if len(values)!=1:raise ValueError('Missing/ambiguous original age schedule '+key)
        return values[0]
    monthly=int(one('SWMONTH'))
    if monthly not in (0,1):raise ValueError('Invalid original age monthly output selector')
    if monthly:
        # Original ReadSwap sets these values and does not read the inactive
        # PERIOD/SWRES/SWODAT input entries in the monthly branch.
        period=reset=dates=0;mode='monthly'
    else:
        dates=int(one('SWODAT'))
        if dates==0:return None
        if dates!=1:raise ValueError('Invalid original age explicit-date selector')
        period=int(one('PERIOD'));reset=int(one('SWRES'))
        if not 0<=period<=366 or reset not in (0,1):raise ValueError('Invalid original age schedule period/reset')
        mode='explicit' if period==0 else 'combined'
    if int(one('NPRINTDAY'))!=1:raise ValueError('Original subdaily age schedule needs separate output-clock qualification')
    for key,value in dict(SWSNOW=0,SWBR=0,SWHYST=0,SWFROST=0,SWDRA=1,SWMETDETAIL=0).items():
        if int(one(key))!=value:raise ValueError('Original age schedule state currently excludes '+key)
    groups={v.strip().upper() for v in one('INLIST_CSV',r"'[^']*'")[1:-1].split(',')}
    if groups!={'WATBAL','GWL'}:raise ValueError('Original age schedule currently requires WATBAL,GWL')
    return dict(mode=mode,swmonth=monthly,swodat=dates,period=period,swres=reset,nprintday=1)


def metadata(project):
    selected=selection(project)
    if selected is None:return None
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(policy=POLICY,native_codec=MAGIC.decode(),**selected,
                source_sha256=sha(Path(__file__)),regular_owner_sha256=sha(Path(regular.__file__)),
                receipt_provider_sha256=sha(regular.ROOT/'src/process'/f'{regular.PROVIDER}.f90'),
                original_integral_sha256=regular.INTEGRAL_SHA,undefined_allocation_tails_serialized=False)


def age_identity(original,project):
    selected=metadata(project)
    if selected is None:return regular.age_identity(original,project)
    result=dict(original);result.update(native_codec=MAGIC.decode(),output_schedule=selected)
    return result


def render_integral(source):
    rendered=regular.render_integral(source)
    old=" if(header(8)>=period.or.header(9)/=1)error stop 'Invalid original regular output counters'"
    assert rendered.count(old)==1
    return rendered.replace(old,""" if(header(9)/=1)error stop 'Invalid original schedule print counter'
 if(period>0.and.header(8)>=period)error stop 'Invalid original schedule periodic counter'
 if(period==0.and.header(8)/=header(7))error stop 'Inconsistent original zero-period day counter'""",1)


def render_macro(source):
    rendered=regular.render_macro(source)
    assert rendered.count("'S5AGE003'")==2
    return rendered.replace("'S5AGE003'","'S5AGE004'")


def apply_build(output,donor_build,project,patched):
    if selection(project) is None:return patched
    # Build orchestration only: use the literal admitted original renderers and
    # receipt provider, with the explicit zero-period reader specialization.
    (output/(regular.PROVIDER+'.f90')).write_bytes((regular.ROOT/'src/process'/(regular.PROVIDER+'.f90')).read_bytes())
    (output/'hybrid_age_output_state.f90').write_text(regular.state_source(project),encoding='cp1252')
    (output/'integral.f90').write_text(render_integral((donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252')),encoding='cp1252')
    (output/'age_output_calendar_probe.f90').write_text(regular.PROBE,encoding='cp1252')
    path=output/'swap.f90';source=regular.render_swap(path.read_text(encoding='cp1252'))
    anchor='use hybrid_day_window, only:';assert source.count(anchor)==1
    source=source.replace(anchor,'use MOD_integral,only:hybrid_output_crop_apply\n'+anchor,1)
    anchor='         call hybrid_apply_wofost(fl_cropemergence)';assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'\n         call hybrid_output_crop_apply()',1);path.write_text(source,encoding='cp1252')
    path=output/'solute.f90';path.write_bytes(regular.render_solute(path.read_bytes()))
    path=output/'macropore.f90';path.write_text(render_macro(path.read_text(encoding='cp1252')),encoding='cp1252')
    path=output/'swap_main.f90';source=path.read_text(encoding='cp1252')
    anchor='use MOD_solute,only:hybrid_age_observe,hybrid_age_effluent_observe';assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'\nuse MOD_integral,only:hybrid_output_calendar_apply',1)
    anchor="\n   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)";assert source.count(anchor)==1
    source=source.replace(anchor,'\n   call hybrid_output_calendar_apply()'+anchor,1);path.write_text(source,encoding='cp1252')
    patched=[regular.PROVIDER,'hybrid_age_output_state','integral',*patched]
    patched.insert(patched.index('swap'),'age_output_calendar_probe')
    return patched
