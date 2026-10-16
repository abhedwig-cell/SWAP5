program test_ppa_wu05a17_rfm_preferential_router
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rfm_unponded_surface_composition, only: rfm_unponded_surface_composition_result_t, &
       RFM_SURFACE_COMPOSITION_AVAILABLE
  use mod_rfm_preferential_router
  implicit none

  real(real64), parameter :: TOL=1.0e-12_real64
  type(rfm_unponded_surface_composition_result_t) :: surface
  type(rfm_preferential_routing_request_t) :: request
  type(rfm_preferential_routing_result_t) :: result

  surface%status=RFM_SURFACE_COMPOSITION_AVAILABLE
  surface%effective_supply_cm_per_day=8.0_real64
  surface%matrix_supply_cm_per_day=6.0_real64
  surface%preferential_supply_cm_per_day=2.0_real64

  request%f_mb=0.2_real64
  request%connectivity_p=1.0_real64
  request%z_ah_cm=20.0_real64
  request%z_ic_cm=100.0_real64
  request%endpoint_depth_cm=[20.0_real64,40.0_real64,60.0_real64,80.0_real64,100.0_real64]

  call route_rfm_preferential_supply(surface,request,TOL,result)
  call require(result%status==RFM_PREF_ROUTER_AVAILABLE,'A17 oracle status')
  call require(abs(result%activation_fraction-0.25_real64)<=TOL,'A17 activation')
  call require(abs(result%mb_amount-0.4_real64)<=TOL,'A17 MB')
  call require(abs(result%ic_amount-1.6_real64)<=TOL,'A17 IC')
  call require(size(result%endpoint_weight)==5,'A17 endpoint count')
  call require(abs(result%endpoint_weight(1))<=TOL,'A17 w1')
  call require(abs(result%endpoint_weight(2)-1.0_real64)<=TOL,'A17 w2')
  call require(maxval(abs(result%endpoint_weight(3:5)))<=TOL,'A17 trailing weights')
  call require(abs(result%endpoint_amount(2)-1.6_real64)<=TOL,'A17 endpoint amount')
  call require(abs(result%mass_residual)<=TOL,'A17 mass closure')
  call require(abs(result%endpoint_weight_residual)<=TOL,'A17 weight closure')

  surface%matrix_supply_cm_per_day=8.0_real64
  surface%preferential_supply_cm_per_day=0.0_real64
  call route_rfm_preferential_supply(surface,request,TOL,result)
  call require(result%status==RFM_PREF_ROUTER_AVAILABLE,'A17 zero pref status')
  call require(abs(result%mb_amount)+abs(result%ic_amount)+sum(abs(result%endpoint_amount))<=TOL,'A17 zero route')

  surface%matrix_supply_cm_per_day=6.0_real64
  surface%preferential_supply_cm_per_day=2.0_real64
  request%f_mb=1.1_real64
  call route_rfm_preferential_supply(surface,request,TOL,result)
  call require(result%status==RFM_PREF_ROUTER_INVALID,'A17 invalid fMB accepted')

  request%f_mb=0.2_real64
  request%connectivity_p=0.0_real64
  call route_rfm_preferential_supply(surface,request,TOL,result)
  call require(result%status==RFM_PREF_ROUTER_INVALID,'A17 invalid p accepted')

  request%connectivity_p=1.0_real64
  request%endpoint_depth_cm=[20.0_real64,40.0_real64,35.0_real64,80.0_real64,100.0_real64]
  call route_rfm_preferential_supply(surface,request,TOL,result)
  call require(result%status==RFM_PREF_ROUTER_INVALID,'A17 nonmonotone grid accepted')

  request%endpoint_depth_cm=[20.0_real64,40.0_real64,60.0_real64,80.0_real64,90.0_real64]
  call route_rfm_preferential_supply(surface,request,TOL,result)
  call require(result%status==RFM_PREF_ROUTER_INVALID,'A17 shallow final endpoint accepted')

  print '(a)', 'PPA_WU05A17_RFM_PREFERENTIAL_ROUTER=PASS'

contains

  subroutine require(ok,msg)
    logical,intent(in)::ok
    character(*),intent(in)::msg
    if(.not.ok)then
      write(*,'(a,1x,a)') 'PPA_WU05A17_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05a17_rfm_preferential_router
