program test_fpe_zero_waste01_parameter_preprocess
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  implicit none

  type(b110_default_mvg_parameters_t) :: hydraulic, prepared, copied
  type(b110_default_mvg_parameters_t), allocatable :: prepared_registry(:)
  type(soil_water_parameter_set_t) :: soil
  real(real64), allocatable :: cofgen(:,:), z(:), dz(:), disnod(:)
  real(real64) :: checksum_hydraulic, checksum_geometry, checksum_copy
  integer(int64) :: c0, c1, rate
  integer :: n, reps, r, registry_count, registry_index
  character(len=32) :: arg

  call get_command_argument(1,arg); read(arg,*) n
  call get_command_argument(2,arg); read(arg,*) reps
  if (n <= 0 .or. reps <= 0) error stop 'parameter preprocess benchmark invalid request'

  allocate(cofgen(24,n),z(n),dz(n),disnod(n))
  call initialize_fixture(cofgen,z,dz,disnod)

  checksum_hydraulic = 0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    call initialize_b110_default_mvg_parameters(hydraulic,cofgen)
    checksum_hydraulic = checksum_hydraulic + hydraulic%cofgen(25,1) + hydraulic%cofgen(42,n)
  end do
  call system_clock(c1)
  call emit('mvg_preprocess',n,reps,c0,c1,rate,checksum_hydraulic)

  prepared = hydraulic

  checksum_copy = 0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    if (allocated(copied%cofgen)) deallocate(copied%cofgen)
    copied = prepared
    checksum_copy = checksum_copy + copied%cofgen(25,1) + copied%cofgen(42,n)
  end do
  call system_clock(c1)
  call emit('prepared_copy_fresh',n,reps,c0,c1,rate,checksum_copy)

  if (allocated(copied%cofgen)) deallocate(copied%cofgen)
  copied%active_nodes = prepared%active_nodes
  copied%ksatexm_extension_enabled = prepared%ksatexm_extension_enabled
  allocate(copied%cofgen(size(prepared%cofgen,1),size(prepared%cofgen,2)))
  checksum_copy = 0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    copied%active_nodes = prepared%active_nodes
    copied%ksatexm_extension_enabled = prepared%ksatexm_extension_enabled
    copied%cofgen = prepared%cofgen
    checksum_copy = checksum_copy + copied%cofgen(25,1) + copied%cofgen(42,n)
  end do
  call system_clock(c1)
  call emit('prepared_copy_reuse',n,reps,c0,c1,rate,checksum_copy)

  select case (n)
  case (1:4)
    registry_count = 10000
  case (5:60)
    registry_count = 1000
  case (61:200)
    registry_count = 300
  case default
    registry_count = 60
  end select
  allocate(prepared_registry(registry_count))
  do r=1,registry_count
    call initialize_b110_default_mvg_parameters(prepared_registry(r),cofgen)
  end do

  if (allocated(copied%cofgen)) deallocate(copied%cofgen)
  checksum_copy = 0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    registry_index = 1 + mod(r-1,registry_count)
    copied = prepared_registry(registry_index)
    checksum_copy = checksum_copy + copied%cofgen(25,1) + copied%cofgen(42,n)
  end do
  call system_clock(c1)
  call emit('prepared_registry_copy_fresh',n,reps,c0,c1,rate,checksum_copy)

  if (allocated(copied%cofgen)) deallocate(copied%cofgen)
  copied%active_nodes = prepared_registry(1)%active_nodes
  copied%ksatexm_extension_enabled = prepared_registry(1)%ksatexm_extension_enabled
  allocate(copied%cofgen(size(prepared_registry(1)%cofgen,1),size(prepared_registry(1)%cofgen,2)))
  checksum_copy = 0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    registry_index = 1 + mod(r-1,registry_count)
    copied%active_nodes = prepared_registry(registry_index)%active_nodes
    copied%ksatexm_extension_enabled = prepared_registry(registry_index)%ksatexm_extension_enabled
    copied%cofgen = prepared_registry(registry_index)%cofgen
    checksum_copy = checksum_copy + copied%cofgen(25,1) + copied%cofgen(42,n)
  end do
  call system_clock(c1)
  call emit('prepared_registry_copy_reuse',n,reps,c0,c1,rate,checksum_copy)

  checksum_geometry = 0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    if (allocated(soil%z)) deallocate(soil%z)
    if (allocated(soil%dz)) deallocate(soil%dz)
    if (allocated(soil%node_distance)) deallocate(soil%node_distance)
    soil%parameter_set_id = int(r,int64)
    soil%active_nodes = n
    allocate(soil%z(n),soil%dz(n),soil%node_distance(n))
    soil%z = z
    soil%dz = dz
    soil%node_distance = disnod
    checksum_geometry = checksum_geometry + soil%z(n) + soil%dz(1) + soil%node_distance(n)
  end do
  call system_clock(c1)
  call emit('geometry_copy',n,reps,c0,c1,rate,checksum_geometry)

contains

  subroutine initialize_fixture(c,zv,dzv,dv)
    real(real64), intent(out) :: c(:,:),zv(:),dzv(:),dv(:)
    integer :: i
    c=0.0_real64
    do i=1,size(c,2)
      c(1,i)=0.032_real64
      c(2,i)=0.423_real64
      c(3,i)=4.75_real64
      c(4,i)=0.0135_real64
      c(5,i)=0.365_real64
      c(6,i)=1.455_real64
      c(7,i)=1.0_real64-1.0_real64/c(6,i)
      c(8,i)=c(4,i)
      c(9,i)=0.0_real64
      c(10,i)=c(3,i)
      c(11,i)=0.999_real64
      c(12,i)=0.99_real64*c(3,i)
      c(22,i)=-1.0e6_real64
      c(23,i)=1.0e-12_real64
      dzv(i)=1.0_real64
      zv(i)=-real(i,real64)
      dv(i)=1.0_real64
    end do
  end subroutine initialize_fixture

  subroutine emit(metric,nvalue,repetitions,start_clock,end_clock,clock_rate,checksum)
    character(len=*), intent(in) :: metric
    integer, intent(in) :: nvalue,repetitions
    integer(int64), intent(in) :: start_clock,end_clock,clock_rate
    real(real64), intent(in) :: checksum
    real(real64) :: seconds, ns_per_call
    seconds=real(end_clock-start_clock,real64)/real(clock_rate,real64)
    ns_per_call=1.0e9_real64*seconds/real(repetitions,real64)
    write(*,'(A,A,A,I0,A,I0,A,ES24.16,A,ES24.16,A,ES24.16)') &
      'ZW_PARAM,metric=',trim(metric),',n=',nvalue,',reps=',repetitions,',seconds=',seconds, &
      ',ns_per_call=',ns_per_call,',checksum=',checksum
  end subroutine emit
end program test_fpe_zero_waste01_parameter_preprocess
