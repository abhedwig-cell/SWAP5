module mod_restricted_soil_temperature
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_soil_temperature_contract, only: &
       SOIL_TEMP_OK, SOIL_TEMP_INVALID_PARAMETERS, SOIL_TEMP_INVALID_STATE, SOIL_TEMP_INVALID_INTERVAL, &
       SOIL_TEMP_INVALID_FORCING, SOIL_TEMP_INVALID_HYDRAULIC_VIEW, SOIL_TEMP_WORKSPACE_FAILURE, &
       SOIL_TEMP_LINEAR_SOLVE_FAILURE, SOIL_TEMP_ENERGY_CLOSURE_FAILURE, SOIL_TEMP_INVALID_RESTART, &
       SOIL_TEMP_INVALID_NODE, soil_temperature_parameters_t, soil_temperature_numerical_config_t, &
       soil_temperature_forcing_t, soil_temperature_state_t, soil_temperature_restart_payload_t, &
       soil_temperature_field_view_t, soil_temperature_workspace_t, soil_temperature_result_t, &
       soil_temperature_diagnostics_t, initialize_soil_temperature_state, materialize_soil_temperature_trial_state, &
       commit_soil_temperature_state, build_soil_temperature_field_view, copy_soil_temperature_profile, &
       soil_temperature_at_node, export_soil_temperature_restart, reconstruct_soil_temperature_restart, &
       SOIL_TEMP_SOLUTION_NUMERIC, SOIL_TEMP_SOLUTION_ANALYTIC, SOIL_TEMP_TOP_AIR_TEMPERATURE, &
       SOIL_TEMP_TOP_PRESCRIBED_TEMPERATURE, SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX, &
       SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION, SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX, &
       SOIL_TEMP_BOTTOM_PRESCRIBED_TEMPERATURE
  implicit none
  private

  real(real64), parameter :: WATER_TOLERANCE = 1.0e-12_real64
  real(real64), parameter :: PIVOT_TOLERANCE = 1.0e-24_real64

  ! Source-bound constants from SWAP 4.3.1 MOD_SoilTemperature/DeVries.
  real(real64), parameter :: C_QUARTZ=800.0_real64, C_CLAY=900.0_real64, C_WATER=4180.0_real64
  real(real64), parameter :: C_AIR=1010.0_real64, C_ORGANIC=1920.0_real64
  real(real64), parameter :: RHO_QUARTZ=2660.0_real64, RHO_CLAY=2650.0_real64, RHO_WATER=1000.0_real64
  real(real64), parameter :: RHO_AIR=1.2_real64, RHO_ORGANIC=1300.0_real64
  real(real64), parameter :: K_QUARTZ=8.8_real64, K_CLAY=2.92_real64, K_WATER=0.57_real64
  real(real64), parameter :: K_AIR=0.025_real64, K_ORGANIC=0.25_real64
  real(real64), parameter :: G_QUARTZ=0.14_real64, G_CLAY=0.125_real64, G_WATER=0.14_real64, G_ORGANIC=0.5_real64
  real(real64), parameter :: THETA_DRY=0.02_real64, THETA_WET=0.05_real64
  real(real64), parameter :: K_AA=1.0_real64, K_WW=1.0_real64
  real(real64), parameter :: K_QW = 0.66_real64/(1.0_real64+(K_QUARTZ/K_WATER-1.0_real64)*G_QUARTZ) + 0.33_real64/(1.0_real64+(K_QUARTZ/K_WATER-1.0_real64)*(1.0_real64-2.0_real64*G_QUARTZ))
  real(real64), parameter :: K_CW = 0.66_real64/(1.0_real64+(K_CLAY/K_WATER-1.0_real64)*G_CLAY) + 0.33_real64/(1.0_real64+(K_CLAY/K_WATER-1.0_real64)*(1.0_real64-2.0_real64*G_CLAY))
  real(real64), parameter :: K_OW = 0.66_real64/(1.0_real64+(K_ORGANIC/K_WATER-1.0_real64)*G_ORGANIC) + 0.33_real64/(1.0_real64+(K_ORGANIC/K_WATER-1.0_real64)*(1.0_real64-2.0_real64*G_ORGANIC))
  real(real64), parameter :: K_WA = 0.66_real64/(1.0_real64+(K_WATER/K_AIR-1.0_real64)*G_WATER) + 0.33_real64/(1.0_real64+(K_WATER/K_AIR-1.0_real64)*(1.0_real64-2.0_real64*G_WATER))
  real(real64), parameter :: K_QA = 0.66_real64/(1.0_real64+(K_QUARTZ/K_AIR-1.0_real64)*G_QUARTZ) + 0.33_real64/(1.0_real64+(K_QUARTZ/K_AIR-1.0_real64)*(1.0_real64-2.0_real64*G_QUARTZ))
  real(real64), parameter :: K_CA = 0.66_real64/(1.0_real64+(K_CLAY/K_AIR-1.0_real64)*G_CLAY) + 0.33_real64/(1.0_real64+(K_CLAY/K_AIR-1.0_real64)*(1.0_real64-2.0_real64*G_CLAY))
  real(real64), parameter :: K_OA = 0.66_real64/(1.0_real64+(K_ORGANIC/K_AIR-1.0_real64)*G_ORGANIC) + 0.33_real64/(1.0_real64+(K_ORGANIC/K_AIR-1.0_real64)*(1.0_real64-2.0_real64*G_ORGANIC))
  real(real64), parameter :: K_AIR_DIV_K_WATER = K_AIR/K_WATER
  real(real64), parameter :: CD_QUARTZ=RHO_QUARTZ*C_QUARTZ, CD_CLAY=RHO_CLAY*C_CLAY
  real(real64), parameter :: CD_WATER=RHO_WATER*C_WATER, CD_AIR=RHO_AIR*C_AIR, CD_ORGANIC=RHO_ORGANIC*C_ORGANIC

  public :: SOIL_TEMP_OK, SOIL_TEMP_INVALID_PARAMETERS, SOIL_TEMP_INVALID_STATE, SOIL_TEMP_INVALID_INTERVAL
  public :: SOIL_TEMP_INVALID_FORCING, SOIL_TEMP_INVALID_HYDRAULIC_VIEW, SOIL_TEMP_WORKSPACE_FAILURE
  public :: SOIL_TEMP_LINEAR_SOLVE_FAILURE, SOIL_TEMP_ENERGY_CLOSURE_FAILURE, SOIL_TEMP_INVALID_RESTART, SOIL_TEMP_INVALID_NODE
  public :: SOIL_TEMP_SOLUTION_NUMERIC, SOIL_TEMP_SOLUTION_ANALYTIC
  public :: SOIL_TEMP_TOP_AIR_TEMPERATURE, SOIL_TEMP_TOP_PRESCRIBED_TEMPERATURE
  public :: SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX, SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION
  public :: SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX, SOIL_TEMP_BOTTOM_PRESCRIBED_TEMPERATURE
  public :: soil_temperature_parameters_t, soil_temperature_numerical_config_t, soil_temperature_forcing_t
  public :: soil_temperature_state_t, soil_temperature_restart_payload_t, soil_temperature_field_view_t
  public :: soil_temperature_workspace_t, soil_temperature_result_t, soil_temperature_diagnostics_t
  public :: initialize_soil_temperature_parameters, initialize_soil_temperature_state
  public :: initialize_soil_temperature_from_texture
  public :: trial_restricted_soil_temperature, commit_soil_temperature_state, build_soil_temperature_field_view
  public :: copy_soil_temperature_profile, soil_temperature_at_node, export_soil_temperature_restart
  public :: reconstruct_soil_temperature_restart
  public :: evaluate_b111_analytical_temperature_profile, resolve_b111_surface_temperature

