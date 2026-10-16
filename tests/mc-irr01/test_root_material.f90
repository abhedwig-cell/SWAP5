program test_root_material
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_root_zone_summary
  implicit none
  type(soil_water_parameter_set_t) :: geometry,bad_geometry
  type(b110_default_mvg_parameters_t),target :: material
  type(b110_default_mvg_provider_t) :: provider
  type(irrigation_root_zone_parameters_t) :: root
  type(irrigation_root_zone_summary_t) :: summary
  type(process_hydraulic_view_t) :: view
  real(real64) :: cof(24,3),rd,depths(6),weight,expected,fc(3),stress(3),wilt(3),negative(5)
  integer :: i,j,status,count
  geometry%active_nodes=3
  geometry%z=[-5._real64,-20._real64,-45._real64]
  geometry%dz=[10._real64,20._real64,30._real64]
  cof=0._real64
  do i=1,3
    cof(1,i)=.03_real64+.01_real64*i;cof(2,i)=.4_real64+.01_real64*i
    cof(3,i)=1._real64;cof(4,i)=.005_real64*i;cof(5,i)=.5_real64
    cof(6,i)=1.3_real64+.1_real64*i;cof(7,i)=1._real64-1._real64/cof(6,i)
    fc(i)=theta(i,-100._real64);stress(i)=theta(i,-500._real64);wilt(i)=theta(i,-15000._real64)
  end do
  call initialize_b110_default_mvg_parameters(material,cof)
  call bind_b110_default_mvg_provider(provider,material,1._real64)
  view%active_nodes=3;view%water_content=[.2_real64,.21_real64,.22_real64]
  depths=[1._real64,10._real64,10._real64+1.e-8_real64,25._real64,30._real64,60._real64]
  count=0
  do j=1,size(depths)
    rd=depths(j)
    call derive_irrigation_root_zone_parameters(geometry,provider,rd,-100._real64,-500._real64,-15000._real64,root,status)
    call require(status==IRR_ROOT_ZONE_OK,'valid heterogeneous material and evolving roots')
    call require(all(abs(root%field_capacity_water_content-fc)<2.e-15_real64),'independent MvG FC oracle')
    call require(all(abs(root%stress_water_content-stress)<2.e-15_real64),'source average-stress pressure')
    call require(all(abs(root%wilting_water_content-wilt)<2.e-15_real64),'source wilting pressure')
    expected=0._real64
    do i=1,3
      weight=max(0._real64,min(geometry%dz(i),rd+geometry%z(i)+.5_real64*geometry%dz(i)))
      expected=expected+(fc(i)-view%water_content(i))*weight
    end do
    call evaluate_irrigation_root_zone_summary(root,view,summary,status)
    call require(status==IRR_ROOT_ZONE_OK.and.abs(summary%field_capacity_deficit_cm-expected)<1.e-13_real64, &
      'partial bottom cell and accepted actual theta')
    call require(abs(sum(root%node_thickness_cm(:root%rooted_nodes-1))+ &
      root%last_rooted_fraction*root%node_thickness_cm(root%rooted_nodes)-rd)<1.e-13_real64,'exact rooted thickness')
    count=count+1
  end do
  call require(root%rooted_nodes==3.and.root%last_rooted_fraction==1._real64,'entire column root boundary')
  ! B1.11 permits negative deficit (wetter than FC); the depth policy owns
  ! zero clipping, daily rain subtraction and the subsequent configured cap.
  view%water_content=fc+.01_real64
  call evaluate_irrigation_root_zone_summary(root,view,summary,status)
  call require(status==IRR_ROOT_ZONE_OK.and.abs(summary%field_capacity_deficit_cm+.6_real64)<1.e-13_real64, &
    'negative deficit is not silently clipped by the material summary')
  negative=[0._real64,-1._real64,61._real64,ieee_value(rd,ieee_quiet_nan),ieee_value(rd,ieee_positive_inf)]
  do i=1,5
    call derive_irrigation_root_zone_parameters(geometry,provider,negative(i),-100._real64,-500._real64,-15000._real64,root,status)
    call rejected('invalid actual root depth')
  end do
  call derive_irrigation_root_zone_parameters(geometry,provider,25._real64,1._real64,-500._real64,-15000._real64,root,status)
  call rejected('positive field capacity pressure')
  call derive_irrigation_root_zone_parameters(geometry,provider,25._real64,-501._real64,-600._real64,-15000._real64,root,status)
  call rejected('field capacity outside source domain')
  call derive_irrigation_root_zone_parameters(geometry,provider,25._real64,-100._real64,-50._real64,-15000._real64,root,status)
  call rejected('stress wetter than FC')
  call derive_irrigation_root_zone_parameters(geometry,provider,25._real64,-100._real64,-500._real64,-400._real64,root,status)
  call rejected('wilting wetter than stress')
  call derive_irrigation_root_zone_parameters(geometry,provider,25._real64,negative(4),-500._real64,-15000._real64,root,status)
  call rejected('nonfinite pressure before comparisons')
  bad_geometry=geometry;bad_geometry%z(2)=bad_geometry%z(2)-1._real64
  call derive_irrigation_root_zone_parameters(bad_geometry,provider,25._real64,-100._real64,-500._real64,-15000._real64,root,status)
  call rejected('gapped accepted geometry')
  bad_geometry=geometry;bad_geometry%dz(2)=0._real64
  call derive_irrigation_root_zone_parameters(bad_geometry,provider,25._real64,-100._real64,-500._real64,-15000._real64,root,status)
  call rejected('zero thickness')
  bad_geometry=geometry;bad_geometry%active_nodes=4
  call derive_irrigation_root_zone_parameters(bad_geometry,provider,25._real64,-100._real64,-500._real64,-15000._real64,root,status)
  call rejected('geometry shape')
  bad_geometry=soil_water_parameter_set_t()
  call derive_irrigation_root_zone_parameters(bad_geometry,provider,25._real64,-100._real64,-500._real64,-15000._real64,root,status)
  call rejected('absent geometry')
  ! A/B/A: no cached root extent or material-derived theta owner.
  call derive_irrigation_root_zone_parameters(geometry,provider,25._real64,-100._real64,-500._real64,-15000._real64,root,status)
  call require(status==IRR_ROOT_ZONE_OK.and.root%rooted_nodes==2.and.root%last_rooted_fraction==.75_real64,'ABA reconstruction')
  call require(all(cof==material%cofgen(:24,:)),'material input nonmutation')
  print '(a,i0)','IRR_ROOT_MATERIAL_DEPTH_CASES=',count
  print '(a)','IRR_ROOT_MATERIAL_PARTIAL_CELL_MVG_INVALID_ABA=PASS'
contains
  real(real64) function theta(node,h)
    integer,intent(in)::node
    real(real64),intent(in)::h
    theta=cof(1,node)+(cof(2,node)-cof(1,node))/(1._real64+abs(cof(4,node)*h)**cof(6,node))**cof(7,node)
  end function
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,label
      error stop 1
    end if
  end subroutine
  subroutine rejected(label)
    character(*),intent(in)::label
    call require(status==IRR_ROOT_ZONE_INVALID_PARAMETERS,label)
    call require(root%active_nodes==0.and.root%rooted_nodes==0,'failure publishes no partial root view')
    call require(.not.allocated(root%field_capacity_water_content),'failure publishes no threshold arrays')
  end subroutine
end program
