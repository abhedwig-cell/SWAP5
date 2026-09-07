module mod_fsi08_failclosed_providers
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, source_sink_provider_t
  implicit none
  private
  public :: failclosed_constitutive_t, failclosed_source_sink_t

  type, extends(constitutive_hydraulics_provider_t) :: failclosed_constitutive_t
   contains
     procedure :: evaluate => constitutive_evaluate
  end type failclosed_constitutive_t

  type, extends(source_sink_provider_t) :: failclosed_source_sink_t
   contains
     procedure :: evaluate => source_sink_evaluate
  end type failclosed_source_sink_t
contains
  subroutine constitutive_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(failclosed_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    if (storage_size(self) <= 0 .or. size(pressure_head) <= 0) error stop 'invalid failclosed constitutive'
    water_content=0.30_real64; conductivity=1.0_real64; capacity=0.0_real64; dconductivity_dhead=0.0_real64
  end subroutine constitutive_evaluate

  subroutine source_sink_evaluate(self, pressure_head, water_content, source, sink)
    class(failclosed_source_sink_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: source(:), sink(:)
    if (storage_size(self) <= 0 .or. size(pressure_head) /= size(water_content)) error stop 'invalid failclosed source/sink'
    source=0.0_real64; sink=0.0_real64
  end subroutine source_sink_evaluate
end module mod_fsi08_failclosed_providers

program test_fsi08_provider_failclosed
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_fsi07_top_provider, only: fsi07_flux_top_provider_t
  use mod_fsi08_failclosed_providers
  use MOD_grid, only: numnod, z, dz, disnod
  use variables
  use fsi07_stub_control, only: headcalc_calls
  implicit none

  type(soil_water_parameter_set_t), target :: params
  type(failclosed_constitutive_t), target :: constitutive
  type(failclosed_source_sink_t), target :: source_sink
  type(fsi07_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws
  type(soil_water_solve_request_t) :: good, no_constitutive, no_source_sink
  type(soil_water_solve_result_t) :: result
  integer :: failures, before_calls

  failures=0
  call configure_params()
  call make_good_request(good)

  no_constitutive=good
  nullify(no_constitutive%evaluation%constitutive)
  before_calls=headcalc_calls
  call solver%solve(no_constitutive,ws,result)
  call expect(result%status==SW_SOLVE_FAILED,failures)
  call expect(trim(result%diagnostics%route)=='constitutive-provider-required',failures)
  call expect(headcalc_calls==before_calls,failures)

  no_source_sink=good
  nullify(no_source_sink%evaluation%source_sink)
  before_calls=headcalc_calls
  call solver%solve(no_source_sink,ws,result)
  call expect(result%status==SW_SOLVE_FAILED,failures)
  call expect(trim(result%diagnostics%route)=='source-sink-provider-required',failures)
  call expect(headcalc_calls==before_calls,failures)

  before_calls=headcalc_calls
  call solver%solve(good,ws,result)
  call expect(result%status==SW_SOLVE_CONVERGED,failures)
  call expect(headcalc_calls==before_calls+1,failures)

  if(failures/=0) then
    write(*,'(A,I0)') 'F-SI08_PROVIDER_FAILCLOSED FAIL failures=',failures
    error stop 1
  end if
  write(*,'(A)') 'F-SI08_PROVIDER_FAILCLOSED PASS'
contains
  subroutine configure_params()
    params%parameter_set_id=48081_int64
    params%active_nodes=numnod
    allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod))
    params%z=z; params%dz=dz; params%node_distance=disnod(1:numnod)
  end subroutine configure_params

  subroutine make_good_request(request)
    type(soil_water_solve_request_t),intent(out)::request
    request%parameters=>params
    request%evaluation%constitutive=>constitutive
    request%evaluation%source_sink=>source_sink
    request%evaluation%top_boundary=>top_provider
    request%step_duration=dt
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode=swbotb
    request%boundary%top_flux=-1.0_real64
    request%boundary%bottom_flux=-1.0_real64
    request%boundary%bottom_head=hbot
    request%numerical%max_iterations=maxit
    request%numerical%max_backtracking=maxbacktr
    request%numerical%conductivity_implicit_mode=swkimpl
    request%numerical%conductivity_mean_method=swkmean
    request%numerical%min_step_duration=dtmin
    request%numerical%compartment_balance_tolerance=CritDevBalCp
    request%numerical%total_balance_tolerance=CritDevBalTot
    request%numerical%head_abs_tolerance=critdevh2cp
    request%numerical%head_rel_tolerance=critdevh1cp
    request%numerical%ponding_tolerance=critdevponddt
    request%base_state%active_nodes=numnod
    allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
    request%base_state%pressure_head=-100.0_real64
    request%base_state%water_content=0.30_real64
    request%base_state%ponding_depth=0.0_real64
    request%base_state%groundwater_level=-2.0_real64
    top_provider%fixed_flux=-1.0_real64
    top_provider%surface_tracks_head=.true.
  end subroutine make_good_request

  subroutine expect(condition,fails)
    logical,intent(in)::condition
    integer,intent(inout)::fails
    if(.not.condition) fails=fails+1
  end subroutine expect
end program test_fsi08_provider_failclosed
