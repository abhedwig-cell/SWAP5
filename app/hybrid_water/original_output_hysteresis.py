"""Explicit original output composed with the admitted hydraulic history owner."""
from pathlib import Path
import hashlib
import re
import original_output as ordinary

ROOT=ordinary.ROOT
regular=ordinary.regular
clock=ordinary.clock
POLICY='original-output-hysteresis-carry-v1'
DOMAIN='original_output_hysteresis_domain'
HYSTERESIS_SHA='e6f5e4744e0a393a9e890abc0aaedaead91fe0128d84c9a7f8864b381c4c2fb8'
MAGICS={'water':b'S5IHW001','cde':b'S5IHC001','age':b'S5IHA001'}


def selection(project):
    if not getattr(project,'original_output',False) or project.macro or not project.input_directory:return None
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    def one(key,default=None,quoted=False):
        pattern=r"'[^']*'" if quoted else r'[+-]?\d+'
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if not values and default is not None:return default
        if len(values)!=1:raise ValueError('Missing/ambiguous original hysteresis output '+key)
        return values[0][1:-1] if quoted else int(values[0])
    mode=one('SWHYST')
    if mode==0:return None
    if mode not in (1,2):raise ValueError('Invalid original hysteresis output mode')
    if project.time_step_policy!='original-adaptive-day-seed-v1':raise ValueError('Original hysteresis output requires original adaptive-day-seed policy')
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
    if len(flags)>1:raise ValueError('Ambiguous original hysteresis output FLPRINTDT')
    token=flags[0].strip().upper() if flags else '.FALSE.'
    if token not in ('.FALSE.','FALSE','.F.','F','.TRUE.','TRUE','.T.','T'):raise ValueError('Invalid original hysteresis output FLPRINTDT')
    perstep=token in ('.TRUE.','TRUE','.T.','T')
    fmt=one('SWCSV',0);nprint=one('NPRINTDAY');monthly=one('SWMONTH')
    if fmt not in (0,1,2,3) or not 1<=nprint<=1440 or monthly not in (0,1):raise ValueError('Invalid original hysteresis output selector domain')
    requested=0 if monthly else one('PERIOD');reset=0 if monthly else one('SWRES');dates=0 if monthly else one('SWODAT')
    if not 0<=requested<=366 or reset not in (0,1) or dates not in (0,1):raise ValueError('Invalid original hysteresis output schedule')
    if perstep and reset:raise ValueError('Original hysteresis per-step cumulative reset needs separate qualification')
    if project.solute and (nprint!=1 or monthly or dates or requested!=1 or perstep):raise ValueError('Original hysteresis CDE output requires daily interval reset cadence')
    for key,value in dict(SWMACRO=0,SWSNOW=0,SWBR=0,SWFROST=0,SWDRA=1,SWMETDETAIL=0,SWSOPHY=0).items():
        if key=='SWDRA':
            from prescribed_history_boundary import enabled as paired_history_enabled
            if paired_history_enabled(project):continue
        if key=='SWDRA' and one(key)==2:
            from extended_drainage import enabled as extended_drainage_enabled
            if extended_drainage_enabled(project):continue
        if one(key)!=value:raise ValueError('Original hysteresis output currently excludes '+key)
    precision=one('NUM_DECIMALS',5) if fmt else None
    if precision is not None and not 5<=precision<=12:raise ValueError('Invalid original hysteresis output precision')
    return dict(kind='age' if project.age else 'cde' if project.solute else 'water',swhyst=mode,swcsv=fmt,nprintday=nprint,swmonth=monthly,swodat=dates,swres=reset,requested_period=requested,period=1 if nprint>1 or perstep else requested,flprintdt=perstep,groups=one('INLIST_CSV',quoted=True) if fmt else None,num_decimals=precision)


def magic(project):
    selected=selection(project)
    return ordinary.magic(project) if selected is None else MAGICS[selected['kind']]


