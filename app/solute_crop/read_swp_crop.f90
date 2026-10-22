! Explicit preparation adapter. No accepted hydraulic, solute or nutrient state.
program read_swp_crop
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_is_finite
  use mod_crop_fixed_phenology
  use mod_crop_rotation_calendar
  use mod_wofost_rate_table
  use mod_crop_et_canopy_view_provider
  use mod_crop_root_depth_dvs
  use mod_reference_et_demand_process
  implicit none
  integer::mode,n,ncrop,i,j,first,last,status,u,datea(6),crop_index
  integer,allocatable::dd(:),mm(:),yyyy(:)
  real(real64)::tstart,tend,starts(64),ends(64),rds,kdir,kdif,lai,rd,dvsend
  real(real64),allocatable::tmin(:),tmax(:),etref(:),times(:),x(:),y(:),cf_x(:),cf_y(:),output(:,:)
  character(1024)::swp,crp,met,declared,names(64)
  logical::rdinqr,active,starts_today,harvested
  integer::crop_types(64),swharv
  type(fixed_crop_parameters_t)::parameters
  type(fixed_crop_state_t)::state,candidate
  type(crop_calendar_t)::calendar
  type(wofost_rate_table_t)::leaf_table,depth_table
  type(crop_et_canopy_parameters_t)::canopy_parameters
  type(crop_et_canopy_state_view_t)::canopy_state
  type(crop_et_canopy_forcing_t)::canopy_forcing
  type(crop_et_canopy_view_t)::canopy
  type(crop_et_canopy_diagnostics_t)::canopy_diagnostics
  type(reference_et_demand_parameters_t)::et_parameters
  type(reference_et_demand_forcing_t)::et_forcing
  type(reference_et_demand_canopy_view_t)::et_canopy
  type(reference_et_demand_result_t)::demand
  type(reference_et_demand_diagnostics_t)::et_diagnostics
  call get_command_argument(1,swp);call get_command_argument(2,crp);call get_command_argument(3,met)
  call basename(crp,'.crp');call basename(met,'.met')
  call rdinit(74,0,trim(swp))
  call rdstim('tstart',tstart);call rdstim('tend',tend)
  call require(all(ieee_is_finite([tstart,tend])),'nonfinite simulation calendar')
  call require(tstart==aint(tstart).and.tend==aint(tend).and.tend>=tstart.and.tend-tstart<2048d0,'whole day capacity')
  call rdsinr('swcrop',0,2,mode);call require(mode==1,'native crop must be enabled')
  call rdsinr('swetr',0,1,mode);call require(mode==1,'only prescribed ETref')
  call rdscha('metfil',declared);call lowerc(declared)
  call require(trim(declared)==trim(met),'METFIL mismatch')
  call rdatim('cropstart',starts,64,ncrop);call require(ncrop==1,'one crop period required')
  call rdinne('cropend',n);call require(n==ncrop,'cropend count')
  call rdftim('cropend',ends,64,n);call require(n==ncrop,'cropend count')
  call rdinne('cropfil',n);call require(n==ncrop,'cropfil count')
  call rdfcha('cropfil',names,64,n);call require(n==ncrop,'cropfil count')
  call rdinne('croptype',n);call require(n==ncrop,'croptype count')
  call rdfinr('croptype',1,2,crop_types,64,n);call require(n==ncrop.and.crop_types(1)==1,'only simple crop')
  call lowerc(names(1))
  call require(trim(names(1))//'.crp'==trim(crp),'CROPFIL mismatch')
  call require(starts(1)==aint(starts(1)).and.ends(1)==aint(ends(1)),'whole crop days required')
  call require(tstart<=starts(1),'simulation must begin before or on emergence')
  call initialize_crop_calendar(starts(:1),ends(:1),calendar,status)
  call require(status==CROP_CAL_OK,'crop calendar rejected')
  call rdsdor('rds',1d0,5000d0,rds)
  call rdsdor('cfevappond',0d0,10d0,et_parameters%pond_evaporation_factor)
  call zero_switch('swcfbs',1);call zero_switch('swredu',2)
  call zero_switch('swmetdetail',1);call zero_switch('swdivide',1)
  close(74)
  call rdinit(74,0,trim(crp))
  call rdsinr('idev',1,2,parameters%development_mode)
  if(parameters%development_mode==1)then
    call rdsinr('lcc',1,366,parameters%cycle_days)
    ! Original IDEV=1 does not read TBASE. It has no effect on DVS.
    ! The preparation adapter reports only DVS/LAI, never that undefined TSUM.
  else
    call rdsdor('tsumea',0d0,1d4,parameters%emergence_anthesis_degree_days)
    call rdsdor('tsumam',0d0,1d4,parameters%anthesis_maturity_degree_days)
    call rdsdor('tbase',-10d0,30d0,parameters%base_temperature_c)
  end if
  call initialize_fixed_crop(parameters,state,status);call require(status==FIXED_CROP_OK,'invalid phenology')
  call zero_switch('swprep',1);call zero_switch('swsow',3);call zero_switch('swgerm',3)
  call zero_switch('swco2',1)
  call rdsinr('swinter',0,3,mode);call require(mode==0,'interception requires physical composition')
  call rdsinr('swcf',1,2,mode);call require(mode==1,'ETref needs crop factors')
  if(rdinqr('swgc'))call require(.false.,'deprecated SWGC not selected')
  call read_table('laitb',0d0,2d0,0d0,12d0,x,y)
  call construct_wofost_rate_table(x,y,leaf_table,status);call require(status==WOFOST_RATE_TABLE_OK,'LAITB')
  call read_table('cftb',0d0,2d0,0d0,2d0,cf_x,cf_y)
  call rdsdor('kdir',0d0,2d0,kdir);call rdsdor('kdif',0d0,2d0,kdif)
  call construct_crop_et_canopy_parameters(kdir,kdif,cf_x,cf_y,.false.,canopy_parameters,status)
  call require(status==CROP_ET_CANOPY_OK,'canopy parameters')
  mode=1
  if(rdinqr('swrd'))call rdsinr('swrd',1,3,mode)
  call require(mode==1,'only DVS root depth selected')
  call read_table('rdtb',0d0,3d0,0d0,1000d0,x,y)
  call construct_wofost_rate_table(x,y,depth_table,status);call require(status==WOFOST_RATE_TABLE_OK,'RDTB')
  swharv=0;dvsend=2d0
  if(rdinqr('swharv'))call rdsinr('swharv',0,1,swharv)
  if(swharv==1.and.rdinqr('dvsend'))call rdsdor('dvsend',0d0,2d0,dvsend)
  close(74)
  call rdinit(74,0,trim(met))
  call rdinne('yyyy',n);call require(n>=1.and.n<=100000,'MET capacity')
  allocate(dd(n),mm(n),yyyy(n),tmin(n),tmax(n),etref(n),times(n))
  call rdfinr('dd',1,31,dd,n,n);call rdfinr('mm',1,12,mm,n,n);call rdfint('yyyy',yyyy,n,n)
  call rdfdor('tmin',-1d5,1d5,tmin,n,n);call rdfdor('tmax',-1d5,1d5,tmax,n,n)
  call rdfdor('etref',0d0,100d0,etref,n,n)
  close(74)
  call require(all(ieee_is_finite(tmin)).and.all(ieee_is_finite(tmax)).and.all(ieee_is_finite(etref)),'nonfinite weather')
  do i=1,n
    datea=0;datea(1:3)=[yyyy(i),mm(i),dd(i)];call dtardp(datea,0.0,times(i))
    if(i>1)call require(times(i)-times(i-1)==1d0,'MET must be consecutive and unique')
  end do
  call require(times(1)<=tstart.and.times(n)>=tend,'incomplete MET calendar')
  first=nint(tstart-times(1))+1;last=nint(tend-times(1))+1
  allocate(output(9,last-first+1));output=0d0;harvested=.false.
  do i=first,last
    j=i-first+1
    call calendar%select_at(times(i),crop_index,active,starts_today,status)
    call require(status==CROP_CAL_OK.or.status==CROP_CAL_OUTSIDE,'calendar selection')
    active=active.and..not.harvested
    canopy_state=crop_et_canopy_state_view_t();lai=0d0;rd=0d0
    if(active)then
      call leaf_table%evaluate(state%development_stage,lai,status);call require(status==0,'leaf state')
      call evaluate_crop_root_depth_dvs(depth_table,state%development_stage,rds,rd,status)
      call require(status==CROP_ROOT_DEPTH_DVS_OK,'root depth')
      canopy_state%crop_emerged=.true.;canopy_state%development_stage=state%development_stage
      canopy_state%leaf_area_index=lai
    end if
    call evaluate_crop_et_canopy_view(canopy_parameters,canopy_state,canopy_forcing,canopy,canopy_diagnostics)
    call require(canopy_diagnostics%status==CROP_ET_CANOPY_OK.and.canopy_diagnostics%result_produced,'canopy')
    et_canopy%crop_emerged=active;et_canopy%vegetation_cover_fraction=canopy%vegetation_cover_fraction
    et_canopy%crop_factor=canopy%crop_factor;et_canopy%co2_transpiration_factor=canopy%co2_transpiration_factor
    et_forcing%reference_et_mm_per_day=etref(i)
    call evaluate_restricted_reference_et_demand(et_parameters,et_forcing,et_canopy,demand,et_diagnostics)
    call require(et_diagnostics%status==REF_ET_DEMAND_OK.and.et_diagnostics%result_produced,'ETref')
    output(:,j)=[times(i),merge(1d0,0d0,active),merge(state%development_stage,0d0,active), &
      lai,canopy%vegetation_cover_fraction,rd,demand%potential_transpiration_cm_per_day, &
      demand%potential_soil_evaporation_cm_per_day,demand%potential_pond_evaporation_cm_per_day]
    if(active)then
      call propose_fixed_crop_day(parameters,state,.5d0*(tmin(i)+tmax(i)),candidate,status)
      call require(status==FIXED_CROP_OK,'phenology day')
      state=candidate
      if(swharv==1.and.state%development_stage>=dvsend)harvested=.true.
    end if
  end do
  ! All validation and computation precede output creation.
  open(newunit=u,file='crop_daily.csv',status='new',action='write')
  write(u,'(A)')'t1900,active,dvs,lai,cover,root_depth_cm,transpiration_cm_day,soil_evaporation_cm_day,pond_evaporation_cm_day'
  do j=1,size(output,2)
    write(u,'(ES25.16E3,8(A,ES25.16E3))')output(1,j),',',output(2,j),',',output(3,j),',',output(4,j), &
      ',',output(5,j),',',output(6,j),',',output(7,j),',',output(8,j),',',output(9,j)
  end do
  close(u)
  print '(A)','SWP_NATIVE_SIMPLE_CROP_PREPARED'
contains
  subroutine require(ok,message)
    logical,intent(in)::ok
    character(*),intent(in)::message
    if(.not.ok)then
      print '(A)','SWP_CROP_REJECTED: '//message
      error stop 1
    end if
  end subroutine
  subroutine basename(name,suffix)
    character(*),intent(in)::name,suffix
    integer::length
    length=len_trim(name)
    call require(length>len(suffix),'filename required')
    call require(index(name,'/')==0.and.index(name,'..')==0.and.index(name,achar(92))==0,'basename required')
    call require(name(length-len(suffix)+1:length)==suffix,'filename suffix')
  end subroutine
  subroutine zero_switch(name,maximum)
    character(*),intent(in)::name
    integer,intent(in)::maximum
    integer::value
    if(.not.rdinqr(name))return
    call rdsinr(name,0,maximum,value);call require(value==0,'unsupported '//name)
  end subroutine
  subroutine read_table(name,xmin,xmax,ymin,ymax,x,y)
    character(*),intent(in)::name
    real(real64),intent(in)::xmin,xmax,ymin,ymax
    real(real64),allocatable,intent(out)::x(:),y(:)
    real(real64),allocatable::flat(:)
    integer::count,k
    call rdinne(name,count);call require(count>=4.and.count<=1000.and.mod(count,2)==0,'table size '//name)
    allocate(flat(count));call rdfdou(name,flat,count,count)
    call require(all(ieee_is_finite(flat)),'nonfinite '//name)
    x=flat(1::2);y=flat(2::2)
    call require(all(x>=xmin).and.all(x<=xmax).and.all(y>=ymin).and.all(y<=ymax),'table domain '//name)
    do k=2,size(x)
      call require(x(k)>x(k-1),'table order '//name)
    end do
  end subroutine
end program
