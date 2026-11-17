"""Original subdaily output epoch and annual-only age calendar owner."""
from pathlib import Path
import hashlib
import re
import age_output_calendar as regular
import age_output_schedule as schedule

POLICY='original-bound-output-epoch-age-clock-v1'
MAGIC=b'S5AGE005'
TIME_SHA='88b3d17865169672767b2d53460a625e191a6f6527067261e41bd99fd98e7c84'


def selection(project):
    if not project.age or not project.input_directory or project.macro:return None
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    def one(key,pattern=r'[+-]?\d+'):
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if len(values)!=1:raise ValueError('Missing/ambiguous original age output clock '+key)
        return values[0]
    nprint=int(one('NPRINTDAY'));monthly=int(one('SWMONTH'))
    if nprint==1 and monthly==1:return None # monthly reader owns inactive entries
    dates=int(one('SWODAT'))
    if nprint==1 and dates==1:return None
    requested=int(one('PERIOD'))
    if nprint==1 and requested!=0:return None
    if not 1<=nprint<=1440 or monthly!=0 or dates!=0 or not 0<=requested<=366:
        raise ValueError('Original age output clock requires annual-only or subdaily month0/date0 input')
    reset=int(one('SWRES'))
    if reset not in (0,1):raise ValueError('Invalid original age output reset selector')
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
    if len(flags)>1 or flags and flags[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F'):
        raise ValueError('Original per-step FLPRINTDT needs separate output-clock qualification')
    if project.time_step_policy!='original-adaptive-day-seed-v1':
        raise ValueError('Original age clock currently requires original adaptive-day-seed policy')
    for key,value in dict(SWSNOW=0,SWBR=0,SWHYST=0,SWFROST=0,SWDRA=1,SWMETDETAIL=0).items():
        if int(one(key))!=value:raise ValueError('Original age clock state currently excludes '+key)
    groups={v.strip().upper() for v in one('INLIST_CSV',r"'[^']*'")[1:-1].split(',')}
    if groups!={'WATBAL','GWL'}:raise ValueError('Original age clock currently requires WATBAL,GWL')
    return dict(mode='subdaily' if nprint>1 else 'annual',nprintday=nprint,requested_period=requested,
                period=1 if nprint>1 else 0,swmonth=0,swodat=0,swres=reset,flprintdt=False)


def metadata(project):
    selected=selection(project)
    if selected is None:return None
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(policy=POLICY,native_codec=MAGIC.decode(),**selected,original_output_epoch=project.start_clock,
                initialization_epoch='physical-tstart-before-calendar-state-apply',
                source_sha256=sha(Path(__file__)),regular_owner_sha256=sha(Path(regular.__file__)),
                schedule_owner_sha256=sha(Path(schedule.__file__)),original_timecontrol_sha256=TIME_SHA,
                receipt_provider_sha256=sha(regular.ROOT/'src/process'/(regular.PROVIDER+'.f90')),
                original_integral_sha256=regular.INTEGRAL_SHA,undefined_allocation_tails_serialized=False)


def age_identity(original,project):
    selected=metadata(project)
    if selected is None:return schedule.age_identity(original,project)
    result=dict(original);result.update(native_codec=MAGIC.decode(),output_clock=selected)
    return result


def render_integral(source):
    text=schedule.render_integral(source)
    old=" if(header(9)/=1)error stop 'Invalid original schedule print counter'"
    assert text.count(old)==1
    text=text.replace(old,""" if(nprintday>1)then
  if(int(header(9),int64)/=int(header(7),int64)*int(nprintday,int64)+1_int64) &
   error stop 'Inconsistent original global print counter'
 else
  if(header(9)/=1)error stop 'Invalid original annual print counter'
 end if""",1)
    old=" if(any(header(19:20)/=0))error stop 'Foreign original regular output flags'"
    assert text.count(old)==1
    return text.replace(old," if(header(19)/=merge(1,0,nprintday>1).or.header(20)/=0)error stop 'Foreign original age output clock flags'",1)


def render_timecontrol(source):
    text=source.replace('\r\n','\n')
    if hashlib.sha256(text.encode('cp1252')).hexdigest()!=TIME_SHA:raise ValueError('Changed original output clock owner')
    anchor='   use MOD_timer';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\n   use hybrid_age_output_state,only:original_output_start_clock',1)
    anchor='   select case (task)';assert text.count(anchor)==1
    text=text.replace(anchor,"""   real(8)::hybrid_age_print_epoch
! Original initialization precedes native calendar restoration. Its local print
! counter must not cap the persisted DT against the later global output epoch.
   hybrid_age_print_epoch=tstart
   if(task/=1)hybrid_age_print_epoch=original_output_start_clock
"""+anchor,1)
    assert text.count('t1900 - tstart + dtCrit')==1 and text.count('(tstart - t1900)')==2
    return text.replace('t1900 - tstart + dtCrit','t1900 - hybrid_age_print_epoch + dtCrit').replace('(tstart - t1900)','(hybrid_age_print_epoch - t1900)')


def render_macro(source):
    text=schedule.render_macro(source);assert text.count("'S5AGE004'")==2
    return text.replace("'S5AGE004'","'S5AGE005'")


def apply_build(output,donor_build,project,patched):
    selected=selection(project)
    if selected is None:return patched
    (output/(regular.PROVIDER+'.f90')).write_bytes((regular.ROOT/'src/process'/(regular.PROVIDER+'.f90')).read_bytes())
    (output/'hybrid_age_output_state.f90').write_text(regular.state_source(project),encoding='cp1252')
    (output/'integral.f90').write_text(render_integral((donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252')),encoding='cp1252')
    (output/'age_output_calendar_probe.f90').write_text(regular.PROBE,encoding='cp1252')
    path=output/'swap.f90';text=regular.render_swap(path.read_text(encoding='cp1252'))
    anchor='use hybrid_day_window, only:';assert text.count(anchor)==1
    text=text.replace(anchor,'use MOD_integral,only:hybrid_output_crop_apply\n'+anchor,1)
    anchor='         call hybrid_apply_wofost(fl_cropemergence)';assert text.count(anchor)==1
    path.write_text(text.replace(anchor,anchor+'\n         call hybrid_output_crop_apply()',1),encoding='cp1252')
    path=output/'solute.f90';path.write_bytes(regular.render_solute(path.read_bytes()))
    path=output/'macropore.f90';path.write_text(render_macro(path.read_text(encoding='cp1252')),encoding='cp1252')
    path=output/'swap_main.f90';text=path.read_text(encoding='cp1252')
    anchor='use MOD_solute,only:hybrid_age_observe,hybrid_age_effluent_observe';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\nuse MOD_integral,only:hybrid_output_calendar_apply',1)
    anchor="\n   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)";assert text.count(anchor)==1
    path.write_text(text.replace(anchor,'\n   call hybrid_output_calendar_apply()'+anchor,1),encoding='cp1252')
    extra=[]
    if selected['mode']=='subdaily':
        if 'timecontrol' in patched or (output/'timecontrol.f90').exists():raise ValueError('Multiple original output clock owners')
        (output/'timecontrol.f90').write_text(render_timecontrol((donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')),encoding='cp1252');extra=['timecontrol']
    patched=[regular.PROVIDER,'hybrid_age_output_state',*extra,'integral',*patched]
    patched.insert(patched.index('swap'),'age_output_calendar_probe')
    return patched
