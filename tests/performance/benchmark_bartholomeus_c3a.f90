program benchmark_bartholomeus_c3a
  use iso_fortran_env, only: real64,int64
  use mod_bartholomeus_runtime_input, only: bartholomeus_runtime_view_t
  use mod_bartholomeus_parameter_contract
  use mod_bartholomeus_factor_provider, only: evaluate_bartholomeus_factors_from_state
  use mod_bartholomeus_waterfilm_provider, only: BARTHOLOMEUS_WATERFILM_REFERENCE
  implicit none
  integer,parameter::N=3, WARM=500, REPS=50000
  type(bartholomeus_runtime_view_t)::view
  type(BartholomeusImmutableDataset)::data
  type(BartholomeusCropParameters)::crop
  real(real64)::wroot(N),wz0(N),ctop,t0,t1,checksum
  real(real64),allocatable::f(:)
  integer::i,rate,c0,c1
  logical::ok

  call setup_case(view,data,crop,wroot,wz0,ctop)
  checksum=0
  do i=1,WARM
    call evaluate_bartholomeus_factors_from_state(view,data,crop,wroot,wz0,ctop,BARTHOLOMEUS_WATERFILM_REFERENCE,f,ok)
    if(.not.ok) error stop 'warmup'
    checksum=checksum+sum(f)
  end do
  call system_clock(c0,rate)
  do i=1,REPS
    call evaluate_bartholomeus_factors_from_state(view,data,crop,wroot,wz0,ctop,BARTHOLOMEUS_WATERFILM_REFERENCE,f,ok)
    if(.not.ok) error stop 'benchmark'
    checksum=checksum+sum(f)
  end do
  call system_clock(c1)
  t0=real(c1-c0,real64)/real(rate,real64)
  print '(a,i0)','C3A_PERF_REPS=',REPS
  print '(a,es24.16)','C3A_PERF_SECONDS=',t0
  print '(a,es24.16)','C3A_PERF_NS_PER_EVAL=',t0*1.e9_real64/REPS
  print '(a,es24.16)','C3A_PERF_CHECKSUM=',checksum
contains
  subroutine setup_case(v,d,c,wr,w0,top)
    type(bartholomeus_runtime_view_t),intent(out)::v
    type(BartholomeusImmutableDataset),intent(out)::d
    type(BartholomeusCropParameters),intent(out)::c
    real(real64),intent(out)::wr(N),w0(N),top
    real(real64)::cofgen(7,N),dz(N),org(N),sand(N),bd(N),w100(N),w500(N)
    logical::valid
    cofgen=0._real64
    cofgen(1,:)=.05_real64;cofgen(2,:)=.45_real64;cofgen(4,:)=.01_real64
    cofgen(6,:)=1.5_real64;cofgen(7,:)=1._real64-1._real64/cofgen(6,:)
    dz=10._real64;org=.02_real64;sand=.6_real64;bd=1300._real64
    w100=.30_real64;w500=.20_real64
    call construct_bartholomeus_dataset(cofgen,dz,org,sand,bd,w100,w500,w100,-100._real64,-500._real64,0,d,valid)
    if(.not.valid) error stop 'dataset construction'
    v%rooted_nodes=N
    allocate(v%pressure_head_cm(N),v%water_content(N),v%soil_temperature_k(N))
    v%pressure_head_cm=[-100._real64,-500._real64,-10._real64]
    v%water_content=[.30_real64,.20_real64,.40_real64]
    v%soil_temperature_k=293._real64
    c%c_mroot=1.e-5_real64;c%f_senes=1;c%q10_root=2
    c%specific_resp_humus=1.e-6_real64;c%q10_microbial=2
    c%microbial_shape_m=.9_real64;c%root_shape_m=.9_real64
    c%root_radius_m=.0002_real64;c%max_resp_factor=2
    wr=1._real64;w0=[1._real64,.8_real64,.6_real64];top=.27_real64
  end subroutine
end program
