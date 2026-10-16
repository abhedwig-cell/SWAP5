program test_fpe_elastic08_prepare
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use MOD_grid, only: numnod
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, prepare_fmr_b110_default_mvg
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  type(fmr_b110_physical_parameters_t) :: runtime
  type(b110_default_mvg_parameters_t), target :: direct
  type(b110_default_mvg_provider_t) :: runtime_provider, direct_provider
  real(real64), allocatable :: c(:,:), ss(:), h(:), trun(:), krun(:), crun(:), drun(:)
  real(real64), allocatable :: tdir(:), kdir(:), cdir(:), ddir(:)
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,mm
  character(len=32) :: mode
  logical :: prepared
  integer :: i

  call get_command_argument(1,mode)
  call rr(2,tr); call rr(3,ts); call rr(4,alpha); call rr(5,nvg); call rr(6,ksat); call rr(7,lambda)

  allocate(c(24,numnod),ss(numnod),h(numnod),trun(numnod),krun(numnod),crun(numnod),drun(numnod))
  allocate(tdir(numnod),kdir(numnod),cdir(numnod),ddir(numnod))
  c=0.0_real64
  mm=1.0_real64-1.0_real64/nvg
  do i=1,numnod
    c(1,i)=tr; c(2,i)=ts; c(3,i)=ksat; c(4,i)=alpha; c(5,i)=lambda; c(6,i)=nvg; c(7,i)=mm
    c(8,i)=alpha; c(9,i)=0.0_real64; c(10,i)=ksat; c(11,i)=0.999_real64; c(12,i)=0.99_real64*ksat
    c(22,i)=-1.0e6_real64; c(23,i)=1.0e-12_real64
    ss(i)=1.0e-7_real64*real(i,real64)
    c(24,i)=ss(i)
  end do

  runtime%parameter_set_id=8008
  runtime%active_nodes=numnod
  runtime%cofgen=c
  runtime%bottom_mode=7
  runtime%swkimpl=0
  runtime%swsophy=0

  select case(trim(mode))
  case('off')
    runtime%elasticity_active=.false.
    call prepare_fmr_b110_default_mvg(runtime,prepared)
    call req(prepared,'off prepare')
    call req(runtime%prepared_default_mvg_available,'off prepared available')
    call req(.not.runtime%prepared_default_mvg%elastic_storage_active,'off elastic flag')
    call req(.not.allocated(runtime%prepared_default_mvg%specific_elastic_storage),'off elastic array')
    call initialize_b110_default_mvg_parameters(direct,c)
    call req(all(runtime%prepared_default_mvg%cofgen==direct%cofgen),'off cofgen identity')
  case('on')
    runtime%elasticity_active=.true.
    call prepare_fmr_b110_default_mvg(runtime,prepared)
    call req(prepared,'on prepare')
    call req(runtime%prepared_default_mvg_available,'on prepared available')
    call req(runtime%prepared_default_mvg%elastic_storage_active,'on elastic flag')
    call req(allocated(runtime%prepared_default_mvg%specific_elastic_storage),'on elastic array')
    call req(all(runtime%prepared_default_mvg%specific_elastic_storage==c(24,:)),'on row24 identity')
    call initialize_b110_default_mvg_parameters(direct,c,enable_elastic_storage=.true., &
         specific_elastic_storage_input=c(24,:))
    call req(all(runtime%prepared_default_mvg%cofgen==direct%cofgen),'on cofgen identity')
    call req(all(runtime%prepared_default_mvg%specific_elastic_storage==direct%specific_elastic_storage), &
         'on direct storage identity')
    call bind_b110_default_mvg_provider(runtime_provider,runtime%prepared_default_mvg,0.01_real64)
    call bind_b110_default_mvg_provider(direct_provider,direct,0.01_real64)
    h=2.0_real64
    call runtime_provider%evaluate(h,trun,krun,crun,drun)
    call direct_provider%evaluate(h,tdir,kdir,cdir,ddir)
    call req(all(trun==tdir).and.all(krun==kdir).and.all(crun==cdir).and.all(drun==ddir), &
         'on provider identity')
    do i=1,numnod
      call req(abs(trun(i)-(ts+2.0_real64*ss(i)))<=1.0e-14_real64,'heterogeneous theta')
      call req(crun(i)==ss(i),'heterogeneous capacity')
    end do
  case('invalid-negative')
    runtime%elasticity_active=.true.; runtime%cofgen(24,1)=-1.0e-6_real64
    call prepare_fmr_b110_default_mvg(runtime,prepared)
    call req(.not.prepared,'negative rejected')
  case('invalid-nan')
    runtime%elasticity_active=.true.; runtime%cofgen(24,1)=ieee_value(0.0_real64,ieee_quiet_nan)
    call prepare_fmr_b110_default_mvg(runtime,prepared)
    call req(.not.prepared,'nan rejected')
  case('invalid-ksatexm')
    runtime%elasticity_active=.true.; runtime%ksatexm_extension_active=.true.
    call prepare_fmr_b110_default_mvg(runtime,prepared)
    call req(.not.prepared,'ksatexm composition rejected')
  case('invalid-direct')
    runtime%elasticity_active=.true.; runtime%direct_retention_active=.true.
    call prepare_fmr_b110_default_mvg(runtime,prepared)
    call req(.not.prepared,'direct-retention composition rejected')
  case('invalid-tabulated')
    runtime%elasticity_active=.true.; runtime%tabulated_hydraulics_active=.true.
    call prepare_fmr_b110_default_mvg(runtime,prepared)
    call req(.not.prepared,'tabulated composition rejected')
  case('invalid-hysteresis')
    runtime%elasticity_active=.true.; runtime%hysteresis_active=.true.
    call prepare_fmr_b110_default_mvg(runtime,prepared)
    call req(.not.prepared,'hysteresis composition rejected')
  case default
    error stop 'F-PE-ELASTIC08 unknown mode'
  end select

  write(*,'(A,1X,A)') 'F_PE_ELASTIC08_PREPARE=PASS',trim(mode)
contains
  subroutine rr(k,x)
    integer,intent(in)::k
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(k,s); read(s,*)x
  end subroutine
  subroutine req(ok,msg)
    logical,intent(in)::ok
    character(len=*),intent(in)::msg
    if(.not.ok)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC08_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_elastic08_prepare
