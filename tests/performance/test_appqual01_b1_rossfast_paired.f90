program test_appqual01_b1_rossfast_paired
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK
  use mod_fmr_rossfast_solver_selection_binding, only: FMR_ROSSFAST_SOLVER_MODEL_KEY
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_HARD_MASS_TOL_CM
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY, ROSSFAST_D3R_RETRY_SCALE, &
       ROSSFAST_D3R_MAX_FULL_INDEX
  implicit none

  real(real64), parameter :: INITIAL_HEAD_CM=-101.0_real64
  type(rossfast_d3r_material_t) :: material
  character(len=16) :: route
  character(len=32) :: arg
  integer :: n,status
  logical :: found
  real(real64) :: init_s,run_s,max_mass
  integer(int64) :: c0,c1,rate

  call get_command_argument(1,arg); read(arg,*) n
  call get_command_argument(2,route)
  if(n<=0) error stop 'APPQUAL01 paired requires N>0'
  if(trim(route)/='REFERENCE' .and. trim(route)/='ROSSFAST') error stop 'APPQUAL01 invalid route'

  call rossfast_d3r_material_from_id('B01',material,found)
  if(.not.found) error stop 'APPQUAL01 B01 authority missing'

  call run_route(n,trim(route),material,init_s,run_s,max_mass,status)
  if(status/=FMR_APP_BOOT_OK) error stop 'APPQUAL01 paired production route failed'

  write(*,'(A,A,A,I0,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16)') &
       'APPQUAL01_B1_PAIRED,route=',trim(route),',n=',n,',init_seconds=',init_s,',run_seconds=',run_s, &
       ',ns_per_column=',1.0e9_real64*run_s/real(n,real64),',max_mass_residual=',max_mass
  write(*,'(A,A,A)') 'APPQUAL01_B1_PAIRED_',trim(route),'=PASS'

