module mod_ftab02d_dummy_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  type, extends(constitutive_hydraulics_provider_t) :: dummy_constitutive_t
  contains
    procedure :: evaluate => dummy_evaluate
  end type dummy_constitutive_t
contains
  subroutine dummy_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(dummy_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    water_content=0.0_real64
    conductivity=1.0_real64
    capacity=1.0_real64
    dconductivity_dhead=0.0_real64
  end subroutine dummy_evaluate
end module mod_ftab02d_dummy_provider

program test_ftab02d_constitutive_context_capability
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       initialize_b110_generated_mvg_table_state, F_TAB02_STATE_OK
  use mod_b110_generated_mvg_provider, only: b110_generated_mvg_provider_t, &
       bind_b110_generated_mvg_provider, F_TAB02_PROVIDER_OK
  use mod_ftab02d_dummy_provider, only: dummy_constitutive_t
  implicit none

  real(real64), parameter :: dt=0.25_real64
  real(real64) :: cofgen(24,1)
  type(b110_default_mvg_parameters_t), target :: parameters
  type(b110_default_mvg_provider_t) :: analytic
  type(b110_generated_mvg_table_state_t), target :: state
  type(b110_generated_mvg_provider_t) :: generated
  type(dummy_constitutive_t) :: dummy
  integer :: status

  cofgen=0.0_real64
  cofgen(1,1)=0.0_real64
  cofgen(2,1)=0.43_real64
  cofgen(3,1)=1.54_real64
  cofgen(4,1)=0.0065_real64
  cofgen(5,1)=-2.161_real64
  cofgen(6,1)=1.325_real64
  cofgen(7,1)=1.0_real64-1.0_real64/cofgen(6,1)
  cofgen(8,1)=cofgen(4,1)
  cofgen(9,1)=0.0_real64
  cofgen(10,1)=cofgen(3,1)
  cofgen(11,1)=0.999_real64
  cofgen(12,1)=0.99_real64*cofgen(3,1)
  cofgen(22,1)=-1.0e6_real64
  cofgen(23,1)=1.0e-12_real64

  call initialize_b110_default_mvg_parameters(parameters,cofgen)
  call bind_b110_default_mvg_provider(analytic,parameters,dt)
  call require(analytic%context_compatible(dt),'analytical exact context')
  call require(.not. analytic%context_compatible(1.25_real64*dt),'analytical mismatched context')
  call require(.not. analytic%context_compatible(0.0_real64),'analytical invalid context')

  call initialize_b110_generated_mvg_table_state(state,parameters,status)
  call require(status==F_TAB02_STATE_OK .and. state%ready(),'generated state')
  call bind_b110_generated_mvg_provider(generated,state,dt,status)
  call require(status==F_TAB02_PROVIDER_OK .and. generated%ready(),'generated bind')
  call require(generated%context_compatible(dt),'generated exact context')
  call require(.not. generated%context_compatible(1.25_real64*dt),'generated mismatched context')
  call require(.not. generated%context_compatible(-dt),'generated invalid context')

  call require(.not. dummy%context_compatible(dt),'default capability fails closed')

  write(*,'(a)') 'F_TAB02_D_ANALYTICAL_CONTEXT_MATCH=PASS'
  write(*,'(a)') 'F_TAB02_D_GENERATED_CONTEXT_MATCH=PASS'
  write(*,'(a)') 'F_TAB02_D_MISMATCH_FAIL_CLOSED=PASS'
  write(*,'(a)') 'F_TAB02_D_DEFAULT_FAIL_CLOSED=PASS'
  write(*,'(a)') 'F-TAB02-D CONTEXT CAPABILITY GATE PASS'
contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(a,1x,a)') 'F_TAB02_D_GATE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ftab02d_constitutive_context_capability
