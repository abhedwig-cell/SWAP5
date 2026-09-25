program test_fahl49_multiapp_slot_stability
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_direct_retention_core, only: reset_b110_direct_retention_pool, acquire_b110_direct_retention_slot, &
       freeze_b110_direct_retention_pool, sample_b110_direct_retention
  implicit none
  type(b110_default_mvg_parameters_t) :: a,b
  real(real64) :: ca(42,1),cb(42,1),ta,cap_a,t_before,c_before,t_after,c_after,t_b,c_b
  integer :: slot_a,slot_b
  logical :: ok,hit,inside

  call make_authority(ca,0.02_real64,0.427494_real64,0.021659_real64,1.734737_real64)
  call make_authority(cb,0.01_real64,0.336701_real64,0.030304_real64,2.887502_real64)
  call initialize_b110_default_mvg_parameters(a,ca)
  call initialize_b110_default_mvg_parameters(b,cb)

  call reset_b110_direct_retention_pool()
  call acquire_b110_direct_retention_slot(a,slot_a,ok,hit)
  call require(ok .and. slot_a==1,'authority A acquire')
  call freeze_b110_direct_retention_pool()
  call sample_b110_direct_retention(slot_a,-75.0_real64,t_before,c_before,inside)
  call require(inside,'authority A sample before reset')

  ! Mirrors initialization of a second direct-retention production application.
  call reset_b110_direct_retention_pool()
  call acquire_b110_direct_retention_slot(b,slot_b,ok,hit)
  call require(ok .and. slot_b==1,'authority B acquire after reset')
  call freeze_b110_direct_retention_pool()
  call sample_b110_direct_retention(slot_b,-75.0_real64,t_b,c_b,inside)
  call require(inside,'authority B sample')

  ! The old slot value from application A must remain bound to A for safe
  ! multi-application ownership. The current module-global reset is expected
  ! to falsify this requirement.
  call sample_b110_direct_retention(slot_a,-75.0_real64,t_after,c_after,inside)
  call require(inside,'old slot still numerically addressable')
  write(*,'(*(g0))') 'FAHL49_MULTIAPP|SLOT_A=',slot_a,'|SLOT_B=',slot_b, &
       '|A_BEFORE=',t_before,'|A_AFTER=',t_after,'|B=',t_b, &
       '|DELTA_OLD_SLOT=',abs(t_after-t_before)
  if(t_after==t_before .and. c_after==c_before)then
    write(*,'(A)') 'FAHL49_MULTIAPP_SLOT_STABILITY=PASS'
  else
    write(*,'(A)') 'FAHL49_MULTIAPP_SLOT_STABILITY=FALSIFIED'
    error stop 2
  end if
contains
  subroutine make_authority(c,tr,ts,alpha,n)
    real(real64),intent(out)::c(42,1)
    real(real64),intent(in)::tr,ts,alpha,n
    c=0.0_real64
    c(1,1)=tr;c(2,1)=ts;c(3,1)=10.0_real64;c(4,1)=alpha;c(5,1)=0.5_real64;c(6,1)=n
    c(7,1)=1.0_real64-1.0_real64/n;c(8,1)=alpha;c(10,1)=c(3,1)
    c(11,1)=0.999_real64;c(12,1)=0.99_real64*c(3,1);c(22,1)=-1.0e6_real64;c(23,1)=1.0e-12_real64
  end subroutine
  subroutine require(cond,label)
    logical,intent(in)::cond
    character(len=*),intent(in)::label
    if(.not.cond)then
      write(*,'(A,1X,A)')'FAHL49_MULTIAPP_FAIL',trim(label)
      error stop 1
    end if
  end subroutine
end program
