program test_mc_irr01_tcs7_ssdi_binding_unit
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_irrigation_process
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  use mod_fmr_scheduled_irrigation_runtime_binding
  implicit none
  type(scheduled_irrigation_parameters_t) :: p
  type(scheduled_irrigation_request_t) :: r
  type(irrigation_state_t) :: s,c
  type(irrigation_flux_result_t) :: y
  type(irrigation_diagnostics_t) :: pd
  type(fmr_scheduled_irrigation_binding_diagnostics_t) :: d
  type(kernel_committed_state_t) :: physical
  type(fmr_b110_physical_forcing_t) :: base,bound
  real(real64), parameter :: tol=1.0e-12_real64

  p%scheduled_irrigation_enabled=.true.
  p%active_nodes=3
  p%sensor_node=2
  p%single_ssdi_node=3
  p%irr_rate_cm_per_day=0.48_real64
  p%tcs7_knot_count=2
  p%tcs7_dvs(1:2)=[0.0_real64,2.0_real64]
  p%tcs7_pressure_head(1:2)=[-70.0_real64,-70.0_real64]
  p%dcs2_knot_count=2
  p%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%dcs2_depth_cm(1:2)=[0.12_real64,0.12_real64]

  r%t0=10.0_real64; r%t1=10.25_real64; r%dvs=1.0_real64
  r%selection_opportunity=.true.; r%irrigation_enabled=.true.; r%schedule_enabled=.true.
  r%crop_emerged=.true.; r%irrigation_window_open=.true.
  physical%marker=1

  call fmr_evaluate_and_bind_scheduled_ssdi(p,s,r,physical,base,c,bound,y,pd,d)
  if(d%status/=FMR_SCHEDULED_IRRIGATION_BIND_OK .or. .not.d%source_bound) error stop 1
  if(pd%status/=IRRIGATION_OK .or. .not.pd%triggered) error stop 2
  if(.not.allocated(bound%subsurface_irrigation_source)) error stop 3
  if(abs(bound%subsurface_irrigation_source(3)-0.48_real64)>tol) error stop 4
  if(abs(d%external_inflow_amount_cm-0.12_real64)>tol) error stop 5

  allocate(base%subsurface_irrigation_source(3)); base%subsurface_irrigation_source=0.1_real64
  s=irrigation_state_t()
  call fmr_evaluate_and_bind_scheduled_ssdi(p,s,r,physical,base,c,bound,y,pd,d)
  if(abs(bound%subsurface_irrigation_source(3)-0.58_real64)>tol) error stop 6
  if(abs(bound%subsurface_irrigation_source(1)-0.1_real64)>tol) error stop 7

  physical%marker=0
  s=irrigation_state_t()
  call fmr_evaluate_and_bind_scheduled_ssdi(p,s,r,physical,base,c,bound,y,pd,d)
  if(d%status/=FMR_SCHEDULED_IRRIGATION_BIND_HYDRAULIC_VIEW .or. d%source_bound) error stop 8

  print '(A)','MC_IRR01_TCS7_SSDI_BINDING_UNIT=PASS'
end program test_mc_irr01_tcs7_ssdi_binding_unit
