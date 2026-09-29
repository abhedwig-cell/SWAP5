program test_ppa_atm02_pmdirect_prescribed_root_sink
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_interval_result_t, pmdirect_swetr0_diagnostics_t
  use mod_ppa_atm02_pmdirect_prescribed_root_sink
  implicit none
  type(crop_root_uptake_input_t) :: root, invalid
  type(pmdirect_swetr0_interval_result_t) :: pmdirect
  type(pmdirect_swetr0_diagnostics_t) :: upstream
  type(ppa_atm02_root_sink_diagnostics_t) :: diagnostics
  real(real64), allocatable :: sink(:)

  root%crop_emerged = .true.; root%rooted_nodes = 2
  allocate(root%cumulative_root_fraction(3))
  root%cumulative_root_fraction = [0.0_real64, 0.35_real64, 1.0_real64]
  pmdirect%potential_transpiration_cm_per_day = 0.20_real64
  upstream%interval_result_produced = .true.
  call materialize_ppa_atm02_prescribed_root_sink(root, 4, pmdirect, upstream, sink, diagnostics)
  call require(diagnostics%status == PPA_ATM02_ROOT_SINK_OK .and. diagnostics%result_produced, 'valid root sink rejected')
  call require(size(sink) == 4, 'sink size')
  call require(abs(sink(1) - 0.07_real64) <= 1.e-12_real64 .and. abs(sink(2) - 0.13_real64) <= 1.e-12_real64, 'fraction mapping')
  call require(abs(sum(sink) - 0.20_real64) <= 1.e-12_real64, 'sink conservation')
  invalid = root; invalid%rooted_nodes = 3
  call materialize_ppa_atm02_prescribed_root_sink(invalid, 4, pmdirect, upstream, sink, diagnostics)
  call require(diagnostics%status == PPA_ATM02_ROOT_SINK_GEOMETRY_REJECTED .and. size(sink) == 0, 'geometry fails closed')
  upstream%interval_result_produced = .false.
  call materialize_ppa_atm02_prescribed_root_sink(root, 4, pmdirect, upstream, sink, diagnostics)
  call require(diagnostics%status == PPA_ATM02_ROOT_SINK_UPSTREAM_REJECTED .and. size(sink) == 0, 'upstream fails closed')
  print '(a)', 'PPA_ATM02_ROOT_SINK_FRACTION_CONSERVATION=PASS'
  print '(a)', 'PPA_ATM02_ROOT_SINK_FAIL_CLOSED=PASS'
contains
  subroutine require(ok, label)
    logical, intent(in) :: ok
    character(*), intent(in) :: label
    if (.not. ok) then; write(*,'(a)') trim(label); error stop 1; end if
  end subroutine require
end program test_ppa_atm02_pmdirect_prescribed_root_sink
