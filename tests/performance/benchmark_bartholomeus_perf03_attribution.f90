program benchmark_bartholomeus_perf03_attribution
  use iso_fortran_env, only: real64,int64
  use mod_bartholomeus_runtime_input, only: bartholomeus_runtime_view_t
  use mod_bartholomeus_parameter_contract
  use mod_bartholomeus_waterfilm_provider
  use mod_bartholomeus_response_assembly, only: assemble_bartholomeus_response_inputs
  use mod_bartholomeus_response, only: BartholomeusResponseInput
  use mod_bartholomeus_profile_response, only: bartholomeus_profile_factors
  use mod_bartholomeus_factor_provider, only: evaluate_bartholomeus_factors_from_state
  use mod_bartholomeus_no_stress_gate, only: bartholomeus_macro_supply_bound_no_stress
#ifdef PERF03_COUNT
  use mod_bartholomeus_response, only: perf03_residual_calls
#endif
  implicit none
  integer,parameter :: n=3
  type(bartholomeus_runtime_view_t) :: v
  type(BartholomeusImmutableDataset) :: d
  type(BartholomeusCropParameters) :: c
  type(BartholomeusResponseInput),allocatable :: inputs(:)
  real(real64),allocatable :: film(:),f(:),reference(:)
  real(real64) :: cg(7,n),dz(n),org(n),sand(n),bd(n),w100(n),w500(n),wr(n),w0(n),checksum
  real(real64),parameter :: top=.27_real64
  integer :: i,j,status,reps,warm
  integer(int64) :: a,b,rate
  logical :: ok
  character(len=24) :: arg
  character(len=12),parameter :: labels(4)=[character(len=12)::'WATERFILM','ASSEMBLY','PROFILE','FULL']
#ifdef PERF03_COUNT
  integer :: previous,total
#endif
  reps=5000;warm=100
  call get_command_argument(1,arg)
  if(trim(arg)=='check') then
    reps=1;warm=0
  end if
  cg=0;cg(1,:)=.05_real64;cg(2,:)=.45_real64;cg(4,:)=.01_real64
  cg(6,:)=1.5_real64;cg(7,:)=1._real64-1._real64/cg(6,:)
  dz=10;org=.02;sand=.6;bd=1300;w100=.30;w500=.20
  call construct_bartholomeus_dataset(cg,dz,org,sand,bd,w100,w500,w100,-100._real64,-500._real64,0,d,ok)
  if(.not.ok) error stop 'dataset'
  v%rooted_nodes=n
  allocate(v%pressure_head_cm(n),v%water_content(n),v%soil_temperature_k(n))
  v%pressure_head_cm=-75._real64;v%water_content=.40_real64;v%soil_temperature_k=293._real64
  c%c_mroot=1.e-5_real64;c%f_senes=1;c%q10_root=2
  c%specific_resp_humus=1.e-6_real64;c%q10_microbial=2
  c%microbial_shape_m=.9_real64;c%root_shape_m=.9_real64;c%root_radius_m=.0002_real64;c%max_resp_factor=2
  wr=1;w0=[1._real64,.8_real64,.6_real64]
  if(bartholomeus_macro_supply_bound_no_stress(v,d,c,wr,w0,top)) error stop 'PERF02 unexpectedly eligible'
  call stage(1);call stage(2);call stage(3)
  reference=f
  call stage(4)
  if(any(f/=reference)) error stop 'full/profile identity'
  write(*,'(a)') 'PERF03_GATE_NEGATIVE_AND_FACTOR_IDENTITY=PASS'
  do i=1,n
    write(*,'(a,i0,a,es24.16,a,es24.16)') 'PERF03_SCIENCE|NODE=',i,'|FILM=',film(i),'|FACTOR=',reference(i)
  end do
#ifdef PERF03_COUNT
  previous=0
  do i=1,n
    perf03_residual_calls=0
    call bartholomeus_profile_factors(inputs(:i),top,f,ok)
    if(.not.ok.or.any(f/=reference(:i))) error stop 'instrumented profile identity'
    total=perf03_residual_calls
    write(*,'(a,i0,a,i0)') 'PERF03_RESIDUAL_COUNT|NODE=',i,'|CALLS=',total-previous
    previous=total
  end do
#endif
  do j=1,4
    do i=1,warm
      call stage(j)
    end do
    checksum=0
    call system_clock(a,rate)
    do i=1,reps
      call stage(j)
      if(j==1) then
        checksum=checksum+sum(film)
      else if(j==2) then
        checksum=checksum+inputs(1)%micro%waterfilm_thickness_m
      else
        checksum=checksum+sum(f)
      end if
    end do
    call system_clock(b)
    if(trim(arg)/='check') write(*,'(a,a,a,es24.16,a,es24.16)') &
      'PERF03_TIME|STAGE=',trim(labels(j)),'|NS=',real(b-a,real64)/real(rate,real64)*1.e9_real64/reps, &
      '|CHECKSUM=',checksum
  end do
contains
  subroutine stage(k)
    integer,intent(in) :: k
    select case(k)
    case(1)
      call evaluate_bartholomeus_waterfilm(v,d,BARTHOLOMEUS_WATERFILM_REFERENCE,film,status)
      if(status/=BARTHOLOMEUS_WATERFILM_OK) error stop 'waterfilm'
    case(2)
      call assemble_bartholomeus_response_inputs(v,d,c,wr,w0,film,inputs,ok)
      if(.not.ok) error stop 'assembly'
    case(3)
      call bartholomeus_profile_factors(inputs,top,f,ok)
      if(.not.ok) error stop 'profile'
    case(4)
      call evaluate_bartholomeus_factors_from_state(v,d,c,wr,w0,top,BARTHOLOMEUS_WATERFILM_REFERENCE,f,ok)
      if(.not.ok) error stop 'full'
    end select
  end subroutine stage
end program benchmark_bartholomeus_perf03_attribution
