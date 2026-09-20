program tabhyd_generated_provider_break_even
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, initialize_tabhyd_raw_provider_from_mvg
  implicit none

  integer, parameter :: NROUND=12, NINIT=12, NSEQ=2048, NREPEAT=30
  real(real64), allocatable :: cofgen(:,:), h(:), ta(:),ka(:),ca(:),da(:), tt(:),kt(:),ct(:),dt(:), seq(:,:)
  real(real64) :: ai(NROUND), ti(NROUND), ae(NROUND), te(NROUND)
  real(real64) :: t0,t1,step_duration, frac, exponent, checksum
  real(real64) :: med_ai,med_ti,med_ae,med_te, extra_init, saved_eval, break_even
  integer :: n,i,j,r,rep,iu,ios
  character(len=512) :: path
  character(len=32) :: soil
  real(real64) :: ores,osat,alpha,npar,ksat,lexp,henpr
  type(b110_default_mvg_parameters_t), target :: ap
  type(b110_default_mvg_provider_t) :: analytic
  type(tabhyd_raw_provider_t) :: table

  if(command_argument_count()/=1) error stop 'usage: break-even INPUT'
  call get_command_argument(1,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 'cannot open input'
  read(iu,*,iostat=ios) n,step_duration
  if(ios/=0 .or. n<=0) error stop 'invalid header'
  allocate(cofgen(24,n)); cofgen=0.0_real64
  do i=1,n
    read(iu,*,iostat=ios) soil,ores,osat,alpha,npar,ksat,lexp,henpr
    if(ios/=0) error stop 'invalid row'
    cofgen(1,i)=ores; cofgen(2,i)=osat; cofgen(3,i)=ksat; cofgen(4,i)=alpha
    cofgen(5,i)=lexp; cofgen(6,i)=npar; cofgen(7,i)=1.0_real64-1.0_real64/npar
    cofgen(8,i)=alpha; cofgen(9,i)=henpr; cofgen(10,i)=ksat
    cofgen(11,i)=0.999_real64; cofgen(12,i)=0.99_real64*ksat
    cofgen(22,i)=-1.0e6_real64; cofgen(23,i)=1.0e-12_real64
  end do
  close(iu)

  allocate(h(n),ta(n),ka(n),ca(n),da(n),tt(n),kt(n),ct(n),dt(n),seq(n,NSEQ))
  do j=1,NSEQ
    do i=1,n
      frac=real(mod((j-1)*37+(i-1)*101,NSEQ),real64)/real(NSEQ-1,real64)
      exponent=-5.0_real64+12.0_real64*frac
      seq(i,j)=-10.0_real64**exponent
    end do
  end do

  ! Warm-up.
  call initialize_b110_default_mvg_parameters(ap,cofgen)
  call bind_b110_default_mvg_provider(analytic,ap,step_duration)
  call initialize_tabhyd_raw_provider_from_mvg(table,cofgen,step_duration)

  do r=1,NROUND
    if(mod(r,2)==1) then
      call time_analytic_init(ai(r))
      call time_table_init(ti(r))
    else
      call time_table_init(ti(r))
      call time_analytic_init(ai(r))
    end if
  end do

  ! Bind one stable pair for repeated hot-loop evaluation timing.
  call initialize_b110_default_mvg_parameters(ap,cofgen)
  call bind_b110_default_mvg_provider(analytic,ap,step_duration)
  call initialize_tabhyd_raw_provider_from_mvg(table,cofgen,step_duration)
  checksum=0.0_real64
  do r=1,NROUND
    if(mod(r,2)==1) then
      call time_analytic_eval(ae(r),checksum)
      call time_table_eval(te(r),checksum)
    else
      call time_table_eval(te(r),checksum)
      call time_analytic_eval(ae(r),checksum)
    end if
  end do

  med_ai=median_small(ai); med_ti=median_small(ti)
  med_ae=median_small(ae); med_te=median_small(te)
  extra_init=max(0.0_real64,med_ti-med_ai)
  saved_eval=(med_ae-med_te)/real(NSEQ*NREPEAT,real64)
  if(saved_eval>0.0_real64) then
    break_even=extra_init/saved_eval
  else
    break_even=huge(1.0_real64)
  end if

  write(*,'(a,i0)') 'BREAKEVEN_NODES=',n
  write(*,'(a,es24.16)') 'BREAKEVEN_ANALYTIC_INIT_MEDIAN_S=',med_ai
  write(*,'(a,es24.16)') 'BREAKEVEN_TABLE_INIT_MEDIAN_S=',med_ti
  write(*,'(a,es24.16)') 'BREAKEVEN_EXTRA_INIT_S=',extra_init
  write(*,'(a,es24.16)') 'BREAKEVEN_ANALYTIC_EVAL_BLOCK_S=',med_ae
  write(*,'(a,es24.16)') 'BREAKEVEN_TABLE_EVAL_BLOCK_S=',med_te
  write(*,'(a,es24.16)') 'BREAKEVEN_SAVED_PER_VECTOR_EVAL_S=',saved_eval
  write(*,'(a,es24.16)') 'BREAKEVEN_VECTOR_EVALUATIONS=',break_even
  write(*,'(a,es24.16)') 'BREAKEVEN_CHECKSUM=',checksum
  write(*,'(a,i0)') 'BREAKEVEN_TABLE_STATE_BYTES_ESTIMATE=',7*400*n*8+5*n*8

contains
  subroutine time_analytic_init(seconds)
    real(real64),intent(out)::seconds
    type(b110_default_mvg_parameters_t), target :: p
    type(b110_default_mvg_provider_t) :: v
    integer :: k
    call cpu_time(t0)
    do k=1,NINIT
      call initialize_b110_default_mvg_parameters(p,cofgen)
      call bind_b110_default_mvg_provider(v,p,step_duration)
    end do
    call cpu_time(t1)
    seconds=(t1-t0)/real(NINIT,real64)
  end subroutine

  subroutine time_table_init(seconds)
    real(real64),intent(out)::seconds
    type(tabhyd_raw_provider_t) :: v
    integer :: k
    call cpu_time(t0)
    do k=1,NINIT
      call initialize_tabhyd_raw_provider_from_mvg(v,cofgen,step_duration)
    end do
    call cpu_time(t1)
    seconds=(t1-t0)/real(NINIT,real64)
  end subroutine

  subroutine time_analytic_eval(seconds,sum)
    real(real64),intent(out)::seconds
    real(real64),intent(inout)::sum
    integer :: rr,jj
    call cpu_time(t0)
    do rr=1,NREPEAT
      do jj=1,NSEQ
        call analytic%evaluate(seq(:,jj),ta,ka,ca,da)
        sum=sum+ta(1)+ka(n)+ca(1+mod(jj-1,n))
      end do
    end do
    call cpu_time(t1); seconds=t1-t0
  end subroutine

  subroutine time_table_eval(seconds,sum)
    real(real64),intent(out)::seconds
    real(real64),intent(inout)::sum
    integer :: rr,jj
    call cpu_time(t0)
    do rr=1,NREPEAT
      do jj=1,NSEQ
        call table%evaluate(seq(:,jj),tt,kt,ct,dt)
        sum=sum+tt(1)+kt(n)+ct(1+mod(jj-1,n))
      end do
    end do
    call cpu_time(t1); seconds=t1-t0
  end subroutine

  real(real64) function median_small(v) result(m)
    real(real64),intent(in)::v(:)
    real(real64)::x(size(v)),tmp
    integer::a,b
    x=v
    do a=1,size(x)-1
      do b=a+1,size(x)
        if(x(b)<x(a)) then; tmp=x(a);x(a)=x(b);x(b)=tmp;end if
      end do
    end do
    if(mod(size(x),2)==0) then;m=0.5_real64*(x(size(x)/2)+x(size(x)/2+1));else;m=x((size(x)+1)/2);end if
  end function
end program tabhyd_generated_provider_break_even