def metadata(project):
    selected=selection(project)
    if selected is None:return ordinary.metadata(project)
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    result=dict(policy=POLICY,native_codec=magic(project).decode(),**selected,
                source_sha256=sha(Path(__file__)),ordinary_owner_sha256=sha(Path(ordinary.__file__)),
                domain_source_sha256=sha(Path(__file__).with_name(DOMAIN+'.f90')),
                calendar_owner_sha256=sha(Path(regular.__file__)),clock_owner_sha256=sha(Path(clock.__file__)),
                receipt_provider_sha256=sha(ROOT/'src/process/mod_original_output_receipt.f90'),
                original_integral_sha256=regular.INTEGRAL_SHA,original_output_epoch=project.start_clock,
                original_hysteresis_sha256=HYSTERESIS_SHA,
                cde_output_state_sha256=sha(Path(ordinary.__file__).with_name('original_cde_output_state.f90')) if project.solute else None,
                vector_catalog_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-VECTOR-OUTPUT-01/source.py') if selected['swcsv'] else None,
                binary_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01/source.py') if selected['swcsv']==3 else None,
                preserves_requested_groups_and_precision=True,undefined_allocation_tails_serialized=False,
                conserved_cde_prefix_offset_bytes=48 if project.solute else None)
    from prescribed_history_boundary import enabled as paired_history_enabled,domain_source as paired_history_domain
    if paired_history_enabled(project):
        result.update(paired_boundary=9,paired_history_policy='existing-original-hysteresis-explicit-paired9-daily-v1',
                      paired_history_source_sha256=sha(Path(__file__).with_name('prescribed_history_boundary.py')),
                      domain_source_sha256=hashlib.sha256(paired_history_domain(Path(__file__).with_name(DOMAIN+'.f90').read_bytes(),project)).hexdigest(),
                      domain_version=2,domain_bytes=56)
    return result


def age_identity(original,project):
    if selection(project) is None:return ordinary.age_identity(original,project)
    result=dict(original);result.update(native_codec=magic(project).decode(),original_output=metadata(project));return result


def probe_source(project):
    if project.age:return ordinary.PROBE[:ordinary.PROBE.index('subroutine hybrid_age_output_day_emit()')]+regular.PROBE
    probe=ordinary.PROBE
    if project.solute:
        probe=probe.replace('use hybrid_age_output_state','use MOD_solute,only:sampro,sdstor,imsqprec,imsqirrig,imsqbot,imsqdra,imdectot,imrottot,sbaldev\nuse MOD_integral,only:iptra,iqrot,iqreddry,iqredwet,iqredsol,iqredfrs\nuse hybrid_age_output_state',1)
        anchor="write(*,'(a,1x,i0,1x,es25.17e3)')'ORIGINAL_DAILY_RECEIPT',daycum,t1900"
        assert probe.count(anchor)==1
        probe=probe.replace(anchor,"write(*,'(a,9(1x,es25.17e3))')'HYBRID_SOLUTE_LEDGER',sampro,sdstor,imsqprec,imsqirrig,imsqbot,imsqdra,imdectot,imrottot,sbaldev\nwrite(*,'(a,6(1x,es25.17e3))')'HYBRID_UPTAKE',iptra,iqrot,iqreddry,iqredwet,iqredsol,iqredfrs\n"+anchor,1)
    return probe


def render_macro(source,project):
    if project.age:source=regular.render_macro(source)
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    assert source.count(begin)==source.count(end)==1
    first=source.index(begin);last=source.index(end,first)+len(end);prefix,suffix=source[:first],source[last:];source=source[first:last]
    magics=re.findall(r"'(S5[A-Z0-9]{6})'",source);assert len(magics)==2 and len(set(magics))==1
    source=source.replace("'"+magics[0]+"'","'"+magic(project).decode()+"'")
    # Preserve the entire real history import, including DZ. A partial NNUMNOD
    # replacement would accidentally move DZ into the following module import.
    anchor='      use MOD_grid, only: numnod,dz';assert source.count(anchor)==1
    imports='\n      use hybrid_output_hysteresis_domain,only:hybrid_output_hysteresis_checkpoint'
    if not project.age:imports+='\n      use MOD_integral,only:hybrid_output_calendar_checkpoint'
    if project.solute:imports+='\n      use hybrid_original_cde_output_state,only:hybrid_cde_output_checkpoint'
    source=source.replace(anchor,anchor+imports,1)
    if not project.age:
        anchor='        read(unit,iostat=ios) trailing';assert source.count(anchor)==1
        calls='        call hybrid_output_calendar_checkpoint(unit,.true.)\n'
        if project.solute:calls+='        call hybrid_cde_output_checkpoint(unit,.true.)\n'
        source=source.replace(anchor,calls+anchor,1)
        anchor='      end if\n      close(unit)';assert source.count(anchor)==1
        calls='        call hybrid_output_calendar_checkpoint(unit,.false.)\n'
        if project.solute:calls+='        call hybrid_cde_output_checkpoint(unit,.false.)\n'
        source=source.replace(anchor,calls+anchor,1)
    for restore in ('.true.','.false.'):
        anchor=f'        call hybrid_output_calendar_checkpoint(unit,{restore})';assert source.count(anchor)==1
        source=source.replace(anchor,f'        call hybrid_output_hysteresis_checkpoint(unit,{restore})\n'+anchor,1)
    return prefix+source+suffix


