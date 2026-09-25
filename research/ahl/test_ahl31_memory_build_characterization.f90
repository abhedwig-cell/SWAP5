program test_ahl31_memory_build_characterization
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_builder, only: b110_adaptive_hydraulic_table_t, build_b110_adaptive_hydraulic_table
  implicit none

  integer, parameter :: N=256
  integer :: i, counts(N), sorted_counts(N), family, local_idx
  integer(int64) :: bytes(N), total_bytes, projected_mean_10k, projected_max_10k
  real(real64) :: times(N), sorted_times(N), t0, t1, mean_points, mean_time
  real(real64) :: raw(24,1), tr,ts,alpha,nvg,ksat,lambda
  type(b110_default_mvg_parameters_t) :: parameters
  type(b110_default_mvg_provider_t) :: provider
  type(b110_adaptive_hydraulic_table_t) :: table
  logical :: ok

  total_bytes=0_int64
  do i=1,N
    family=1+mod(i-1,4)
    local_idx=(i-1)/4
    call perturbed_material(family,local_idx,tr,ts,alpha,nvg,ksat,lambda)
    call make_raw(tr,ts,alpha,nvg,ksat,lambda,raw)
    call initialize_b110_default_mvg_parameters(parameters,raw)
    call bind_b110_default_mvg_provider(provider,parameters,0.25_real64)
    call cpu_time(t0)
    call build_b110_adaptive_hydraulic_table(provider,tr,ts,table,ok)
    call cpu_time(t1)
    call require(ok,'adaptive build failed')
    counts(i)=table%n
    times(i)=t1-t0
    bytes(i)=int(4_int64*8_int64*int(table%n,int64),int64)
    total_bytes=total_bytes+bytes(i)
  end do

  sorted_counts=counts
  sorted_times=times
  call sort_int(sorted_counts)
  call sort_real(sorted_times)
  mean_points=sum(real(counts,real64))/real(N,real64)
  mean_time=sum(times)/real(N,real64)
  projected_mean_10k=nint(real(total_bytes,real64)/real(N,real64)*10000.0_real64,kind=int64)
  projected_max_10k=maxval(bytes)*10000_int64

  write(*,'(A,1X,A,I0,1X,A,I0,1X,A,F10.3,1X,A,F10.3,1X,A,I0)') &
       'AHL31_SUPPORT','MIN=',minval(counts),'MEDIAN=',sorted_counts((N+1)/2), &
       'MEAN=',mean_points,'MAX=',real(maxval(counts),real64),'N=',N
  write(*,'(A,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0)') &
       'AHL31_MEMORY','TOTAL_BYTES_256=',total_bytes,'MEAN_BYTES=',nint(real(total_bytes,real64)/real(N,real64),kind=int64), &
       'PROJECTED_MEAN_BYTES_10000=',projected_mean_10k,'PROJECTED_MAX_BYTES_10000=',projected_max_10k
  write(*,'(A,1X,A,ES18.10,1X,A,ES18.10,1X,A,ES18.10)') &
       'AHL31_BUILD_CPU','MEAN_SEC=',mean_time,'MEDIAN_SEC=',sorted_times((N+1)/2),'MAX_SEC=',maxval(times)
  write(*,'(A)') 'AHL31_CHARACTERIZATION=PASS'

contains

  subroutine perturbed_material(family,idx,tr,ts,alpha,nvg,ksat,lambda)
    integer,intent(in)::family,idx
    real(real64),intent(out)::tr,ts,alpha,nvg,ksat,lambda
    real(real64)::fa,fn,fk,dl
    integer::a,b,c,d
    a=mod(idx,8); b=mod(idx/8,8); c=mod(3*idx+1,8); d=mod(5*idx+2,8)
    fa=0.95_real64+0.10_real64*real(a,real64)/7.0_real64
    fn=0.98_real64+0.04_real64*real(b,real64)/7.0_real64
    fk=0.90_real64+0.20_real64*real(c,real64)/7.0_real64
    dl=-0.05_real64+0.10_real64*real(d,real64)/7.0_real64
    select case(family)
    case(1)
      tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64*fa;nvg=1.734737_real64*fn
      ksat=31.225016_real64*fk;lambda=0.98087_real64+dl
    case(2)
      tr=0.01_real64;ts=0.529749_real64;alpha=0.016562_real64*fa;nvg=1.090671_real64*fn
      ksat=2.245895_real64*fk;lambda=-4.493581_real64+dl
    case(3)
      tr=0.01_real64;ts=0.336701_real64;alpha=0.030304_real64*fa;nvg=2.887502_real64*fn
      ksat=17.418504_real64*fk;lambda=0.0736_real64+dl
    case(4)
      tr=0.01_real64;ts=0.393878_real64;alpha=0.003288_real64*fa;nvg=1.616573_real64*fn
      ksat=2.495984_real64*fk;lambda=0.514012_real64+dl
    end select
  end subroutine perturbed_material

  subroutine make_raw(tr,ts,alpha,nvg,ksat,lambda,a)
    real(real64),intent(in)::tr,ts,alpha,nvg,ksat,lambda
    real(real64),intent(out)::a(24,1)
    a=0.0_real64
    a(1,1)=tr; a(2,1)=ts; a(3,1)=ksat; a(4,1)=alpha; a(5,1)=lambda; a(6,1)=nvg
    a(7,1)=1.0_real64-1.0_real64/nvg; a(8,1)=alpha; a(9,1)=0.0_real64
    a(10,1)=ksat; a(11,1)=0.999_real64; a(12,1)=0.99_real64*ksat
    a(22,1)=-1.0e6_real64; a(23,1)=1.0e-12_real64
  end subroutine make_raw

  subroutine sort_int(v)
    integer,intent(inout)::v(:)
    integer::i,j,tmp
    do i=1,size(v)-1
      do j=i+1,size(v)
        if(v(j)<v(i))then;tmp=v(i);v(i)=v(j);v(j)=tmp;end if
      end do
    end do
  end subroutine sort_int

  subroutine sort_real(v)
    real(real64),intent(inout)::v(:)
    integer::i,j
    real(real64)::tmp
    do i=1,size(v)-1
      do j=i+1,size(v)
        if(v(j)<v(i))then;tmp=v(i);v(i)=v(j);v(j)=tmp;end if
      end do
    end do
  end subroutine sort_real

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'AHL31_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_ahl31_memory_build_characterization
