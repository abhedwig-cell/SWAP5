program test_ppa_wu05d3_geometry
  use iso_fortran_env, only: real64
  use ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_root_uptake_compensation
  use mod_root_uptake_compensation_execution
  use mod_root_water_uptake_process
  implicit none
  type(root_walsum_geometry_t)::g
  type(root_compensation_config_t)::cfg,j
  type(root_water_uptake_flux_result_t)::base,out,expected
  type(root_water_uptake_diagnostics_t)::bd
  type(root_compensation_diagnostics_t)::d,e
  real(real64)::alpha,thickness(4),depths(6),answers(6),nan
  integer::status,node,i,k,js
  thickness=[10._real64,20._real64,30._real64,40._real64]
  depths=[0._real64,5._real64,10._real64,10.5_real64,40._real64,95._real64]
  answers=[1._real64,1._real64,1._real64,.8_real64,.5_real64,.1_real64]
  g%maximum_root_depth_cm=100;g%critical_root_zone_depth_cm=10
  do i=1,6
    g%current_root_depth_cm=depths(i)
    call evaluate_walsum_geometry(g,thickness,alpha,node,status)
    call require(status==ROOT_COMP_OK,'valid geometry')
    call require(abs(alpha-answers(i))<2.e-16_real64,'independent alpha oracle')
  end do
  ! Unit scaling is invariant; fields and owner node thicknesses are centimetres.
  g=root_walsum_geometry_t(20._real64,200._real64,80._real64)
  call evaluate_walsum_geometry(g,2*thickness,alpha,node,status)
  call require(status==0.and.node==3.and.alpha==.5_real64,'cm scaling and partial node')
  g=root_walsum_geometry_t(10._real64,55._real64,50._real64)
  call evaluate_walsum_geometry(g,thickness,alpha,node,status)
  call require(status==0.and.abs(alpha-1._real64/11)<1.e-16_real64,'node bottom exceeds RDM')
  nan=ieee_value(0._real64,ieee_quiet_nan)
  do i=1,8
    g=root_walsum_geometry_t(10._real64,100._real64,40._real64)
    select case(i)
    case(1);g%maximum_root_depth_cm=0
    case(2);g%critical_root_zone_depth_cm=-1
    case(3);g%current_root_depth_cm=101
    case(4);g%current_root_depth_cm=-1
    case(5);g%current_root_depth_cm=nan
    case(6);g%maximum_root_depth_cm=nan
    case(7);g%critical_root_zone_depth_cm=nan
    case(8);g=root_walsum_geometry_t(0._real64,50._real64,50._real64)
    end select
    call evaluate_walsum_geometry(g,thickness,alpha,node,status)
    call require(status/=0,'invalid geometry fail closed')
  end do
  g=root_walsum_geometry_t(10._real64,200._real64,150._real64)
  call evaluate_walsum_geometry(g,thickness,alpha,node,status)
  call require(status/=0,'root depth outside column')
  g%current_root_depth_cm=20
  call evaluate_walsum_geometry(g,[real(real64)::],alpha,node,status)
  call require(status/=0,'empty column')
  call evaluate_walsum_geometry(g,[10._real64,nan],alpha,node,status)
  call require(status/=0,'NaN thickness with floating point traps')
  call evaluate_walsum_geometry(g,[10._real64,0._real64],alpha,node,status)
  call require(status/=0,'zero thickness')
  cfg%method=ROOT_COMP_WALSUM;cfg%alpha_critical=nan
  j%method=ROOT_COMP_JARVIS
  base%root_extraction_sink=[.1_real64,.05_real64,.02_real64,0._real64]
  base%actual_uptake_total=sum(base%root_extraction_sink);bd%drought_reduction_total=1-base%actual_uptake_total
  do k=1,3
    cfg%stressor=k;j%stressor=k
    do i=1,2
      g=root_walsum_geometry_t(10._real64,100._real64,40._real64)
      if(i==2) g%critical_root_zone_depth_cm=50
      j%alpha_critical=.5_real64
      if(i==2) j%alpha_critical=.9_real64
      call apply_root_uptake_compensation(cfg,1._real64,base,bd,0._real64,out,d,status,g,thickness)
      call compose_jarvis_root_uptake(j,1._real64,base,bd%drought_reduction_total,0._real64,expected,e,js)
      call require(status==0.and.js==0,'dynamic composition')
      call require(maxval(abs(out%root_extraction_sink-expected%root_extraction_sink))<1.e-15_real64,'node oracle')
      call require(abs(d%drought_reduction_total-e%drought_reduction_total)<1.e-15_real64,'stress totals')
      call require(out%actual_uptake_total==sum(out%root_extraction_sink),'one summed uptake')
    end do
  end do
  call apply_root_uptake_compensation(cfg,1._real64,base,bd,0._real64,out,d,status)
  call require(status/=0,'missing geometry rejected')
  g%current_root_depth_cm=5
  call apply_root_uptake_compensation(cfg,1._real64,base,bd,0._real64,out,d,status,g,thickness)
  call require(status/=0,'sink below roots rejected')
  g%current_root_depth_cm=0;base%root_extraction_sink=0;base%actual_uptake_total=0;bd%drought_reduction_total=1
  call apply_root_uptake_compensation(cfg,1._real64,base,bd,0._real64,out,d,status,g,thickness)
  call require(status==0.and.out%actual_uptake_total==0,'zero roots')
  print '(a)','PPA_WU05D3_GEOMETRY=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok) then
      print *, 'FAIL ',label
      error stop 1
    end if
  end subroutine
end program
