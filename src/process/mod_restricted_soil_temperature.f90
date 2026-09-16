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
       soil_temperature_at_node, export_soil_temperature_restart, reconstruct_soil_temperature_restart
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
  public :: soil_temperature_parameters_t, soil_temperature_numerical_config_t, soil_temperature_forcing_t
  public :: soil_temperature_state_t, soil_temperature_restart_payload_t, soil_temperature_field_view_t
  public :: soil_temperature_workspace_t, soil_temperature_result_t, soil_temperature_diagnostics_t
  public :: initialize_soil_temperature_parameters, initialize_soil_temperature_state
  public :: trial_restricted_soil_temperature, commit_soil_temperature_state, build_soil_temperature_field_view
  public :: copy_soil_temperature_profile, soil_temperature_at_node, export_soil_temperature_restart
  public :: reconstruct_soil_temperature_restart

contains

  subroutine initialize_soil_temperature_parameters(dz_cm, distance_above_cm, theta_sat, f_quartz, f_clay, f_organic, parameters, status)
    real(real64), intent(in) :: dz_cm(:), distance_above_cm(:), theta_sat(:)
    real(real64), intent(in) :: f_quartz(:), f_clay(:), f_organic(:)
    type(soil_temperature_parameters_t), intent(out) :: parameters
    integer, intent(out) :: status
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
    allocate(parameters%dz_cm(n),parameters%distance_above_cm(n),parameters%theta_sat(n))
    allocate(parameters%f_quartz(n),parameters%f_clay(n),parameters%f_organic(n))
    allocate(parameters%fkk_qco_dry(n),parameters%fk_qco_dry(n),parameters%fkk_qco_wet(n),parameters%fk_qco_wet(n))
    parameters%dz_cm=dz_cm; parameters%distance_above_cm=distance_above_cm; parameters%theta_sat=theta_sat
    parameters%f_quartz=f_quartz; parameters%f_clay=f_clay; parameters%f_organic=f_organic
    parameters%fkk_qco_dry=f_quartz*(K_QA*K_QUARTZ)+f_clay*(K_CA*K_CLAY)+f_organic*(K_OA*K_ORGANIC)
    parameters%fk_qco_dry=f_quartz*K_QA+f_clay*K_CA+f_organic*K_OA
    parameters%fkk_qco_wet=f_quartz*(K_QW*K_QUARTZ)+f_clay*(K_CW*K_CLAY)+f_organic*(K_OW*K_ORGANIC)
    parameters%fk_qco_wet=f_quartz*K_QW+f_clay*K_CW+f_organic*K_OW
    parameters%initialized=.true.
    status=SOIL_TEMP_OK
  end subroutine initialize_soil_temperature_parameters

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
    real(real64) :: dt,top_flux,storage_change,boundary_energy,residual

    result=soil_temperature_result_t(); diagnostics=soil_temperature_diagnostics_t()
    if (.not. parameters%ready()) then; result%status=SOIL_TEMP_INVALID_PARAMETERS; diagnostics%status=result%status; return; end if
    n=parameters%active_nodes; diagnostics%active_nodes=n
    if (.not. committed_state%ready() .or. committed_state%node_count()/=n) then
      result%status=SOIL_TEMP_INVALID_STATE; diagnostics%status=result%status; return
    end if
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1<=t0) then
      result%status=SOIL_TEMP_INVALID_INTERVAL; diagnostics%status=result%status; return
    end if
    if (.not. ieee_is_finite(forcing%prescribed_surface_temperature_c)) then
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
    call assemble_system(parameters,forcing%prescribed_surface_temperature_c,dt,workspace)
    call solve_tridiagonal(workspace,n,status); diagnostics%tridiagonal_solves=1
    if (status/=SOIL_TEMP_OK) then; result%status=status; diagnostics%status=status; return; end if

    storage_change=sum(workspace%heat_capacity_j_cm3_k*parameters%dz_cm*(workspace%solution-workspace%old_temperature_c))
    top_flux=workspace%face_conductivity_j_cm_k_day(1)*(forcing%prescribed_surface_temperature_c-workspace%solution(1))/ &
             parameters%distance_above_cm(1)
    boundary_energy=dt*top_flux; residual=storage_change-boundary_energy
    if (.not. ieee_is_finite(storage_change) .or. .not. ieee_is_finite(top_flux) .or. .not. ieee_is_finite(residual)) then
      result%status=SOIL_TEMP_ENERGY_CLOSURE_FAILURE; diagnostics%status=result%status; return
    end if
    if (abs(residual)>numerical%energy_abs_tolerance_j_cm2) then
      result%status=SOIL_TEMP_ENERGY_CLOSURE_FAILURE; diagnostics%status=result%status; return
    end if
    call materialize_soil_temperature_trial_state(workspace%solution,trial_state,status)
    if (status/=SOIL_TEMP_OK) then; result%status=status; diagnostics%status=status; return; end if

    result%status=SOIL_TEMP_OK; result%produced=.true.; result%surface_temperature_c=forcing%prescribed_surface_temperature_c
    result%top_heat_flux_into_soil_j_cm2_day=top_flux; result%sensible_storage_change_j_cm2=storage_change
    result%boundary_energy_into_soil_j_cm2=boundary_energy; result%energy_residual_j_cm2=residual
    result%min_temperature_c=minval(workspace%solution); result%max_temperature_c=maxval(workspace%solution)
    diagnostics%status=SOIL_TEMP_OK; diagnostics%prescribed_surface_temperature_used=.true.
    diagnostics%zero_bottom_heat_flux_used=.true.; diagnostics%energy_accounting_complete=.true.
  end subroutine trial_restricted_soil_temperature

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

  subroutine assemble_system(parameters,surface_temperature_c,dt,w)
    type(soil_temperature_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: surface_temperature_c,dt
    type(soil_temperature_workspace_t), intent(inout) :: w
    integer :: i,n
    n=parameters%active_nodes; w%lower=0.0_real64; w%upper=0.0_real64
    i=1
    w%lower(i)=-dt*w%face_conductivity_j_cm_k_day(i)/(parameters%dz_cm(i)*parameters%distance_above_cm(i))
    w%upper(i)=-dt*w%face_conductivity_j_cm_k_day(i+1)/(parameters%dz_cm(i)*parameters%distance_above_cm(i+1))
    w%diagonal(i)=w%heat_capacity_j_cm3_k(i)-w%lower(i)-w%upper(i)
    w%rhs(i)=w%heat_capacity_j_cm3_k(i)*w%old_temperature_c(i)-w%lower(i)*surface_temperature_c; w%lower(i)=0.0_real64
    do i=2,n-1
      w%lower(i)=-dt*w%face_conductivity_j_cm_k_day(i)/(parameters%dz_cm(i)*parameters%distance_above_cm(i))
      w%upper(i)=-dt*w%face_conductivity_j_cm_k_day(i+1)/(parameters%dz_cm(i)*parameters%distance_above_cm(i+1))
      w%diagonal(i)=w%heat_capacity_j_cm3_k(i)-w%lower(i)-w%upper(i)
      w%rhs(i)=w%heat_capacity_j_cm3_k(i)*w%old_temperature_c(i)
    end do
    i=n
    w%lower(i)=-dt*w%face_conductivity_j_cm_k_day(i)/(parameters%dz_cm(i)*parameters%distance_above_cm(i))
    w%upper(i)=0.0_real64; w%diagonal(i)=w%heat_capacity_j_cm3_k(i)-w%lower(i)
    w%rhs(i)=w%heat_capacity_j_cm3_k(i)*w%old_temperature_c(i)
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
