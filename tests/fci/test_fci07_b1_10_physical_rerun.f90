program test_fci07_physical_rerun_probe
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_arrays, only: macp, fillen
  use MOD_grid, only: numnod
  use variables, only: h, theta, hm1, thetm1, pond, pondm1, gwl, gwlm1, volact, ldwet, spev, saev, tstart
  use MOD_SoilTemperature, only: tsoil
  use MOD_solute_global, only: cml
  use MOD_Solute, only: cmsy
  use MOD_integral, only: cgrai, cqbotdo, crunoff, cevap, cqdra, iqrot, iqssdi
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker
  use mod_b1_10_legacy_trial_capsule, only: b1_10_legacy_trial_capsule_t, capture_b1_10_legacy_trial_capsule, restore_b1_10_legacy_trial_capsule
  use swap_exchange
  implicit none
  interface
    subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap, worker)
      use swap_exchange
      use MOD_arrays, only: fillen
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
      integer, intent(in) :: iCaller, iTask
      real(8), intent(inout) :: tstart_in, tend_in
      character(len=fillen), intent(in), optional :: swp_file
      character(len=fillen), intent(in), optional :: outfile
      type(swap_input), intent(in), optional :: toswap
      type(swap_output), intent(out), optional :: fromswap
      type(a23bu_worker_context_t), intent(inout), optional :: worker
    end subroutine SWAP
  end interface
  type(a23bu_worker_context_t) :: worker
  type(b1_10_legacy_trial_capsule_t) :: capsule
  real(real64), allocatable :: h0(:),th0(:),hm10(:),thm10(:),ts0(:),cml0(:),cmsy0(:)
  real(real64), allocatable :: h1(:),th1(:),ts1(:),cml1(:),cmsy1(:)
  real(real64) :: pond0,pondm10,gwl0,gwlm10,vol0,ld0,sp0,sa0
  real(real64) :: t0,t1,base
  real(real64) :: acc1(7), acc2(7)
  integer :: n, offset
  character(len=32) :: arg

  offset=499
  call get_command_argument(1,arg)
  if (len_trim(arg)>0) read(arg,*) offset
  if (offset < 1) error stop 'offset must be positive'

  t0=0.0_real64; t1=0.0_real64
  call SWAP(0,1,t0,t1)
  n=numnod
  allocate(h0(n),th0(n),hm10(n),thm10(n),ts0(n),cml0(n),cmsy0(n))
  allocate(h1(n),th1(n),ts1(n),cml1(n),cmsy1(n))
  call a23bu_initialize_worker(worker,n,77)
  base=tstart

  ! Advance to the committed state immediately before the requested probe day.
  t0=base; t1=base+real(offset-1,real64)
  call SWAP(0,21,t0,t1,worker=worker)
  call SWAP(0,2,t0,t1,worker=worker)

  h0=h(1:n); th0=theta(1:n); hm10=hm1(1:n); thm10=thetm1(1:n)
  ts0=tsoil(1:n); cml0=cml(1:n); cmsy0=cmsy(1:n)
  pond0=pond; pondm10=pondm1; gwl0=gwl; gwlm10=gwlm1; vol0=volact; ld0=ldwet; sp0=spev; sa0=saev
  call capture_b1_10_legacy_trial_capsule(capsule)

  call run_probe_day()
  h1=h(1:n); th1=theta(1:n); ts1=tsoil(1:n); cml1=cml(1:n); cmsy1=cmsy(1:n)
  acc1=[cgrai,cqbotdo,crunoff,cevap,cqdra,iqrot,iqssdi]

  h(1:n)=h0; theta(1:n)=th0; hm1(1:n)=hm10; thetm1(1:n)=thm10
  tsoil(1:n)=ts0; cml(1:n)=cml0; cmsy(1:n)=cmsy0
  pond=pond0; pondm1=pondm10; gwl=gwl0; gwlm1=gwlm10; volact=vol0; ldwet=ld0; spev=sp0; saev=sa0
  call restore_b1_10_legacy_trial_capsule(capsule)
  call a23bu_initialize_worker(worker,n,77)

  call run_probe_day()
  acc2=[cgrai,cqbotdo,crunoff,cevap,cqdra,iqrot,iqssdi]

  print '(A,1PE13.5)', 'MAX_DH=',maxval(abs(h(1:n)-h1))
  print '(A,1PE13.5)', 'MAX_DTHETA=',maxval(abs(theta(1:n)-th1))
  print '(A,1PE13.5)', 'MAX_DTSOIL=',maxval(abs(tsoil(1:n)-ts1))
  print '(A,1PE13.5)', 'MAX_DCML=',maxval(abs(cml(1:n)-cml1))
  print '(A,1PE13.5)', 'MAX_DCMSY=',maxval(abs(cmsy(1:n)-cmsy1))
  print '(A,1PE13.5)', 'MAX_DACCOUNT=',maxval(abs(acc2-acc1))
  if (maxval(abs(h(1:n)-h1)) > 1.0e-10_real64 .or. maxval(abs(theta(1:n)-th1)) > 1.0e-12_real64 .or. &
      maxval(abs(tsoil(1:n)-ts1)) > 1.0e-10_real64 .or. maxval(abs(cml(1:n)-cml1)) > 1.0e-12_real64 .or. &
      maxval(abs(cmsy(1:n)-cmsy1)) > 1.0e-12_real64 .or. maxval(abs(acc2-acc1)) > 1.0e-12_real64) then
    print *, 'FCI07_PHYSICAL_RERUN_PROBE DIFFERENCE'
    stop 3
  end if
  print *, 'FCI07_PHYSICAL_RERUN_PROBE PASS'
contains
  subroutine run_probe_day()
    real(real64) :: a,b
    a=base+real(offset,real64); b=a
    call SWAP(0,21,a,b,worker=worker)
    call SWAP(0,2,a,b,worker=worker)
  end subroutine run_probe_day
end program
