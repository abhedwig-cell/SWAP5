program test_fpe_zero_waste01_groundwater_forcing_materialization
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_canonical_contracts, only: canonical_forcing_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_groundwater_swap_forcing_adapter, only: GW_SWAP_FORCING_OK
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, &
       interface_head_m_to_swap_bottom_pressure_head_cm, GW_INTERFACE_OK
  implicit none

  type(fmr_b110_physical_forcing_t) :: base, reusable
  type(fmr_groundwater_head_forcing_materializer_t) :: materializer
  type(groundwater_head_datum_t) :: datum
  class(canonical_forcing_t), allocatable :: polymorphic_forcing
  integer(int64) :: c0, c1, rate
  integer :: n, reps, r, status
  integer(int64) :: generation_before, generation_after
  real(real64) :: current_seconds, reused_seconds, current_ns, reused_ns
  real(real64) :: current_checksum, reused_checksum, h, a_head, b_head, a_bottom_first, a_bottom_second
  character(len=32) :: arg

  call get_command_argument(1,arg); read(arg,*) n
  call get_command_argument(2,arg); read(arg,*) reps
  if (n <= 0 .or. reps <= 0) error stop 'H-GWFORCE01 invalid request'

  call initialize_base_forcing(base,n)
  call materializer%initialize(base)
  datum%available = .true.
  datum%datum_id = 780001_int64
  datum%bottom_boundary_elevation_m = 0.0_real64
  a_head = 0.25_real64
  b_head = 0.35_real64

  current_checksum = 0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    if (mod(r,2) == 0) then
      h = a_head
    else
      h = b_head
    end if
    call materializer%materialize(h,datum,polymorphic_forcing,status)
    if (status /= GW_SWAP_FORCING_OK .or. .not. allocated(polymorphic_forcing)) &
         error stop 'H-GWFORCE01 current materialization failed'
    select type (typed => polymorphic_forcing)
    type is (fmr_b110_physical_forcing_t)
      current_checksum = current_checksum + typed%bottom_head + typed%top_flux + &
           typed%drainage_flux_by_level(1,n) + typed%subsurface_irrigation_source(n) + typed%root_extraction_sink(n)
    class default
      error stop 'H-GWFORCE01 unexpected forcing dynamic type'
    end select
  end do
  call system_clock(c1)
  current_seconds = real(c1-c0,real64)/real(rate,real64)

  call materializer%initialize_reusable(reusable,status)
  if (status /= GW_SWAP_FORCING_OK) error stop 'H-GWFORCE01 reusable initialization failed'
  generation_before = materializer%current_generation()
  if (generation_before <= 0_int64) error stop 'H-GWFORCE01 invalid initial generation'
  reused_checksum = 0.0_real64
  call system_clock(c0)
  do r=1,reps
    if (mod(r,2) == 0) then
      h = a_head
    else
      h = b_head
    end if
    call materializer%materialize_reused(h,datum,reusable,status)
    if (status /= GW_SWAP_FORCING_OK) error stop 'H-GWFORCE01 reused materialization failed'
    reused_checksum = reused_checksum + reusable%bottom_head + reusable%top_flux + &
         reusable%drainage_flux_by_level(1,n) + reusable%subsurface_irrigation_source(n) + reusable%root_extraction_sink(n)
  end do
  call system_clock(c1)
  reused_seconds = real(c1-c0,real64)/real(rate,real64)

  call require_base_fields_preserved(base,reusable)
  call materializer%materialize_reused(a_head,datum,reusable,status)
  if (status /= GW_SWAP_FORCING_OK) error stop 'H-GWFORCE01 A1 failed'
  a_bottom_first = reusable%bottom_head
  call materializer%materialize_reused(b_head,datum,reusable,status)
  if (status /= GW_SWAP_FORCING_OK .or. same_bits(reusable%bottom_head,a_bottom_first)) &
       error stop 'H-GWFORCE01 B did not replace bottom head'
  call materializer%materialize_reused(a_head,datum,reusable,status)
  if (status /= GW_SWAP_FORCING_OK) error stop 'H-GWFORCE01 A2 failed'
  a_bottom_second = reusable%bottom_head
  if (.not. same_bits(a_bottom_first,a_bottom_second)) error stop 'H-GWFORCE01 A-B-A bottom head drift'
  call require_base_fields_preserved(base,reusable)

  base%top_flux = base%top_flux + 0.125_real64
  call materializer%initialize(base)
  generation_after = materializer%current_generation()
  if (generation_after <= generation_before) error stop 'H-GWFORCE01 generation did not advance'
  call materializer%initialize_reusable(reusable,status)
  if (status /= GW_SWAP_FORCING_OK) error stop 'H-GWFORCE01 generation refresh failed'
  call require_base_fields_preserved(base,reusable)
  call materializer%materialize_reused(a_head,datum,reusable,status)
  if (status /= GW_SWAP_FORCING_OK) error stop 'H-GWFORCE01 refreshed materialization failed'
  call require_base_fields_preserved(base,reusable)

  current_ns = 1.0e9_real64*current_seconds/real(reps,real64)
  reused_ns = 1.0e9_real64*reused_seconds/real(reps,real64)
  write(*,'(A,I0,A,I0,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16)') &
       'GWFORCE01,n=',n,',reps=',reps,',current_ns_per_materialization=',current_ns, &
       ',reused_ns_per_materialization=',reused_ns,',ratio=',reused_ns/current_ns, &
       ',current_checksum=',current_checksum,',reused_checksum=',reused_checksum
  write(*,'(A,I0,A)') 'GWFORCE01_ABA_AND_BASE_PRESERVATION,n=',n,',PASS'
  write(*,'(A,I0,A)') 'GWFORCE01_GENERATION_REFRESH,n=',n,',PASS'
  write(*,'(A)') 'FPE_ZERO_WASTE01_GWFORCE01=PASS'

