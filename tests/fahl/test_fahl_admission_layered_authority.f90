program test_fahl_admission_layered_authority
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: numnod
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, bind_b110_adaptive_hydraulic_provider
  implicit none

  real(real64), parameter :: dt=0.25_real64, h0=-75.0_real64
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t) :: analytical
  type(b110_adaptive_hydraulic_provider_t) :: adaptive
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: h(numnod), wa(numnod),ka(numnod),ca(numnod),da(numnod)
  real(real64) :: wl(numnod),kl(numnod),cl(numnod),dl(numnod)
  real(real64) :: theta_upper,theta_lower,logc_upper,logc_lower,logk_upper,logk_lower
  logical :: ok,hit
  integer :: i,split

  allocate(cofgen(24,numnod));cofgen=0.0_real64
  split=max(1,numnod/2)
  do i=1,numnod
    if(i<=split)then
      call set_mvg(cofgen(:,i),0.02_real64,0.427494_real64,31.225016_real64,0.021659_real64,0.98087_real64,1.734737_real64)
    else
      call set_mvg(cofgen(:,i),0.01_real64,0.393878_real64,2.495984_real64,0.003288_real64,0.514012_real64,1.616573_real64)
    end if
  end do

  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(analytical,hp,dt)
  call bind_b110_adaptive_hydraulic_provider(adaptive,hp,dt,ok,hit)
  if(.not.ok) error stop 'adaptive bind failed'

  h=h0
  call analytical%evaluate(h,wa,ka,ca,da)
  call adaptive%evaluate(h,wl,kl,cl,dl)

  theta_upper=maxval(abs(wl(:split)-wa(:split)))
  logc_upper=maxval(abs(log(max(cl(:split),tiny(1.0_real64)))-log(max(ca(:split),tiny(1.0_real64)))))
  logk_upper=maxval(abs(log(max(kl(:split),1.0e-10_real64))-log(max(ka(:split),1.0e-10_real64))))

  if(split<numnod)then
    theta_lower=maxval(abs(wl(split+1:)-wa(split+1:)))
    logc_lower=maxval(abs(log(max(cl(split+1:),tiny(1.0_real64)))-log(max(ca(split+1:),tiny(1.0_real64)))))
    logk_lower=maxval(abs(log(max(kl(split+1:),1.0e-10_real64))-log(max(ka(split+1:),1.0e-10_real64))))
  else
    theta_lower=0.0_real64;logc_lower=0.0_real64;logk_lower=0.0_real64
  end if

  write(*,'(A,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6)') 'FAHL_LAYER upper', &
       'DTHETA=',theta_upper,'DLOGC=',logc_upper,'DLOGK=',logk_upper
  write(*,'(A,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6)') 'FAHL_LAYER lower', &
       'DTHETA=',theta_lower,'DLOGC=',logc_lower,'DLOGK=',logk_lower

  if(theta_lower<=1.0e-4_real64 .and. logc_lower<=1.0e-2_real64 .and. logk_lower<=1.0e-2_real64)then
    write(*,'(A)') 'FAHL_LAYERED_AUTHORITY=PASS'
  else
    write(*,'(A)') 'FAHL_LAYERED_AUTHORITY=FAIL'
  end if

contains
  subroutine set_mvg(c,tr,ts,ksat,alpha,lambda,n)
    real(real64),intent(inout)::c(:)
    real(real64),intent(in)::tr,ts,ksat,alpha,lambda,n
    c=0.0_real64
    c(1)=tr;c(2)=ts;c(3)=ksat;c(4)=alpha;c(5)=lambda;c(6)=n
    c(7)=1.0_real64-1.0_real64/n;c(8)=alpha
    c(9)=0.0_real64;c(10)=ksat;c(11)=0.999_real64;c(12)=0.99_real64*ksat
    c(22)=-1.0e6_real64;c(23)=1.0e-12_real64
  end subroutine set_mvg
end program test_fahl_admission_layered_authority
