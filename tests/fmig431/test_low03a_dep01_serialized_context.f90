program test_low03a_dep01_serialized_context
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t
  use mod_b110_serialized_context_binding, only: bind_b110_serialized_legacy_context
  use MOD_swap_base, only: swmacro
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_snow, only: melt
  use variables, only: dt, swbotb, swkimpl, swkmean, dtmin, maxit, maxbacktr, CritDevBalCp, CritDevBalTot, &
       critdevh2cp, critdevh1cp, critdevponddt, fldtmin, qtop, qbot, hbot, qrot
  implicit none
  type(soil_water_parameter_set_t), target :: parameters
  type(soil_water_solve_request_t) :: request
  integer, parameter :: admitted(5)=[7,-2,5,2,3]
  integer :: i
  logical :: ok

  parameters%active_nodes=numnod
  allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
  parameters%z=z
  parameters%dz=dz
  parameters%node_distance=disnod(1:numnod)
  swmacro=0
  melt=0.0_real64
  qrot=0.0_real64

  do i=1,size(admitted)
    call make_request(admitted(i),0)
    call bind_b110_serialized_legacy_context(request,ok)
    call require(ok,'admitted mode rejected')
    call require(swbotb==admitted(i),'bottom mode mirror')
    call require(swkimpl==0 .and. swkmean==2,'numerical mode mirror')
    call require(maxit==17 .and. maxbacktr==6,'iteration mirror')
    call require(same_bits(dt,0.125_real64) .and. same_bits(dtmin,1.25e-6_real64),'time mirror')
    call require(same_bits(qtop,-0.004_real64) .and. same_bits(qbot,0.0123_real64) .and. &
         same_bits(hbot,-75.0_real64),'boundary value mirror')
    call require(same_bits(CritDevBalCp,2.0e-10_real64) .and. same_bits(CritDevBalTot,3.0e-10_real64),'mass tolerances mirror')
    call require(same_bits(critdevh2cp,4.0e-8_real64) .and. same_bits(critdevh1cp,5.0e-8_real64) .and. &
         same_bits(critdevponddt,6.0e-8_real64),'head tolerances mirror')
    call require(.not.fldtmin,'trial minimum-step flag reset')
  end do
  print '(a)','LOW03A_DEP01_EXISTING_MODES_AND_MODE3_MIRROR=PASS'

  do i=1,3
    call make_request([1,8,9](i),0)
    call bind_b110_serialized_legacy_context(request,ok)
    call require(.not.ok,'unsupported selector admitted')
  end do
  call make_request(3,1)
  call bind_b110_serialized_legacy_context(request,ok)
  call require(.not.ok,'mode3 SWKIMPL1 admitted')
  print '(a)','LOW03A_DEP01_FAIL_CLOSED_MATRIX=PASS'
  print '(a)','LOW03A_DEP01_SERIALIZED_CONTEXT_GATE=PASS'
contains
  subroutine make_request(mode,kimpl)
    integer,intent(in)::mode,kimpl
    request=soil_water_solve_request_t()
    request%parameters=>parameters
    request%step_duration=0.125_real64
    request%boundary%bottom_mode=mode
    request%boundary%top_flux=-0.004_real64
    request%boundary%bottom_flux=0.0123_real64
    request%boundary%bottom_head=-75.0_real64
    request%numerical%conductivity_implicit_mode=kimpl
    request%numerical%conductivity_mean_method=2
    request%numerical%min_step_duration=1.25e-6_real64
    request%numerical%max_iterations=17
    request%numerical%max_backtracking=6
    request%numerical%compartment_balance_tolerance=2.0e-10_real64
    request%numerical%total_balance_tolerance=3.0e-10_real64
    request%numerical%head_abs_tolerance=4.0e-8_real64
    request%numerical%head_rel_tolerance=5.0e-8_real64
    request%numerical%ponding_tolerance=6.0e-8_real64
  end subroutine
  logical function same_bits(a,b) result(same)
    real(real64),intent(in)::a,b
    same=transfer(a,0_int64)==transfer(b,0_int64)
  end function
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)')'LOW03A_DEP01_FAIL',trim(label)
      error stop 1
    end if
  end subroutine
end program test_low03a_dep01_serialized_context
