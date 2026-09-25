program test_fahl48_parallel_read
  use, intrinsic :: iso_fortran_env, only: real64
  use omp_lib, only: omp_get_max_threads
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_ahl48_shared_direct_retention_provider, only: ahl48_shared_provider_t, bind_ahl48_shared_provider, &
       ahl48_freeze_shared_pool, ahl48_reset_shared_pool
  implicit none
  integer,parameter::n=60,nreplay=20000
  type(b110_default_mvg_parameters_t),target::p
  type(ahl48_shared_provider_t)::provider
  real(real64)::cof(42,n),h(n),wr(n),cr(n),kr(n),dr(n),w(n),c(n),k(n),d(n)
  real(real64)::maxerr
  integer::i,j
  logical::ok,hit

  call make_cof(cof)
  call initialize_b110_default_mvg_parameters(p,cof)
  call ahl48_reset_shared_pool()
  call bind_ahl48_shared_provider(provider,p,0.25_real64,ok,hit)
  if(.not.ok)error stop 'AHL48 parallel bind failed'
  call ahl48_freeze_shared_pool()
  do j=1,n
    h(j)=-10.0_real64**(6.0_real64*real(j-1,real64)/real(n-1,real64))
  end do
  call provider%evaluate_demand(h,CONSTITUTIVE_DEMAND_WATER_CONTENT,wr,kr,cr,dr)
  call provider%evaluate_demand(h,CONSTITUTIVE_DEMAND_CAPACITY,w,k,cr,d)

  maxerr=0.0_real64
!$omp parallel do default(shared) private(i,w,k,c,d) reduction(max:maxerr)
  do i=1,nreplay
    call provider%evaluate_demand(h,CONSTITUTIVE_DEMAND_WATER_CONTENT,w,k,c,d)
    maxerr=max(maxerr,maxval(abs(w-wr)))
    call provider%evaluate_demand(h,CONSTITUTIVE_DEMAND_CAPACITY,w,k,c,d)
    maxerr=max(maxerr,maxval(abs(c-cr)))
  end do
!$omp end parallel do
  if(maxerr/=0.0_real64)error stop 'AHL48 parallel read drift'
  write(*,'(*(g0))') 'FAHL48_PARALLEL_READ|THREADS=',omp_get_max_threads(),'|REPLAYS=',nreplay,'|MAXERR=',maxerr
  write(*,'(A)') 'FAHL48_PARALLEL_READ=PASS'
contains
  subroutine make_cof(x)
    real(real64),intent(out)::x(42,n)
    integer::q
    x=0.0_real64
    do q=1,n
      x(1,q)=0.02_real64;x(2,q)=0.427494_real64;x(3,q)=31.225016_real64
      x(4,q)=0.021659_real64;x(5,q)=0.98087_real64;x(6,q)=1.734737_real64
      x(7,q)=1.0_real64-1.0_real64/x(6,q);x(8,q)=x(4,q);x(10,q)=x(3,q)
      x(11,q)=0.999_real64;x(12,q)=0.99_real64*x(3,q);x(22,q)=-1.0e6_real64;x(23,q)=1.0e-12_real64
    end do
  end subroutine
end program
