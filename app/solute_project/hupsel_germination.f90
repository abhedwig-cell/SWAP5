! Original maize pre-emergence lifecycle adapter. Existing germination law and
! lifecycle continuation own the state; this file only binds original input,
! accepted physical sampling, daily publication and joint persistence.
module mod_hupsel_germination
 use iso_fortran_env,only:real64,int64,int8,int32
 use ieee_arithmetic,only:ieee_is_finite
 use mod_crop_fixed_phenology
 use mod_crop_root_depth_rate_owner
 use mod_crop_root_profile_static
 use mod_wofost_rate_table
 use mod_pmdirect_swetr0_process
 use mod_root_water_uptake_process
 use mod_root_uptake_compensation
 use mod_crop_lifecycle_continuation
 use mod_crop_lifecycle_daily_composition
 use mod_fmr_wofost_accepted_window_lineage
 use mod_crop_germination_preflight
 use mod_crop_b111_pressure_head_average
 use mod_kernel_transactions
 use mod_transaction_reference,only:transaction_state_t
 use mod_fmr_serialized_reference_backend
 use mod_pond_thermal_restart_file
 use mod_fmr_runtime_core
 use mod_fmr_b111_matrix_solute_route
 use mod_age_joint_restart_file,only:crc32
 implicit none
 private
 public::hupsel_germination_t
 type::hupsel_germination_t
  type(crop_lifecycle_continuation_t)::lifecycle
  real(real64)::simulation_days=0d0
  real(real64)::crop_start=0d0,optimal=0d0,tbase=0d0,teff=0d0,dry=0d0,wet=0d0,a=0d0,zgerm=0d0
  real(real64)::last_pressure=0d0
  integer(int32)::source_crc=0
  type(fixed_crop_parameters_t)::phenology_parameters
  type(fixed_crop_state_t)::phenology
  type(crop_root_depth_rate_parameters_t)::root_parameters
  type(crop_root_depth_rate_state_t)::roots
  type(wofost_rate_table_t)::leaf_table,factor_table,root_table
  type(root_water_uptake_parameters_t)::uptake_parameters
  type(root_compensation_config_t)::compensation
  type(pmdirect_swetr0_site_t)::site
  real(real64)::crop_end=0d0,next_crop_start=0d0,kdir=0d0,kdif=0d0,cofab=0d0
  real(real64)::rad(10000),tmn(10000),tmx(10000),humidity(10000),wind(10000),rain(10000)
  integer::weather_days=0,weather_day_of_year(10000)=0
  real(real64)::daily_potential=0d0
  logical::active_today=.false.
  integer::source_maxit=0,source_maxbacktrack=0,source_swkmean=0
  real(real64)::source_dtmax=0d0,source_dtmin=0d0
 contains
  procedure::initialize
  procedure::prepare
  procedure::day_begin
  procedure::day_end
  procedure::write_restart
  procedure::read_restart
 end type
