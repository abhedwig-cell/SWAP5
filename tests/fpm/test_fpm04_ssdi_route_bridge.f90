program test_fpm04_ssdi_route_bridge
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: irrigation_parameters_t, fixed_irrigation_event_t, irrigation_management_request_t, &
       scheduled_irrigation_parameters_t, scheduled_irrigation_request_t, irrigation_state_t, &
       irrigation_flux_result_t, irrigation_diagnostics_t, evaluate_fixed_irrigation_interval, &
       evaluate_scheduled_irrigation_interval, IRRIGATION_OK, IRRIGATION_APPLICATION_SSDI
  implicit none

  type(irrigation_parameters_t) :: fixed_parameters
  type(scheduled_irrigation_parameters_t) :: scheduled_parameters
  type(irrigation_management_request_t) :: fixed_request
  type(scheduled_irrigation_request_t) :: scheduled_request
  type(process_hydraulic_view_t) :: view
  type(irrigation_state_t) :: committed, fixed_candidate, scheduled_candidate
  type(irrigation_flux_result_t) :: fixed_flux, scheduled_flux
  type(irrigation_diagnostics_t) :: fixed_diag, scheduled_diag
  real(real64), parameter :: t0=70.0_real64, t1=70.5_real64

  fixed_parameters%fixed_irrigation_enabled=.true.
  fixed_parameters%active_nodes=4
  fixed_parameters%ssdi_first_node=3
  fixed_parameters%ssdi_last_node=3
  allocate(fixed_parameters%fixed_events(1))
  fixed_parameters%fixed_events(1)=fixed_irrigation_event_t(t0,IRRIGATION_APPLICATION_SSDI,0.5_real64,1.0_real64,0.0_real64)
  fixed_request%t0=t0; fixed_request%t1=t1

  scheduled_parameters%scheduled_irrigation_enabled=.true.
  scheduled_parameters%active_nodes=4
  scheduled_parameters%sensor_node=2
  scheduled_parameters%single_ssdi_node=3
  scheduled_parameters%irr_rate_cm_per_day=1.0_real64
  scheduled_parameters%tcs7_knot_count=3
  scheduled_parameters%tcs7_dvs(1:3)=[0.0_real64,1.0_real64,2.0_real64]
  scheduled_parameters%tcs7_pressure_head(1:3)=[-100.0_real64,-200.0_real64,-300.0_real64]
  scheduled_parameters%dcs2_knot_count=3
  scheduled_parameters%dcs2_dvs(1:3)=[0.0_real64,1.0_real64,2.0_real64]
  scheduled_parameters%dcs2_depth_cm(1:3)=[0.2_real64,0.5_real64,0.8_real64]

  scheduled_request%t0=t0; scheduled_request%t1=t1; scheduled_request%dvs=1.0_real64
  scheduled_request%selection_opportunity=.true.
  scheduled_request%irrigation_enabled=.true.
  scheduled_request%schedule_enabled=.true.
  scheduled_request%crop_emerged=.true.
  scheduled_request%irrigation_window_open=.true.

  view%active_nodes=4
  allocate(view%pressure_head(4),view%water_content(4))
  view%pressure_head=-50.0_real64
  view%pressure_head(2)=-200.0_real64
  view%water_content=0.25_real64

  call evaluate_fixed_irrigation_interval(fixed_parameters,committed,fixed_request,fixed_candidate,fixed_flux,fixed_diag)
  call evaluate_scheduled_irrigation_interval(scheduled_parameters,committed,scheduled_request,view, &
       scheduled_candidate,scheduled_flux,scheduled_diag)

  call require(fixed_diag%status==IRRIGATION_OK .and. scheduled_diag%status==IRRIGATION_OK,'both process routes')
  call require(fixed_flux%applied .and. scheduled_flux%applied,'both process sources applied')
  call require(allocated(fixed_flux%subsurface_source) .and. allocated(scheduled_flux%subsurface_source),'both source arrays')
  call require(size(fixed_flux%subsurface_source)==size(scheduled_flux%subsurface_source),'same source shape')
  call require(all_bits(fixed_flux%subsurface_source,scheduled_flux%subsurface_source),'bitwise source identity')
  call require(same_bits(fixed_flux%event_duration,scheduled_flux%event_duration),'event duration identity')
  call require(same_bits(fixed_flux%active_duration,scheduled_flux%active_duration),'active duration identity')
  call require(same_bits(fixed_flux%external_inflow_amount,scheduled_flux%external_inflow_amount),'process mass identity')
  call require(same_bits(scheduled_flux%external_inflow_amount,0.5_real64),'scheduled full-event mass')
  call require(fixed_candidate%next_fixed_event_index==2 .and. scheduled_candidate%next_fixed_event_index==1, &
       'scheduled route leaves fixed cursor untouched')

  write(*,'(A)') 'FPM04_SCHEDULED_FIXED_SINGLE_NODE_SOURCE_IDENTITY=PASS'
  write(*,'(A)') 'FPM04_SSDI_ROUTE_BRIDGE_TEST PASS'

contains

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    same_bits=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits

  logical function all_bits(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    all_bits=size(a)==size(b)
    if (.not. all_bits) return
    do i=1,size(a)
      if (.not. same_bits(a(i),b(i))) then
        all_bits=.false.
        return
      end if
    end do
  end function all_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM04_ROUTE_BRIDGE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpm04_ssdi_route_bridge
