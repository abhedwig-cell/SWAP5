program test_fpe_zero_waste01_state_binding_reuse
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, initialize_reference_state_binding
  implicit none

  type(soil_water_parameter_set_t), target :: parameters
  type(soil_water_solve_request_t) :: request
  type(reference_richards_state_binding_t) :: binding
  integer :: n, reps, r
  integer(int64) :: c0,c1,rate,checksum
  real(real64) :: fresh_seconds,reuse_seconds
  character(len=32) :: arg

  call get_command_argument(1,arg); read(arg,*) n
  call get_command_argument(2,arg); read(arg,*) reps
  if (n <= 0 .or. reps <= 0) error stop 'H18 state binding benchmark invalid request'

  parameters%active_nodes=n
  request%parameters=>parameters
  request%base_state%active_nodes=n
  allocate(request%base_state%pressure_head(n),request%base_state%water_content(n))
  request%base_state%pressure_head=-100.0_real64
  request%base_state%water_content=0.25_real64
  request%base_state%ponding_depth=0.0_real64
  request%base_state%groundwater_level=-200.0_real64
  request%boundary%bottom_head=-250.0_real64
  request%boundary%top_head=0.0_real64
  request%boundary%top_flux=0.01_real64
  request%boundary%bottom_flux=0.0_real64
  request%step_duration=1.0_real64

  checksum=0_int64
  call system_clock(c0,rate)
  do r=1,reps
    binding=reference_richards_state_binding_t()
    call initialize_reference_state_binding(binding,request)
    checksum=checksum+int(size(binding%h)+size(binding%kmean)+size(binding%itnumb),int64)
  end do
  call system_clock(c1)
  fresh_seconds=real(c1-c0,real64)/real(rate,real64)

  binding=reference_richards_state_binding_t()
  call initialize_reference_state_binding(binding,request)
  checksum=0_int64
  call system_clock(c0)
  do r=1,reps
    call initialize_reference_state_binding(binding,request)
    checksum=checksum+int(size(binding%h)+size(binding%kmean)+size(binding%itnumb),int64)
  end do
  call system_clock(c1)
  reuse_seconds=real(c1-c0,real64)/real(rate,real64)

  write(*,'(A,I0,A,I0,A,ES24.16,A,ES24.16,A,ES24.16,A,I0)') &
       'ZW_STATE_BINDING,n=',n,',reps=',reps,',fresh_ns=',1.0e9_real64*fresh_seconds/real(reps,real64), &
       ',reuse_ns=',1.0e9_real64*reuse_seconds/real(reps,real64), &
       ',ratio=',reuse_seconds/fresh_seconds,',checksum=',checksum
  write(*,'(A)') 'FPE_ZERO_WASTE01_STATE_BINDING_REUSE=PASS'
end program test_fpe_zero_waste01_state_binding_reuse
