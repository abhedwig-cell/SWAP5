program benchmark_bartholomeus_c3a_stages
 use iso_fortran_env,only:real64,int64
 use mod_bartholomeus_runtime_input,only:bartholomeus_runtime_view_t
 use mod_bartholomeus_parameter_contract
 use mod_bartholomeus_waterfilm_provider
 use mod_bartholomeus_response_assembly,only:assemble_bartholomeus_response_inputs
 use mod_bartholomeus_profile_response,only:bartholomeus_profile_factors
 use mod_bartholomeus_response,only:BartholomeusResponseInput
 implicit none
 integer,parameter::N=3,WARM=500,REPS=50000
 type(bartholomeus_runtime_view_t)::v
 type(BartholomeusImmutableDataset)::d
 type(BartholomeusCropParameters)::c
 type(BartholomeusResponseInput),allocatable::inp(:)
 real(real64),allocatable::film(:),fac(:)
 real(real64)::wr(N),w0(N),top,sec,chk
 integer(int64)::a,b,rate
 integer::i,status
 logical::ok
 call setup(v,d,c,wr,w0,top)
 do i=1,WARM;call evaluate_bartholomeus_waterfilm(v,d,BARTHOLOMEUS_WATERFILM_REFERENCE,film,status);end do
 call system_clock(a,rate)
 do i=1,REPS;call evaluate_bartholomeus_waterfilm(v,d,BARTHOLOMEUS_WATERFILM_REFERENCE,film,status);if(status/=0)error stop 'film';end do
 call system_clock(b);sec=real(b-a,real64)/rate;print '(a,es24.16)','STAGE_WATERFILM_NS=',sec*1e9_real64/REPS
 chk=sum(film)
 do i=1,WARM;call assemble_bartholomeus_response_inputs(v,d,c,wr,w0,film,inp,ok);end do
 call system_clock(a)
 do i=1,REPS;call assemble_bartholomeus_response_inputs(v,d,c,wr,w0,film,inp,ok);if(.not.ok)error stop 'assembly';end do
 call system_clock(b);sec=real(b-a,real64)/rate;print '(a,es24.16)','STAGE_ASSEMBLY_NS=',sec*1e9_real64/REPS
 top=.27_real64
 do i=1,WARM;call bartholomeus_profile_factors(inp,top,fac,ok);end do
 call system_clock(a)
 do i=1,REPS;call bartholomeus_profile_factors(inp,top,fac,ok);if(.not.ok)error stop 'profile';end do
 call system_clock(b);sec=real(b-a,real64)/rate;print '(a,es24.16)','STAGE_PROFILE_NS=',sec*1e9_real64/REPS
 chk=chk+sum(fac);print '(a,es24.16)','STAGE_CHECKSUM=',chk
contains
 subroutine setup(v,d,c,wr,w0,top)
 type(bartholomeus_runtime_view_t),intent(out)::v;type(BartholomeusImmutableDataset),intent(out)::d
 type(BartholomeusCropParameters),intent(out)::c;real(real64),intent(out)::wr(N),w0(N),top
 real(real64)::cg(7,N),dz(N),org(N),sand(N),bd(N),w100(N),w500(N);logical::valid
 cg=0;cg(1,:)=.05;cg(2,:)=.45;cg(4,:)=.01;cg(6,:)=1.5;cg(7,:)=1._real64-1._real64/cg(6,:)
 dz=10;org=.02;sand=.6;bd=1300;w100=.30;w500=.20
 call construct_bartholomeus_dataset(cg,dz,org,sand,bd,w100,w500,w100,-100._real64,-500._real64,0,d,valid)
 if(.not.valid)error stop 'dataset';v%rooted_nodes=N;allocate(v%pressure_head_cm(N),v%water_content(N),v%soil_temperature_k(N))
 v%pressure_head_cm=[-100._real64,-500._real64,-10._real64];v%water_content=[.30_real64,.20_real64,.40_real64];v%soil_temperature_k=293
 c%c_mroot=1e-5;c%f_senes=1;c%q10_root=2;c%specific_resp_humus=1e-6;c%q10_microbial=2
 c%microbial_shape_m=.9;c%root_shape_m=.9;c%root_radius_m=.0002;c%max_resp_factor=2
 wr=1;w0=[1._real64,.8_real64,.6_real64];top=.27
 end subroutine
end program
