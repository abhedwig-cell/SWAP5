module mod_ross14_boundary_mock
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_trial_kernel_t, &
       rossfast_d3r_kernel_request_t, rossfast_d3r_kernel_result_t
  implicit none
  private

  type, extends(rossfast_d3r_trial_kernel_t), public :: ross14_mock_kernel_t
  contains
    procedure :: solve => mock_solve
  end type ross14_mock_kernel_t

contains

  subroutine mock_solve(self, request, result)
    class(ross14_mock_kernel_t), intent(in) :: self
    type(rossfast_d3r_kernel_request_t), intent(in) :: request
    type(rossfast_d3r_kernel_result_t), intent(out) :: result

    if (.not. same_type_as(self, self)) error stop 'unreachable mock type'
    result = rossfast_d3r_kernel_result_t()
    result%request_admitted = .true.
    result%solver_ok = .true.
    result%candidate_state = request%base_state
    result%temporal_certificate_available = .true.
    result%temporal_indicator = 0.25_real64
    result%linear_solves = 1
  end subroutine mock_solve

end module mod_ross14_boundary_mock

program test_ross14_preimage_boundary_proof
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: trial_outcome_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_interval_t, canonical_numerical_config_t
  use mod_rossfast_d3r_execution_policy, only: apply_rossfast_d3r_retry_policy, &
       ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_model_t, rossfast_d3r_state_t, &
       rossfast_d3r_forcing_t, rossfast_d3r_material_t, bind_rossfast_d3r_model, &
       rossfast_d3r_material_from_id, ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, &
       ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION
  use mod_ross14_boundary_mock, only: ross14_mock_kernel_t
  implicit none

  character(len=3), parameter :: ids(36) = [character(len=3) :: &
       'B01','B02','B03','B04','B05','B06','B07','B08','B09', &
       'B10','B11','B12','B13','B14','B15','B16','B17','B18', &
       'O01','O02','O03','O04','O05','O06','O07','O08','O09', &
       'O10','O11','O12','O13','O14','O15','O16','O17','O18']
  real(real64), parameter :: se_levels(3) = [0.65_real64,0.85_real64,0.98_real64]
  real(real64), parameter :: top_internal_factors(3) = [0.005_real64,-0.010_real64,-0.025_real64]
  real(real64), parameter :: bottom_up_factors(3) = [-0.019_real64,-0.004_real64,0.011_real64]

  integer :: imat, ise, iforce
  integer :: drying_accept, nominal_accept, wetting_reject
  type(ross14_mock_kernel_t), target :: kernel
  type(rossfast_d3r_model_t) :: model
  type(rossfast_d3r_material_t) :: material
  type(rossfast_d3r_state_t) :: state
  type(rossfast_d3r_forcing_t) :: forcing
  type(canonical_interval_t) :: interval
  type(canonical_numerical_config_t) :: config
  type(trial_outcome_t) :: outcome
  real(real64) :: dz(ROSSFAST_D3R_N_CELLS)
  real(real64) :: h0,k0
  logical :: found, valid

  call require(ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION==0.02_real64, &
       'preimage symmetric envelope fraction is 0.02')

  config=canonical_numerical_config_t()
  config%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  config%transaction%mass_tolerance=1.0e-12_real64
  config%max_committed_substeps=32
  call apply_rossfast_d3r_retry_policy(config)
  interval=canonical_interval_t(0.0_real64,ROSSFAST_D3R_OUTER_HORIZON_DAY)
  dz=ROSSFAST_D3R_DZ_CM

  drying_accept=0
  nominal_accept=0
  wetting_reject=0

  do imat=1,size(ids)
    call rossfast_d3r_material_from_id(ids(imat),material,found)
    call require(found,'36-material catalog lookup')
    call bind_rossfast_d3r_model(model,kernel,material,dz,8,valid)
    call require(valid,'bind 36-material preimage model')

    do ise=1,size(se_levels)
      h0=head_from_effective_saturation(se_levels(ise),material)
      k0=conductivity_from_head(h0,material)
      call require(k0>0.0_real64,'positive state-local conductivity')
      call initialize_state(state,h0,material)

      do iforce=1,3
        forcing%top_flux_cm_per_day=top_internal_factors(iforce)*k0
        forcing%bottom_flux_upward_cm_per_day=bottom_up_factors(iforce)*k0
        call model%prepare_interval(forcing,interval,config)
        call model%advance(state,interval%t0,interval%t1,outcome)

        select case(iforce)
        case(1)
          call require(outcome%solver_ok,'DRYING admitted by current binding')
          drying_accept=drying_accept+1
        case(2)
          call require(outcome%solver_ok,'NOMINAL admitted by current binding')
          nominal_accept=nominal_accept+1
        case(3)
          call require(.not.outcome%solver_ok,'WETTING rejected by current binding')
          wetting_reject=wetting_reject+1
        end select
      end do
    end do
  end do

  call require(drying_accept==108,'108/108 DRYING preimage admissions')
  call require(nominal_accept==108,'108/108 NOMINAL preimage admissions')
  call require(wetting_reject==108,'108/108 WETTING preimage rejections')

  call prove_edge_arithmetic()

  write(*,'(A,I0)') 'F_ROSS14_PREIMAGE_DRYING_ACCEPT_COUNT=',drying_accept
  write(*,'(A,I0)') 'F_ROSS14_PREIMAGE_NOMINAL_ACCEPT_COUNT=',nominal_accept
  write(*,'(A,I0)') 'F_ROSS14_PREIMAGE_WETTING_REJECT_COUNT=',wetting_reject
  write(*,'(A)') 'F_ROSS14_PREIMAGE_TOP_INTERVAL_OVER_K=[-0.010,+0.030]'
  write(*,'(A)') 'F_ROSS14_TARGET_TOP_LOWER_EDGE_OVER_K=-0.025'
  write(*,'(A)') 'F_ROSS14_PRESERVED_TOP_UPPER_EDGE_OVER_K=+0.030'
  write(*,'(A)') 'F_ROSS14_PRESERVED_BOTTOM_INTERVAL_OVER_K=[-0.024,+0.016]'
  write(*,'(A)') 'F_ROSS14_PREIMAGE_BOUNDARY_PROOF=PASS'

