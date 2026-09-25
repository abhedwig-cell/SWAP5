program test_fahl_governance_heterogeneous_profile
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, &
       bind_b110_adaptive_hydraulic_provider
  implicit none
  integer, parameter :: n=2
  real(real64) :: cofgen(24,n), h(n), wa(n),ka(n),ca(n),da(n), wt(n),kt(n),ct(n),dt(n)
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t) :: analytical
  type(b110_adaptive_hydraulic_provider_t) :: adaptive
  logical :: ok,hit

  cofgen=0.0_real64
  call set_material(1,0.02_real64,0.427494_real64,0.021659_real64,1.734737_real64,31.225016_real64,0.98087_real64)
  call set_material(2,0.01_real64,0.393878_real64,0.003288_real64,1.616573_real64,2.495984_real64,0.514012_real64)

  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(analytical,hp,0.25_real64)
  call bind_b110_adaptive_hydraulic_provider(adaptive,hp,0.25_real64,ok,hit)
  if(.not.ok) error stop 'adaptive bind failed before heterogeneity check exists'

  h=-75.0_real64
  call analytical%evaluate(h,wa,ka,ca,da)
  call adaptive%evaluate(h,wt,kt,ct,dt)

  write(*,'(A,ES14.6)') 'HET_NODE1_DTHETA=',abs(wt(1)-wa(1))
  write(*,'(A,ES14.6)') 'HET_NODE2_DTHETA=',abs(wt(2)-wa(2))
  write(*,'(A,ES14.6)') 'HET_NODE2_DK=',abs(kt(2)-ka(2))
  write(*,'(A,ES14.6)') 'HET_NODE2_DC=',abs(ct(2)-ca(2))
  if(abs(wt(2)-wa(2))<=1.0e-4_real64 .and. abs(kt(2)-ka(2))<=1.0e-5_real64) then
    write(*,'(A)') 'FAHL_HETEROGENEOUS_PROFILE_UNEXPECTED_PASS'
  else
    write(*,'(A)') 'FAHL_HETEROGENEOUS_PROFILE_FIRST_NODE_LEAK_REPRODUCED'
  end if

contains
  subroutine set_material(i,tr,ts,alpha,nvg,ksat,lambda)
    integer,intent(in)::i
    real(real64),intent(in)::tr,ts,alpha,nvg,ksat,lambda
    cofgen(1,i)=tr;cofgen(2,i)=ts;cofgen(3,i)=ksat
    cofgen(4,i)=alpha;cofgen(5,i)=lambda;cofgen(6,i)=nvg
    cofgen(7,i)=1.0_real64-1.0_real64/nvg;cofgen(8,i)=alpha
    cofgen(9,i)=0.0_real64;cofgen(10,i)=ksat;cofgen(11,i)=0.999_real64
    cofgen(12,i)=0.99_real64*ksat;cofgen(22,i)=-1.0e6_real64;cofgen(23,i)=1.0e-12_real64
  end subroutine set_material
end program test_fahl_governance_heterogeneous_profile
