 subroutine saved_write(prefix,w,c,o,s,d,r)
  character(*),intent(in)::prefix
  type(kernel_committed_state_t),intent(in)::w
  type(crop_soil_state_t),intent(in)::c
  type(crop_ext_state_t),intent(in)::o
  type(crop_ext_saved_residue_t),intent(in)::s
  character(10),intent(in)::d(:)
  type(crop_ext_row_t),intent(in)::r(:)
  integer::code
  call write_crop_n_saved_generation(prefix,column,cfg%tiles(1)%template,670001_int64,w,c,o,s,d,r,code)
  call require(code==0,'saved full authority snapshot')
 end subroutine
 subroutine saved_physical(prefix,w,c)
  character(*),intent(in)::prefix
  type(kernel_committed_state_t),intent(in)::w
  type(crop_soil_state_t),intent(in)::c
  integer::code
  call write_crop_soil_n_joint_restart_file(prefix,column,cfg%tiles(1)%template,670001_int64,w,c,code)
  call require(code==0,'saved route physical authority')
 end subroutine
 subroutine saved_output_proof(prefix,w,c,delayed)
  character(*),intent(in)::prefix
  type(kernel_committed_state_t),intent(in)::w
  type(crop_soil_state_t),intent(in)::c
  logical,intent(in)::delayed
  type(kernel_committed_state_t)::actual_water,manual_water
  type(crop_soil_state_t)::actual,manual
  type(crop_ext_state_t)::o
  type(crop_ext_saved_residue_t)::s,absent
  type(crop_ext_row_t),allocatable::rows(:)
  character(10),allocatable::dates(:)
  type(crop_soil_harvest_receipt_t)::r,reference
  type(crop_soil_harvest_observation_t)::observation
  type(reactive_state_t)::rs
  type(wofost81_crop_owner_state_t)::owner
  type(wofost81_harvest_record_t)::h
  type(crop_residue_pending_t)::pnd
  real(real64)::v(9),expected(8),daily(8)
  logical::has,ready
  integer::phase,code
  character(1)::tag
  allocate(rows(0),dates(0));call initialize_crop_ext(2d0,o,code)
  actual=c;manual=c;actual_water=w;manual_water=w
  call saved_physical(prefix//'.before-stage',actual_water,actual)
  call run_crop_soil_n_saved_harvest('missing-saved-output/file',1,column,cfg%tiles(1)%template, &
   670001_int64,actual_water,actual,o,s,dates,rows,r,code)
  call require(code==OUTPUT_DAY_SAVE_FAILED.and.r%status/=0,'capture save failure rejects phase')
  call s%snapshot(v,ready);call require(.not.ready,'failed capture publishes no diagnostic memory')
  call saved_physical(prefix//'.failed-stage',actual_water,actual)
  do phase=1,3
   tag=achar(48+phase)
   if(phase==1)then
    call harvest_crop_soil_boundary(manual,reference)
    call manual%snapshot(rs,owner);call owner%harvest_snapshot(h,has)
    call require(has,'source harvest organ record present')
    daily=0d0
    call manual%pending_snapshot(pnd,has)
    if(has)then
     daily(1:3)=pnd%dry_matter_kg_ha
     daily(5:7)=pnd%nitrogen_kg_ha
    end if
    call original_harvest_inputs(daily,h%pending_dm,h%pending_n,expected)
    call require(any(expected(1:4)/=0d0).and.any(h%exported_dm/=h%pending_dm),'harvest return/export discriminant')
   else if(phase==2)then
    call consume_crop_soil_harvest_pending(manual,reference)
   else
    call acknowledge_crop_soil_harvest(manual,observation,reference)
   end if
   call require(reference%status==0.and.abs(reference%residual)<=1d-12,'manual harvest whole N gate')
   if(phase>1)then
    call run_crop_soil_n_saved_harvest('missing-saved-output/file',phase,column,cfg%tiles(1)%template, &
     670001_int64,actual_water,actual,o,s,dates,rows,r,code,observation)
    call require(code==OUTPUT_DAY_SAVE_FAILED.and.r%status/=0,'failed later phase publishes nothing')
    call saved_write(prefix//'.failed-'//tag,actual_water,actual,o,s,dates,rows)
   end if
   call run_crop_soil_n_saved_harvest(prefix//'.phase-'//tag,phase,column,cfg%tiles(1)%template, &
    670001_int64,actual_water,actual,o,s,dates,rows,r,code,observation)
   call require(code==0.and.r%status==0.and.abs(r%residual)<=1d-12,'saved harvest original owner N gate')
   call s%snapshot(v,ready)
   call require(ready.and.v(1)==2d0.and.all(v(2:9)==expected),'daily plus harvest return survives phases')
   call saved_physical(prefix//'.manual-'//tag,manual_water,manual)
   call saved_physical(prefix//'.actual-'//tag,actual_water,actual)
   if(phase==1)then
    call observe_crop_soil_harvest(actual,observation,code);call require(code==0,'explicit biological observation')
   end if
   call run_crop_soil_n_saved_harvest(prefix//'.invalid',phase,column,cfg%tiles(1)%template, &
    670001_int64,actual_water,actual,o,s,dates,rows,r,code,observation)
   call require(code/=0.and.r%status/=0,'phase replay rejects')
   call saved_write(prefix//'.replay-'//tag,actual_water,actual,o,s,dates,rows)
  end do
  call capture_crop_soil_n_saved_harvest(actual_water,actual,o,absent,code)
  call absent%snapshot(v,ready)
  call require(code/=0.and..not.ready,'cannot reconstruct lost organ diagnostics after retirement')
  call saved_fallow_proof(prefix,actual_water,actual,o,s,dates,rows,delayed,manual_water,manual)
  print '(A)','SAVED_HARVEST_REAL_PHASES_AND_RICHARDS_FALLOW_PASS'
 end subroutine
 subroutine saved_fallow_proof(prefix,w,c,o,s,dates,rows,delayed,mw,mc)
  character(*),intent(in)::prefix
  type(kernel_committed_state_t),intent(inout)::w
  type(crop_soil_state_t),intent(inout)::c
  type(crop_ext_state_t),intent(inout)::o
  type(crop_ext_saved_residue_t),intent(inout)::s
  character(10),allocatable,intent(inout)::dates(:)
  type(crop_ext_row_t),allocatable,intent(inout)::rows(:)
  logical,intent(in)::delayed
  type(kernel_committed_state_t),optional,intent(inout)::mw
  type(crop_soil_state_t),optional,intent(inout)::mc
  type(material_joint_result_t)::r,manual
  type(fmr_b110_physical_forcing_t)::forcing,badforcing
  type(soil_n_day_environment_t)::e
  type(soil_n_material_input_t)::none(0)
  real(real64)::v(9),expected(8),t,clock,tot(8),ext(8)
  integer::day,code
  logical::ready,emit
  character(10)::date
  character(1)::tag
  forcing=cfg%tiles(1)%base_forcing;forcing%root_extraction_sink=0d0;forcing%root_potential_transpiration=0d0
  call s%snapshot(v,ready);call require(ready,'fallow saved initial ready')
  call o%snapshot(clock,expected,ext,ready)
  expected(3)=expected(3)+v(3)+v(4)+v(5)
  expected(4)=expected(4)+v(7)+v(8)+v(9)
  expected(5)=expected(5)+.1d0*(v(7)+v(8)+v(9))
  expected(6)=expected(6)+v(2);expected(7)=expected(7)+v(6);expected(8)=expected(8)+.1d0*v(6)
  do day=int(v(1))+1,4
   t=real(day-1,real64);e=soil_n_day_environment_t(t,t+1d0,5d0)
   date='1900-01-03';if(day==4)date='1900-01-04'
   tag=achar(48+day);emit=.not.delayed.or.day==4
   call saved_write(prefix//'.before-day-'//tag,w,c,o,s,dates,rows)
   call run_crop_soil_n_saved_fallow_day('missing-saved-output/file',date,emit,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,c,weather,t,t+1d0, &
    none,split,o,s,dates,rows,r,code,e)
   call require(code==OUTPUT_DAY_SAVE_FAILED.and.r%status/=JOINT_OK,'late fallow save rejection')
   call saved_write(prefix//'.failed-day-'//tag,w,c,o,s,dates,rows)
   badforcing=forcing;badforcing%root_potential_transpiration=.001d0
   call run_crop_soil_n_saved_fallow_day(prefix//'.invalid',date,emit,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,badforcing,cfg%numerical,c,weather,t,t+1d0, &
    none,split,o,s,dates,rows,r,code,e)
   call require(code/=0.and.r%status/=JOINT_OK,'nonzero fallow roots reject')
   call saved_write(prefix//'.bad-roots-'//tag,w,c,o,s,dates,rows)
   call run_crop_soil_n_saved_fallow_day(prefix//'.invalid',date,emit,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,c,weather,t,ieee_value(0d0,ieee_quiet_nan), &
    none,split,o,s,dates,rows,r,code,e)
   call require(code/=0.and.r%status/=JOINT_OK,'nonfinite fallow day rejects before physics')
   call saved_write(prefix//'.nan-day-'//tag,w,c,o,s,dates,rows)
   block
    type(kernel_committed_state_t)::vw
    type(crop_soil_state_t)::vc
    type(crop_ext_state_t)::vo
    type(crop_ext_saved_residue_t)::vs
    character(10),allocatable::vd(:)
    type(crop_ext_row_t),allocatable::vr(:)
    vw=w;vc=c;vo=o;vs=s;vd=dates;vr=rows
    call run_crop_soil_n_saved_fallow_day(prefix//'.view-day-'//tag,date,emit,670001_int64,backend,column, &
     cfg%tiles(1)%template,cfg%tiles(1)%parameters,vw,forcing,cfg%numerical,vc,weather,t,t+1d0, &
     none,split,vo,vs,vd,vr,r,code,e,csv_path='missing-saved-output/view.csv')
    call require(code==OUTPUT_DAY_VIEW_FAILED.and.r%status==JOINT_OK,'CSV-only failure retains saved fallow authority')
    call saved_write(prefix//'.view-memory-'//tag,vw,vc,vo,vs,vd,vr)
   end block
   if(present(mw).and.present(mc))then
    call run_crop_soil_n_material_interval(second,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters, &
     mw,forcing,cfg%numerical,mc,weather,t,t+1d0,none,split,manual,e,fallow=.true.)
    call require(manual%status==JOINT_OK.and.abs(manual%joint%chemical%whole_n_residual)<=1d-12, &
     'manual real fallow whole N gate')
    call saved_physical(prefix//'.manual-day-'//tag,mw,mc)
   end if
   call run_crop_soil_n_saved_fallow_day(prefix//'.day-'//tag,date,emit,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,c,weather,t,t+1d0, &
    none,split,o,s,dates,rows,r,code,e,csv_path=prefix//'.csv')
   if(code/=0)print *,'saved fallow rejected',day,code,r%status
   call require(code==0.and.r%status==JOINT_OK.and.abs(r%joint%chemical%whole_n_residual)<=1d-12, &
    'saved real fallow whole N gate')
   call saved_physical(prefix//'.actual-day-'//tag,w,c)
   call s%snapshot(v,ready)
   call require(ready.and.v(1)==day.and.all(v(2:9)==0d0),'saved harvest replaced by fallow zeros')
   if(day==3.and.emit.or.day==4.and.delayed)then
    call require(all(rows(size(rows))%values==expected),'original previous-day report quantity')
   else if(day==4)then
    call require(all(rows(size(rows))%values==0d0),'no duplicate harvest report')
   else
    call o%snapshot(clock,tot,ext,ready)
    call require(all(tot==expected),'deferred report retains interval values')
   end if
   call run_crop_soil_n_saved_fallow_day(prefix//'.invalid',date,emit,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,c,weather,t,t+1d0, &
    none,split,o,s,dates,rows,r,code,e)
   call require(code/=0.and.r%status/=JOINT_OK,'fallow day replay rejects')
   call saved_write(prefix//'.replay-day-'//tag,w,c,o,s,dates,rows)
  end do
 end subroutine
 subroutine saved_resume_mode()
  type(crop_ext_state_t)::o
  type(crop_ext_saved_residue_t)::s
  type(crop_ext_row_t),allocatable::rows(:)
  character(10),allocatable::dates(:)
  type(crop_soil_harvest_receipt_t)::r
  type(crop_soil_harvest_observation_t)::observation
  type(reactive_state_t)::rs
  type(wofost81_crop_owner_state_t)::owner
  type(wofost81_harvest_record_t)::h
  real(real64)::v(9)
  integer::code,phase
  integer(int64)::wid
  logical::has,delayed
  character(16)::action
  call get_command_argument(5,action);delayed=action=='delayed'
  wid=670001_int64;if(action=='wrong-water')wid=670002_int64
  if(trim(mode)=='saved-reject-live')then
   call read_crop_n_saved_generation(trim(endpoint),column,cfg%tiles(1)%template,670001_int64,9001_int64, &
    9101_int64,sp,cp,water,state,o,s,dates,rows,code)
   call require(code==0,'live rejection starts with a complete generation')
   call saved_write(trim(endpoint)//'.before-invalid',water,state,o,s,dates,rows)
  end if
  call read_crop_n_saved_generation(trim(path),column,cfg%tiles(1)%template,wid,9001_int64, &
   9101_int64,sp,cp,water,state,o,s,dates,rows,code)
  if(trim(mode)=='saved-reject'.or.trim(mode)=='saved-reject-live')then
   if(trim(mode)=='saved-reject-live')then
    call require(code/=0,'invalid read rejected over existing live state')
    call saved_write(trim(endpoint)//'.after-invalid',water,state,o,s,dates,rows)
    print '(A)','SAVED_GENERATION_INVALID_LIVE_ATOMIC_PASS';return
   end if
   call s%snapshot(v,has)
   call require(code/=0.and..not.water%ready().and..not.state%ready().and..not.has,'invalid saved generation atomic')
   print '(A)','SAVED_GENERATION_INVALID_ATOMIC_PASS';return
  end if
  call require(code==0,'fresh saved generation reconstructs all owners')
  if(action=='roundtrip')then
   call saved_write(trim(endpoint),water,state,o,s,dates,rows)
  else
   call state%snapshot(rs,owner);call owner%harvest_snapshot(h,has)
   if(has)then
    if(.not.h%pending_incorporated)then
     call run_crop_soil_n_saved_harvest(trim(endpoint)//'.phase-2',2,column,cfg%tiles(1)%template, &
      670001_int64,water,state,o,s,dates,rows,r,code)
     call require(code==0.and.r%status==0,'fresh incorporation')
    end if
    call observe_crop_soil_harvest(state,observation,code);call require(code==0,'fresh detached observation')
    call run_crop_soil_n_saved_harvest(trim(endpoint)//'.phase-3',3,column,cfg%tiles(1)%template, &
     670001_int64,water,state,o,s,dates,rows,r,code,observation)
    call require(code==0.and.r%status==0,'fresh retirement')
   end if
   call saved_fallow_proof(trim(endpoint),water,state,o,s,dates,rows,delayed)
  end if
  print '(A)','SAVED_GENERATION_FRESH_CONTINUATION_PASS'
 end subroutine
 subroutine original_harvest_inputs(daily,hdm,hn,expected)
  real(real64),intent(in)::daily(8),hdm(4),hn(4)
  real(real64),intent(out)::expected(8)
  real(real64)::idwrt,idwlv,idwst,idwso,inlossr,inlossl,inlosss,inlosso
  real(real64)::HarLosOrm_rt,HarLosOrm_lv,HarLosOrm_st,HarLosOrm_so
  real(real64)::HarLosNit_rt,HarLosNit_lv,HarLosNit_st,HarLosNit_so
  idwrt=daily(1);idwlv=daily(2);idwst=daily(3);idwso=daily(4)
  inlossr=daily(5);inlossl=daily(6);inlosss=daily(7);inlosso=daily(8)
  HarLosOrm_rt=hdm(1);HarLosOrm_lv=hdm(2);HarLosOrm_st=hdm(3);HarLosOrm_so=hdm(4)
  HarLosNit_rt=hn(1);HarLosNit_lv=hn(2);HarLosNit_st=hn(3);HarLosNit_so=hn(4)
  include 'original_harvest_dm.inc'
  include 'original_harvest_n.inc'
  expected=[idwrt,idwlv,idwst,idwso,inlossr,inlossl,inlosss,inlosso]
 end subroutine
