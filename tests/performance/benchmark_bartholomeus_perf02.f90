program benchmark_bartholomeus_perf02
 use iso_fortran_env,only:real64,int64
 use mod_bartholomeus_runtime_input,only:bartholomeus_runtime_view_t
 use mod_bartholomeus_parameter_contract
 use mod_bartholomeus_factor_provider,only:evaluate_bartholomeus_factors_from_state,evaluate_bartholomeus_factors
 use mod_bartholomeus_waterfilm_provider,only:evaluate_bartholomeus_waterfilm,BARTHOLOMEUS_WATERFILM_REFERENCE,BARTHOLOMEUS_WATERFILM_OK
 use mod_bartholomeus_no_stress_gate,only:bartholomeus_macro_supply_bound_no_stress
 implicit none
 integer,parameter::N=3,WARM=500,REPS=30000
 type(bartholomeus_runtime_view_t)::v;type(BartholomeusImmutableDataset)::d;type(BartholomeusCropParameters)::c
 real(real64)::wr(N),w0(N),tops(3),sec,chk
 real(real64),allocatable::f(:),film(:)
 integer(int64)::a,b,rate;integer::i,j,status;logical::ok,g
 call setup(v,d,c,wr,w0);tops=[.27_real64,27._real64,2700._real64]
 do j=1,3
   do i=1,WARM;call gated(tops(j));enddo
   call system_clock(a,rate);chk=0
   do i=1,REPS;call gated(tops(j));chk=chk+sum(f);enddo
   call system_clock(b);sec=real(b-a,real64)/real(rate,real64)
   print '(a,i0,a,es16.8)','PERF02_GATED_REGIME=',j,' NS=',sec*1e9_real64/REPS
   do i=1,WARM;call perf01(tops(j));enddo
   call system_clock(a)
   do i=1,REPS;call perf01(tops(j));chk=chk+sum(f);enddo
   call system_clock(b);sec=real(b-a,real64)/real(rate,real64)
   print '(a,i0,a,es16.8)','PERF02_PERF01_REGIME=',j,' NS=',sec*1e9_real64/REPS
   call system_clock(a)
   do i=1,REPS;g=bartholomeus_macro_supply_bound_no_stress(v,d,c,wr,w0,tops(j));if(g)chk=chk+1e-12_real64;enddo
   call system_clock(b);sec=real(b-a,real64)/real(rate,real64)
   print '(a,i0,a,es16.8,a,l1)','PERF02_GATE_REGIME=',j,' NS=',sec*1e9_real64/REPS,' SKIP=',g
 enddo
 ! Mixed workload cycles stress/no-stress/high-oxygen calls.
 call system_clock(a);chk=0
 do i=1,REPS
   j=1+mod(i-1,3);call gated(tops(j));chk=chk+sum(f)
 enddo
 call system_clock(b);sec=real(b-a,real64)/real(rate,real64);print '(a,es16.8)','PERF02_GATED_MIXED_NS=',sec*1e9_real64/REPS
 call system_clock(a)
 do i=1,REPS
   j=1+mod(i-1,3);call perf01(tops(j));chk=chk+sum(f)
 enddo
 call system_clock(b);sec=real(b-a,real64)/real(rate,real64);print '(a,es16.8)','PERF02_PERF01_MIXED_NS=',sec*1e9_real64/REPS
 print '(a,es24.16)','PERF02_CHECKSUM=',chk
contains
 subroutine gated(top)
  real(real64),intent(in)::top
  call evaluate_bartholomeus_factors_from_state(v,d,c,wr,w0,top,BARTHOLOMEUS_WATERFILM_REFERENCE,f,ok)
  if(.not.ok)error stop 'gated'
 end subroutine
 subroutine perf01(top)
  real(real64),intent(in)::top
  call evaluate_bartholomeus_waterfilm(v,d,BARTHOLOMEUS_WATERFILM_REFERENCE,film,status);if(status/=BARTHOLOMEUS_WATERFILM_OK)error stop 'film'
  call evaluate_bartholomeus_factors(v,d,c,wr,w0,film,top,f,ok);if(.not.ok)error stop 'perf01'
 end subroutine
 subroutine setup(v,d,c,wr,w0)
  type(bartholomeus_runtime_view_t),intent(out)::v;type(BartholomeusImmutableDataset),intent(out)::d
  type(BartholomeusCropParameters),intent(out)::c;real(real64),intent(out)::wr(N),w0(N)
  real(real64)::cg(7,N),dz(N),org(N),sand(N),bd(N),w100(N),w500(N);logical::valid
  cg=0;cg(1,:)=.05;cg(2,:)=.45;cg(4,:)=.01;cg(6,:)=1.5;cg(7,:)=1._real64-1._real64/cg(6,:)
  dz=10;org=.02;sand=.6;bd=1300;w100=.30;w500=.20
  call construct_bartholomeus_dataset(cg,dz,org,sand,bd,w100,w500,w100,-100._real64,-500._real64,0,d,valid);if(.not.valid)error stop 'dataset'
  v%rooted_nodes=N;allocate(v%pressure_head_cm(N),v%water_content(N),v%soil_temperature_k(N))
  v%pressure_head_cm=[-100._real64,-500._real64,-10._real64];v%water_content=[.30_real64,.20_real64,.40_real64];v%soil_temperature_k=293
  c%c_mroot=1e-5;c%f_senes=1;c%q10_root=2;c%specific_resp_humus=1e-6;c%q10_microbial=2
  c%microbial_shape_m=.9;c%root_shape_m=.9;c%root_radius_m=.0002;c%max_resp_factor=2
  wr=1;w0=[1._real64,.8_real64,.6_real64]
 end subroutine
end program
