 subroutine cycle_config(p)
  type(crop_n_configuration_t),intent(out)::p
  p=cp;p%harvest%crop_identity=2;p%harvest%crop_end=5d0
 end subroutine
 subroutine cycle_resume_mode()
  type(crop_n_configuration_t)::p
  type(crop_ext_state_t)::o
  type(crop_ext_saved_residue_t)::s
  type(crop_ext_row_t),allocatable::rows(:)
  character(10),allocatable::dates(:)
  integer::code
  integer(int64)::id
  character(16)::action
  call cycle_config(p);call get_command_argument(5,action);id=9102_int64
  if(action=='old-identity')then;p=cp;id=9101_int64;end if
  call read_crop_n_saved_generation(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64, &
   id,sp,p,water,state,o,s,dates,rows,code,CYCLE_HEAT_PARAMETERS)
  if(action=='old-identity')then
   call require(code/=0.and..not.water%ready().and..not.state%ready(),'old crop identity cannot read successor generation')
   return
  end if
  call require(code==0,'fresh cycle generation reconstructs new crop identity')
  if(action=='roundtrip')then
   call saved_write(trim(endpoint),water,state,o,s,dates,rows)
  else
   call cycle_run(trim(endpoint),water,state,o,s,dates,rows,action=='delayed',.false.)
  end if
  print '(A)','CYCLE_FRESH_GENERATION_PASS'
 end subroutine
 subroutine cycle_run(prefix,w,c,o,s,dates,rows,delayed,seed)
  character(*),intent(in)::prefix
  type(kernel_committed_state_t),intent(inout)::w
  type(crop_soil_state_t),intent(inout)::c
  type(crop_ext_state_t),intent(inout)::o
  type(crop_ext_saved_residue_t),intent(inout)::s
  character(10),allocatable,intent(inout)::dates(:)
  type(crop_ext_row_t),allocatable,intent(inout)::rows(:)
  logical,intent(in)::delayed,seed
  type(crop_n_configuration_t)::p,bad
  type(crop_soil_harvest_receipt_t)::h,mh
  type(crop_soil_harvest_observation_t)::observation
  type(kernel_committed_state_t)::mw,vw
  type(crop_soil_state_t)::mc,vc
  type(crop_ext_state_t)::mo,vo
  type(crop_ext_saved_residue_t)::ms,vs
  type(crop_ext_row_t),allocatable::mr(:),vr(:)
  character(10),allocatable::md(:),vd(:)
  type(senescence_joint_result_t)::r,manual
  type(material_joint_result_t)::fallow,mf
  type(soil_n_material_input_t)::batch(2),invalid(2)
  type(fmr_b110_physical_forcing_t)::forcing
  type(soil_n_day_environment_t)::e
  type(crop_senescence_policy_t)::senescence
  type(crop_residue_pending_t)::pending
  type(reactive_state_t)::rs
  type(wofost81_crop_owner_state_t)::owner
  type(wofost81_harvest_record_t)::hr
  type(crop_ext_row_t)::row
  real(real64)::clock,v(9),dm(4),nn(4),up(2),ov(17),mv(17),expected(8),total_uptake
  logical::ready,has,emit
  integer::code,t,phase,n
  character(1)::tag
  character(10)::date
  call cycle_config(p);call materials(batch,split)
  forcing=cfg%tiles(1)%base_forcing;senescence=policy
  if(seed)then
   call saved_write(prefix//'.before-seed',w,c,o,s,dates,rows)
   bad=p;bad%harvest%crop_identity=1
   call run_crop_soil_n_saved_successor(prefix//'.invalid',column,cfg%tiles(1)%template,670001_int64, &
    w,c,crop,bad,9102_int64,o,s,dates,rows,h,code)
   call require(code/=0.and.h%status/=0,'same crop identity rejects')
   call saved_write(prefix//'.bad-seed',w,c,o,s,dates,rows)
   call run_crop_soil_n_saved_successor('absent-cycle-dir/file',column,cfg%tiles(1)%template,670001_int64, &
    w,c,crop,p,9102_int64,o,s,dates,rows,h,code)
   call require(code==OUTPUT_DAY_SAVE_FAILED.and.h%status/=0,'late successor save failure rejects')
   call saved_write(prefix//'.failed-seed',w,c,o,s,dates,rows)
   mw=w;mc=c;call initialize_crop_soil_successor(mc,crop,p,9102_int64,mh)
   call require(mh%status==0.and.abs(mh%residual)<=1d-12.and.mh%seed_n>0d0,'independent physical seed N receipt')
   call run_crop_soil_n_saved_successor(prefix//'.seed',column,cfg%tiles(1)%template,670001_int64, &
    w,c,crop,p,9102_int64,o,s,dates,rows,h,code)
   call require(code==0.and.h%status==0.and.abs(h%residual)<=1d-12,'saved successor seed N gate')
   call saved_write(prefix//'.manual-seed',mw,mc,o,s,dates,rows)
   call saved_write(prefix//'.after-seed',w,c,o,s,dates,rows)
  end if
  call w%current_time(clock,ready);call require(ready,'cycle accepted clock')
  call c%snapshot(rs,owner);total_uptake=0d0
  if(.not.owner%harvested().and..not.owner%harvest_retired())then
   do t=int(clock),5
    tag=achar(49+t);date='1900-01-0'//tag;emit=.not.delayed.or.t==5
    e=soil_n_day_environment_t(real(t,real64),real(t+1,real64),5d0)
    call saved_write(prefix//'.before-day-'//tag,w,c,o,s,dates,rows)
    call run_crop_soil_n_saved_cycle_day('absent-cycle-dir/file',date,emit,670001_int64,backend,column, &
     cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,c,weather,real(t,real64),real(t+1,real64), &
     batch,split,senescence,o,s,dates,rows,r,code,CYCLE_ENVIRONMENT)
    call require(code==OUTPUT_DAY_SAVE_FAILED.and.r%status/=0,'late cycle day save failure rejects all owners')
    call saved_write(prefix//'.failed-day-'//tag,w,c,o,s,dates,rows)
    invalid=batch;invalid(2)%kind=999
    call run_crop_soil_n_saved_cycle_day(prefix//'.invalid',date,emit,670001_int64,backend,column, &
     cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,c,weather,real(t,real64),real(t+1,real64), &
     invalid,split,senescence,o,s,dates,rows,r,code,CYCLE_ENVIRONMENT)
    call require(code/=0.and.r%status/=0,'invalid cycle amendment rejects')
    call saved_write(prefix//'.invalid-day-'//tag,w,c,o,s,dates,rows)
    mw=w;mc=c;mo=o;ms=s;md=dates;mr=rows
    CYCLE_MANUAL_ACTIVE
    call require(manual%status==0,'manual successor accepted active day')
    call ms%snapshot(v,ready)
    associate(exchange=>manual%joint%joint%chemical%soil%process%exchange)
     up=[exchange%nh4_crop_uptake_kg_m2,exchange%no3_crop_uptake_kg_m2]
    end associate
    total_uptake=total_uptake+sum(up)
    call observe_crop_ext(mo,real(t,real64),real(t+1,real64),up,v(2:5),v(6:9),emit,row,code)
    call require(code==0,'independent original task6 previous-day observation')
    dm=0d0;nn=0d0;call mc%pending_snapshot(pending,has)
    if(has)then;dm(1:3)=pending%dry_matter_kg_ha;nn(1:3)=pending%nitrogen_kg_ha;end if
    call restore_crop_ext_saved_residue([real(t+1,real64),dm,nn],ms,code)
    if(emit)then;md=[md,date];mr=[mr,row];end if
    vw=w;vc=c;vo=o;vs=s;vd=dates;vr=rows
    call run_crop_soil_n_saved_cycle_day(prefix//'.view-day-'//tag,date,emit,670001_int64,backend,column, &
     cfg%tiles(1)%template,cfg%tiles(1)%parameters,vw,forcing,cfg%numerical,vc,weather,real(t,real64),real(t+1,real64), &
     batch,split,senescence,vo,vs,vd,vr,r,code,CYCLE_ENVIRONMENT,csv_path='absent-cycle-dir/view.csv')
    call require(code==OUTPUT_DAY_VIEW_FAILED.and.r%status==0,'cycle CSV failure retains authoritative generation')
    call saved_write(prefix//'.view-memory-'//tag,vw,vc,vo,vs,vd,vr)
    call run_crop_soil_n_saved_cycle_day(prefix//'.day-'//tag,date,emit,670001_int64,backend,column, &
     cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,c,weather,real(t,real64),real(t+1,real64), &
     batch,split,senescence,o,s,dates,rows,r,code,CYCLE_ENVIRONMENT,csv_path=prefix//'.csv')
    if(code/=0)print *,'cycle active failure',t,code,r%status
    call require(code==0.and.r%status==0,'cycle actual active day')
    call require(r%joint%joint%diagnostics%max_abs_step_mass_residual<=HARD_MASS_GATE.and. &
     abs(r%joint%joint%chemical%whole_n_residual)<=1d-12.and.abs(r%joint%materials%residual)<=1d-12,'cycle hard water and whole N')
    call saved_write(prefix//'.manual-day-'//tag,mw,mc,mo,ms,md,mr)
   end do
   if(seed)call require(total_uptake>0d0,'actual successor has nonzero soil N uptake')
  end if
  call c%snapshot(rs,owner)
  if(.not.owner%harvest_retired())then
   call owner%harvest_snapshot(hr,has);phase=1
   if(has)then
    phase=2;if(hr%pending_incorporated)phase=3
   end if
   do n=phase,3
    tag=achar(48+n);mw=w;mc=c;ms=s
    if(n==1)then
     call harvest_crop_soil_boundary(mc,mh);call require(mh%status==0,'manual repeated harvest')
     call mc%snapshot(rs,owner);call owner%harvest_snapshot(hr,has)
     dm=0d0;nn=0d0;call mc%pending_snapshot(pending,has)
     if(has)then;dm(1:3)=pending%dry_matter_kg_ha;nn(1:3)=pending%nitrogen_kg_ha;end if
     call original_harvest_inputs([dm,nn],hr%pending_dm,hr%pending_n,expected)
     call restore_crop_ext_saved_residue([6d0,expected],ms,code)
    else if(n==2)then
     call consume_crop_soil_harvest_pending(mc,mh)
    else
     call observe_crop_soil_harvest(c,observation,code);call require(code==0,'cycle explicit harvest observation')
     call acknowledge_crop_soil_harvest(mc,observation,mh)
    end if
    call require(mh%status==0.and.abs(mh%residual)<=1d-12,'manual cycle boundary whole N')
    call saved_write(prefix//'.before-phase-'//tag,w,c,o,s,dates,rows)
    call run_crop_soil_n_saved_cycle_harvest('absent-cycle-dir/file',n,column,cfg%tiles(1)%template, &
     670001_int64,w,c,o,s,dates,rows,h,code,observation)
    call require(code==OUTPUT_DAY_SAVE_FAILED.and.h%status/=0,'cycle boundary save failure rejects')
    call saved_write(prefix//'.failed-phase-'//tag,w,c,o,s,dates,rows)
    call run_crop_soil_n_saved_cycle_harvest(prefix//'.phase-'//tag,n,column,cfg%tiles(1)%template, &
     670001_int64,w,c,o,s,dates,rows,h,code,observation)
    call require(code==0.and.h%status==0,'cycle actual repeated harvest boundary')
    call saved_write(prefix//'.manual-phase-'//tag,mw,mc,o,ms,dates,rows)
   end do
  end if
  call w%current_time(clock,ready)
  forcing%root_extraction_sink=0d0;forcing%root_potential_transpiration=0d0
  do t=int(clock),7
   tag=achar(49+t);date='1900-01-0'//tag;emit=.not.delayed.or.t==7
   mw=w;mc=c;mo=o;ms=s;md=dates;mr=rows
   e=soil_n_day_environment_t(real(t,real64),real(t+1,real64),5d0)
   CYCLE_MANUAL_FALLOW
   call require(mf%status==0,'manual after-second-harvest fallow')
   call ms%snapshot(v,ready)
   call observe_crop_ext(mo,real(t,real64),real(t+1,real64),[0d0,0d0],v(2:5),v(6:9),emit,row,code)
   call restore_crop_ext_saved_residue([real(t+1,real64),0d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0],ms,code)
   if(emit)then;md=[md,date];mr=[mr,row];end if
   call CYCLE_FALLOW_OWNER(prefix//'.day-'//tag,date,emit,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,c,weather,real(t,real64),real(t+1,real64), &
    batch,split,o,s,dates,rows,fallow,code,CYCLE_ENVIRONMENT)
   call require(code==0.and.fallow%status==0,'second crop saved returns consumed once by actual fallow')
   call saved_write(prefix//'.manual-day-'//tag,mw,mc,mo,ms,md,mr)
  end do
  print '(A)','CYCLE_ACTUAL_TWO_CROPS_SEED_ACTIVE_HARVEST_FALLOW_PASS'
 end subroutine
