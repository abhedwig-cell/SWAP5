"""Explicit original regular age output/calendar state, independent daily IO.

No water/age equation is implemented here. The increment expressions are taken
once from the pinned real original integral owner and observed in source order.
"""
from pathlib import Path
import hashlib
import re

ROOT=Path(__file__).resolve().parents[2]
POLICY='original-regular-age-output-independent-daily-receipt-v1'
MAGIC=b'S5AGE003'
INTEGRAL_SHA='62e4d36693eb090eb7ba2c20871fce619ab4314cee75bb6961aa531cb734207a'
PROVIDER='mod_original_output_receipt'


def selection(project):
    if not project.age or not project.input_directory or project.macro:return None
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    def one(key,pattern=r'[+-]?\d+'):
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if len(values)!=1:raise ValueError('Missing/ambiguous original age output '+key)
        return values[0]
    period=int(one('PERIOD'));nprint=int(one('NPRINTDAY'));swodat=int(one('SWODAT'))
    if nprint!=1:return None # original TimeControl explicitly sets effective PERIOD1
    if swodat!=0:raise ValueError('Original irregular age output requires separate calendar qualification')
    if period==1:return None
    if not 2<=period<=366:raise ValueError('Original regular age calendar currently requires PERIOD2..366')
    for key,value in dict(SWSNOW=0,SWBR=0,SWHYST=0,SWHEA=0,SWFROST=0,SWDRA=1,SWMETDETAIL=0).items():
        if int(one(key))!=value:raise ValueError('Original regular age output state currently excludes '+key)
    groups={v.strip().upper() for v in one('INLIST_CSV',r"'[^']*'")[1:-1].split(',')}
    if groups!={'WATBAL','GWL'}:raise ValueError('Original regular age output currently requires WATBAL,GWL')
    return dict(period=period,nprintday=nprint,swres=int(one('SWRES')))


def metadata(project):
    selected=selection(project)
    if selected is None:return None
    sha=lambda path:hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(policy=POLICY,native_codec=MAGIC.decode(),**selected,source_sha256=sha(Path(__file__)),
                receipt_provider_sha256=sha(ROOT/'src/process'/f'{PROVIDER}.f90'),
                original_integral_sha256=INTEGRAL_SHA,undefined_allocation_tails_serialized=False)


def age_identity(original,project):
    result=dict(original);selected=metadata(project)
    if selected is not None:result.update(native_codec=MAGIC.decode(),output_calendar=selected)
    return result


def state_source(project):
    return f'''module hybrid_age_output_state
use iso_fortran_env,only:real64
use mod_original_output_receipt
implicit none
type(output_receipt_frame_t),save::hybrid_output_frame
integer,save::pending_header(20)=0
real(8),allocatable,save::pending_values(:)
logical,save::output_restore_pending=.false.
real(8),parameter::original_output_start_clock={project.start_clock}d0
contains
subroutine output_assert_age_clock(day,period)
 integer,intent(in)::day
 real(8),intent(in)::period
 if(.not.output_restore_pending.or..not.allocated(pending_values))error stop 'Missing original output calendar owner'
 if(day/=pending_header(7))error stop 'Inconsistent original age output day'
 if(abs(period-pending_values(size(pending_values)))>0d0)error stop 'Inconsistent original age output period'
end subroutine
end module
'''


def _layout(source):
    fields=[]
    for line in source[:source.index('   public')].splitlines():
        line=line.split('!')[0]
        if not re.match(r'\s*real\(8\)',line,re.I) or '::' not in line:continue
        left,right=line.split('::');dims=re.search(r'dimension\(([^)]+)\)',left,re.I)
        for name in right.split(','):
            name=name.strip()
            if name in {'cgsnow','cmelt','csnrai','csubl','isnrai','igsnow','isubl'}:continue
            shape=() if not dims else tuple(v.strip().replace('macp','numnod').replace('madr','nrlevs') for v in dims[1].split(','))
            fields.append((name,shape))
    fields += [(n,('numnod',)) for n in ('inqpotrot_day','inqredrot_day')]
    fields += [(n,()) for n in ('iqrot_day','iqreddry_day','iqredsol_day','iptra_day','ialpwet_day','ialpdry_day')]
    fields += [(n,()) for n in ('volini','pondini','ivolbeg','ipondbeg','issnowbeg','isicbeg')]+[('ithetabeg',('numnod',))]
    fields += [(n,()) for n in ('ipgass','igass','imres','ipgasspot','igasspot','imrespot','tcumold','outper')]
    return fields


