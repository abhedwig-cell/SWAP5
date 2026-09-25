program test_fpe_zero_waste01_parameter_preprocess
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  implicit none

  type(b110_default_mvg_parameters_t) :: hydraulic, prepared, copied
  type(b110_default_mvg_parameters_t), allocatable :: prepared_registry(:)
  type(soil_water_parameter_set_t) :: soil
  real(real64), allocatable :: cofgen(:,:), raw_registry(:,:,:), compact_cache(:,:), &
       compact_dependency_registry(:,:,:), compact_derived_registry(:,:,:), z(:), dz(:), disnod(:)
  real(real64) :: checksum_hydraulic, checksum_geometry, checksum_copy
  integer(int64) :: c0, c1, rate
  integer :: n, reps, r, registry_count, registry_index, compat_count
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

  allocate(compact_cache(4,n))
  compact_cache(1,:) = prepared%cofgen(26,:)
  compact_cache(2,:) = prepared%cofgen(28,:)
  compact_cache(3,:) = prepared%cofgen(41,:)
  compact_cache(4,:) = prepared%cofgen(42,:)
  checksum_copy = 0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    call refresh_from_compact_cache(cofgen, compact_cache, .false., copied)
    checksum_copy = checksum_copy + copied%cofgen(25,1) + copied%cofgen(42,n)
  end do
  call system_clock(c1)
  call emit('compact_derived_cache_refresh',n,reps,c0,c1,rate,checksum_copy)

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
  allocate(prepared_registry(registry_count), raw_registry(size(cofgen,1),n,registry_count), &
       compact_dependency_registry(6,n,registry_count), compact_derived_registry(4,n,registry_count))
  do r=1,registry_count
    raw_registry(:,:,r) = cofgen
    call initialize_b110_default_mvg_parameters(prepared_registry(r),raw_registry(:,:,r))
    call capture_compact_cache(raw_registry(:,:,r), prepared_registry(r), &
         compact_dependency_registry(:,:,r), compact_derived_registry(:,:,r))
  end do

  compat_count = 0
  call system_clock(c0,rate)
  do r=1,reps
    registry_index = 1 + mod(r-1,registry_count)
    if (all(prepared_registry(registry_index)%cofgen(1:size(raw_registry,1),:) == &
            raw_registry(:,:,registry_index))) compat_count = compat_count + 1
  end do
  call system_clock(c1)
  call emit('prepared_registry_exact_scan',n,reps,c0,c1,rate,real(compat_count,real64))

  compat_count = 0
  checksum_copy = 0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    registry_index = 1 + mod(r-1,registry_count)
    if (compact_dependencies_match(raw_registry(:,:,registry_index), compact_dependency_registry(:,:,registry_index))) then
      compat_count = compat_count + 1
      call refresh_from_compact_cache(raw_registry(:,:,registry_index), compact_derived_registry(:,:,registry_index), &
           .false., copied)
      checksum_copy = checksum_copy + copied%cofgen(25,1) + copied%cofgen(42,n)
    end if
  end do
  call system_clock(c1)
  if (compat_count /= reps) error stop 'compact registry compatibility unexpectedly failed'
  call emit('compact_registry_scan_refresh',n,reps,c0,c1,rate,checksum_copy)

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

  call qualify_compact_variants(n)