def apply_build(output,donor_build,project,patched):
    selected=selection(project)
    if selected is None:return patched
    if hashlib.sha256((donor_build/'swap-selected/hysteresis.f90').read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=HYSTERESIS_SHA:raise ValueError('Changed original hysteresis provider source')
    (output/(regular.PROVIDER+'.f90')).write_bytes((ROOT/'src/process'/(regular.PROVIDER+'.f90')).read_bytes())
    (output/'hybrid_age_output_state.f90').write_text(regular.state_source(project),encoding='cp1252')
    from prescribed_history_boundary import domain_source as paired_history_domain
    (output/(DOMAIN+'.f90')).write_bytes(paired_history_domain(Path(__file__).with_name(DOMAIN+'.f90').read_bytes(),project))
    original=(donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252');trial=selected['nprintday']>1 or selected['flprintdt']
    watstor=(donor_build/'swap-selected/watstor.f90').read_text(encoding='cp1252') if trial else None
    (output/'integral.f90').write_text(ordinary.render_integral(original,watstor,selected),encoding='cp1252')
    (output/'age_output_calendar_probe.f90').write_text(probe_source(project),encoding='cp1252')
    if project.age:
        path=output/'solute.f90';path.write_bytes(regular.render_solute(path.read_bytes()))
    if project.solute:
        (output/'original_cde_output_state.f90').write_bytes(Path(ordinary.__file__).with_name('original_cde_output_state.f90').read_bytes())
        patched.insert(patched.index('solute')+1,'original_cde_output_state')
    path=output/'swap.f90';text=regular.render_swap(path.read_text(encoding='cp1252'))
    anchor='use hybrid_day_window, only:';assert text.count(anchor)==1;text=text.replace(anchor,'use MOD_integral,only:hybrid_output_crop_apply\n'+anchor,1)
    anchor='         call hybrid_apply_wofost(fl_cropemergence)';assert text.count(anchor)==1;path.write_text(text.replace(anchor,anchor+'\n         call hybrid_output_crop_apply()',1),encoding='cp1252')
    path=output/'macropore.f90';path.write_text(render_macro(path.read_text(encoding='cp1252'),project),encoding='cp1252')
    path=output/'swap_main.f90';text=path.read_text(encoding='cp1252');anchor='use MOD_grid, only: numnod';assert text.count(anchor)==1;text=text.replace(anchor,anchor+'\nuse MOD_integral,only:hybrid_output_calendar_apply',1)
    if project.solute:text=text.replace(anchor,anchor+'\nuse hybrid_original_cde_output_state,only:hybrid_cde_output_apply',1)
    anchor="\n   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)";assert text.count(anchor)==1
    calls='\n   call hybrid_output_calendar_apply()'
    if project.solute:calls+='\n   call hybrid_cde_output_apply()'
    path.write_text(text.replace(anchor,calls+'\n   call hybrid_original_output_initial_emit()'+anchor,1),encoding='cp1252')
    extra=[]
    if trial:
        if 'timecontrol' in patched or (output/'timecontrol.f90').exists():raise ValueError('Multiple original hysteresis output clock owners')
        (output/'timecontrol.f90').write_text(clock.render_timecontrol((donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')),encoding='cp1252');extra=['timecontrol']
        path=output/'headcalc.f90';text=path.read_text(encoding='cp1252');anchor='   use hybrid_step_budget, only: projected_water_residual';assert text.count(anchor)==1;text=text.replace(anchor,'   use MOD_integral,only:hybrid_output_trial_residual\n'+anchor,1)
        anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.';assert text.count(anchor)==1
        path.write_text(text.replace(anchor,anchor+'\n         if(abs(hybrid_output_trial_residual())>1d-10)flnonconv=.true.',1),encoding='cp1252')
    if selected['swcsv']:
        path=output/'swap_csv_output.f90';text=path.read_text(encoding='cp1252');original=(donor_build/'swap-selected/swap_csv_output.f90').read_bytes()
        if selected['swcsv']==3:
            anchor='      else if (swcsv == 3) then ! binary\n         ! datetime';assert text.count(anchor)==1
            ordinary.binary_patch().source(original) # require the qualified original source/manifest
            text=text.replace(anchor,'      else if (swcsv == 3) then ! binary\n         allocate(buffer(parlen-1))\n         ! datetime',1)
        for old,new in ordinary.output_patch('vector').edits(original):
            assert text.count(old)==1,old;text=text.replace(old,new,1)
        path.write_text(text,encoding='cp1252')
    patched=[regular.PROVIDER,'hybrid_age_output_state',DOMAIN,*extra,'integral',*patched]
    patched.insert(patched.index('swap'),'age_output_calendar_probe');return patched