def _section(name,shape):return name+('('+','.join('1:'+v for v in shape)+')' if shape else '')
def _length(shape):return '*'.join('('+v+')' for v in shape) if shape else '1'


def _routines(fields):
    pack=[];unpack=[];lengths=[]
    for name,shape in fields:
        section=_section(name,shape);length=_length(shape);lengths.append(length)
        pack.append('reshape('+section+',['+length+'])' if len(shape)>1 else section)
        value='pending_values(pos)' if not shape else 'pending_values(pos:pos+'+length+'-1)'
        if len(shape)>1:value='reshape('+value+',shape('+section+'))'
        unpack.append(section+'='+value+';pos=pos+'+length)
    uses='''use iso_fortran_env,only:int64
use ieee_arithmetic,only:ieee_is_finite
use MOD_grid,only:numnod
use MOD_drain,only:nrlevs
use MOD_timer,only:tcumold
use plant_interface,only:ipgass,igass,imres,ipgasspot,igasspot,imrespot,sicact
use variables,only:volact,pond,volini,pondini,ivolbeg,ipondbeg,issnowbeg,isicbeg,ithetabeg, &
 daycum,cntper,nprintcount,ioutdat,ioutdatint,period,nprintday,swres,outper, &
 flzerocumu,flzerointr,floutput,floutputshort,flbaloutput,flheader,flprintshort,flprintdt,t1900
'''
    nreal='+'.join(lengths)
    return '''
subroutine hybrid_output_day_begin()
use variables,only:volact,pond
use plant_interface,only:sicact
integer::status
call begin_output_receipt(hybrid_output_frame,[volact,pond,0d0,sicact,0d0,0d0],status)
if(status/=OUTPUT_RECEIPT_OK)error stop 'Original output daily frame begin rejected'
end subroutine
subroutine hybrid_output_calendar_checkpoint(unit,restoring)
'''+uses+'''integer,intent(in)::unit
logical,intent(in)::restoring
integer::header(20),witness_header(20),ios,nreal
real(8),allocatable::values(:),witness(:)
nreal='''+nreal+'''
if(restoring)then
 read(unit,iostat=ios)header,witness_header
 if(ios/=0)error stop 'Incomplete original output calendar header'
 if(any(header/=witness_header))error stop 'Original output calendar header witness mismatch'
 if(any(header(1:6)/=[1,numnod,nrlevs,nreal,period,nprintday]))error stop 'Foreign original output calendar shape/policy'
 if(header(12)/=swres.or.minval(header(7:11))<0)error stop 'Invalid original output calendar counters'
 if(any(header(13:20)<0).or.any(header(13:20)>1))error stop 'Invalid original output calendar flags'
 allocate(values(nreal),witness(nreal));read(unit,iostat=ios)values,witness
 if(ios/=0)error stop 'Incomplete original output calendar values'
 if(.not.all(ieee_is_finite(values)))error stop 'Nonfinite original output calendar values'
 if(any(transfer(values,0_int64,nreal)/=transfer(witness,0_int64,nreal)))error stop 'Original output calendar value witness mismatch'
 if(values(nreal)<0d0)error stop 'Negative original output period'
 pending_header=header
 if(allocated(pending_values))deallocate(pending_values)
 call move_alloc(values,pending_values);output_restore_pending=.true.
else
 header=[1,numnod,nrlevs,nreal,period,nprintday,daycum,cntper,nprintcount,ioutdat,ioutdatint,swres, &
 merge(1,0,flzerocumu),merge(1,0,flzerointr),merge(1,0,floutput),merge(1,0,floutputshort), &
 merge(1,0,flbaloutput),merge(1,0,flheader),merge(1,0,flprintshort),merge(1,0,flprintdt)]
 allocate(values(nreal));values=['''+','.join(pack)+''']
 if(.not.all(ieee_is_finite(values)))error stop 'Cannot publish nonfinite original output calendar'
 write(unit)header,header,values,values
end if
end subroutine
subroutine hybrid_output_calendar_apply()
'''+uses+'''integer::pos
if(.not.output_restore_pending)return
if(abs(t1900-original_output_start_clock-dble(pending_header(7)))>1d-8)error stop 'Foreign original output calendar day'
daycum=pending_header(7);cntper=pending_header(8);nprintcount=pending_header(9)
ioutdat=pending_header(10);ioutdatint=pending_header(11)
flzerocumu=pending_header(13)==1;flzerointr=pending_header(14)==1
floutput=pending_header(15)==1;floutputshort=pending_header(16)==1
flbaloutput=pending_header(17)==1;flheader=pending_header(18)==1
flprintshort=pending_header(19)==1;flprintdt=pending_header(20)==1
pos=1
'''+ '\n'.join(unpack)+'''
if(pos/=size(pending_values)+1)error stop 'Original output calendar layout mismatch'
output_restore_pending=.false.
end subroutine
'''


