program test_ftab02b_generated_mvg_provider
  use, intrinsic :: iso_fortran_env, only: error_unit, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       initialize_b110_generated_mvg_table_state, evaluate_b110_generated_mvg_table_state, F_TAB02_STATE_OK
  use mod_b110_generated_mvg_provider, only: b110_generated_mvg_provider_t, &
       bind_b110_generated_mvg_provider, F_TAB02_PROVIDER_OK, &
       F_TAB02_PROVIDER_STATE_NOT_READY, F_TAB02_PROVIDER_INVALID_STEP
  implicit none

  real(real64), parameter :: STEP = 4.0e-2_real64
  integer, parameter :: NSAMPLE = 1801
  integer :: n, i, j, iu, ios, status
  character(len=512) :: path
  character(len=16) :: soil
  real(real64), allocatable :: cofgen(:,:), h(:)
  real(real64), allocatable :: ta(:),ka(:),ca(:),da(:), tt(:),kt(:),ct(:),dt(:)
  real(real64) :: ores, osat, alpha, npar, ksat, lexp, frac, exponent
  real(real64) :: theta_err, capacity_err, logk_err
  type(b110_default_mvg_parameters_t), target :: parameters
  type(b110_default_mvg_provider_t) :: analytic
  type(b110_generated_mvg_table_state_t), target :: table_state
  type(b110_generated_mvg_table_state_t), target :: empty_state
  type(b110_generated_mvg_provider_t) :: table

  if (command_argument_count() /= 1) error stop 'usage: test_ftab02b FIXTURE'
  call get_command_argument(1,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if (ios /= 0) error stop 'cannot open F-TAB02 fixture'
  read(iu,*,iostat=ios) n
  if (ios /= 0 .or. n <= 0) error stop 'invalid F-TAB02 fixture header'
  allocate(cofgen(24,n)); cofgen=0.0_real64
  do i=1,n
    read(iu,*,iostat=ios) soil,ores,osat,alpha,npar,ksat,lexp
    if (ios /= 0) error stop 'invalid F-TAB02 fixture row'
    cofgen(1,i)=ores
    cofgen(2,i)=osat
    cofgen(3,i)=ksat
    cofgen(4,i)=alpha
    cofgen(5,i)=lexp
    cofgen(6,i)=npar
    cofgen(7,i)=1.0_real64-1.0_real64/npar
    cofgen(8,i)=alpha
    cofgen(9,i)=0.0_real64
    cofgen(10,i)=ksat
    cofgen(11,i)=0.999_real64
    cofgen(12,i)=0.99_real64*ksat
  end do
  close(iu)

  allocate(h(n),ta(n),ka(n),ca(n),da(n),tt(n),kt(n),ct(n),dt(n))
  call initialize_b110_default_mvg_parameters(parameters,cofgen)
  call bind_b110_default_mvg_provider(analytic,parameters,STEP)
  call initialize_b110_generated_mvg_table_state(table_state,parameters,status)
  call require(status == F_TAB02_STATE_OK, 'table state initialization')
  call bind_b110_generated_mvg_provider(table,table_state,STEP,status)
  call require(status == F_TAB02_PROVIDER_OK .and. table%ready(), 'typed provider binding')

  theta_err=0.0_real64
  capacity_err=0.0_real64
  logk_err=0.0_real64
  do j=1,NSAMPLE
    frac=real(j-1,real64)/real(NSAMPLE-1,real64)
    exponent=7.0_real64-15.0_real64*frac
    h=-10.0_real64**exponent
    call analytic%evaluate(h,ta,ka,ca,da)
    call evaluate_b110_generated_mvg_table_state(table_state,h,tt,kt,ct,status)
    if (status /= F_TAB02_STATE_OK) write(error_unit,'(a,i0,1x,a,es24.16,1x,a,i0)') &
         'F_TAB02_B_STATE_FAIL_SAMPLE=', j, 'h=', h(1), 'status=', status
    call require(status == F_TAB02_STATE_OK, 'table state broad sweep')
    call table%evaluate(h,tt,kt,ct,dt)
    theta_err=max(theta_err,maxval(abs(tt-ta)))
    capacity_err=max(capacity_err,maxval(abs(ct-ca)))
    do i=1,n
      logk_err=max(logk_err,abs(log10(kt(i))-log10(ka(i))))
    end do
    call require(all(dt == 0.0_real64), 'K0 derivative slot')
  end do

  ! Saturated and near-saturated capacity uses the same per-step floor as the
  ! canonical analytical provider. Rebinding changes only numerical context,
  ! not immutable table state.
  call bind_b110_default_mvg_provider(analytic,parameters,0.2_real64)
  call bind_b110_generated_mvg_provider(table,table_state,0.2_real64,status)
  call require(status == F_TAB02_PROVIDER_OK, 'step-duration rebind')
  h=0.0_real64
  call analytic%evaluate(h,ta,ka,ca,da)
  call table%evaluate(h,tt,kt,ct,dt)
  call require(all(ct == ca), 'saturated capacity floor')
  h=-1.0e-8_real64
  call analytic%evaluate(h,ta,ka,ca,da)
  call table%evaluate(h,tt,kt,ct,dt)
  call require(maxval(abs(ct-ca)) <= 1.0e-4_real64, 'near-saturated capacity after rebind')

  call bind_b110_generated_mvg_provider(table,empty_state,STEP,status)
  call require(status == F_TAB02_PROVIDER_STATE_NOT_READY, 'unready state fails closed')
  call bind_b110_generated_mvg_provider(table,table_state,0.0_real64,status)
  call require(status == F_TAB02_PROVIDER_INVALID_STEP, 'invalid step fails closed')

  call require(theta_err <= 1.0e-4_real64, 'theta envelope')
  call require(capacity_err <= 1.0e-4_real64, 'capacity envelope')
  call require(logk_err <= 5.0e-4_real64, 'conductivity envelope')

  write(*,'(a,i0)') 'F_TAB02_B_STARING_ROWS=',n
  write(*,'(a,es24.16)') 'F_TAB02_B_THETA_MAX_ABS=',theta_err
  write(*,'(a,es24.16)') 'F_TAB02_B_CAPACITY_MAX_ABS=',capacity_err
  write(*,'(a,es24.16)') 'F_TAB02_B_LOG10K_MAX_ABS=',logk_err
  write(*,'(a)') 'F_TAB02_B_K0_DERIVATIVE_SLOT_ZERO=PASS'
  write(*,'(a)') 'F_TAB02_B_STEP_DURATION_REBIND=PASS'
  write(*,'(a)') 'F_TAB02_B_BIND_FAIL_CLOSED=PASS'
  write(*,'(a)') 'F-TAB02-B TYPED GENERATED MVG PROVIDER GATE PASS'

contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(error_unit,'(a,1x,a)') 'F_TAB02_B_GATE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ftab02b_generated_mvg_provider