contains
 subroutine input_bytes(path,b,status)
  character(*),intent(in)::path
  integer(int8),allocatable,intent(out)::b(:)
  integer,intent(out)::status
  integer::n,u,io
  status=1;inquire(file=path,size=n,iostat=io)
  if(io/=0.or.n<1.or.n>10485760)return
  allocate(b(n));open(newunit=u,file=path,access='stream',form='unformatted',status='old',iostat=io)
  if(io/=0)return
  read(u,iostat=io)b;close(u);if(io==0)status=0
 end subroutine
 subroutine initialize(self,swp,crp,status)
  class(hupsel_germination_t),intent(inout)::self
  character(*),intent(in)::swp,crp
  integer,intent(out)::status
  real(real64)::start,finish,dates(64),ends(64),rds
  real(real64)::tab(2048)
  integer::length
  integer::n,mode,i,dates_met(6),dd_met(10000),mm_met(10000),yy_met(10000)
  real(real64)::date_met,jan1_met
  integer(int8),allocatable::raw(:),rawswp(:)
  status=1
  call input_bytes(crp,raw,n);if(n/=0)return
  call input_bytes(swp,rawswp,n);if(n/=0)return
  self%source_crc=crc32([rawswp,raw])
  call rdinit(74,0,swp);call rdstim('tstart',start);call rdstim('tend',finish)
  self%simulation_days=finish-start+1d0
  call rdatim('cropstart',dates,64,n)
  if(n<1)then;close(74);return;end if
  self%crop_start=dates(1)-start;self%next_crop_start=dates(2)-start
  call rdatim('cropend',ends,64,n);self%crop_end=ends(1)-start
  call rdsdou('lat',self%site%latitude_degrees);call rdsdou('alt',self%site%altitude_m)
  call rdsdou('altw',self%site%wind_measurement_height_m);call rdsdou('alth',self%site%humidity_measurement_height_m)
  call rdsdou('angstroma',self%site%angstrom_a);call rdsdou('angstromb',self%site%angstrom_b)
  call rdsdou('fwind',self%site%wind_function_factor);call rdsdou('rsoil',self%site%soil_surface_resistance_s_m)
  call rdsdou('rds',rds)
  call rdsint('maxit',self%source_maxit);call rdsint('maxbacktr',self%source_maxbacktrack)
  call rdsint('swkmean',self%source_swkmean)
  call rdsdou('dtmax',self%source_dtmax);call rdsdou('dtmin',self%source_dtmin)
  if(self%source_dtmax<=0d0.or.self%source_dtmax>1d0)then;close(74);return;end if
  close(74)
  call rdinit(74,0,crp)
  call rdsint('swprep',mode);if(mode/=0)then;close(74);return;end if
  call rdsint('swsow',mode);if(mode/=0)then;close(74);return;end if
  call rdsint('swgerm',mode);if(mode/=2)then;close(74);return;end if
  call rdsdou('tsumemeopt',self%optimal);call rdsdou('tbasem',self%tbase);call rdsdou('teffmx',self%teff)
  call rdsdou('hdrygerm',self%dry);call rdsdou('hwetgerm',self%wet);call rdsdou('agerm',self%a)
  call rdsdou('zgerm',self%zgerm)
  call rdsint('idev',self%phenology_parameters%development_mode)
  call rdsdou('tsumea',self%phenology_parameters%emergence_anthesis_degree_days)
  call rdsdou('tsumam',self%phenology_parameters%anthesis_maturity_degree_days)
  call rdsdou('tbase',self%phenology_parameters%base_temperature_c)
  call initialize_fixed_crop(self%phenology_parameters,self%phenology,mode);if(mode/=0)then;close(74);return;end if
  call rdsint('swrd',mode);if(mode/=2)then;close(74);return;end if
  call rdsint('swwrtnonox',mode);if(mode/=0)then;close(74);return;end if
  call rdsint('swdmi2rd',mode);if(mode/=1)then;close(74);return;end if
  call rdsdou('rdi',self%root_parameters%initial_root_depth_cm)
  call rdsdou('rri',self%root_parameters%maximum_daily_extension_cm)
  call rdsdou('rdc',self%root_parameters%maximum_root_depth_cm)
  self%root_parameters%maximum_root_depth_cm=min(rds,self%root_parameters%maximum_root_depth_cm)
  self%root_parameters%require_root_growth=.false.;self%root_parameters%actual_extension_mode=CROP_ROOT_RATE_WATER_SCALED
  self%root_parameters%negligible_transpiration=1d-10;self%root_parameters%negligible_extension=1d-6
  call initialize_crop_root_depth_rate_state(self%root_parameters,self%roots,mode);if(mode/=0)then;close(74);return;end if
  call rdsdou('kdir',self%kdir);call rdsdou('kdif',self%kdif);call rdsdou('cofab',self%cofab)
  call rdsint('swinter',mode);if(mode/=1)then;close(74);return;end if
  call rdsint('swcf',mode);if(mode/=1)then;close(74);return;end if
  call rdsint('swdrought',mode);if(mode/=1)then;close(74);return;end if
  call rdsint('swoxygen',mode);if(mode/=1)then;close(74);return;end if
  call rdsint('swcompensate',self%compensation%method);if(self%compensation%method/=ROOT_COMP_JARVIS)then;close(74);return;end if
  call rdsint('swstressor',self%compensation%stressor);call rdsdou('alphacrit',self%compensation%alpha_critical)
  self%uptake_parameters%empirical_oxygen_enabled=.true.
  call rdsdou('hlim1',self%uptake_parameters%hlim1);call rdsdou('hlim2u',self%uptake_parameters%hlim2u)
  call rdsdou('hlim2l',self%uptake_parameters%hlim2l);call rdsdou('hlim3l',self%uptake_parameters%hlim3l)
  call rdsdou('hlim3h',self%uptake_parameters%hlim3h);call rdsdou('hlim4',self%uptake_parameters%hlim4)
  call rdsdou('adcrl',self%uptake_parameters%adcrl);call rdsdou('adcrh',self%uptake_parameters%adcrh)
  call read_table('laitb',self%leaf_table);call read_table('cftb',self%factor_table);call read_table('rdctb',self%root_table)
  close(74)
  call rdinit(74,0,'283.met');call rdinne('yyyy',self%weather_days)
  if(self%weather_days<1.or.self%weather_days>10000)then;close(74);return;end if
  call rdfint('dd',dd_met,10000,self%weather_days);call rdfint('mm',mm_met,10000,self%weather_days)
  call rdfint('yyyy',yy_met,10000,self%weather_days)
  do i=1,self%weather_days
   dates_met=0;dates_met(:3)=[yy_met(i),mm_met(i),dd_met(i)]
   call dtardp(dates_met,0.,date_met)
   if(date_met/=start+i-1d0)then;close(74);return;end if
   dates_met(2:3)=[1,1];call dtardp(dates_met,0.,jan1_met)
   self%weather_day_of_year(i)=nint(date_met-jan1_met)+1
  end do
  call rdfdou('rad',self%rad,10000,self%weather_days);call rdfdou('tmin',self%tmn,10000,self%weather_days)
  call rdfdou('tmax',self%tmx,10000,self%weather_days);call rdfdou('hum',self%humidity,10000,self%weather_days)
  call rdfdou('wind',self%wind,10000,self%weather_days);call rdfdou('rain',self%rain,10000,self%weather_days)
  close(74)
  call initialize_b111_crop_lifecycle(615001_int64,0,0,2,self%lifecycle,status)
 end subroutine
 subroutine read_table(name,table)
  character(*),intent(in)::name
  type(wofost_rate_table_t),intent(out)::table
  real(real64)::v(2048)
  integer::n,code
  call rdinne(name,n);call rdfdou(name,v,2048,n)
  call construct_wofost_rate_table(v(1:n:2),v(2:n:2),table,code)
  if(code/=0)error stop 'invalid original crop table'
 end subroutine
 subroutine prepare(self,time,water,p,soil,pond,rain,potential,active,depth,status)
  class(hupsel_germination_t),intent(inout)::self
  real(real64),intent(in)::time
  type(kernel_committed_state_t),intent(in)::water
  type(fmr_b110_physical_parameters_t),intent(inout)::p
  real(real64),intent(out)::soil,pond,rain,potential,depth
  logical,intent(out)::active
  integer,intent(out)::status
  type(pmdirect_swetr0_weather_t)::weather
  type(pmdirect_swetr0_canopy_t)::canopy
  type(pmdirect_swetr0_daily_result_t)::daily
  type(pmdirect_swetr0_interval_result_t)::interval
  type(pmdirect_swetr0_diagnostics_t)::diagnostic
  integer::day,code
  real(real64)::factor
  status=1;day=int(time)+1
  if(day<1.or.day>self%weather_days)return
  active=self%lifecycle%germinated.and.time>=self%crop_start.and.time<=self%crop_end
  self%active_today=active;depth=0d0
  weather%day_of_year=self%weather_day_of_year(day)
  weather%radiation_j_m2_d=1000d0*self%rad(day)
  weather%minimum_air_temperature_c=self%tmn(day);weather%maximum_air_temperature_c=self%tmx(day)
  weather%vapour_pressure_kpa=self%humidity(day);weather%wind_speed_m_s=self%wind(day)
  weather%gross_rain_cm_d=.1d0*self%rain(day)
  if(active)then
   canopy%crop_emerged=.true.;canopy%albedo=.23d0;canopy%dry_canopy_resistance_s_m=70d0
   call self%leaf_table%evaluate(self%phenology%development_stage,canopy%lai,code);if(code/=0)return
   call self%factor_table%evaluate(self%phenology%development_stage,factor,code);if(code/=0)return
   canopy%vegetation_cover_fraction=1d0-exp(-self%kdir*self%kdif*canopy%lai)
   canopy%cofab_cm=self%cofab;depth=self%roots%actual_root_depth_cm
  end if
  call evaluate_pmdirect_swetr0_daily(weather,self%site,canopy,daily,diagnostic);if(diagnostic%status/=0)return
  ! Source SWDIVIDE1 already separates dry canopy/soil; SWCF1 uses
  ! reference albedo/resistance and does not scale ET by CFTB here.
  call apply_swinter1_daily_interval(weather,canopy,daily,interval,diagnostic);if(diagnostic%status/=0)return
  soil=daily%potential_soil_evaporation_cm_per_day;pond=daily%potential_pond_evaporation_cm_per_day
  rain=interval%net_rain_cm_per_day;potential=interval%potential_transpiration_cm_per_day
  self%daily_potential=potential
  status=0
 end subroutine
 subroutine day_begin(self,time,water,status)
  class(hupsel_germination_t),intent(inout)::self
  real(real64),intent(in)::time
  type(kernel_committed_state_t),intent(in)::water
  integer,intent(out)::status
  class(transaction_state_t),allocatable::physical
  type(kernel_parameter_identity_t)::identity
  logical::ok
  integer::code
  status=1
  if(.not.self%lifecycle%ready())return
  if(.not.ieee_is_finite(time))return
  ! Original previous-day gate: germination completion becomes emergence on
  ! the following day; do not continue bare soil past that physical event.
  if(time>=self%next_crop_start)return
  ! Original croprotation(2) samples H_AVERAGE before this day's water solve.
  if(time>=self%crop_start.and.time==aint(time).and..not.self%lifecycle%germinated)then
    call water%certified_parameter_identity(identity,ok);if(.not.ok)return
    call water%snapshot(physical,ok);if(.not.ok)return
    select type(q=>physical)
    class is(fmr_b110_physical_state_t)
      call compute_b111_pressure_head_average(self%zgerm,identity%dz,q%pressure_head,self%last_pressure,code)
      if(code/=0)return
    class default
      return
    end select
  end if
  status=0
 end subroutine
 subroutine day_end(self,time,temperature,water,status,uptake)
  class(hupsel_germination_t),intent(inout)::self
  real(real64),intent(in)::time,temperature
  type(kernel_committed_state_t),intent(in)::water
  integer,intent(out)::status
  real(real64),optional,intent(in)::uptake
  type(fixed_crop_state_t)::next_phenology
  type(crop_root_depth_rate_state_t)::next_roots
  type(crop_root_depth_rate_daily_forcing_t)::root_forcing
  type(crop_root_depth_rate_diagnostics_t)::root_diagnostic
  type(crop_germination_candidate_t)::proposal
  type(crop_lifecycle_continuation_t)::next
  type(crop_daily_lifecycle_candidate_t)::plan
  type(fmr_wofost_crop_event_identity_persistence_t)::event_view
  type(fmr_wofost_crop_event_identity_t)::event
  class(transaction_state_t),allocatable::physical
  type(kernel_parameter_identity_t)::identity
  logical::ok
  integer::code
  real(real64)::clock
  status=1
  call water%current_time(clock,ok);if(.not.ok.or.clock/=time)return
  if(time<self%crop_start+1d0.or.time/=aint(time))then;status=0;return;end if
  if(self%active_today)then
    if(.not.present(uptake))return
    call propose_fixed_crop_day(self%phenology_parameters,self%phenology,temperature,next_phenology,code)
    if(code/=0)return
    root_forcing%potential_transpiration=self%daily_potential;root_forcing%actual_root_uptake=min(uptake,self%daily_potential)
    ! Daily uptake accounting is certified before this call. Cap the derived
    ! extension factor at its physical maximum1 for summation roundoff only;
    ! the accepted water/solute sink and budgets are not modified.
    if(uptake>self%daily_potential+1d-12)return
    call evaluate_crop_root_depth_rate_candidate(self%root_parameters,self%roots,root_forcing,next_roots,root_diagnostic,code)
    if(code/=0)return
    self%phenology=next_phenology;self%roots=next_roots;status=0;return
  end if
  if(time>self%crop_end+1d0)then;status=0;return;end if
  call propose_crop_germination(2,self%lifecycle%germination_temperature_sum,self%optimal,self%tbase,self%teff, &
    temperature,self%last_pressure,self%dry,self%wet,self%a,proposal,code)
  if(code/=0.or..not.proposal%valid)return
  ! Publication after certified physical acceptance. No trial/retry modifies
  ! this continuation. Prepared/sown are literal task2 values, not inferred.
  event_view%valid=.true.;event_view%lineage_id=water%current_lineage_id()
  event_view%final_revision=water%current_revision();event_view%t0=time-1d0;event_view%t1=time
  call reconstruct_wofost_crop_event_identity_from_persistence(event_view,event,code)
  if(code/=0)return
  plan%valid=.true.;plan%initialization_profile=CROP_PROFILE_B111_TASK2
  plan%prepared=.true.;plan%sown=.true.;plan%germination_evaluated=.true.
  plan%germinated=proposal%complete;plan%emergence_eligible=proposal%complete
  call propose_crop_lifecycle_continuation(self%lifecycle,plan,proposal,self%lifecycle%revision,event,next,code)
  if(code/=0)return
  self%lifecycle=next;status=0
 end subroutine
 subroutine write_restart(self,path,column,template,water_id,p,water,chemical,status)
  class(hupsel_germination_t),intent(in)::self
  character(*),intent(in)::path
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id
  type(fmr_b110_physical_parameters_t),intent(in)::p
  type(kernel_committed_state_t),intent(in)::water
  type(matrix_solute_state_t),intent(in)::chemical
  integer,intent(out)::status
  integer(int8),allocatable::raw(:),allbytes(:)
  integer::u,io,code
  real(real64)::clock
  logical::ok
  status=1;if(.not.self%lifecycle%ready())return
  call water%current_time(clock,ok);if(.not.ok)return
  call write_pond_thermal_restart(path//'.physical',column,template,water_id,p,water,chemical,code)
  if(code/=0)return
  call input_bytes(path//'.physical',raw,code);if(code/=0)return
  open(newunit=u,file=path//'.pending',access='stream',form='unformatted',status='replace',iostat=io)
  if(io/=0)return
  write(u,iostat=io)'S5HG0002',self%source_crc,clock,self%lifecycle%revision, &
    self%lifecycle%germination_temperature_sum,self%lifecycle%germinated,self%last_pressure, &
    self%phenology%completed_days,self%phenology%development_stage,self%phenology%temperature_sum_degree_days, &
    self%roots%actual_root_depth_cm,self%roots%potential_root_depth_cm,size(raw),raw
  close(u);if(io/=0)return
  call input_bytes(path//'.pending',allbytes,code);if(code/=0)return
  open(newunit=u,file=path//'.pending',access='stream',form='unformatted',status='old',position='append',iostat=io)
  if(io/=0)return
  write(u,iostat=io)crc32(allbytes);flush(u);close(u);if(io/=0)return
  call rename(path//'.pending',path,code);if(code/=0)return
  open(newunit=u,file=path//'.physical',status='old');close(u,status='delete')
  status=0
 end subroutine
 subroutine read_restart(self,path,column,template,water_id,chemical_id,p,chemistry,water,chemical,status)
  use mod_b111_reactive_solute_substep,only:b111_reactive_solute_substep_forcing_t
  class(hupsel_germination_t),intent(inout)::self
  character(*),intent(in)::path
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id,chemical_id
  type(fmr_b110_physical_parameters_t),intent(in)::p
  type(b111_reactive_solute_substep_forcing_t),intent(in)::chemistry
  type(kernel_committed_state_t),intent(inout)::water
  type(matrix_solute_state_t),intent(inout)::chemical
  integer,intent(out)::status
  type(kernel_committed_state_t)::w
  type(matrix_solute_state_t)::c
  type(crop_lifecycle_continuation_t)::next
  type(fixed_crop_state_t)::fixed_next
  type(crop_root_depth_rate_state_t)::root_next
  integer(int8),allocatable::allbytes(:),raw(:)
  integer(int32)::checksum,binding
  integer::u,io,code,n,position
  real(real64)::clock,physical_clock,pressure
  character(8)::tag
  logical::ok
  status=1
  call input_bytes(path,allbytes,code);if(code/=0)return
  if(size(allbytes)<64)return
  checksum=transfer(allbytes(size(allbytes)-3:),checksum)
  if(crc32(allbytes(:size(allbytes)-4))/=checksum)return
  open(newunit=u,file=path,access='stream',form='unformatted',status='old',iostat=io);if(io/=0)return
  next=self%lifecycle
  read(u,iostat=io)tag,binding,clock,next%revision,next%germination_temperature_sum,next%germinated,pressure, &
    fixed_next%completed_days,fixed_next%development_stage,fixed_next%temperature_sum_degree_days, &
    root_next%actual_root_depth_cm,root_next%potential_root_depth_cm,n
  if(io/=0.or.tag/='S5HG0002'.or.binding/=self%source_crc.or.n<1.or.n>10485760)then;close(u);return;end if
  if(root_next%validate()/=0)then;close(u);return;end if
  if(.not.self%root_parameters%ready())then;close(u);return;end if
  if(max(root_next%actual_root_depth_cm,root_next%potential_root_depth_cm)> &
     self%root_parameters%maximum_root_depth_cm)then;close(u);return;end if
  if(.not.all(ieee_is_finite([fixed_next%development_stage,fixed_next%temperature_sum_degree_days])))then
    close(u);return
  end if
  if(fixed_next%development_stage<0d0.or.fixed_next%development_stage>2d0.or. &
     fixed_next%temperature_sum_degree_days<0d0.or.fixed_next%temperature_sum_degree_days>1d10.or. &
     fixed_next%completed_days<0.or.fixed_next%completed_days>=100000)then;close(u);return;end if
  fixed_next%initialized=.true.
  if(.not.next%ready().or..not.all(ieee_is_finite([clock,pressure])))then;close(u);return;end if
  if(clock/=aint(clock).or.clock<0d0.or.clock>self%simulation_days)then;close(u);return;end if
  if(fixed_next%completed_days>int(clock))then;close(u);return;end if
  inquire(unit=u,pos=position)
  if(size(allbytes)/=position-1+n+4)then;close(u);return;end if
  allocate(raw(n));read(u,iostat=io)raw;close(u);if(io/=0)return
  open(newunit=u,file=path//'.readphysical',access='stream',form='unformatted',status='replace',iostat=io)
  if(io/=0)return
  write(u,iostat=io)raw;close(u);if(io/=0)return
  call read_pond_thermal_restart(path//'.readphysical',column,template,water_id,chemical_id,p,chemistry,w,c,code)
  open(newunit=u,file=path//'.readphysical',status='old');close(u,status='delete')
  if(code/=0)return
  call w%current_time(physical_clock,ok);if(.not.ok.or.physical_clock/=clock)return
  self%lifecycle=next;self%last_pressure=pressure;self%phenology=fixed_next;self%roots=root_next
  water=w;chemical=c;status=0
 end subroutine
end module
