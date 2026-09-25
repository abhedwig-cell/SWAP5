program test_fpe_planvalid01_baseline
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_serialized_execution_plan_t, &
       fmr_build_serialized_execution_plan, FMR_BACKEND_SERIALIZED_REFERENCE
  implicit none
  type(fmr_logical_column_t), allocatable :: columns(:)
  type(fmr_template_t), allocatable :: templates(:)
  type(fmr_serialized_execution_plan_t) :: plan
  integer(int64) :: c0,c1,rate,checksum
  integer :: n,reps,r,i
  logical :: valid
  real(real64) :: seconds
  character(len=32) :: arg

  call get_command_argument(1,arg); read(arg,*) n
  call get_command_argument(2,arg); read(arg,*) reps
  if(n<=0 .or. reps<=0) error stop 'PLANVALID01 requires N>0 reps>0'
  allocate(columns(n),templates(n))
  do i=1,n
    templates(i)%template_id=1000000_int64+int(i,int64)
    templates(i)%physics_topology_id=11_int64
    templates(i)%vertical_layout_id=12_int64
    templates(i)%state_layout_id=13_int64
    templates(i)%solver_interface_id=14_int64
    templates(i)%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    columns(i)%column_id=2000000_int64+int(i,int64)
    columns(i)%template_id=templates(i)%template_id
    columns(i)%parameter_ref=int(i,int64)
    columns(i)%state_handle=int(i,int64)
    columns(i)%forcing_handle=int(i,int64)
    columns(i)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end do

  checksum=0_int64
  call system_clock(c0,rate)
  do r=1,reps
    call fmr_build_serialized_execution_plan(columns,templates,n,plan,valid)
    if(.not.valid .or. .not.plan%ready()) error stop 'PLANVALID01 canonical build failed'
    checksum=checksum+int(plan%column_count(),int64)+int(plan%order_index(1),int64)+ &
         int(plan%order_index(n),int64)+int(plan%template_index(n),int64)
  end do
  call system_clock(c1)
  seconds=real(c1-c0,real64)/real(rate,real64)
  write(*,'(A,I0,A,I0,A,ES24.16,A,ES24.16,A,I0)') 'PLANVALID01_BASELINE,n=',n,',reps=',reps, &
       ',seconds=',seconds,',ns_per_build=',1.0e9_real64*seconds/real(reps,real64),',checksum=',checksum
  write(*,'(A)') 'PLANVALID01_BASELINE=PASS'
end program test_fpe_planvalid01_baseline
