program test_ftab02_g1_g3_generated_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_generated_mvg_provider, only: b110_generated_mvg_provider_t, &
       initialize_b110_generated_mvg_provider, bind_b110_generated_mvg_step_duration, B110_GENERATED_MVG_OK, &
       B110_GENERATED_MVG_INVALID_INPUT, B110_GENERATED_MVG_UNSUPPORTED_PROFILE
  implicit none

  type, extends(constitutive_hydraulics_provider_t) :: dummy_provider_t
  contains
    procedure :: evaluate => dummy_evaluate
  end type dummy_provider_t

  type(b110_default_mvg_parameters_t), target :: apar
  type(b110_default_mvg_provider_t) :: analytic
  type(b110_generated_mvg_provider_t) :: table1, table2, bad_provider
  type(dummy_provider_t) :: dummy
  real(real64), allocatable :: cofgen(:,:), bad(:,:), h(:)
  real(real64), allocatable :: ta(:),ka(:),ca(:),da(:),t1(:),k1(:),c1(:),d1(:),t2(:),k2(:),c2(:),d2(:)
  real(real64) :: ores,osat,alpha,npar,ksat,lexp,henpr,mpar,frac,exponent
  real(real64) :: max_theta,max_c,max_logk
  integer :: n,i,q,iu,ios,status
  character(len=32) :: soil
  character(len=512) :: path
  logical :: deterministic

  if (command_argument_count() /= 1) error stop 'usage: ftab02-g1-g3 INPUT'
  call get_command_argument(1,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if (ios /= 0) error stop 'cannot open input'
  read(iu,*,iostat=ios) n
  if (ios /= 0 .or. n <= 0) error stop 'invalid input header'
  allocate(cofgen(24,n))
  cofgen=0.0_real64
  do i=1,n
    read(iu,*,iostat=ios) soil,ores,osat,alpha,npar,ksat,lexp,henpr
    if (ios /= 0) error stop 'invalid material row'
    mpar=1.0_real64-1.0_real64/npar
    cofgen(1,i)=ores
    cofgen(2,i)=osat
    cofgen(3,i)=ksat
    cofgen(4,i)=alpha
    cofgen(5,i)=lexp
    cofgen(6,i)=npar
    cofgen(7,i)=mpar
    cofgen(9,i)=henpr
  end do
  close(iu)

  call initialize_b110_default_mvg_parameters(apar,cofgen)
  call bind_b110_default_mvg_provider(analytic,apar,0.04_real64)
  call initialize_b110_generated_mvg_provider(table1,cofgen,status)
  call require(status==B110_GENERATED_MVG_OK,'generated provider initializes')
  call initialize_b110_generated_mvg_provider(table2,cofgen,status)
  call require(status==B110_GENERATED_MVG_OK,'second generated provider initializes')
  call require(table1%ready() .and. table2%ready(),'generated providers ready')
  call require(.not. table1%context_compatible(0.04_real64),'generated context unbound fails closed')
  call bind_b110_generated_mvg_step_duration(table1,0.04_real64,status)
  call require(status==B110_GENERATED_MVG_OK,'generated timestep binds')
  call bind_b110_generated_mvg_step_duration(table2,0.04_real64,status)
  call require(status==B110_GENERATED_MVG_OK,'second generated timestep binds')

  call require(.not. dummy%context_compatible(0.04_real64),'default context capability fails closed')
  call require(analytic%context_compatible(0.04_real64),'analytical context compatible')
  call require(.not. analytic%context_compatible(0.05_real64),'analytical context mismatch fails closed')
  call require(table1%context_compatible(0.04_real64),'generated context compatible')
  call require(.not. table1%context_compatible(0.05_real64),'generated context mismatch fails closed')

  bad=cofgen
  bad(9,1)=-1.0_real64
  call initialize_b110_generated_mvg_provider(bad_provider,bad,status)
  call require(status==B110_GENERATED_MVG_UNSUPPORTED_PROFILE,'H_ENPR fails closed')
  bad=cofgen
  bad(10,1)=2.0_real64*bad(3,1)
  call initialize_b110_generated_mvg_provider(bad_provider,bad,status)
  call require(status==B110_GENERATED_MVG_UNSUPPORTED_PROFILE,'KSATEXM fails closed in core slice')
  bad=cofgen
  bad(4,1)=0.0_real64
  call initialize_b110_generated_mvg_provider(bad_provider,bad,status)
  call require(status==B110_GENERATED_MVG_INVALID_INPUT,'invalid alpha fails closed')

  allocate(h(n),ta(n),ka(n),ca(n),da(n),t1(n),k1(n),c1(n),d1(n),t2(n),k2(n),c2(n),d2(n))
  max_theta=0.0_real64
  max_c=0.0_real64
  max_logk=0.0_real64
  deterministic=.true.
  do q=1,1801
    frac=real(q-1,real64)/1800.0_real64
    exponent=7.0_real64-15.0_real64*frac
    h=-10.0_real64**exponent
    call analytic%evaluate(h,ta,ka,ca,da)
    call table1%evaluate(h,t1,k1,c1,d1)
    call table2%evaluate(h,t2,k2,c2,d2)
    if (any(.not. ieee_is_finite(t1)) .or. any(.not. ieee_is_finite(k1)) .or. &
        any(.not. ieee_is_finite(c1)) .or. any(k1 <= 0.0_real64)) error stop 'non-finite generated output'
    max_theta=max(max_theta,maxval(abs(t1-ta)))
    max_c=max(max_c,maxval(abs(c1-ca)))
    max_logk=max(max_logk,maxval(abs(log10(max(k1,1.0e-300_real64))-log10(max(ka,1.0e-300_real64)))))
    deterministic=deterministic .and. all(t1==t2) .and. all(k1==k2) .and. all(c1==c2) .and. all(d1==d2)
  end do

  write(*,'(a,i0)') 'FTAB02_SOIL_COUNT=',n
  write(*,'(a,es24.16)') 'FTAB02_THETA_MAX_ABS=',max_theta
  write(*,'(a,es24.16)') 'FTAB02_C_MAX_ABS=',max_c
  write(*,'(a,es24.16)') 'FTAB02_LOG10K_MAX_ABS=',max_logk
  call require(n==30,'30 Staring rows present')
  call require(max_theta<=1.0e-4_real64,'theta frozen gate')
  call require(max_c<=1.0e-4_real64,'capacity frozen gate')
  call require(max_logk<=5.0e-4_real64,'K frozen gate')
  call require(deterministic,'deterministic duplicate generation/evaluation')

  print '(a)', 'FTAB02_G1_CONTEXT_CAPABILITY=PASS'
  print '(a)', 'FTAB02_G2_DETERMINISTIC_GENERATION=PASS'
  print '(a)', 'FTAB02_G2_FAIL_CLOSED_SCOPE=PASS'
  print '(a)', 'FTAB02_G3_CONSTITUTIVE_ENVELOPE=PASS'
  print '(a)', 'F-TAB02 G1-G3 GENERATED K0 PROVIDER GATE PASS'

contains

  subroutine dummy_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(dummy_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    water_content=0.0_real64
    conductivity=1.0_real64
    capacity=0.0_real64
    dconductivity_dhead=0.0_real64
  end subroutine dummy_evaluate

  subroutine require(ok,label)
    logical, intent(in) :: ok
    character(len=*), intent(in) :: label
    if (.not. ok) then
      write(*,'(a,1x,a)') 'FTAB02_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ftab02_g1_g3_generated_provider