contains

  subroutine initialize_state(s,h,mat)
    type(rossfast_d3r_state_t), intent(out) :: s
    real(real64), intent(in) :: h
    type(rossfast_d3r_material_t), intent(in) :: mat
    s%active_nodes=ROSSFAST_D3R_N_CELLS
    allocate(s%pressure_head_cm(ROSSFAST_D3R_N_CELLS),s%water_content(ROSSFAST_D3R_N_CELLS))
    s%pressure_head_cm=h
    s%water_content=water_content_from_head(h,mat)
  end subroutine initialize_state

  subroutine prove_edge_arithmetic()
    real(real64) :: qref, scale, legacy_limit, current_lower, current_upper
    real(real64) :: target_lower, bottom_ref, bottom_lower, bottom_upper

    qref=0.01_real64
    scale=1.0_real64
    legacy_limit=ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION*scale
    current_lower=qref-legacy_limit
    current_upper=qref+legacy_limit
    target_lower=qref-0.035_real64*scale
    bottom_ref=-0.004_real64
    bottom_lower=bottom_ref-legacy_limit
    bottom_upper=bottom_ref+legacy_limit

    call require(abs(current_lower-(-0.01_real64))<=epsilon(1.0_real64),'current top lower arithmetic')
    call require(abs(current_upper-0.03_real64)<=epsilon(1.0_real64),'current top upper arithmetic')
    call require(abs(target_lower-(-0.025_real64))<=epsilon(1.0_real64),'target one-sided lower arithmetic')
    call require(abs(bottom_lower-(-0.024_real64))<=epsilon(1.0_real64),'bottom lower preserved arithmetic')
    call require(abs(bottom_upper-0.016_real64)<=epsilon(1.0_real64),'bottom upper preserved arithmetic')
  end subroutine prove_edge_arithmetic

  pure real(real64) function water_content_from_head(h,mat) result(theta)
    real(real64), intent(in) :: h
    type(rossfast_d3r_material_t), intent(in) :: mat
    real(real64) :: m,se
    m=1.0_real64-1.0_real64/mat%n
    se=(1.0_real64+abs(mat%alpha_per_cm*h)**mat%n)**(-m)
    theta=mat%theta_r+(mat%theta_s-mat%theta_r)*se
  end function water_content_from_head

  pure real(real64) function head_from_effective_saturation(se,mat) result(h)
    real(real64), intent(in) :: se
    type(rossfast_d3r_material_t), intent(in) :: mat
    real(real64) :: m
    m=1.0_real64-1.0_real64/mat%n
    h=-(se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/mat%n)/mat%alpha_per_cm
  end function head_from_effective_saturation

  pure real(real64) function conductivity_from_head(h,mat) result(k)
    real(real64), intent(in) :: h
    type(rossfast_d3r_material_t), intent(in) :: mat
    real(real64) :: m,se,term
    m=1.0_real64-1.0_real64/mat%n
    se=(1.0_real64+abs(mat%alpha_per_cm*h)**mat%n)**(-m)
    term=(1.0_real64-se**(1.0_real64/m))**m
    k=mat%ksatfit_cm_per_day*se**mat%lambda*(1.0_real64-term)**2
  end function conductivity_from_head

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'F_ROSS14_PREIMAGE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ross14_preimage_boundary_proof
