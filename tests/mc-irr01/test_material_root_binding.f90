program material_root_binding
 use iso_fortran_env, only: real64,int64
 use ieee_arithmetic, only: ieee_value,ieee_quiet_nan
 use mod_b110_default_mvg_provider
 use mod_fmr_irrigation_material_root_binding
 use mod_irrigation_root_zone_summary
 use mod_process_hydraulic_view
 implicit none
 type(b110_default_mvg_parameters_t),target::material,original,bad
 type(irrigation_root_zone_parameters_t)::root,again
 type(irrigation_root_zone_summary_t)::summary
 type(process_hydraulic_view_t)::view
 real(real64)::cof(24,3),dz(3),rd,hfc,expected(4),theta_fc,theta_stress,theta_wilt,weight,left
 real(real64)::heads(5)
 integer::i,j,k,st,cases,invalid
 logical::ok
 cof=0;cof(1,:)=.05_real64;cof(2,:)=[.40_real64,.43_real64,.46_real64]
 cof(3,:)=1;cof(4,:)=[.01_real64,.02_real64,.03_real64];cof(5,:)=.5_real64
 cof(6,:)=1.5_real64;cof(7,:)=1._real64-1._real64/1.5_real64
 call initialize_b110_default_mvg_parameters(material,cof);original=material
 dz=[5._real64,10._real64,15._real64];view%active_nodes=3
 allocate(view%water_content(3));cases=0
 do j=0,3
 hfc=-real(j,real64)*100._real64
 do k=1,60
 rd=real(k,real64)*.5_real64
 call fmr_build_irrigation_material_root_zone(material,dz,rd,hfc,-500._real64,-800._real64,-16000._real64,root,ok)
 call require(ok,'actual material composition')
 expected=0;left=rd
 do i=1,3
  theta_fc=literal(i,hfc);theta_stress=literal(i,-650._real64);theta_wilt=literal(i,-16000._real64)
  view%water_content(i)=literal(i,-300._real64-real(k,real64)*10._real64)
  call require(abs(root%field_capacity_water_content(i)-theta_fc)<1.e-14_real64,'independent literal material FC')
  call require(abs(root%stress_water_content(i)-theta_stress)<1.e-14_real64,'irrigation arithmetic mean head, not Feddes demand')
  call require(abs(root%wilting_water_content(i)-theta_wilt)<1.e-14_real64,'independent literal material wilting')
  weight=max(0._real64,min(dz(i),left));left=left-dz(i)
  expected=expected+weight*[theta_fc-theta_wilt,theta_stress-theta_wilt,view%water_content(i)-theta_wilt,theta_fc-view%water_content(i)]
 end do
 call evaluate_irrigation_root_zone_summary(root,view,summary,st)
 call require(st==IRR_ROOT_ZONE_OK,'actual fractional root summary')
 call require(maxval(abs(expected-[summary%total_available_water_cm,summary%stress_to_wilting_available_cm, &
  summary%actual_available_water_cm,summary%field_capacity_deficit_cm]))<2.e-14_real64,'independent partial deepest compartment sums')
 call require(all(material%cofgen==original%cofgen),'material nonmutation')
 cases=cases+1
 end do
 end do
 do invalid=1,13
  bad=material;heads=[12._real64,-100._real64,-500._real64,-800._real64,-16000._real64];dz=[5._real64,10._real64,15._real64]
  select case(invalid)
  case(1);heads(1)=0
  case(2);heads(1)=-1
  case(3);heads(1)=31
  case(4);heads(1)=ieee_value(0._real64,ieee_quiet_nan)
  case(5);heads(2)=-501
  case(6);heads(2)=1
  case(7);heads(3)=-20000
  case(8);heads(5)=-100
  case(9);dz(2)=0
  case(10);dz(2)=ieee_value(0._real64,ieee_quiet_nan)
  case(11);bad%active_nodes=2
  case(12);bad%cofgen(4,1)=ieee_value(0._real64,ieee_quiet_nan)
  case(13);bad%conductivity_power_tail_enabled=.true.
  end select
  call fmr_build_irrigation_material_root_zone(bad,dz,heads(1),heads(2),heads(3),heads(4),heads(5),root,ok)
  call require(.not.ok.and.root%active_nodes==0.and..not.allocated(root%node_thickness_cm),'invalid request empty output and fail closed')
 end do
 dz=[5._real64,10._real64,15._real64]
 call fmr_build_irrigation_material_root_zone(material,dz,12._real64,-100._real64,-500._real64,-800._real64,-16000._real64,root,ok)
 call require(ok,'A repeat after independent invalid B')
 call fmr_build_irrigation_material_root_zone(material,dz,12._real64,-100._real64,-500._real64,-800._real64,-16000._real64,again,ok)
 call require(ok.and.root%rooted_nodes==2.and.abs(root%last_rooted_fraction-.7_real64)<1.e-15_real64,'12cm uses partial second node, not configured/potential depth')
 call require(all(transfer(root%field_capacity_water_content,[0_int64],3)==transfer(again%field_capacity_water_content,[0_int64],3)),'A/B/A exact material authority')
 print '(a,i0)','MATERIAL_ROOT_LITERAL_CASES=',cases
 print '(a)','MC_IRR01_MATERIAL_ROOT_LITERAL_NONMUTATION_INVALID_ABA=PASS'
contains
 real(real64) function literal(node,h)result(theta)
 integer,intent(in)::node
 real(real64),intent(in)::h
 theta=cof(1,node)+(cof(2,node)-cof(1,node))/(1._real64+abs(cof(4,node)*h)**cof(6,node))**cof(7,node)
 end function
 subroutine require(value,message)
 logical,intent(in)::value
 character(*),intent(in)::message
 if(.not.value)then
 print *,message
 error stop 1
 end if
 end subroutine
end program
