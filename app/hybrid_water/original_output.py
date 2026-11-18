"""Explicit original output controls; admitted compatibility routes delegate unchanged."""
from pathlib import Path
import hashlib
import importlib.util
import re
import age_output_calendar as regular
import age_output_clock as clock

POLICY='original-user-output-controls-v1'
MAGIC=b'S5IOW001'
ROOT=regular.ROOT


def selection(project):
    if not getattr(project,'original_output',False):return None
    if project.macro or not project.input_directory:raise ValueError('Original output requires an explicit nonmacro original project')
    if project.time_step_policy!='original-adaptive-day-seed-v1':raise ValueError('Original output currently requires original adaptive-day-seed policy')
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    def one(key,default=None,quoted=False):
        pattern=r"'[^']*'" if quoted else r'[+-]?\d+'
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if not values and default is not None:return default
        if len(values)!=1:raise ValueError('Missing/ambiguous original output '+key)
        return values[0][1:-1] if quoted else int(values[0])
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
    if len(flags)>1:raise ValueError('Ambiguous original output FLPRINTDT')
    token=flags[0].strip().upper() if flags else '.FALSE.'
    if token not in ('.FALSE.','FALSE','.F.','F','.TRUE.','TRUE','.T.','T'):raise ValueError('Invalid original output FLPRINTDT')
    perstep=token in ('.TRUE.','TRUE','.T.','T')
    fmt=one('SWCSV',0);nprint=one('NPRINTDAY');monthly=one('SWMONTH')
    if fmt not in (0,1,2,3) or not 1<=nprint<=1440 or monthly not in (0,1):raise ValueError('Invalid original output selector domain')
    requested=0 if monthly else one('PERIOD');reset=0 if monthly else one('SWRES');dates=0 if monthly else one('SWODAT')
    if not 0<=requested<=366 or reset not in (0,1) or dates not in (0,1):raise ValueError('Invalid original output schedule')
    if perstep and reset:raise ValueError('Original per-step cumulative reset needs separate qualification')
    if project.solute and (nprint!=1 or monthly or dates or requested!=1 or perstep):
        raise ValueError('Original CDE output currently requires daily interval reset cadence')
    for key,value in dict(SWSNOW=0,SWBR=0,SWHYST=0,SWFROST=0,SWDRA=1,SWMETDETAIL=0).items():
        if one(key)!=value:raise ValueError('Original output pilot currently excludes '+key)
    precision=one('NUM_DECIMALS',5) if fmt else None
    if precision is not None and not 5<=precision<=12:raise ValueError('Invalid original output precision')
    return dict(kind='age' if project.age else 'cde' if project.solute else 'water',swcsv=fmt,nprintday=nprint,swmonth=monthly,swodat=dates,swres=reset,
                requested_period=requested,period=1 if nprint>1 or perstep else requested,flprintdt=perstep,
                groups=one('INLIST_CSV',quoted=True) if fmt else None,num_decimals=precision)