contains

  subroutine initialize_soil_temperature_parameters(dz_cm, distance_above_cm, theta_sat, f_quartz, f_clay, f_organic, &
       parameters, status, solution_mode, analytic_mean_temperature_c, analytic_amplitude_c, &
       analytic_reference_day, analytic_damping_depth_cm)
    real(real64), intent(in) :: dz_cm(:), distance_above_cm(:), theta_sat(:)
    real(real64), intent(in) :: f_quartz(:), f_clay(:), f_organic(:)
    type(soil_temperature_parameters_t), intent(out) :: parameters
    integer, intent(out) :: status
    integer, intent(in), optional :: solution_mode
    real(real64), intent(in), optional :: analytic_mean_temperature_c, analytic_amplitude_c
    real(real64), intent(in), optional :: analytic_reference_day, analytic_damping_depth_cm
    integer :: i, n
    real(real64) :: solid_sum

    status = SOIL_TEMP_INVALID_PARAMETERS
    n = size(dz_cm)
    if (n < 2) return
    if (size(distance_above_cm)/=n .or. size(theta_sat)/=n .or. size(f_quartz)/=n .or. &
        size(f_clay)/=n .or. size(f_organic)/=n) return
    do i=1,n
      if (.not. ieee_is_finite(dz_cm(i)) .or. dz_cm(i)<=0.0_real64) return
      if (.not. ieee_is_finite(distance_above_cm(i)) .or. distance_above_cm(i)<=0.0_real64) return
      if (.not. ieee_is_finite(theta_sat(i)) .or. theta_sat(i)<=0.0_real64 .or. theta_sat(i)>1.0_real64) return
      if (.not. ieee_is_finite(f_quartz(i)) .or. .not. ieee_is_finite(f_clay(i)) .or. .not. ieee_is_finite(f_organic(i))) return
      if (f_quartz(i)<0.0_real64 .or. f_clay(i)<0.0_real64 .or. f_organic(i)<0.0_real64) return
      solid_sum=f_quartz(i)+f_clay(i)+f_organic(i)
      if (solid_sum<=0.0_real64 .or. solid_sum>1.0_real64) return
    end do
    parameters%active_nodes=n
    allocate(parameters%dz_cm(n),parameters%distance_above_cm(n),parameters%node_depth_cm(n),parameters%theta_sat(n))
    allocate(parameters%f_quartz(n),parameters%f_clay(n),parameters%f_organic(n))
    allocate(parameters%fkk_qco_dry(n),parameters%fk_qco_dry(n),parameters%fkk_qco_wet(n),parameters%fk_qco_wet(n))
    parameters%dz_cm=dz_cm; parameters%distance_above_cm=distance_above_cm; parameters%theta_sat=theta_sat
    parameters%node_depth_cm(1)=-distance_above_cm(1)
    do i=2,n
      parameters%node_depth_cm(i)=parameters%node_depth_cm(i-1)-distance_above_cm(i)
    end do
    parameters%f_quartz=f_quartz; parameters%f_clay=f_clay; parameters%f_organic=f_organic
    parameters%fkk_qco_dry=f_quartz*(K_QA*K_QUARTZ)+f_clay*(K_CA*K_CLAY)+f_organic*(K_OA*K_ORGANIC)
    parameters%fk_qco_dry=f_quartz*K_QA+f_clay*K_CA+f_organic*K_OA
    parameters%fkk_qco_wet=f_quartz*(K_QW*K_QUARTZ)+f_clay*(K_CW*K_CLAY)+f_organic*(K_OW*K_ORGANIC)
    parameters%fk_qco_wet=f_quartz*K_QW+f_clay*K_CW+f_organic*K_OW
    if (present(solution_mode)) parameters%solution_mode=solution_mode
    if (present(analytic_mean_temperature_c)) &
         parameters%analytic_mean_temperature_c=analytic_mean_temperature_c
    if (present(analytic_amplitude_c)) parameters%analytic_amplitude_c=analytic_amplitude_c
    if (present(analytic_reference_day)) parameters%analytic_reference_day=analytic_reference_day
    if (present(analytic_damping_depth_cm)) parameters%analytic_damping_depth_cm=analytic_damping_depth_cm
    parameters%initialized=.true.
    if (parameters%ready()) status=SOIL_TEMP_OK
  end subroutine initialize_soil_temperature_parameters

  ! Original SWAP4.3.1 temperature.f90 task1, mineral/organic mass to volume.
  ! PSAND/PSILT/PCLAY refer to mineral parts; ORGMAT to total dry mass.
  subroutine initialize_soil_temperature_from_texture(dz_cm,distance_above_cm,theta_sat, &
       sand,silt,clay,organic,parameters,status)
    real(real64),intent(in)::dz_cm(:),distance_above_cm(:),theta_sat(:),sand(:),silt(:),clay(:),organic(:)
    type(soil_temperature_parameters_t),intent(out)::parameters
    integer,intent(out)::status
    real(real64),allocatable::fq(:),fc(:),fo(:)
    real(real64)::dummy,gmineral
    integer::n,i
    status=SOIL_TEMP_INVALID_PARAMETERS;n=size(dz_cm)
    if(n<2.or.size(distance_above_cm)/=n.or.size(theta_sat)/=n.or. &
       size(sand)/=n.or.size(silt)/=n.or.size(clay)/=n.or.size(organic)/=n)return
    if(any(.not.ieee_is_finite(theta_sat)).or.any(.not.ieee_is_finite(sand)).or. &
       any(.not.ieee_is_finite(silt)).or.any(.not.ieee_is_finite(clay)).or. &
       any(.not.ieee_is_finite(organic)))return
    if(any(theta_sat<=0.0_real64).or.any(theta_sat>1.0_real64).or. &
       any(sand<0.0_real64).or.any(sand>1.0_real64).or.any(silt<0.0_real64).or.any(silt>1.0_real64).or. &
       any(clay<0.0_real64).or.any(clay>1.0_real64).or.any(organic<0.0_real64).or.any(organic>=1.0_real64))return
    ! Original rounded texture tables are not normalized or forced to sum exactly1.
    allocate(fq(n),fc(n),fo(n))
    do i=1,n
      dummy=organic(i)/(1.0_real64-organic(i))
      gmineral=(1.0_real64-theta_sat(i))/(0.370_real64+0.714_real64*dummy)
      fq(i)=(sand(i)+silt(i))*gmineral/2.7_real64
      fc(i)=clay(i)*gmineral/2.7_real64
      fo(i)=dummy*gmineral/1.4_real64
    end do
    call initialize_soil_temperature_parameters(dz_cm,distance_above_cm,theta_sat,fq,fc,fo,parameters,status)
  end subroutine initialize_soil_temperature_from_texture

  subroutine trial_restricted_soil_temperature(parameters,numerical,forcing,hydraulic_start,hydraulic_end, &
       committed_state,t0,t1,workspace,trial_state,result,diagnostics)
    type(soil_temperature_parameters_t), intent(in) :: parameters
    type(soil_temperature_numerical_config_t), intent(in) :: numerical
    type(soil_temperature_forcing_t), intent(in) :: forcing
    type(process_hydraulic_view_t), intent(in) :: hydraulic_start, hydraulic_end
    type(soil_temperature_state_t), intent(in) :: committed_state
    real(real64), intent(in) :: t0,t1
    type(soil_temperature_workspace_t), intent(inout) :: workspace
    type(soil_temperature_state_t), intent(out) :: trial_state
    type(soil_temperature_result_t), intent(out) :: result
    type(soil_temperature_diagnostics_t), intent(out) :: diagnostics
    real(real64), allocatable :: committed_temperature(:)
    integer :: i,n,status
    real(real64) :: dt,top_flux,bottom_flux,storage_change,boundary_energy,residual,surface_temperature

    result=soil_temperature_result_t(); diagnostics=soil_temperature_diagnostics_t()
    if (.not. parameters%ready()) then; result%status=SOIL_TEMP_INVALID_PARAMETERS; diagnostics%status=result%status; return; end if
    n=parameters%active_nodes; diagnostics%active_nodes=n
    if (.not. committed_state%ready() .or. committed_state%node_count()/=n) then
      result%status=SOIL_TEMP_INVALID_STATE; diagnostics%status=result%status; return
    end if
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1<=t0) then
      result%status=SOIL_TEMP_INVALID_INTERVAL; diagnostics%status=result%status; return
    end if
    if (.not. forcing_usable(parameters,forcing)) then
      result%status=SOIL_TEMP_INVALID_FORCING; diagnostics%status=result%status; return
    end if
    if (.not. ieee_is_finite(numerical%energy_abs_tolerance_j_cm2) .or. numerical%energy_abs_tolerance_j_cm2<0.0_real64) then
      result%status=SOIL_TEMP_INVALID_PARAMETERS; diagnostics%status=result%status; return
    end if
    if (.not. hydraulic_view_usable(parameters,hydraulic_start) .or. .not. hydraulic_view_usable(parameters,hydraulic_end)) then
      result%status=SOIL_TEMP_INVALID_HYDRAULIC_VIEW; diagnostics%status=result%status; return
    end if
    call ensure_workspace(workspace,n,status)
    if (status/=SOIL_TEMP_OK) then; result%status=status; diagnostics%status=status; return; end if
    call copy_soil_temperature_profile(committed_state,committed_temperature,status)
    if (status/=SOIL_TEMP_OK) then; result%status=status; diagnostics%status=status; return; end if

    dt=t1-t0
    workspace%old_temperature_c=committed_temperature
    workspace%average_water_content=0.5_real64*(hydraulic_start%water_content+hydraulic_end%water_content)
    call evaluate_devries(parameters,workspace%average_water_content,workspace%heat_capacity_j_cm3_k, &
         workspace%node_conductivity_j_cm_k_day,status)
    if (status/=SOIL_TEMP_OK) then; result%status=status; diagnostics%status=status; return; end if
    diagnostics%constitutive_evaluations=1
    workspace%face_conductivity_j_cm_k_day(1)=workspace%node_conductivity_j_cm_k_day(1)
    do i=2,n
      workspace%face_conductivity_j_cm_k_day(i)=0.5_real64*(workspace%node_conductivity_j_cm_k_day(i-1)+ &
           workspace%node_conductivity_j_cm_k_day(i))
    end do

    if (parameters%solution_mode==SOIL_TEMP_SOLUTION_ANALYTIC) then
      call evaluate_b111_analytical_temperature_profile(parameters,forcing%day_number,workspace%solution,status)
      diagnostics%analytical_profile_used=.true.
    else
      call resolve_b111_surface_temperature(parameters,forcing,workspace%old_temperature_c(1), &
           workspace%node_conductivity_j_cm_k_day(1),surface_temperature,status,diagnostics%snow_thermal_resistance_used)
      if (status/=SOIL_TEMP_OK) then; result%status=status; diagnostics%status=status; return; end if
      call assemble_system(parameters,forcing,surface_temperature,dt,workspace)
      call solve_tridiagonal(workspace,n,status); diagnostics%tridiagonal_solves=1
    end if
    if (status/=SOIL_TEMP_OK) then; result%status=status; diagnostics%status=status; return; end if
    if (parameters%solution_mode==SOIL_TEMP_SOLUTION_NUMERIC .and. &
        forcing%top_boundary_mode==SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX) then
      surface_temperature=workspace%solution(1)+forcing%prescribed_top_heat_flux_j_cm2_day* &
           parameters%distance_above_cm(1)/workspace%face_conductivity_j_cm_k_day(1)
    end if

    storage_change=sum(workspace%heat_capacity_j_cm3_k*parameters%dz_cm*(workspace%solution-workspace%old_temperature_c))
    bottom_flux=0.0_real64
    if (parameters%solution_mode==SOIL_TEMP_SOLUTION_NUMERIC .and. &
        forcing%bottom_boundary_mode==SOIL_TEMP_BOTTOM_PRESCRIBED_TEMPERATURE) then
      bottom_flux=workspace%node_conductivity_j_cm_k_day(n)* &
           (forcing%prescribed_bottom_temperature_c-workspace%solution(n))/(0.5_real64*parameters%dz_cm(n))
    end if
    select case(parameters%solution_mode)
    case(SOIL_TEMP_SOLUTION_ANALYTIC)
      top_flux=storage_change/dt
      surface_temperature=workspace%solution(1)
    case default
      select case(forcing%top_boundary_mode)
      case(SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX)
        top_flux=forcing%prescribed_top_heat_flux_j_cm2_day
      case(SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION)
        top_flux=storage_change/dt-bottom_flux
      case default
        top_flux=workspace%face_conductivity_j_cm_k_day(1)*(surface_temperature-workspace%solution(1))/ &
             parameters%distance_above_cm(1)
      end select
    end select
    boundary_energy=dt*(top_flux+bottom_flux); residual=storage_change-boundary_energy
    if (.not. ieee_is_finite(storage_change) .or. .not. ieee_is_finite(top_flux) .or. &
        .not. ieee_is_finite(bottom_flux) .or. .not. ieee_is_finite(residual)) then
      result%status=SOIL_TEMP_ENERGY_CLOSURE_FAILURE; diagnostics%status=result%status; return
    end if
    if (abs(residual)>numerical%energy_abs_tolerance_j_cm2) then
      result%status=SOIL_TEMP_ENERGY_CLOSURE_FAILURE; diagnostics%status=result%status; return
    end if
    call materialize_soil_temperature_trial_state(workspace%solution,trial_state,status)
    if (status/=SOIL_TEMP_OK) then; result%status=status; diagnostics%status=status; return; end if

    result%status=SOIL_TEMP_OK; result%produced=.true.; result%surface_temperature_c=surface_temperature
    result%top_heat_flux_into_soil_j_cm2_day=top_flux
    result%bottom_heat_flux_into_soil_j_cm2_day=bottom_flux; result%sensible_storage_change_j_cm2=storage_change
    result%boundary_energy_into_soil_j_cm2=boundary_energy; result%energy_residual_j_cm2=residual
    result%min_temperature_c=minval(workspace%solution); result%max_temperature_c=maxval(workspace%solution)
    diagnostics%status=SOIL_TEMP_OK
    diagnostics%prescribed_surface_temperature_used = parameters%solution_mode==SOIL_TEMP_SOLUTION_NUMERIC .and. &
         (forcing%top_boundary_mode==SOIL_TEMP_TOP_PRESCRIBED_TEMPERATURE .or. &
          forcing%top_boundary_mode==SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION)
    diagnostics%prescribed_top_heat_flux_used = parameters%solution_mode==SOIL_TEMP_SOLUTION_NUMERIC .and. &
         forcing%top_boundary_mode==SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX
    diagnostics%surface_temperature_flux_correction_used = parameters%solution_mode==SOIL_TEMP_SOLUTION_NUMERIC .and. &
         forcing%top_boundary_mode==SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION
    diagnostics%zero_bottom_heat_flux_used = parameters%solution_mode==SOIL_TEMP_SOLUTION_NUMERIC .and. &
         forcing%bottom_boundary_mode==SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX
    diagnostics%prescribed_bottom_temperature_used = parameters%solution_mode==SOIL_TEMP_SOLUTION_NUMERIC .and. &
         forcing%bottom_boundary_mode==SOIL_TEMP_BOTTOM_PRESCRIBED_TEMPERATURE
    diagnostics%energy_accounting_complete=.true.
  end subroutine trial_restricted_soil_temperature

  logical function forcing_usable(parameters,forcing) result(usable)
    type(soil_temperature_parameters_t), intent(in) :: parameters
    type(soil_temperature_forcing_t), intent(in) :: forcing
    usable=.false.
    if (parameters%solution_mode==SOIL_TEMP_SOLUTION_ANALYTIC) then
      usable=forcing%day_number>=1 .and. forcing%day_number<=366
      return
    end if
    if (forcing%top_boundary_mode<SOIL_TEMP_TOP_AIR_TEMPERATURE .or. &
        forcing%top_boundary_mode>SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION) return
    if (forcing%bottom_boundary_mode<SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX .or. &
        forcing%bottom_boundary_mode>SOIL_TEMP_BOTTOM_PRESCRIBED_TEMPERATURE) return
    if (.not. ieee_is_finite(forcing%prescribed_surface_temperature_c) .or. &
        .not. ieee_is_finite(forcing%prescribed_top_heat_flux_j_cm2_day) .or. &
        .not. ieee_is_finite(forcing%prescribed_bottom_temperature_c) .or. &
        .not. ieee_is_finite(forcing%air_temperature_c) .or. &
        .not. ieee_is_finite(forcing%snow_water_storage_cm)) return
    if (forcing%snow_water_storage_cm<0.0_real64) return
    if (forcing%top_boundary_mode/=SOIL_TEMP_TOP_AIR_TEMPERATURE .and. &
        forcing%snow_water_storage_cm>0.0_real64) return
    usable=.true.
  end function forcing_usable

  logical function hydraulic_view_usable(parameters,view) result(usable)
    type(soil_temperature_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: view
    integer :: i,n
    usable=.false.; n=parameters%active_nodes
    if (view%active_nodes/=n .or. .not. allocated(view%water_content)) return
    if (size(view%water_content)/=n) return
    do i=1,n
      if (.not. ieee_is_finite(view%water_content(i))) return
      if (view%water_content(i)<-WATER_TOLERANCE .or. view%water_content(i)>parameters%theta_sat(i)+WATER_TOLERANCE) return
    end do
    usable=.true.
  end function hydraulic_view_usable

  subroutine ensure_workspace(workspace,n,status)
    type(soil_temperature_workspace_t), intent(inout) :: workspace
    integer, intent(in) :: n
    integer, intent(out) :: status
    integer :: a
    status=SOIL_TEMP_WORKSPACE_FAILURE
    if (allocated(workspace%old_temperature_c)) then
      if (size(workspace%old_temperature_c)/=n) call clear_workspace(workspace)
    end if
    if (.not. allocated(workspace%old_temperature_c)) then
      allocate(workspace%old_temperature_c(n),workspace%average_water_content(n),workspace%heat_capacity_j_cm3_k(n), &
           workspace%node_conductivity_j_cm_k_day(n),workspace%face_conductivity_j_cm_k_day(n),workspace%lower(n), &
           workspace%diagonal(n),workspace%upper(n),workspace%rhs(n),workspace%solution(n),stat=a)
      if (a/=0) then; call clear_workspace(workspace); return; end if
    end if
    status=SOIL_TEMP_OK
  end subroutine ensure_workspace

  subroutine clear_workspace(w)
    type(soil_temperature_workspace_t), intent(inout) :: w
    if (allocated(w%old_temperature_c)) deallocate(w%old_temperature_c)
    if (allocated(w%average_water_content)) deallocate(w%average_water_content)
    if (allocated(w%heat_capacity_j_cm3_k)) deallocate(w%heat_capacity_j_cm3_k)
    if (allocated(w%node_conductivity_j_cm_k_day)) deallocate(w%node_conductivity_j_cm_k_day)
    if (allocated(w%face_conductivity_j_cm_k_day)) deallocate(w%face_conductivity_j_cm_k_day)
    if (allocated(w%lower)) deallocate(w%lower); if (allocated(w%diagonal)) deallocate(w%diagonal)
    if (allocated(w%upper)) deallocate(w%upper); if (allocated(w%rhs)) deallocate(w%rhs)
    if (allocated(w%solution)) deallocate(w%solution)
  end subroutine clear_workspace

  subroutine evaluate_devries(parameters,theta,heat_capacity,conductivity,status)
    type(soil_temperature_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: theta(:)
    real(real64), intent(out) :: heat_capacity(:),conductivity(:)
    integer, intent(out) :: status
    integer :: i,n
    real(real64) :: f_air,g_air,g_air_dry,k_aw,numerator,denominator,conductivity_dry,conductivity_wet
    status=SOIL_TEMP_INVALID_HYDRAULIC_VIEW; n=parameters%active_nodes
    if (size(theta)/=n .or. size(heat_capacity)/=n .or. size(conductivity)/=n) return
    do i=1,n
      if (.not. ieee_is_finite(theta(i)) .or. theta(i)<-WATER_TOLERANCE .or. theta(i)>parameters%theta_sat(i)+WATER_TOLERANCE) return
      f_air=max(0.0_real64,parameters%theta_sat(i)-theta(i))
      heat_capacity(i)=(parameters%f_quartz(i)*CD_QUARTZ+parameters%f_clay(i)*CD_CLAY+ &
           parameters%f_organic(i)*CD_ORGANIC+theta(i)*CD_WATER+f_air*CD_AIR)*1.0e-6_real64
      if (theta(i)>THETA_DRY) then
        g_air=0.333_real64-f_air/parameters%theta_sat(i)*0.298_real64
      else
        g_air_dry=0.333_real64-f_air/parameters%theta_sat(i)*0.298_real64
        g_air=0.013_real64+theta(i)/THETA_DRY*(g_air_dry-0.013_real64)
      end if
      k_aw=0.66_real64/(1.0_real64+(K_AIR_DIV_K_WATER-1.0_real64)*g_air)+ &
           0.33_real64/(1.0_real64+(K_AIR_DIV_K_WATER-1.0_real64)*(1.0_real64-2.0_real64*g_air))
      if (theta(i)<=THETA_DRY) then
        numerator=parameters%fkk_qco_dry(i)+f_air*(K_AA*K_AIR)+theta(i)*(K_WA*K_WATER)
        denominator=parameters%fk_qco_dry(i)+f_air*K_AA+theta(i)*K_WA
        if (denominator<=0.0_real64) return
        conductivity(i)=numerator/denominator*1.25_real64*864.0_real64
      else if (theta(i)>=THETA_WET) then
        numerator=parameters%fkk_qco_wet(i)+f_air*k_aw*K_AIR+theta(i)*(K_WW*K_WATER)
        denominator=parameters%fk_qco_wet(i)+f_air*k_aw+theta(i)*K_WW
        if (denominator<=0.0_real64) return
        conductivity(i)=numerator/denominator*864.0_real64
      else
        numerator=parameters%fkk_qco_dry(i)+f_air*(K_AA*K_AIR)+THETA_DRY*(K_WA*K_WATER)
        denominator=parameters%fk_qco_dry(i)+f_air*K_AA+THETA_DRY*K_WA
        if (denominator<=0.0_real64) return
        conductivity_dry=numerator/denominator*1.25_real64
        numerator=parameters%fkk_qco_wet(i)+f_air*k_aw*K_AIR+THETA_WET*(K_WW*K_WATER)
        denominator=parameters%fk_qco_wet(i)+f_air*k_aw+THETA_WET*K_WW
        if (denominator<=0.0_real64) return
        conductivity_wet=numerator/denominator
        conductivity(i)=(conductivity_dry+(theta(i)-THETA_DRY)*(conductivity_wet-conductivity_dry)/(THETA_WET-THETA_DRY))*864.0_real64
      end if
      if (.not. ieee_is_finite(heat_capacity(i)) .or. heat_capacity(i)<=0.0_real64) return
      if (.not. ieee_is_finite(conductivity(i)) .or. conductivity(i)<=0.0_real64) return
    end do
    status=SOIL_TEMP_OK
  end subroutine evaluate_devries

  subroutine evaluate_b111_analytical_temperature_profile(parameters,day_number,temperature_c,status)
    type(soil_temperature_parameters_t), intent(in) :: parameters
    integer, intent(in) :: day_number
    real(real64), intent(out) :: temperature_c(:)
    integer, intent(out) :: status
    real(real64) :: pi,halfpi,omega
    integer :: i
    status=SOIL_TEMP_INVALID_PARAMETERS
    if (.not. parameters%ready() .or. parameters%solution_mode/=SOIL_TEMP_SOLUTION_ANALYTIC) return
    if (size(temperature_c)/=parameters%active_nodes .or. day_number<1 .or. day_number>366) return
    pi=4.0_real64*atan(1.0_real64); halfpi=0.5_real64*pi; omega=2.0_real64*pi/365.0_real64
    do i=1,parameters%active_nodes
      temperature_c(i)=parameters%analytic_mean_temperature_c+parameters%analytic_amplitude_c* &
           sin(halfpi+omega*(real(day_number,real64)-parameters%analytic_reference_day)+ &
               parameters%node_depth_cm(i)/parameters%analytic_damping_depth_cm)* &
           exp(parameters%node_depth_cm(i)/parameters%analytic_damping_depth_cm)
    end do
    if (any(.not. ieee_is_finite(temperature_c))) return
    status=SOIL_TEMP_OK
  end subroutine evaluate_b111_analytical_temperature_profile

  subroutine resolve_b111_surface_temperature(parameters,forcing,first_node_temperature_c, &
       first_node_conductivity_j_cm_k_day,surface_temperature_c,status,snow_resistance_used)
    type(soil_temperature_parameters_t), intent(in) :: parameters
    type(soil_temperature_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: first_node_temperature_c,first_node_conductivity_j_cm_k_day
    real(real64), intent(out) :: surface_temperature_c
    integer, intent(out) :: status
    logical, intent(out) :: snow_resistance_used
    real(real64) :: snow_density_g_cm3,snow_conductivity_j_cm_k_day,snow_depth_cm,ratio
    surface_temperature_c=0.0_real64; status=SOIL_TEMP_INVALID_FORCING; snow_resistance_used=.false.
    if (.not. ieee_is_finite(first_node_temperature_c) .or. &
        .not. ieee_is_finite(first_node_conductivity_j_cm_k_day) .or. &
        first_node_conductivity_j_cm_k_day<=0.0_real64) return
    select case(forcing%top_boundary_mode)
    case(SOIL_TEMP_TOP_AIR_TEMPERATURE)
      surface_temperature_c=forcing%air_temperature_c
      if (abs(forcing%snow_water_storage_cm)>1.0e-10_real64) then
        snow_density_g_cm3=0.17_real64
        snow_conductivity_j_cm_k_day=2.86e-6_real64*864.0_real64*170.0_real64**2
        snow_depth_cm=forcing%snow_water_storage_cm/snow_density_g_cm3
        ratio=(0.5_real64*snow_conductivity_j_cm_k_day*parameters%dz_cm(1))/ &
             (first_node_conductivity_j_cm_k_day*snow_depth_cm)
        surface_temperature_c=(first_node_temperature_c+ratio*forcing%air_temperature_c)/(1.0_real64+ratio)
        snow_resistance_used=.true.
      end if
    case(SOIL_TEMP_TOP_PRESCRIBED_TEMPERATURE,SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION)
      surface_temperature_c=forcing%prescribed_surface_temperature_c
    case(SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX)
      surface_temperature_c=first_node_temperature_c
    case default
      return
    end select
    if (.not. ieee_is_finite(surface_temperature_c)) return
    status=SOIL_TEMP_OK
  end subroutine resolve_b111_surface_temperature

  subroutine assemble_system(parameters,forcing,surface_temperature_c,dt,w)
    type(soil_temperature_parameters_t), intent(in) :: parameters
    type(soil_temperature_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: surface_temperature_c,dt
    type(soil_temperature_workspace_t), intent(inout) :: w
    integer :: i,n
    n=parameters%active_nodes; w%lower=0.0_real64; w%upper=0.0_real64
    i=1
    w%upper(i)=-dt*w%face_conductivity_j_cm_k_day(i+1)/(parameters%dz_cm(i)*parameters%distance_above_cm(i+1))
    select case(forcing%top_boundary_mode)
    case(SOIL_TEMP_TOP_AIR_TEMPERATURE,SOIL_TEMP_TOP_PRESCRIBED_TEMPERATURE)
      w%lower(i)=-dt*w%face_conductivity_j_cm_k_day(i)/(parameters%dz_cm(i)*parameters%distance_above_cm(i))
      w%diagonal(i)=w%heat_capacity_j_cm3_k(i)-w%lower(i)-w%upper(i)
      w%rhs(i)=w%heat_capacity_j_cm3_k(i)*w%old_temperature_c(i)-w%lower(i)*surface_temperature_c
      w%lower(i)=0.0_real64
    case(SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX)
      w%lower(i)=0.0_real64
      w%diagonal(i)=w%heat_capacity_j_cm3_k(i)-w%upper(i)
      w%rhs(i)=w%heat_capacity_j_cm3_k(i)*w%old_temperature_c(i)+ &
           forcing%prescribed_top_heat_flux_j_cm2_day*dt/parameters%dz_cm(i)
    case(SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION)
      w%lower(i)=0.0_real64; w%upper(i)=0.0_real64; w%diagonal(i)=1.0_real64
      w%rhs(i)=surface_temperature_c-parameters%distance_above_cm(i)/ &
           w%face_conductivity_j_cm_k_day(i)*forcing%prescribed_top_heat_flux_j_cm2_day
    end select
    do i=2,n-1
      w%lower(i)=-dt*w%face_conductivity_j_cm_k_day(i)/(parameters%dz_cm(i)*parameters%distance_above_cm(i))
      w%upper(i)=-dt*w%face_conductivity_j_cm_k_day(i+1)/(parameters%dz_cm(i)*parameters%distance_above_cm(i+1))
      w%diagonal(i)=w%heat_capacity_j_cm3_k(i)-w%lower(i)-w%upper(i)
      w%rhs(i)=w%heat_capacity_j_cm3_k(i)*w%old_temperature_c(i)
    end do
    i=n
    w%lower(i)=-dt*w%face_conductivity_j_cm_k_day(i)/(parameters%dz_cm(i)*parameters%distance_above_cm(i))
    select case(forcing%bottom_boundary_mode)
    case(SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX)
      w%upper(i)=0.0_real64; w%diagonal(i)=w%heat_capacity_j_cm3_k(i)-w%lower(i)
      w%rhs(i)=w%heat_capacity_j_cm3_k(i)*w%old_temperature_c(i)
    case(SOIL_TEMP_BOTTOM_PRESCRIBED_TEMPERATURE)
      w%upper(i)=-dt*w%node_conductivity_j_cm_k_day(i)/(parameters%dz_cm(i)*0.5_real64*parameters%dz_cm(i))
      w%diagonal(i)=w%heat_capacity_j_cm3_k(i)-w%lower(i)-w%upper(i)
      w%rhs(i)=w%heat_capacity_j_cm3_k(i)*w%old_temperature_c(i)- &
           w%upper(i)*forcing%prescribed_bottom_temperature_c
      w%upper(i)=0.0_real64
    end select
  end subroutine assemble_system

  subroutine solve_tridiagonal(w,n,status)
    type(soil_temperature_workspace_t), intent(inout) :: w
    integer, intent(in) :: n
    integer, intent(out) :: status
    integer :: i
    real(real64) :: factor
    status=SOIL_TEMP_LINEAR_SOLVE_FAILURE
    if (abs(w%diagonal(1))<=PIVOT_TOLERANCE .or. .not. ieee_is_finite(w%diagonal(1))) return
    do i=2,n
      factor=w%lower(i)/w%diagonal(i-1); w%diagonal(i)=w%diagonal(i)-factor*w%upper(i-1); w%rhs(i)=w%rhs(i)-factor*w%rhs(i-1)
      if (abs(w%diagonal(i))<=PIVOT_TOLERANCE .or. .not. ieee_is_finite(w%diagonal(i))) return
    end do
    w%solution(n)=w%rhs(n)/w%diagonal(n)
    do i=n-1,1,-1; w%solution(i)=(w%rhs(i)-w%upper(i)*w%solution(i+1))/w%diagonal(i); end do
    do i=1,n; if (.not. ieee_is_finite(w%solution(i))) return; end do
    status=SOIL_TEMP_OK
  end subroutine solve_tridiagonal

end module mod_restricted_soil_temperature
