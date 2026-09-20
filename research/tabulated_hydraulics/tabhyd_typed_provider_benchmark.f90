program tabhyd_typed_provider_benchmark
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, initialize_tabhyd_raw_provider, &
       TABHYD_RAW_TABLE_N
  implicit none

  integer, parameter :: NSEQ=2048, NROUNDS=8, NREPEAT=40
  type(b110_default_mvg_parameters_t), target :: apar
  type(b110_default_mvg_provider_t) :: analytic
  type(tabhyd_raw_provider_t) :: table
  real(real64), allocatable :: cofgen(:,:), headtab(:,:), thetatab(:,:), ktab(:,:)
  real(real64), allocatable :: h(:), ta(:), ka(:), ca(:), da(:), tt(:), kt(:), ct(:), dtbl(:)
  real(real64), allocatable :: seq(:,:), atime(:), ttime(:)
  real(real64) :: step_duration, ores, osat, alpha, npar, ksat, lexp, henpr, mpar
  real(real64) :: hval, frac, exponent, max_theta, max_c, max_logk, checksum_a, checksum_t
  real(real64) :: t0, t1, med_a, med_t
  integer :: nodes, nt, i, j, q, r, rep, iu, ios
  character(len=512) :: path
  character(len=32) :: soil

  if(command_argument_count()<1) error stop 'usage: typed-provider-benchmark INPUT'
  call get_command_argument(1,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 'cannot open benchmark input'
  read(iu,*,iostat=ios) nodes, nt, step_duration
  if(ios/=0 .or. nodes<=0 .or. nt/=TABHYD_RAW_TABLE_N) error stop 'invalid benchmark header'

  allocate(cofgen(24,nodes),headtab(nt,nodes),thetatab(nt,nodes),ktab(nt,nodes))
  cofgen=0.0_real64
  do i=1,nodes
    read(iu,*,iostat=ios) soil, ores, osat, alpha, npar, ksat, lexp, henpr
    if(ios/=0) error stop 'invalid material row'
    mpar=1.0_real64-1.0_real64/npar
    cofgen(1,i)=ores
    cofgen(2,i)=osat
    cofgen(3,i)=ksat
    cofgen(4,i)=alpha
    cofgen(5,i)=lexp
    cofgen(6,i)=npar
    cofgen(7,i)=mpar
    cofgen(9,i)=henpr
    do j=1,nt
      read(iu,*,iostat=ios) headtab(j,i),thetatab(j,i),ktab(j,i)
      if(ios/=0) error stop 'invalid table row'
    end do
  end do
  close(iu)

  call initialize_b110_default_mvg_parameters(apar,cofgen)
  call bind_b110_default_mvg_provider(analytic,apar,step_duration)
  call initialize_tabhyd_raw_provider(table,headtab,thetatab,ktab,cofgen,step_duration)

  allocate(h(nodes),ta(nodes),ka(nodes),ca(nodes),da(nodes),tt(nodes),kt(nodes),ct(nodes),dtbl(nodes))
  max_theta=0.0_real64
  max_c=0.0_real64
  max_logk=0.0_real64
  do q=1,1801
    frac=real(q-1,real64)/1800.0_real64
    exponent=7.0_real64-15.0_real64*frac
    hval=-10.0_real64**exponent
    h=hval
    call analytic%evaluate(h,ta,ka,ca,da)
    call table%evaluate(h,tt,kt,ct,dtbl)
    max_theta=max(max_theta,maxval(abs(tt-ta)))
    max_c=max(max_c,maxval(abs(ct-ca)))
    max_logk=max(max_logk,maxval(abs(log10(max(kt,1.0e-300_real64))-log10(max(ka,1.0e-300_real64)))))
  end do
  write(*,'(a,es24.16)') 'TYPED_ACCURACY_THETA_MAX=',max_theta
  write(*,'(a,es24.16)') 'TYPED_ACCURACY_C_MAX=',max_c
  write(*,'(a,es24.16)') 'TYPED_ACCURACY_LOG10K_MAX=',max_logk

  allocate(seq(nodes,NSEQ),atime(NROUNDS),ttime(NROUNDS))
  do j=1,NSEQ
    do i=1,nodes
      frac=real(mod((j-1)*37+(i-1)*101,NSEQ),real64)/real(NSEQ-1,real64)
      exponent=-5.0_real64+12.0_real64*frac
      seq(i,j)=-10.0_real64**exponent
    end do
  end do

  ! Warm-up both concrete type-bound routes.
  do j=1,NSEQ
    call analytic%evaluate(seq(:,j),ta,ka,ca,da)
    call table%evaluate(seq(:,j),tt,kt,ct,dtbl)
  end do

  checksum_a=0.0_real64
  checksum_t=0.0_real64
  do r=1,NROUNDS
    if(mod(r,2)==1) then
      call time_analytic(atime(r),checksum_a)
      call time_table(ttime(r),checksum_t)
    else
      call time_table(ttime(r),checksum_t)
      call time_analytic(atime(r),checksum_a)
    end if
    write(*,'(a,i0,a,es16.8,a,es16.8)') 'TYPED_BLOCK round=',r,' analytic_s=',atime(r),' table_s=',ttime(r)
  end do

  med_a=median_small(atime)
  med_t=median_small(ttime)
  write(*,'(a,es24.16)') 'TYPED_ANALYTIC_MEDIAN_S=',med_a
  write(*,'(a,es24.16)') 'TYPED_TABLE_MEDIAN_S=',med_t
  write(*,'(a,f14.8)') 'TYPED_TABLE_DELTA_PCT=',100.0_real64*(med_t/med_a-1.0_real64)
  write(*,'(a,es24.16)') 'TYPED_ANALYTIC_CHECKSUM=',checksum_a
  write(*,'(a,es24.16)') 'TYPED_TABLE_CHECKSUM=',checksum_t

contains

  subroutine time_analytic(seconds,checksum)
    real(real64), intent(out) :: seconds
    real(real64), intent(inout) :: checksum
    real(real64) :: a,b
    integer :: rr,jj
    call cpu_time(a)
    do rr=1,NREPEAT
      do jj=1,NSEQ
        call analytic%evaluate(seq(:,jj),ta,ka,ca,da)
        checksum=checksum+ta(1)+ka(nodes)+ca(1+mod(jj-1,nodes))
      end do
    end do
    call cpu_time(b)
    seconds=b-a
  end subroutine time_analytic

  subroutine time_table(seconds,checksum)
    real(real64), intent(out) :: seconds
    real(real64), intent(inout) :: checksum
    real(real64) :: a,b
    integer :: rr,jj
    call cpu_time(a)
    do rr=1,NREPEAT
      do jj=1,NSEQ
        call table%evaluate(seq(:,jj),tt,kt,ct,dtbl)
        checksum=checksum+tt(1)+kt(nodes)+ct(1+mod(jj-1,nodes))
      end do
    end do
    call cpu_time(b)
    seconds=b-a
  end subroutine time_table

  real(real64) function median_small(values) result(med)
    real(real64), intent(in) :: values(:)
    real(real64) :: x(size(values)), tmp
    integer :: a,b
    x=values
    do a=1,size(x)-1
      do b=a+1,size(x)
        if(x(b)<x(a)) then
          tmp=x(a); x(a)=x(b); x(b)=tmp
        end if
      end do
    end do
    if(mod(size(x),2)==0) then
      med=0.5_real64*(x(size(x)/2)+x(size(x)/2+1))
    else
      med=x((size(x)+1)/2)
    end if
  end function median_small

end program tabhyd_typed_provider_benchmark