def binary_patch():
    path=ROOT/'reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01/source.py'
    spec=importlib.util.spec_from_file_location('original_binary_output_correction',path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module


def metadata(project):
    selected=selection(project)
    if selected is None:return None
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(policy=POLICY,native_codec=magic(project).decode(),**selected,source_sha256=sha(Path(__file__)),
                calendar_owner_sha256=sha(Path(regular.__file__)),clock_owner_sha256=sha(Path(clock.__file__)),
                receipt_provider_sha256=sha(ROOT/'src/process/mod_original_output_receipt.f90'),
                original_integral_sha256=regular.INTEGRAL_SHA,
                original_output_epoch=project.start_clock,
                cde_output_state_sha256=sha(Path(__file__).with_name('original_cde_output_state.f90')) if project.solute else None,
                binary_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01/source.py') if selected['swcsv']==3 else None,
                preserves_requested_groups_and_precision=True,undefined_allocation_tails_serialized=False)


def age_identity(original,project):
    if selection(project) is None:return clock.age_identity(original,project)
    result=dict(original);result.update(native_codec=magic(project).decode(),original_output=metadata(project))
    return result


def magic(project):
    return {'water':MAGIC,'cde':b'S5IOC001','age':b'S5IOA001'}[selection(project)['kind']]


def render_integral(source,watstor,selected):
    text=clock.render_integral(source,watstor)
    if not selected['flprintdt']:return text
    replacements={
      ' if(nprintday>1)then':' if(nprintday>1.and..not.flprintdt)then',
      " if(period>0.and.header(8)>=period)error stop 'Invalid original schedule periodic counter'":
      " if(.not.flprintdt.and.period>0.and.header(8)>=period)error stop 'Invalid original schedule periodic counter'",
      " if(period==0.and.header(8)/=header(7))error stop 'Inconsistent original zero-period day counter'":
      " if((period==0.or.flprintdt).and.header(8)/=header(7))error stop 'Inconsistent original zero-period day counter'",
      " if(header(19)/=merge(1,0,nprintday>1).or.header(20)/=0)error stop 'Foreign original age output clock flags'":
      " if(header(19)/=merge(1,0,nprintday>1.or.flprintdt).or.header(20)/=merge(1,0,flprintdt))error stop 'Foreign original output step flags'",
      "if(ioutdatint/=1+count(outdatint>0d0.and.outdatint<t1900-1d-8))error stop 'Inconsistent original interval date pointer'":
      """! Original FLPRINTDT advances this pointer only when the actual terminal
! step hits its separate DT-dependent condition. A passed date may remain
! pending; do not fabricate an advance or normalize original output history.
if(ioutdatint>1+count(outdatint>0d0.and.outdatint<t1900-1d-8))error stop 'Future original per-step date pointer'"""}
    for old,new in replacements.items():
        assert text.count(old)==1,old
        text=text.replace(old,new,1)
    return text


PROBE='''subroutine hybrid_original_output_initial_emit()
use variables,only:volact,pond
use plant_interface,only:sicact
implicit none
write(*,'(a,12(1x,es25.17e3))')'HYBRID_STOCK_FLUX', &
 volact,pond,0d0,sicact,0d0,0d0,volact,pond,0d0,sicact,0d0,0d0
end subroutine
subroutine hybrid_age_output_day_emit()
use hybrid_age_output_state
use variables,only:volact,pond,daycum,t1900
use plant_interface,only:sicact
implicit none
real(8)::stocks(12),flow(16)
integer::status
call finish_output_receipt(hybrid_output_frame,[volact,pond,0d0,sicact,0d0,0d0],stocks,flow,status)
if(status/=OUTPUT_RECEIPT_OK)error stop 'Original output daily frame finish rejected'
write(*,'(a,12(1x,es25.17e3))')'HYBRID_STOCK_FLUX',stocks
write(*,'(a,16(1x,es25.17e3))')'HYBRID_EXTERNAL_FLUX',flow
write(*,'(a,1x,i0,1x,es25.17e3)')'ORIGINAL_DAILY_RECEIPT',daycum,t1900
end subroutine
'''


def render_macro(source,project):
    if project.age:
        source=regular.render_macro(source)
        assert source.count("'S5AGE003'")==2
        return source.replace("'S5AGE003'","'"+magic(project).decode()+"'")
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    assert source.count(begin)==source.count(end)==1
    first=source.index(begin);last=source.index(end,first)+len(end)
    prefix,suffix=source[:first],source[last:];source=source[first:last]
    magics=re.findall(r"'(S5[A-Z0-9]{6})'",source);assert len(magics)==2 and len(set(magics))==1,magics
    source=source.replace("'"+magics[0]+"'","'"+magic(project).decode()+"'")
    anchor='      use MOD_grid, only: numnod';assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'\n      use MOD_integral,only:hybrid_output_calendar_checkpoint',1)
    if project.solute:
        source=source.replace(anchor,anchor+'\n      use hybrid_original_cde_output_state,only:hybrid_cde_output_checkpoint',1)
    anchor='        read(unit,iostat=ios) trailing';assert source.count(anchor)==1
    source=source.replace(anchor,'        call hybrid_output_calendar_checkpoint(unit,.true.)\n'+anchor,1)
    if project.solute:source=source.replace(anchor,'        call hybrid_cde_output_checkpoint(unit,.true.)\n'+anchor,1)
    anchor='      end if\n      close(unit)';assert source.count(anchor)==1
    calls='        call hybrid_output_calendar_checkpoint(unit,.false.)\n'
    if project.solute:calls+='        call hybrid_cde_output_checkpoint(unit,.false.)\n'
    return prefix+source.replace(anchor,calls+anchor,1)+suffix


