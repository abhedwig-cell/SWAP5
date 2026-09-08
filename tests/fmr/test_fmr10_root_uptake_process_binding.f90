program test_fmr10_root_uptake_process_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_request_t, &
       root_water_uptake_flux_result_t, root_water_uptake_diagnostics_t, evaluate_macro_feddes_drought_uptake, &
       ROOT_UPTAKE_OK
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  use mod_fmr_root_uptake_process_binding, only: fmr_root_uptake_crop_input_t, fmr_root_uptake_binding_diagnostics_t, &
       fmr_evaluate_committed_root_uptake, FMR_ROOT_UPTAKE_BINDING_OK, FMR_ROOT_UPTAKE_BINDING_PROCESS_REJECTED
  implicit none

  type(root_water_uptake_parameters_t) :: parameters
  type(fmr_root_uptake_crop_input_t) :: input_a, input_b, inactive_input, invalid_input
  type(root_water_uptake_flux_result_t) :: bound_a1, bound_b, bound_a2, bound_inactive, direct_flux, rejected_flux
  type(root_water_uptake_diagnostics_t) :: proc_a1, proc_b, proc_a2, proc_inactive, direct_diag, rejected_proc
  type(fmr_root_uptake_binding_diagnostics_t) :: diag_a1, diag_b, diag_a2, diag_inactive, rejected_diag
  type(fmr_b110_physical_state_t) :: physical
  type(kernel_committed_state_t) :: committed, unavailable
  type(process_hydraulic_view_t) :: view
  type(root_water_uptake_request_t) :: direct_request
  class(transaction_state_t), allocatable :: snapshot_before, snapshot_after
  integer(int64) :: revision_before
  logical :: ok

  call configure_parameters(parameters)

  inactive_input%crop_emerged=.false.
  inactive_input%potential_transpiration=-999.0_real64
  inactive_input%rooted_nodes=99
  call fmr_evaluate_committed_root_uptake(unavailable,parameters,inactive_input,bound_inactive,proc_inactive,diag_inactive)
  call require(diag_inactive%status==FMR_ROOT_UPTAKE_BINDING_OK,'inactive binding status')
  call require(diag_inactive%inactive_crop_zero_route,'inactive zero route')
  call require(.not. diag_inactive%hydraulic_view_built,'inactive does not build hydraulic view')
  call require(proc_inactive%status==ROOT_UPTAKE_OK .and. proc_inactive%no_roots,'inactive process zero route')
  call require(allocated(bound_inactive%root_extraction_sink) .and. &
       maxval(abs(bound_inactive%root_extraction_sink))==0.0_real64,'inactive zero root sink')
  write(*,'(A)') 'FMR10_INACTIVE_CROP_NO_COMMITTED_VIEW_OR_DISTRIBUTION_DEPENDENCY=PASS'

  call configure_physical_state(physical)
  call fmr_new_b110_committed_state(committed,1010_int64,physical,4000.25_real64,ok)
  call require(ok,'committed init')
  revision_before=committed%current_revision()
  call committed%snapshot(snapshot_before,ok)
  call require(ok,'snapshot before')

  call configure_crop_input(input_a,0.30_real64,[0.0_real64,0.15_real64,0.50_real64,1.0_real64])
  call fmr_build_committed_process_hydraulic_view(committed,view,ok)
  call require(ok,'direct committed view')
  call crop_to_request(input_a,direct_request)
  call evaluate_macro_feddes_drought_uptake(parameters,view,direct_request,direct_flux,direct_diag)
  call require(direct_diag%status==ROOT_UPTAKE_OK,'direct process status')

  call fmr_evaluate_committed_root_uptake(committed,parameters,input_a,bound_a1,proc_a1,diag_a1)
  call require(diag_a1%status==FMR_ROOT_UPTAKE_BINDING_OK,'active binding status')
  call require(diag_a1%hydraulic_view_built .and. diag_a1%process_called,'active view and process')
  call require(all_bits_identical(bound_a1%root_extraction_sink,direct_flux%root_extraction_sink), &
       'binding root sink equals direct')
  call require(same_bits(bound_a1%actual_uptake_total,direct_flux%actual_uptake_total),'binding total equals direct')
  call require(all_bits_identical(proc_a1%potential_root_sink,direct_diag%potential_root_sink),'binding diagnostics equal direct')
  write(*,'(A)') 'FMR10_ACTIVE_BINDING_DIRECT_PROCESS_BITWISE_IDENTITY=PASS'
  write(*,'(A)') 'FMR10_DYNAMIC_ROOT_DISTRIBUTION_PASS_THROUGH=PASS'

  call committed%snapshot(snapshot_after,ok)
  call require(ok,'snapshot after')
  call require(committed%current_revision()==revision_before,'binding revision unchanged')
  call require(physical_snapshot_identical(snapshot_before,snapshot_after),'binding committed state unchanged')
  write(*,'(A)') 'FMR10_COMMITTED_STATE_READ_ONLY=PASS'

  invalid_input=input_a
  invalid_input%cumulative_root_fraction(4)=0.95_real64
  call fmr_evaluate_committed_root_uptake(committed,parameters,invalid_input,rejected_flux,rejected_proc,rejected_diag)
  call require(rejected_diag%status==FMR_ROOT_UPTAKE_BINDING_PROCESS_REJECTED,'invalid active input rejected')
  call require(rejected_diag%hydraulic_view_built .and. rejected_diag%process_called,'invalid active path explicitly evaluated')
  write(*,'(A)') 'FMR10_INVALID_ACTIVE_CROP_INPUT_FAIL_CLOSED=PASS'

  call configure_crop_input(input_b,0.42_real64,[0.0_real64,0.25_real64,0.70_real64,1.0_real64])
  call fmr_evaluate_committed_root_uptake(committed,parameters,input_b,bound_b,proc_b,diag_b)
  call require(diag_b%status==FMR_ROOT_UPTAKE_BINDING_OK,'B binding status')
  call require(.not. all_bits_identical(bound_a1%root_extraction_sink,bound_b%root_extraction_sink),'B distinct from A')
  call fmr_evaluate_committed_root_uptake(committed,parameters,input_a,bound_a2,proc_a2,diag_a2)
  call require(diag_a2%status==FMR_ROOT_UPTAKE_BINDING_OK,'A2 binding status')
  call require(all_bits_identical(bound_a1%root_extraction_sink,bound_a2%root_extraction_sink),'A/B/A root sink')
  call require(same_bits(bound_a1%actual_uptake_total,bound_a2%actual_uptake_total),'A/B/A total')
  call require(all_bits_identical(proc_a1%drought_reduction,proc_a2%drought_reduction),'A/B/A diagnostics')
  call require(committed%current_revision()==revision_before,'A/B/A revision unchanged')
  write(*,'(A)') 'FMR10_BINDING_A_B_A_IDENTITY=PASS'
  write(*,'(A)') 'FMR10_ROOT_UPTAKE_PROCESS_BINDING_TEST PASS'

