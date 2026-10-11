program test_fahl49_provider_extraction
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t,b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
  use mod_b110_direct_retention_core, only: acquire_b110_direct_retention_slot,freeze_b110_direct_retention_pool, &
       reset_b110_direct_retention_pool,b110_direct_retention_pool_stats
  use mod_b110_direct_retention_provider, only: b110_direct_retention_provider_t,bind_b110_direct_retention_provider, &
       evaluate_b110_direct_retention_state_direction, evaluate_b110_direct_retention_water_content_direction
  implicit none
  integer,parameter::n=60
  type(b110_default_mvg_parameters_t),target::p
  type(b110_default_mvg_provider_t)::analytical
  type(b110_direct_retention_provider_t)::fast
  real(real64)::cof(42,n),h(n),wa(n),ka(n),ca(n),da(n),wf(n),kf(n),cf(n),df(n)
  real(real64)::dh(n),dtheta(n),dk(n),dtheta_only(n)
  integer::i,slot,slot2,entries,builds,hits
  integer(8)::payload
  logical::ok,hit,frozen,directional_ok
  character(len=64)::directional_route

  call make_cof(cof)
  call initialize_b110_default_mvg_parameters(p,cof)
  call bind_b110_default_mvg_provider(analytical,p,0.25_real64)
  call reset_b110_direct_retention_pool()
  call acquire_b110_direct_retention_slot(p,slot,ok,hit)
  call require(ok .and. .not.hit .and. slot==1,'first acquire')
  call acquire_b110_direct_retention_slot(p,slot2,ok,hit)
  call require(ok .and. hit .and. slot2==slot,'second acquire hit')
  call freeze_b110_direct_retention_pool()
  call bind_b110_direct_retention_provider(fast,p,0.25_real64,slot,ok)
  call require(ok,'provider bind')
  call b110_direct_retention_pool_stats(entries,builds,hits,payload,frozen)
  call require(entries==1 .and. builds==1 .and. hits==1 .and. payload==12384_8 .and. frozen,'pool stats')

  do i=1,n
    h(i)=-10.0_real64**(6.0_real64*real(i-1,real64)/real(n-1,real64))
  end do

  call analytical%evaluate(h,wa,ka,ca,da)
  call fast%evaluate(h,wf,kf,cf,df)
  call require(maxval(abs(wf-wa))==0.0_real64,'full theta analytical')
  call require(maxval(abs(kf-ka))==0.0_real64,'full K analytical')
  call require(maxval(abs(cf-ca))==0.0_real64,'full C analytical')

  call fast%evaluate_demand(h,CONSTITUTIVE_DEMAND_WATER_CONTENT,wf,kf,cf,df)
  call require(maxval(abs(wf-wa))<=1.0e-6_real64,'theta demand fidelity')
  call fast%evaluate_demand(h,CONSTITUTIVE_DEMAND_CAPACITY,wf,kf,cf,df)
  call require(maxval(abs(cf-ca))<=1.0e-6_real64,'capacity demand fidelity')

  h(1)=-0.5_real64
  h(n)=-2.0e6_real64
  call analytical%evaluate_demand(h,CONSTITUTIVE_DEMAND_WATER_CONTENT,wa,ka,ca,da)
  call fast%evaluate_demand(h,CONSTITUTIVE_DEMAND_WATER_CONTENT,wf,kf,cf,df)
  call require(wf(1)==wa(1) .and. wf(n)==wa(n),'outside-domain analytical fallback')

  dh=1.0_real64
  call evaluate_b110_direct_retention_state_direction(fast,h,dh,dtheta,dk,directional_ok,directional_route)
  call require(directional_ok,'state directional capability')
  call evaluate_b110_direct_retention_water_content_direction(fast,h,dh,dtheta_only,directional_ok,directional_route)
  call require(directional_ok,'water-content directional capability')
  call require(maxval(abs(dtheta-dtheta_only))<=1.0e-12_real64,'directional theta route consistency')
  call require(all(dtheta==dtheta) .and. all(dk==dk),'directional finite outputs')

  write(*,'(*(g0))') 'FAHL49_PROVIDER|SLOT=',slot,'|ENTRIES=',entries,'|BUILDS=',builds,'|HITS=',hits, &
       '|PAYLOAD=',payload
  write(*,'(A)') 'FAHL49_PROVIDER_EXTRACTION=PASS'
contains
  subroutine make_cof(c)
    real(real64),intent(out)::c(42,n)
    integer::j
    c=0.0_real64
    do j=1,n
      c(1,j)=0.02_real64;c(2,j)=0.427494_real64;c(3,j)=31.225016_real64
      c(4,j)=0.021659_real64;c(5,j)=0.98087_real64;c(6,j)=1.734737_real64
      c(7,j)=1.0_real64-1.0_real64/c(6,j);c(8,j)=c(4,j);c(10,j)=c(3,j)
      c(11,j)=0.999_real64;c(12,j)=0.99_real64*c(3,j);c(22,j)=-1.0e6_real64;c(23,j)=1.0e-12_real64
    end do
  end subroutine
  subroutine require(cond,label)
    logical,intent(in)::cond
    character(len=*),intent(in)::label
    if(.not.cond)then
      write(*,'(A,1X,A)')'FAHL49_PROVIDER_FAIL',trim(label)
      error stop 1
    end if
  end subroutine
end program
