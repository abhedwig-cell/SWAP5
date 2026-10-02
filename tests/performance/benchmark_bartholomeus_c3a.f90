program benchmark_bartholomeus_c3a
  use iso_fortran_env, only: real64,int64
  use mod_bartholomeus_runtime_input, only: bartholomeus_runtime_view_t
  use mod_bartholomeus_parameter_contract
  use mod_bartholomeus_factor_provider, only: evaluate_bartholomeus_factors_from_state
  implicit none
  integer,parameter::N=3, WARM=2000, REPS=200000
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
    call evaluate_bartholomeus_factors_from_state(view,data,crop,wroot,wz0,ctop,0,f,ok)
    if(.not.ok) error stop 'warmup'
    checksum=checksum+sum(f)
  end do
  call system_clock(c0,rate)
  do i=1,REPS
    call evaluate_bartholomeus_factors_from_state(view,data,crop,wroot,wz0,ctop,0,f,ok)
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
    integer::j
    v%rooted_nodes=N
    allocate(v%pressure_head_cm(N),v%water_content(N),v%soil_temperature_k(N),d%soil(N))
    v%pressure_head_cm=[-50._real64,-10._real64,-1._real64]
    v%water_content=[.40_real64,.422_real64,.423_real64]
    v%soil_temperature_k=[293._real64,293._real64,293._real64]
    do j=1,N
      d%soil(j)%saturated_water_content=.423_real64
      d%soil(j)%depth_m=.1_real64
      d%soil(j)%percent_org_mat=.02_real64
      d%soil(j)%percent_sand=.6_real64
      d%soil(j)%soil_density=1300._real64
      d%soil(j)%diffusivity%gas_porosity_at_reference=.1_real64
      d%soil(j)%diffusivity%reference_diffusivity=1.e-6_real64
      d%soil(j)%waterfilm_gen_alpha_per_cm=.0135_real64
      d%soil(j)%waterfilm_gen_n=1.455_real64
      d%soil(j)%waterfilm_theta_r=.032_real64
      d%soil(j)%waterfilm_theta_s=.423_real64
      d%soil(j)%waterfilm_reference_head_cm=-100._real64
      d%soil(j)%waterfilm_reference_content=.30_real64
    end do
    c%c_mroot=1.e-5_real64;c%f_senes=1;c%q10_root=2
    c%specific_resp_humus=1.e-6_real64;c%q10_microbial=2
    c%microbial_shape_m=.9_real64;c%root_shape_m=.9_real64
    c%root_radius_m=.0002_real64;c%max_resp_factor=2
    wr=1._real64;w0=[1._real64,.8_real64,.6_real64];top=.27_real64
  end subroutine
end program