contains

  subroutine initialize_base_forcing(value,node_count)
    type(fmr_b110_physical_forcing_t), intent(out) :: value
    integer, intent(in) :: node_count
    value%top_flux = 0.0125_real64
    value%top_head = -45.0_real64
    value%bottom_flux = 0.0_real64
    value%bottom_head = -75.0_real64
    allocate(value%drainage_flux_by_level(1,node_count))
    allocate(value%subsurface_irrigation_source(node_count))
    allocate(value%root_extraction_sink(node_count))
    value%drainage_flux_by_level = 0.0_real64
    value%subsurface_irrigation_source = 0.0_real64
    value%root_extraction_sink = 0.0_real64
  end subroutine initialize_base_forcing



  subroutine require_base_fields_preserved(reference,value)
    type(fmr_b110_physical_forcing_t), intent(in) :: reference,value
    if (.not. same_bits(reference%top_flux,value%top_flux) .or. &
        .not. same_bits(reference%top_head,value%top_head) .or. &
        .not. same_bits(reference%bottom_flux,value%bottom_flux)) &
         error stop 'H-GWFORCE01 scalar base field drift'
    if (.not. allocated(value%drainage_flux_by_level) .or. &
        .not. allocated(value%subsurface_irrigation_source) .or. &
        .not. allocated(value%root_extraction_sink)) error stop 'H-GWFORCE01 forcing arrays lost'
    if (any(value%drainage_flux_by_level /= reference%drainage_flux_by_level) .or. &
        any(value%subsurface_irrigation_source /= reference%subsurface_irrigation_source) .or. &
        any(value%root_extraction_sink /= reference%root_extraction_sink)) &
         error stop 'H-GWFORCE01 forcing array drift'
  end subroutine require_base_fields_preserved

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    equal = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_bits
end program test_fpe_zero_waste01_groundwater_forcing_materialization
