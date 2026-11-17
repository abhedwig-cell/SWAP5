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


def render_integral(source,watstor=None):
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
    text=text.replace(old," if(header(19)/=merge(1,0,nprintday>1).or.header(20)/=0)error stop 'Foreign original age output clock flags'",1)
    if watstor is not None:
        anchor="end module MOD_integral";assert text.count(anchor)==1
        text=text.replace(anchor,trial_receipt_source(source,watstor)+"\n"+anchor,1)
    return text



def trial_receipt_source(source,watstor):
    """Project the actual original Integral increments on a private receipt clone.

    Expressions/operation order come from SHA-pinned Integral, not a second
    water law. No original or accepted receipt state is assigned here.
    """
    source=source.replace('\r\n','\n');watstor=watstor.replace('\r\n','\n')
    if hashlib.sha256(source.encode('cp1252')).hexdigest()!=regular.INTEGRAL_SHA:
        raise ValueError('Changed original trial receipt integral owner')
    expected='71d5e7c93fecfe444f0862532f1db3bbfbef1ca0c552e673e45340216e27589c'
    if hashlib.sha256(watstor.encode('cp1252')).hexdigest()!=expected:
        raise ValueError('Changed original trial receipt stock owner')
    body=source[source.index('   case (3)'):source.index('   case (4)')]
    def line(name):
        found=re.findall(r'(?mi)^[ \t]*'+name+r'[ \t]*=[ \t]*([^!\n]+)',body)
        if len(found)!=1:raise ValueError('Changed original trial increment '+name)
        return name+'='+found[0].strip()
    def increment(name,slot):
        found=re.findall(r'(?mi)^[ \t]*'+name+r'\s*=\s*'+name+r'\s*([+-])\s*([^!\n]+)',body)
        if len(found)!=1:raise ValueError('Changed original trial receipt '+name)
        op,expr=found[0]
        return f'trial%flow_cm({slot})=trial%flow_cm({slot})'+op+'('+expr.strip()+')'
    def block(begin,end):
        first=body.index(begin);last=body.index(end,first)+len(end)
        text=body[first:last]
        for name,slot in [('iintc',8),('iqbdo',16),('iqbup',7)]:
            pattern=r'(?mi)^([ \t]*)'+name+r'\s*=\s*'+name+r'\s*([+-])\s*([^!\n]+)'
            text=re.sub(pattern,lambda m:m[1]+f'trial%flow_cm({slot})=trial%flow_cm({slot})'+m[2]+'('+m[3].strip()+')',text)
        return text
    uses=source[source.index('      use plant_interface'):source.index('      implicit none')]
    uses=uses.replace('only: numnod','only: numnod,dz')
    canopy=re.findall(r'(?mi)^\s*sicact\s*=([^!\n]+)',body);assert len(canopy)==1
    stock=re.findall(r'(?mi)^\s*volact\s*=([^!\n]+)',watstor)
    stock=[x.strip() for x in stock if 'sum(theta(1:numnod)*dz(1:numnod))'==x.strip()];assert len(stock)==1
    lines=[line(k) for k in ('epdts','revats','qbotts','qrotts','qdrats')]
    lines += [increment('iqrot',10),'do node=1,numnod',increment('iqssdi',6),'end do',
              block('      if (sw_inter /= 3) then','      end if')]
    lines += [increment(k,slot) for k,slot in [('iepd',11),('ievap',12),('iruno',9),('irunon',5),('igrai',1),('igird',4)]]
    lines += [block('      if (qbotts < 0.0d0) then','      end if'),increment('iqdra',14),
              'projected_canopy='+canopy[0].strip(),'projected_soil='+stock[0]]
    return ('real(8) function hybrid_output_trial_residual() result(residual)\n'
            'use iso_fortran_env,only:real128\n'+uses+
            'implicit none\ntype(output_receipt_frame_t)::trial\n'
            'real(8)::epdts,revats,qbotts,qrotts,qdrats,projected_canopy,projected_soil,terms(28)\ninteger::node\n'
            "if(.not.hybrid_output_frame%active)error stop 'Inactive original trial receipt'\n"
            "if(swmacro/=0.or.swsnow/=0.or.swdra/=1)error stop 'Foreign original trial receipt domain'\n"
            'trial=hybrid_output_frame\n'+'\n'.join(lines)+'\n'
            'terms=[trial%flow_cm(1:7),-trial%flow_cm(8:16),trial%start_stock_cm, &\n'
            ' -projected_soil,-pond,0d0,-projected_canopy,0d0,0d0]\n'
            'residual=real(sum(real(terms,real128)),8)\nend function\n')


def render_timecontrol(source):
    text=source.replace('\r\n','\n')
    if hashlib.sha256(text.encode('cp1252')).hexdigest()!=TIME_SHA:raise ValueError('Changed original output clock owner')
    anchor='   use MOD_timer';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\n   use hybrid_age_output_state,only:original_output_start_clock',1)
    anchor='\n   select case (task)';assert text.count(anchor)==1
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
    (output/'integral.f90').write_text(render_integral((donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252'),(donor_build/'swap-selected/watstor.f90').read_text(encoding='cp1252') if selected['mode']=='subdaily' else None),encoding='cp1252')
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
        path=output/'headcalc.f90';text=path.read_text(encoding='cp1252')
        anchor='   use hybrid_step_budget, only: projected_water_residual';assert text.count(anchor)==1
        text=text.replace(anchor,'   use MOD_integral,only:hybrid_output_trial_residual\n'+anchor,1)
        anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.'
        assert text.count(anchor)==1
        text=text.replace(anchor,anchor+"\n         if(tcum+dt>=1d0-1d-8)then\n"
                          "            if(abs(hybrid_output_trial_residual())>1d-10)flnonconv=.true.\n         end if",1)
        anchor='      if (.NOT.flnonconv) then      ! convergence has been reached';assert text.count(anchor)==1
        text=text.replace(anchor,anchor+"\n         if(tcum+dt>=1d0-1d-8)write(*,'(a,4(1x,es25.17e3))') &\n"
                          "          'AGE_OUTPUT_TERMINAL_WATER',t1900,tcum,dt,hybrid_output_trial_residual()",1)
        # tcum is the original within-day physical clock; no output-clock reset.
        anchor='   use MOD_integral,only:hybrid_output_trial_residual'
        text=text.replace(anchor,'   use variables,only:tcum\n'+anchor,1)
        path.write_text(text,encoding='cp1252')
        if 'timecontrol' in patched or (output/'timecontrol.f90').exists():raise ValueError('Multiple original output clock owners')
        (output/'timecontrol.f90').write_text(render_timecontrol((donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')),encoding='cp1252');extra=['timecontrol']
    patched=[regular.PROVIDER,'hybrid_age_output_state',*extra,'integral',*patched]
    patched.insert(patched.index('swap'),'age_output_calendar_probe')
    return patched