contains

  subroutine configure_parameters(p)
    type(root_water_uptake_parameters_t), intent(out) :: p
    p%active_nodes=4
    p%hlim3l=-800.0_real64
    p%hlim3h=-400.0_real64
    p%hlim4=-16000.0_real64
    p%adcrl=0.10_real64
    p%adcrh=0.50_real64
  end subroutine configure_parameters

  subroutine configure_physical_state(s)
    type(fmr_b110_physical_state_t), intent(out) :: s
    s%active_nodes=4
    allocate(s%pressure_head(4),s%water_content(4))
    s%pressure_head=[-17000.0_real64,-8000.0_real64,-600.0_real64,-100.0_real64]
    s%water_content=[0.10_real64,0.15_real64,0.22_real64,0.30_real64]
    s%ponding_depth=0.0_real64
    s%groundwater_level=-2.0_real64
  end subroutine configure_physical_state

  subroutine configure_crop_input(x,ptra,distribution)
    type(fmr_root_uptake_crop_input_t), intent(out) :: x
    real(real64), intent(in) :: ptra
    real(real64), intent(in) :: distribution(4)
    x%crop_emerged=.true.
    x%potential_transpiration=ptra
    x%rooted_nodes=3
    allocate(x%cumulative_root_fraction(4))
    x%cumulative_root_fraction=distribution
  end subroutine configure_crop_input

  subroutine crop_to_request(input,request)
    type(fmr_root_uptake_crop_input_t), intent(in) :: input
    type(root_water_uptake_request_t), intent(out) :: request
    request%potential_transpiration=input%potential_transpiration
    request%rooted_nodes=input%rooted_nodes
    if (allocated(input%cumulative_root_fraction)) then
      allocate(request%cumulative_root_fraction(size(input%cumulative_root_fraction)))
      request%cumulative_root_fraction=input%cumulative_root_fraction
    end if
  end subroutine crop_to_request

  logical function physical_snapshot_identical(a,b) result(equal)
    class(transaction_state_t), intent(in) :: a,b
    integer :: k
    equal=.false.
    select type (pa=>a)
    type is (fmr_b110_physical_state_t)
      select type (pb=>b)
      type is (fmr_b110_physical_state_t)
        if (pa%active_nodes/=pb%active_nodes) return
        do k=1,pa%active_nodes
          if (.not. same_bits(pa%pressure_head(k),pb%pressure_head(k))) return
          if (.not. same_bits(pa%water_content(k),pb%water_content(k))) return
        end do
        if (.not. same_bits(pa%ponding_depth,pb%ponding_depth)) return
        if (.not. same_bits(pa%groundwater_level,pb%groundwater_level)) return
        equal=.true.
      end select
    end select
  end function physical_snapshot_identical

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia)
    ib=transfer(b,ib)
    equal=ia==ib
  end function same_bits

  logical function all_bits_identical(a,b) result(equal)
    real(real64), intent(in) :: a(:),b(:)
    integer :: k
    equal=size(a)==size(b)
    if (.not. equal) return
    do k=1,size(a)
      if (.not. same_bits(a(k),b(k))) then
        equal=.false.
        return
      end if
    end do
  end function all_bits_identical

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR10_BINDING_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fmr10_root_uptake_process_binding