def apply_build(output,donor_build,project,patched):
    selected=selection(project)
    if selected is None:return patched
    (output/(regular.PROVIDER+'.f90')).write_bytes((ROOT/'src/process'/(regular.PROVIDER+'.f90')).read_bytes())
    (output/'hybrid_age_output_state.f90').write_text(regular.state_source(project),encoding='cp1252')
    original=(donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252')
    trial=selected['nprintday']>1 or selected['flprintdt']
    watstor=(donor_build/'swap-selected/watstor.f90').read_text(encoding='cp1252') if trial else None
    (output/'integral.f90').write_text(render_integral(original,watstor,selected),encoding='cp1252')
    probe=PROBE
    if project.age:
        probe=PROBE[:PROBE.index('subroutine hybrid_age_output_day_emit()')]+regular.PROBE
        path=output/'solute.f90';path.write_bytes(regular.render_solute(path.read_bytes()))
    elif project.solute:
        probe=probe.replace('use hybrid_age_output_state','use MOD_solute,only:sampro,sdstor,imsqprec,imsqirrig,imsqbot,imsqdra,imdectot,imrottot,sbaldev\nuse MOD_integral,only:iptra,iqrot,iqreddry,iqredwet,iqredsol,iqredfrs\nuse hybrid_age_output_state',1)
        anchor="write(*,'(a,1x,i0,1x,es25.17e3)')'ORIGINAL_DAILY_RECEIPT',daycum,t1900"
        probe=probe.replace(anchor,"write(*,'(a,9(1x,es25.17e3))')'HYBRID_SOLUTE_LEDGER',sampro,sdstor,imsqprec,imsqirrig,imsqbot,imsqdra,imdectot,imrottot,sbaldev\nwrite(*,'(a,6(1x,es25.17e3))')'HYBRID_UPTAKE',iptra,iqrot,iqreddry,iqredwet,iqredsol,iqredfrs\n"+anchor,1)
        (output/'original_cde_output_state.f90').write_bytes(Path(__file__).with_name('original_cde_output_state.f90').read_bytes())
        patched.insert(patched.index('solute')+1,'original_cde_output_state')
    (output/'age_output_calendar_probe.f90').write_text(probe,encoding='cp1252')
    path=output/'swap.f90';text=regular.render_swap(path.read_text(encoding='cp1252'))
    anchor='use hybrid_day_window, only:';assert text.count(anchor)==1
    text=text.replace(anchor,'use MOD_integral,only:hybrid_output_crop_apply\n'+anchor,1)
    anchor='         call hybrid_apply_wofost(fl_cropemergence)';assert text.count(anchor)==1
    path.write_text(text.replace(anchor,anchor+'\n         call hybrid_output_crop_apply()',1),encoding='cp1252')
    path=output/'macropore.f90';path.write_text(render_macro(path.read_text(encoding='cp1252'),project),encoding='cp1252')
    path=output/'swap_main.f90';text=path.read_text(encoding='cp1252')
    anchor='use MOD_grid, only: numnod';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\nuse MOD_integral,only:hybrid_output_calendar_apply',1)
    if project.solute:text=text.replace(anchor,anchor+'\nuse hybrid_original_cde_output_state,only:hybrid_cde_output_apply',1)
    anchor="\n   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)";assert text.count(anchor)==1
    calls='\n   call hybrid_output_calendar_apply()'
    if project.solute:calls+='\n   call hybrid_cde_output_apply()'
    path.write_text(text.replace(anchor,calls+'\n   call hybrid_original_output_initial_emit()'+anchor,1),encoding='cp1252')
    extra=[]
    if trial:
        if 'timecontrol' in patched or (output/'timecontrol.f90').exists():raise ValueError('Multiple original output clock owners')
        (output/'timecontrol.f90').write_text(clock.render_timecontrol((donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')),encoding='cp1252');extra=['timecontrol']
        path=output/'headcalc.f90';text=path.read_text(encoding='cp1252')
        anchor='   use hybrid_step_budget, only: projected_water_residual';assert text.count(anchor)==1
        text=text.replace(anchor,'   use MOD_integral,only:hybrid_output_trial_residual\n'+anchor,1)
        anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.';assert text.count(anchor)==1
        path.write_text(text.replace(anchor,anchor+'\n         if(abs(hybrid_output_trial_residual())>1d-10)flnonconv=.true.',1),encoding='cp1252')
    if selected['swcsv']==3:
        # Correct the actual original source before adding the same diagnostic
        # tags. The general receipt never depends on a selected CSV group.
        path=output/'swap_csv_output.f90';text=path.read_bytes()
        anchor=b'      else if (swcsv == 3) then ! binary\n         ! datetime'
        normalized=text.replace(b'\r\n',b'\n');assert normalized.count(anchor)==1
        corrected=binary_patch().source((donor_build/'swap-selected/swap_csv_output.f90').read_bytes()).replace(b'\r\n',b'\n')
        original=(donor_build/'swap-selected/swap_csv_output.f90').read_bytes().replace(b'\r\n',b'\n')
        assert corrected==original.replace(anchor,b'      else if (swcsv == 3) then ! binary\n         allocate(buffer(parlen-1))\n         ! datetime',1)
        path.write_bytes(normalized.replace(anchor,b'      else if (swcsv == 3) then ! binary\n         allocate(buffer(parlen-1))\n         ! datetime',1))
    patched=[regular.PROVIDER,'hybrid_age_output_state',*extra,'integral',*patched]
    patched.insert(patched.index('swap'),'age_output_calendar_probe')
    return patched