def render_integral(source):
    source=source.replace('\r\n','\n')
    if hashlib.sha256(source.encode('cp1252')).hexdigest()!=INTEGRAL_SHA:raise ValueError('Changed original integral owner')
    fields=_layout(source)
    source=source.replace('   use MOD_integral_global','   use MOD_integral_global\n   use hybrid_age_output_state',1)
    anchor='      real(8) qrotts,qdrats,ptrats,epdts,pevats,revats,qbotts'
    if source.count(anchor)!=1:raise ValueError('Changed original integral increment locals')
    source=source.replace(anchor,anchor+'\n      real(8)::hybrid_receipt_increment\n      integer::hybrid_receipt_status',1)
    first=source.index('   case (3)');last=source.index('   case (4)',first);body=source[first:last]
    for name,slot,count in [('igrai',1,1),('igird',4,1),('irunon',5,1),('iqssdi',6,1),('iqbup',7,1),('iintc',8,2),('iruno',9,1),('iqrot',10,1),('iepd',11,1),('ievap',12,1),('iqdra',14,1),('iqbdo',16,1)]:
        pattern=r'(?mi)^([ \t]*)'+name+r'\s*=\s*'+name+r'\s*([+-])\s*([^!\n]+)[ \t]*$'
        def observer(match):
            indent,op,expr=match.groups();signed='-' if op=='-' else ''
            return (indent+'hybrid_receipt_increment='+expr.strip()+'\n'+indent+name+'='+name+op+'hybrid_receipt_increment\n'+
                    indent+'if(hybrid_output_frame%active)then\n'+indent+f' call observe_output_increment(hybrid_output_frame,{slot},{signed}hybrid_receipt_increment,hybrid_receipt_status)\n'+
                    indent+" if(hybrid_receipt_status/=OUTPUT_RECEIPT_OK)error stop 'Original output increment observer rejected'\n"+indent+'end if')
        body,n=re.subn(pattern,observer,body);assert n==count,(name,n)
    source=source[:first]+body+source[last:]
    ending=re.search(r'(?mi)^end module MOD_integral\s*$',source)
    if ending is None:raise ValueError('Changed original integral module closure')
    return source[:ending.start()]+_routines(fields)+source[ending.start():]


PROBE='''subroutine hybrid_age_output_day_emit()
use hybrid_age_output_state
use MOD_solute,only:hybrid_age_observe,hybrid_age_effluent_observe
use variables,only:volact,pond,daycum,t1900
use plant_interface,only:sicact
implicit none
real(8)::stocks(12),flow(16),age(11),effluent(24)
integer::status
call finish_output_receipt(hybrid_output_frame,[volact,pond,0d0,sicact,0d0,0d0],stocks,flow,status)
if(status/=OUTPUT_RECEIPT_OK)error stop 'Original output daily frame finish rejected'
call hybrid_age_observe(age);call hybrid_age_effluent_observe(effluent)
write(*,'(a,12(1x,es25.17e3))')'HYBRID_STOCK_FLUX',stocks
write(*,'(a,16(1x,es25.17e3))')'HYBRID_EXTERNAL_FLUX',flow
write(*,'(a,11(1x,es25.17e3))')'HYBRID_AGE_CUMULATIVE',age
write(*,'(a,24(1x,es25.17e3))')'HYBRID_AGE_EFFLUENT',effluent
write(*,'(a,1x,i0,1x,es25.17e3)')'AGE_DAILY_RECEIPT',daycum,t1900
end subroutine
'''


