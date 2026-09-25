program test_fahl27_heterogeneous_profile
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_mvg_provider, only: b110_adaptive_mvg_provider_t, bind_b110_adaptive_mvg_provider, &
       b110_adaptive_mvg_cache_stats
  implicit none

  integer, parameter :: n=6
  real(real64), parameter :: dt=0.25_real64
  real(real64), parameter :: theta_tol=1.0e-5_real64, logc_tol=1.0e-2_real64, logk_tol=1.0e-2_real64
  real(real64) :: input(24,n), h(n), wa(n),ka(n),ca(n),da(n), wl(n),kl(n),cl(n),dl(n)
  real(real64) :: theta_err,logc_err,logk_err,span
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t) :: analytical
  type(b110_adaptive_mvg_provider_t) :: adaptive
  logical :: ok,hit1,hit2
  integer :: i,builds,hits,misses,entries

  input=0.0_real64
  do i=1,n
    if(mod(i,2)==1)then
      call set_material(input(:,i),0.02_real64,0.427494_real64,31.225016_real64,0.021659_real64,0.98087_real64,1.734737_real64)
    else
      call set_material(input(:,i),0.01_real64,0.336701_real64,17.418504_real64,0.030304_real64,0.0736_real64,2.887502_real64)
    end if
  end do

  h=[-10.0_real64,-10.0_real64,-75.0_real64,-75.0_real64,-500.0_real64,-500.0_real64]
  call initialize_b110_default_mvg_parameters(hp,input)
  call bind_b110_default_mvg_provider(analytical,hp,dt)
  call analytical%evaluate(h,wa,ka,ca,da)

  call bind_b110_adaptive_mvg_provider(adaptive,hp,dt,ok,hit1)
  call require(ok,'first heterogeneous bind')
  call require(.not.hit1,'first heterogeneous bind builds')
  call require(adaptive%unique_material_count()==2,'exactly two unique hydraulic materials')
  call adaptive%evaluate(h,wl,kl,cl,dl)

  do i=1,n
    span=hp%cofgen(2,i)-hp%cofgen(1,i)
    theta_err=abs(wl(i)-wa(i))/span
    logc_err=abs(log(max(cl(i),1.0e-300_real64))-log(max(ca(i),1.0e-300_real64)))
    logk_err=abs(log(max(kl(i),1.0e-300_real64))-log(max(ka(i),1.0e-300_real64)))
    call require(theta_err<=theta_tol,'theta gate')
    call require(logc_err<=logc_tol,'capacity gate')
    call require(logk_err<=logk_tol,'conductivity gate')
  end do

  call bind_b110_adaptive_mvg_provider(adaptive,hp,dt,ok,hit2)
  call require(ok,'second heterogeneous bind')
  call require(hit2,'second heterogeneous bind all cache hits')
  call b110_adaptive_mvg_cache_stats(adaptive,builds,hits,misses,entries)
  call require(builds==2,'two unique builds')
  call require(hits==2,'two unique cache hits')
  call require(misses==2,'two unique cache misses')
  call require(entries==2,'two cache entries')

  write(*,'(A,I0)') 'FAHL27_HET_UNIQUE_MATERIALS=',adaptive%unique_material_count()
  write(*,'(A,4(I0,1X))') 'FAHL27_HET_CACHE_BUILDS_HITS_MISSES_ENTRIES=',builds,hits,misses,entries
  write(*,'(A)') 'FAHL27_HETEROGENEOUS_PROFILE=PASS'

contains

  subroutine set_material(c,tr,ts,ksat,alpha,lambda,nvg)
    real(real64),intent(out)::c(24)
    real(real64),intent(in)::tr,ts,ksat,alpha,lambda,nvg
    c=0.0_real64
    c(1)=tr;c(2)=ts;c(3)=ksat;c(4)=alpha;c(5)=lambda;c(6)=nvg
    c(7)=1.0_real64-1.0_real64/nvg;c(8)=alpha
    c(9)=0.0_real64;c(10)=ksat;c(11)=0.999_real64;c(12)=0.99_real64*ksat
    c(22)=-1.0e6_real64;c(23)=1.0e-12_real64
  end subroutine set_material

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'FAHL27_HET_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fahl27_heterogeneous_profile
