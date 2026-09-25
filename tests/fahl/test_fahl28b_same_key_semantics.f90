program test_fahl28b_same_key_semantics
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, &
       bind_b110_adaptive_hydraulic_provider, b110_adaptive_hydraulic_cache_stats
  implicit none

  real(real64), target :: input(24,1)
  type(b110_default_mvg_parameters_t), target :: parameters
  type(b110_adaptive_hydraulic_provider_t) :: adaptive
  integer :: b0,h0,m0,e0,b1,h1,m1,e1
  logical :: ok,hit

  input=0.0_real64
  input(1,1)=0.032_real64; input(2,1)=0.423_real64; input(3,1)=4.75_real64
  input(4,1)=0.0135_real64; input(5,1)=0.365_real64; input(6,1)=1.455_real64
  input(7,1)=1.0_real64-1.0_real64/input(6,1); input(8,1)=input(4,1)
  input(9,1)=0.0_real64; input(10,1)=input(3,1); input(11,1)=0.999_real64
  input(12,1)=0.99_real64*input(3,1); input(22,1)=-1.0e6_real64; input(23,1)=1.0e-12_real64
  call initialize_b110_default_mvg_parameters(parameters,input)

  call bind_b110_adaptive_hydraulic_provider(adaptive,parameters,0.25_real64,ok,hit)
  call require(ok .and. .not.hit,'cold bind builds representation')
  call b110_adaptive_hydraulic_cache_stats(b0,h0,m0,e0)
  call require(b0==1 .and. m0==1 .and. e0==1,'cold bind cache accounting')

  call bind_b110_adaptive_hydraulic_provider(adaptive,parameters,0.50_real64,ok,hit)
  call require(ok .and. hit,'changed-step same-key reuse')
  call b110_adaptive_hydraulic_cache_stats(b1,h1,m1,e1)

  call require(b1==b0,'same-key reuse build count stable')
  call require(h1==h0,'same-key reuse bypasses shared-cache hit accounting')
  call require(m1==m0,'same-key reuse miss count stable')
  call require(e1==e0,'same-key reuse entry count stable')

  write(*,'(A,4(1X,I0))') 'AHL28B_CACHE_BEFORE',b0,h0,m0,e0
  write(*,'(A,4(1X,I0))') 'AHL28B_CACHE_AFTER',b1,h1,m1,e1
  write(*,'(A)') 'AHL28B_SAME_KEY_SEMANTICS=PASS'

contains
  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(A,1X,A)') 'AHL28B_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require
end program test_fahl28b_same_key_semantics