contains

  subroutine refresh_from_compact_cache(raw,cache,extension_enabled,target)
    real(real64), intent(in) :: raw(:,:), cache(:,:)
    logical, intent(in) :: extension_enabled
    type(b110_default_mvg_parameters_t), intent(inout) :: target
    integer :: i, nn

    nn = size(raw,2)
    if (allocated(target%cofgen)) deallocate(target%cofgen)
    target%active_nodes = nn
    target%ksatexm_extension_enabled = extension_enabled
    allocate(target%cofgen(42,nn))
    target%cofgen = 0.0_real64
    target%cofgen(1:min(size(raw,1),42),:) = raw(1:min(size(raw,1),42),:)

    do i=1,nn
      target%cofgen(25,i) = target%cofgen(2,i)-target%cofgen(1,i)
      target%cofgen(26,i) = cache(1,i)
      target%cofgen(27,i) = (target%cofgen(2,i)-target%cofgen(26,i))/1.0e-2_real64
      target%cofgen(28,i) = cache(2,i)
      target%cofgen(29,i) = target%cofgen(6,i)*target%cofgen(7,i)*target%cofgen(4,i)
      target%cofgen(30,i) = target%cofgen(6,i)-1.0_real64
      target%cofgen(31,i) = target%cofgen(7,i)+1.0_real64
      target%cofgen(32,i) = 1.0_real64/target%cofgen(7,i)
      target%cofgen(33,i) = target%cofgen(6,i)*(2.0_real64+target%cofgen(7,i)*target%cofgen(5,i))
      target%cofgen(34,i) = target%cofgen(5,i)+2.0_real64
      target%cofgen(35,i) = target%cofgen(7,i)-1.0_real64
      target%cofgen(36,i) = target%cofgen(5,i)-1.0_real64
      target%cofgen(37,i) = target%cofgen(14,i)*target%cofgen(15,i)*target%cofgen(13,i)
      target%cofgen(38,i) = target%cofgen(14,i)-1.0_real64
      target%cofgen(39,i) = target%cofgen(15,i)+1.0_real64
      if (target%cofgen(15,i)>0.0_real64) then
        target%cofgen(40,i)=1.0_real64/target%cofgen(15,i)
      else
        target%cofgen(40,i)=0.0_real64
      end if
      target%cofgen(41,i)=cache(3,i)
      target%cofgen(42,i)=cache(4,i)
    end do
  end subroutine refresh_from_compact_cache

  subroutine capture_compact_cache(raw,full,dependencies,derived)
    real(real64), intent(in) :: raw(:,:)
    type(b110_default_mvg_parameters_t), intent(in) :: full
    real(real64), intent(out) :: dependencies(:,:), derived(:,:)

    if (size(dependencies,1) /= 6 .or. size(dependencies,2) /= size(raw,2)) &
         error stop 'compact dependency cache shape mismatch'
    if (size(derived,1) /= 4 .or. size(derived,2) /= size(raw,2)) &
         error stop 'compact derived cache shape mismatch'
    dependencies(1,:) = raw(1,:)
    dependencies(2,:) = raw(2,:)
    dependencies(3,:) = raw(4,:)
    dependencies(4,:) = raw(6,:)
    dependencies(5,:) = raw(7,:)
    dependencies(6,:) = raw(9,:)
    derived(1,:) = full%cofgen(26,:)
    derived(2,:) = full%cofgen(28,:)
    derived(3,:) = full%cofgen(41,:)
    derived(4,:) = full%cofgen(42,:)
  end subroutine capture_compact_cache

  logical function compact_dependencies_match(raw,dependencies) result(matches)
    real(real64), intent(in) :: raw(:,:), dependencies(:,:)
    matches = .false.
    if (size(dependencies,1) /= 6 .or. size(dependencies,2) /= size(raw,2)) return
    matches = all(dependencies(1,:) == raw(1,:)) .and. &
         all(dependencies(2,:) == raw(2,:)) .and. &
         all(dependencies(3,:) == raw(4,:)) .and. &
         all(dependencies(4,:) == raw(6,:)) .and. &
         all(dependencies(5,:) == raw(7,:)) .and. &
         all(dependencies(6,:) == raw(9,:))
  end function compact_dependencies_match

  subroutine qualify_compact_variants(nn)
    integer, intent(in) :: nn
    real(real64), allocatable :: raw(:,:), deps(:,:), derived(:,:), zv(:), dzv(:), dv(:)
    type(b110_default_mvg_parameters_t) :: full, compact
    logical :: extension
    integer :: variant

    allocate(raw(24,nn), deps(6,nn), derived(4,nn), zv(nn), dzv(nn), dv(nn))
    do variant = 1, 4
      call initialize_fixture(raw,zv,dzv,dv)
      extension = variant >= 3
      if (mod(variant,2) == 0) raw(9,:) = -100.0_real64
      if (extension) then
        raw(10,:) = 2.0_real64*raw(3,:)
        raw(11,:) = 0.99_real64
        raw(12,:) = 0.95_real64*raw(3,:)
      end if
      call initialize_b110_default_mvg_parameters(full,raw,enable_ksatexm_extension=extension)
      call capture_compact_cache(raw,full,deps,derived)
      if (.not. compact_dependencies_match(raw,deps)) error stop 'fresh compact dependency snapshot mismatch'
      call refresh_from_compact_cache(raw,derived,extension,compact)
      if (compact%active_nodes /= full%active_nodes) error stop 'compact active-node mismatch'
      if (compact%ksatexm_extension_enabled .neqv. full%ksatexm_extension_enabled) &
           error stop 'compact KSATEXM flag mismatch'
      if (.not. allocated(compact%cofgen) .or. .not. allocated(full%cofgen)) &
           error stop 'compact qualification allocation mismatch'
      if (.not. all(compact%cofgen == full%cofgen)) error stop 'compact qualification matrix mismatch'

      raw(1,1) = raw(1,1) + 1.0e-12_real64
      if (compact_dependencies_match(raw,deps)) error stop 'compact dependency mutation not detected'
    end do
    write(*,'(A)') 'FPE_ZERO_WASTE01_COMPACT_CACHE_VARIANTS=PASS'
  end subroutine qualify_compact_variants

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