def render_swap(source):
    pattern=r'(?mi)^([ \t]*use[ \t]+MOD_integral[ \t]*,[ \t]*only:[ \t]*integral)[ \t]*$'
    source,n=re.subn(pattern,r'\1,hybrid_output_day_begin',source);assert n==1,n
    anchor='      if (flDayStart) then';assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'\n         call hybrid_output_day_begin()',1)
    anchor='      if (return_at_day_end .and. flDayEnd) return'
    if anchor in source:return source.replace(anchor,'      if(flDayEnd)call hybrid_age_output_day_emit()\n'+anchor,1)
    anchor='   end do\n\n!  Specific for exchange when called as DLL';assert source.count(anchor)==1
    return source.replace(anchor,'      if(flDayEnd)call hybrid_age_output_day_emit()\n'+anchor,1)


def render_solute(source):
    text=source.decode('cp1252').replace('\r\n','\n')
    replacements={
      '   use variables,only:theta,pond,daycum,outper,flzerocumu,flzerointr':'   use variables,only:theta,pond,daycum,outper,flzerocumu,flzerointr\n   use hybrid_age_output_state,only:output_assert_age_clock',
      '      age_output_day_offset=saved_output_day-daycum':'      call output_assert_age_clock(saved_output_day,saved_output_period)\n      age_output_day_offset=0',
      '      if(.not.age_saved_interval_reset)age_output_period_offset=saved_output_period':'      ! Global original output period is restored by the calendar owner.',
      '      age_initial_reset_pending=.true.':'      age_initial_reset_pending=.false. ! live calendar reset flags own this continuation'}
    for old,new in replacements.items():
        if text.count(old)!=1:raise ValueError('Changed original age calendar native anchor: '+old)
        text=text.replace(old,new,1)
    return text.encode('cp1252')


def render_macro(source):
    if source.count("'S5AGE002'")!=2:raise ValueError('Changed original age calendar format owner')
    source=source.replace("'S5AGE002'","'S5AGE003'")
    anchor='      use MOD_solute,only:hybrid_age_checkpoint';assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'\n      use MOD_integral,only:hybrid_output_calendar_checkpoint',1)
    for restoring in ('.true.','.false.'):
        anchor=f'        call hybrid_age_checkpoint(unit,{restoring})';assert source.count(anchor)==1
        source=source.replace(anchor,f'        call hybrid_output_calendar_checkpoint(unit,{restoring})\n'+anchor,1)
    return source


def apply_build(output,donor_build,project,patched):
    if selection(project) is None:return patched
    (output/(PROVIDER+'.f90')).write_bytes((ROOT/'src/process'/(PROVIDER+'.f90')).read_bytes())
    (output/'hybrid_age_output_state.f90').write_text(state_source(project),encoding='cp1252')
    (output/'integral.f90').write_text(render_integral((donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252')),encoding='cp1252')
    (output/'age_output_calendar_probe.f90').write_text(PROBE,encoding='cp1252')
    path=output/'swap.f90';path.write_text(render_swap(path.read_text(encoding='cp1252')),encoding='cp1252')
    path=output/'solute.f90';path.write_bytes(render_solute(path.read_bytes()))
    path=output/'macropore.f90';path.write_text(render_macro(path.read_text(encoding='cp1252')),encoding='cp1252')
    path=output/'swap_main.f90';source=path.read_text(encoding='cp1252')
    anchor='use MOD_solute,only:hybrid_age_observe,hybrid_age_effluent_observe';assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'\nuse MOD_integral,only:hybrid_output_calendar_apply',1)
    anchor="   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)";assert source.count(anchor)==1
    source=source.replace(anchor,'   call hybrid_output_calendar_apply()\n'+anchor,1);path.write_text(source,encoding='cp1252')
    patched=[PROVIDER,'hybrid_age_output_state','integral',*patched]
    patched.insert(patched.index('swap'),'age_output_calendar_probe')
    return patched