contains

  subroutine run_route(count,route_name,mat,init_seconds,run_seconds,max_residual,status)
    integer,intent(in) :: count
    character(len=*),intent(in) :: route_name
    type(rossfast_d3r_material_t),intent(in) :: mat
    real(real64),intent(out) :: init_seconds,run_seconds,max_residual
    integer,intent(out) :: status
    type(fmr_production_application_config_t) :: config
    type(fmr_production_application_bootstrap_t) :: app
    type(fmr_serialized_column_result_t),allocatable :: results(:)
    integer(int64) :: t0,t1,freq

    call build_config(config,count,route_name,mat)
    call system_clock(t0,freq)
    call app%initialize(config,status)
    call system_clock(t1)
    write(*,'(A,A,A,I0)') 'APPQUAL01_B1_STAGE,route=',trim(route_name),',init_status=',status
    if(status/=FMR_APP_BOOT_OK) return
    init_seconds=real(t1-t0,real64)/real(freq,real64)

    call system_clock(t0)
    call app%run_standalone(0.0_real64,ROSSFAST_D3R_OUTER_HORIZON_DAY,results,status)
    call system_clock(t1)
    write(*,'(A,A,A,I0)') 'APPQUAL01_B1_STAGE,route=',trim(route_name),',run_status=',status
    if(allocated(results)) then
      write(*,'(A,A,A,I0)') 'APPQUAL01_B1_STAGE,route=',trim(route_name),',result_count=',size(results)
      if(size(results)>0) then
        write(*,'(A,A,A,L1,A,L1,A,A)') 'APPQUAL01_B1_STAGE,route=',trim(route_name),',completed=',results(1)%completed, &
             ',committed=',results(1)%committed,',admission=',trim(results(1)%admission_status)
      end if
    end if
    if(status/=FMR_APP_BOOT_OK) return
    run_seconds=real(t1-t0,real64)/real(freq,real64)
    if(.not.allocated(results) .or. size(results)/=count) error stop 'APPQUAL01 paired result shape'
    if(.not.all(results%completed) .or. .not.all(results%committed)) error stop 'APPQUAL01 paired incomplete'
    max_residual=maxval(abs(results%mass%residual))
    if(max_residual>ROSSFAST_D3R_HARD_MASS_TOL_CM) error stop 'APPQUAL01 paired mass gate'
    call app%close(status)
  end subroutine run_route

  subroutine build_config(value,count,route_name,mat)
    type(fmr_production_application_config_t),intent(out) :: value
    integer,intent(in) :: count
    character(len=*),intent(in) :: route_name
    type(rossfast_d3r_material_t),intent(in) :: mat
    integer :: k

    value%initial_time=0.0_real64
    value%numerical%transaction%mass_tolerance=ROSSFAST_D3R_HARD_MASS_TOL_CM
    value%numerical%max_committed_substeps=32
    value%numerical%progress_tolerance=0.0_real64
    if(trim(route_name)=='ROSSFAST') then
      value%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
      value%numerical%transaction%temporal_tolerance=0.0_real64
      value%numerical%transaction%retry_scale=ROSSFAST_D3R_RETRY_SCALE
      value%numerical%transaction%max_retries=ROSSFAST_D3R_MAX_FULL_INDEX
      value%soil_water_model_key=FMR_ROSSFAST_SOLVER_MODEL_KEY
      value%soil_water_asset_root='assets/rossfast/d3r'
      value%soil_water_material_id='B01'
    else
      value%numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
      value%numerical%transaction%temporal_tolerance=1.0e-6_real64
      value%numerical%transaction%retry_scale=0.5_real64
      value%numerical%transaction%max_retries=8
    end if

    allocate(value%tiles(count))
    do k=1,count
      value%tiles(k)%tile_id=6100000_int64+int(k,int64)
      value%tiles(k)%ledger_id=7100000_int64+int(k,int64)
      value%tiles(k)%template%template_id=8100000_int64+int(k,int64)
      value%tiles(k)%template%physics_topology_id=8100010_int64
      value%tiles(k)%template%vertical_layout_id=8100020_int64
      value%tiles(k)%template%state_layout_id=8100030_int64
      value%tiles(k)%template%solver_interface_id=8100040_int64
      value%tiles(k)%template%optional_state_layout_id=0_int64
      value%tiles(k)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
      value%tiles(k)%template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
      call initialize_parameters(value%tiles(k)%parameters,9100000_int64+int(k,int64),mat)
      call initialize_state(value%tiles(k)%initial_state,mat)
      call initialize_forcing(value%tiles(k)%base_forcing,mat)
      value%tiles(k)%groundwater_datum%available=.true.
      value%tiles(k)%groundwater_datum%datum_id=9200000_int64+int(k,int64)
      value%tiles(k)%groundwater_datum%bottom_boundary_elevation_m=0.0_real64
    end do
  end subroutine build_config

  subroutine initialize_parameters(p,id,mat)
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    integer(int64),intent(in) :: id
    type(rossfast_d3r_material_t),intent(in) :: mat
    real(real64) :: m
    integer :: i
    m=1.0_real64-1.0_real64/mat%n
    p%parameter_set_id=id
    p%active_nodes=ROSSFAST_D3R_N_CELLS
    allocate(p%z(ROSSFAST_D3R_N_CELLS),p%dz(ROSSFAST_D3R_N_CELLS), &
         p%node_distance(ROSSFAST_D3R_N_CELLS),p%cofgen(24,ROSSFAST_D3R_N_CELLS))
    do i=1,ROSSFAST_D3R_N_CELLS
      p%z(i)=-ROSSFAST_D3R_DZ_CM*(real(i,real64)-0.5_real64)
    end do
    p%dz=ROSSFAST_D3R_DZ_CM
    p%node_distance=ROSSFAST_D3R_DZ_CM
    p%cofgen=0.0_real64
    do i=1,ROSSFAST_D3R_N_CELLS
      p%cofgen(1,i)=mat%theta_r; p%cofgen(2,i)=mat%theta_s
      p%cofgen(3,i)=mat%ksatfit_cm_per_day; p%cofgen(4,i)=mat%alpha_per_cm
      p%cofgen(5,i)=mat%lambda; p%cofgen(6,i)=mat%n; p%cofgen(7,i)=m
      p%cofgen(8,i)=mat%alpha_per_cm; p%cofgen(9,i)=mat%h_enpr_cm
      p%cofgen(10,i)=mat%ksatfit_cm_per_day; p%cofgen(11,i)=0.999_real64
      p%cofgen(12,i)=0.99_real64*mat%ksatfit_cm_per_day
      p%cofgen(22,i)=-1.0e6_real64; p%cofgen(23,i)=1.0e-12_real64
    end do
    p%bottom_mode=2; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=16; p%max_backtracking=8; p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=ROSSFAST_D3R_HARD_MASS_TOL_CM
    p%total_balance_tolerance=ROSSFAST_D3R_HARD_MASS_TOL_CM
    p%head_abs_tolerance=1.0e-12_real64; p%head_rel_tolerance=1.0e-12_real64
    p%ponding_tolerance=1.0e-12_real64
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.
    p%frost_active=.false.; p%soil_temperature_active=.false.; p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_state(state,mat)
    type(fmr_b110_physical_state_t),intent(out) :: state
    type(rossfast_d3r_material_t),intent(in) :: mat
    real(real64) :: theta,m,se
    m=1.0_real64-1.0_real64/mat%n
    se=(1.0_real64+abs(mat%alpha_per_cm*INITIAL_HEAD_CM)**mat%n)**(-m)
    theta=mat%theta_r+(mat%theta_s-mat%theta_r)*se
    state%active_nodes=ROSSFAST_D3R_N_CELLS
    allocate(state%pressure_head(ROSSFAST_D3R_N_CELLS),state%water_content(ROSSFAST_D3R_N_CELLS))
    state%pressure_head=INITIAL_HEAD_CM
    state%water_content=theta
    state%ponding_depth=0.0_real64
    state%groundwater_level=-999.0_real64
  end subroutine initialize_state

  subroutine initialize_forcing(forcing,mat)
    type(fmr_b110_physical_forcing_t),intent(out) :: forcing
    type(rossfast_d3r_material_t),intent(in) :: mat
    real(real64) :: m,se,term,k
    m=1.0_real64-1.0_real64/mat%n
    se=(1.0_real64+abs(mat%alpha_per_cm*INITIAL_HEAD_CM)**mat%n)**(-m)
    term=(1.0_real64-se**(1.0_real64/m))**m
    k=mat%ksatfit_cm_per_day*se**mat%lambda*(1.0_real64-term)**2
    forcing%top_flux=0.01_real64*k
    forcing%top_head=INITIAL_HEAD_CM
    forcing%bottom_flux=-0.004_real64*k
    forcing%bottom_head=-999999.0_real64
    allocate(forcing%drainage_flux_by_level(1,ROSSFAST_D3R_N_CELLS), &
         forcing%subsurface_irrigation_source(ROSSFAST_D3R_N_CELLS), &
         forcing%root_extraction_sink(ROSSFAST_D3R_N_CELLS))
    forcing%drainage_flux_by_level=0.0_real64
    forcing%subsurface_irrigation_source=0.0_real64
    forcing%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing
end program test_appqual01_b1_rossfast_paired
