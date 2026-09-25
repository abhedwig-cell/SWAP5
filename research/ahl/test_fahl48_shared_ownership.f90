program test_fahl48_shared_ownership
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_ahl48_shared_direct_retention_provider, only: ahl48_shared_provider_t, bind_ahl48_shared_provider, &
       ahl48_shared_pool_stats, ahl48_freeze_shared_pool, ahl48_reset_shared_pool
  implicit none

  integer, parameter :: nproviders=10000, nn=60
  type(ahl48_shared_provider_t), allocatable :: providers(:)
  type(b110_default_mvg_parameters_t), target :: p1,p2,p3
  real(real64) :: cof1(42,nn),cof2(42,nn),cof3(42,nn),h(nn)
  real(real64) :: w1(nn),k1(nn),c1(nn),d1(nn),w2(nn),k2(nn),c2(nn),d2(nn)
  integer :: i,entries,builds,hits
  integer(int64) :: payload_bytes,provider_bytes
  logical :: ok,hit,frozen

  call make_cof(cof1,0.02_real64,0.427494_real64,0.021659_real64,1.734737_real64,31.225016_real64,0.98087_real64)
  call make_cof(cof2,0.01_real64,0.336701_real64,0.030304_real64,2.887502_real64,17.418504_real64,0.0736_real64)
  call make_cof(cof3,0.01_real64,0.393878_real64,0.003288_real64,1.616573_real64,2.495984_real64,0.514012_real64)
  call initialize_b110_default_mvg_parameters(p1,cof1)
  call initialize_b110_default_mvg_parameters(p2,cof2)
  call initialize_b110_default_mvg_parameters(p3,cof3)
  call ahl48_reset_shared_pool()

  allocate(providers(nproviders))
  do i=1,nproviders
    call bind_ahl48_shared_provider(providers(i),p1,0.25_real64,ok,hit)
    call require(ok,'same-authority bind')
    if(i==1)call require(.not.hit,'first bind miss')
    if(i>1)call require(hit,'subsequent same-authority hit')
  end do
  call ahl48_shared_pool_stats(entries,builds,hits,payload_bytes,provider_bytes,frozen)
  call require(entries==1 .and. builds==1 .and. hits==nproviders-1,'one representation for 10000 providers')
  call require(payload_bytes==6240_int64,'64-resolution raw payload bytes')
  call require(.not.frozen,'pool initially mutable')

  h=-75.0_real64
  call providers(1)%evaluate_demand(h,CONSTITUTIVE_DEMAND_WATER_CONTENT,w1,k1,c1,d1)
  call providers(nproviders)%evaluate_demand(h,CONSTITUTIVE_DEMAND_WATER_CONTENT,w2,k2,c2,d2)
  call require(all(transfer(w1,[0_int64],size(w1))==transfer(w2,[0_int64],size(w2))),'shared same-slot theta identity')
  call providers(1)%evaluate_demand(h,CONSTITUTIVE_DEMAND_CAPACITY,w1,k1,c1,d1)
  call providers(nproviders)%evaluate_demand(h,CONSTITUTIVE_DEMAND_CAPACITY,w2,k2,c2,d2)
  call require(all(transfer(c1,[0_int64],size(c1))==transfer(c2,[0_int64],size(c2))),'shared same-slot capacity identity')

  call bind_ahl48_shared_provider(providers(1),p2,0.25_real64,ok,hit)
  call require(ok .and. .not.hit,'second authority builds')
  call ahl48_shared_pool_stats(entries,builds,hits,payload_bytes,provider_bytes,frozen)
  call require(entries==2 .and. builds==2,'second authority owns second representation')
  call require(payload_bytes==12480_int64,'payload scales with unique authority')

  call ahl48_freeze_shared_pool()
  call bind_ahl48_shared_provider(providers(2),p1,0.25_real64,ok,hit)
  call require(ok .and. hit,'frozen pool permits existing authority bind')
  call bind_ahl48_shared_provider(providers(3),p3,0.25_real64,ok,hit)
  call require(.not.ok .and. .not.hit,'frozen pool rejects unseen authority')
  call ahl48_shared_pool_stats(entries,builds,hits,payload_bytes,provider_bytes,frozen)
  call require(frozen .and. entries==2,'freeze preserves immutable pool')

  write(*,'(*(g0))') 'FAHL48_OWNERSHIP|PROVIDERS=',nproviders,'|ENTRIES=',entries,'|BUILDS=',builds, &
       '|HITS=',hits,'|PAYLOAD_BYTES=',payload_bytes,'|PROVIDER_BYTES=',provider_bytes,'|FROZEN=',frozen
  write(*,'(A)') 'FAHL48_SHARED_OWNERSHIP=PASS'

contains
  subroutine make_cof(c,tr,ts,a,n,ksat,lambda)
    real(real64),intent(out)::c(42,nn)
    real(real64),intent(in)::tr,ts,a,n,ksat,lambda
    integer::j
    c=0.0_real64
    do j=1,nn
      c(1,j)=tr;c(2,j)=ts;c(3,j)=ksat;c(4,j)=a;c(5,j)=lambda;c(6,j)=n
      c(7,j)=1.0_real64-1.0_real64/n;c(8,j)=a;c(10,j)=ksat;c(11,j)=0.999_real64
      c(12,j)=0.99_real64*ksat;c(22,j)=-1.0e6_real64;c(23,j)=1.0e-12_real64
    end do
  end subroutine
  subroutine require(cond,label)
    logical,intent(in)::cond
    character(len=*),intent(in)::label
    if(.not.cond)then
      write(*,'(A,1X,A)') 'FAHL48_OWNERSHIP_FAIL',trim(label)
      error stop 1
    end if
  end subroutine
end program
