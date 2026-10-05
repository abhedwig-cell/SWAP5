program test_root_frost
 use iso_fortran_env, only: real64
 use ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf
 use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t
 use mod_root_frost_stress
 use mod_root_uptake_compensation
 use mod_root_uptake_compensation_execution
 use mod_root_water_uptake_process, only: root_water_uptake_diagnostics_t
 implicit none
 type(root_water_uptake_flux_result_t)::base,cut,final
 type(root_frost_config_t)::frost
 type(root_compensation_config_t)::cfg
 type(root_compensation_diagnostics_t)::diag
 type(root_water_uptake_diagnostics_t)::base_diag
 type(root_walsum_geometry_t)::geometry
 real(real64),allocatable::factors(:)
 real(real64)::loss,dry,wet,frs,t(4)
 integer::status,k
 allocate(base%root_extraction_sink(4))
 base%root_extraction_sink=[.125_real64,.25_real64,.125_real64,0._real64]
 base%actual_uptake_total=.5_real64
 frost%active=.true.;frost%rooted_nodes=3
 t=[-epsilon(1._real64),0._real64,epsilon(1._real64),-10._real64]
 call compose_legacy_zero_root_frost(frost,t,base,cut,factors,loss,status)
 call req(status==ROOT_FROST_OK,'cutoff valid')
 call req(all(cut%root_extraction_sink==[0._real64,.25_real64,.125_real64,0._real64]),'strict subzero oracle')
 call req(loss==.125_real64.and.cut%actual_uptake_total==.375_real64,'root loss oracle')
 t(1)=ieee_value(0._real64,ieee_quiet_nan)
 call compose_legacy_zero_root_frost(frost,t,base,cut,factors,loss,status)
 call req(status==ROOT_FROST_INVALID,'NaN rejected')
 t(1)=ieee_value(0._real64,ieee_positive_inf)
 call compose_legacy_zero_root_frost(frost,t,base,cut,factors,loss,status)
 call req(status==ROOT_FROST_INVALID,'infinity rejected')
 call compose_legacy_zero_root_frost(frost,t(:3),base,cut,factors,loss,status)
 call req(status==ROOT_FROST_INVALID,'shape rejected')
 frost%active=.false.
 call compose_legacy_zero_root_frost(frost,t(:3),base,cut,factors,loss,status)
 call req(status==ROOT_FROST_OK.and.all(cut%root_extraction_sink==base%root_extraction_sink),'OFF exact preservation')
 frost%active=.true.;frost%rooted_nodes=5
 call compose_legacy_zero_root_frost(frost,[1._real64,1._real64,1._real64,1._real64],base,cut,factors,loss,status)
 call req(status==ROOT_FROST_INVALID,'root domain rejected')
 frost%rooted_nodes=3;t=-1._real64
 call compose_legacy_zero_root_frost(frost,t,base,cut,factors,loss,status)
 call req(status==ROOT_FROST_OK.and.cut%actual_uptake_total==0._real64,'all frozen')
 cfg%method=ROOT_COMP_JARVIS;cfg%stressor=ROOT_COMP_ALL;cfg%alpha_critical=.5_real64
 call compose_jarvis_root_uptake(cfg,.5_real64,cut,0._real64,0._real64,final,diag,status,.5_real64)
 call req(status==ROOT_COMP_OK.and.final%actual_uptake_total==0._real64,'no frozen root resurrection')
 ! Three node losses: .5 on frozen node, .1875 on each unfrozen node.
 ! Shared reduction weights give dry=.3125, wet=.3125, frost=.25.
 call attribute_root_stress_losses([.5_real64,.25_real64,.25_real64], &
      [.25_real64,.125_real64,.125_real64],[.5_real64,.5_real64,.5_real64],dry,wet,status, &
      [0._real64,1._real64,1._real64],frs)
 call req(status==ROOT_COMP_OK,'three stressors valid')
 call req(abs(dry-.3125_real64)<1.e-14_real64.and.abs(wet-.3125_real64)<1.e-14_real64.and. &
      abs(frs-.25_real64)<1.e-14_real64,'independent node attribution oracle')
 ! Equal attributed losses with alpha=1/8 give each effective alpha=1/2.
 ! Selecting one stressor restores its alpha to one; the other two yield 1/4.
 base%root_extraction_sink=[0._real64,.0625_real64,.0625_real64,0._real64]
 base%actual_uptake_total=.125_real64
 do k=1,5
   if(k==4) cycle
   cfg%stressor=k
   call compose_jarvis_root_uptake(cfg,1._real64,base,7._real64/24._real64,7._real64/24._real64, &
        final,diag,status,7._real64/24._real64)
   call req(status==ROOT_COMP_OK,'selected stressor admitted')
   call req(abs(final%actual_uptake_total-.25_real64)<1.e-14_real64,'closed form compensation oracle')
   call req(final%root_extraction_sink(1)==0._real64.and.final%root_extraction_sink(4)==0._real64,'zero nodes preserved')
   call req(abs(diag%drought_reduction_total+diag%oxygen_reduction_total+diag%frost_reduction_total-.75_real64)<1.e-14_real64, &
        'post compensation attribution closes')
 end do
 cfg%stressor=ROOT_COMP_FROST;cfg%alpha_critical=1._real64
 call compose_jarvis_root_uptake(cfg,1._real64,base,7._real64/24._real64,7._real64/24._real64, &
      final,diag,status,7._real64/24._real64)
 call req(status==ROOT_COMP_OK.and.all(final%root_extraction_sink==base%root_extraction_sink),'alpha one identity')
 cfg%method=ROOT_COMP_WALSUM
 cfg%stressor=ROOT_COMP_FROST
 geometry=root_walsum_geometry_t(1._real64,2._real64,1.5_real64)
 base_diag%drought_reduction_total=7._real64/24._real64
 call apply_root_uptake_compensation(cfg,1._real64,base,base_diag,7._real64/24._real64,final,diag,status, &
      geometry,[.5_real64,.5_real64,1._real64,1._real64],7._real64/24._real64)
 call req(status==ROOT_COMP_EXEC_OK,'Walsum frost composition valid')
 call req(abs(final%actual_uptake_total-.25_real64)<1.e-14_real64,'Walsum geometry alpha oracle')
 print '(A)','PPA-WU05B2_ROOT_FROST_ORACLES=PASS'
contains
 subroutine req(ok,message)
 logical,intent(in)::ok
 character(*),intent(in)::message
 if(.not.ok) then
 print *,message
 error stop 1
 end if
 end subroutine
end program
