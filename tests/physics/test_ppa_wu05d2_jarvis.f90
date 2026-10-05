program test_ppa_wu05d2_jarvis
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_root_water_uptake_process,only:root_water_uptake_flux_result_t
 use mod_root_uptake_compensation
 use mod_root_uptake_compensation_execution
 use mod_root_water_uptake_process,only:root_water_uptake_diagnostics_t
 use mod_root_salinity_response,only:evaluate_mobile_root_salinity_sink,SALINITY_OK
 implicit none
 type(root_water_uptake_flux_result_t)::base,a,b
 type(root_compensation_config_t)::cfg
 type(root_compensation_diagnostics_t)::da,db
 type(root_water_uptake_diagnostics_t)::bd
 integer::s
 real(real64),parameter::tol=1.e-14_real64
 real(real64)::dryloss,wetloss,saltloss
 real(real64),allocatable::cml(:),salt_alpha(:),salt_sink(:),salt_node_loss(:)
 real(real64)::salt_loss,potential_saved(4)
 allocate(base%root_extraction_sink(4))
 base%root_extraction_sink=[0.05_real64,0.10_real64,0.15_real64,0.10_real64]
 base%actual_uptake_total=sum(base%root_extraction_sink)

 cfg%method=ROOT_COMP_OFF
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.1_real64,0.0_real64,a,da,s)
 call req(s==ROOT_COMP_OK.and.all(a%root_extraction_sink==base%root_extraction_sink),'off identity')
 call req(a%actual_uptake_total==base%actual_uptake_total,'off total identity')

 cfg%method=ROOT_COMP_JARVIS; cfg%stressor=ROOT_COMP_DROUGHT; cfg%alpha_critical=1.0_real64
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.1_real64,0.0_real64,a,da,s)
 call req(s==ROOT_COMP_OK.and.all(a%root_extraction_sink==base%root_extraction_sink),'alpha one identity')

 cfg%alpha_critical=0.7_real64
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.1_real64,0.0_real64,a,da,s)
 call req(s==ROOT_COMP_OK.and.da%applied,'drought applies')
 call req(abs(sum(a%root_extraction_sink)-a%actual_uptake_total)<tol,'mass identity')
 call req(a%actual_uptake_total>=base%actual_uptake_total.and.a%actual_uptake_total<=0.5_real64,'bounds')
 call req(abs(a%root_extraction_sink(2)/base%root_extraction_sink(2)-a%root_extraction_sink(4)/base%root_extraction_sink(4))<tol,'nodewise uniform rescale')
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.1_real64,0.0_real64,b,db,s)
 call req(all(a%root_extraction_sink==b%root_extraction_sink).and.a%actual_uptake_total==b%actual_uptake_total,'fresh retry identity')

 cfg%stressor=ROOT_COMP_OXYGEN
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.0_real64,0.1_real64,a,da,s)
 call req(s==ROOT_COMP_OK.and.da%applied,'oxygen applies')

 cfg%stressor=ROOT_COMP_ALL
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.06_real64,0.04_real64,a,da,s)
 call req(s==ROOT_COMP_OK.and.da%applied,'all admitted stressors applies')
 call req(abs(da%drought_reduction_total+da%oxygen_reduction_total-(0.5_real64-a%actual_uptake_total))<tol,'stress attribution closes')

 cfg%stressor=ROOT_COMP_SALINITY;cfg%alpha_critical=.9_real64
 potential_saved=base%root_extraction_sink
 call evaluate_mobile_root_salinity_sink([1.0_real64,1.25_real64,1.5_real64,2.0_real64], &
      [0.2_real64,0.2_real64,0.2_real64,0.2_real64],[1.0_real64,1.0_real64,1.0_real64,1.0_real64], &
      5.0_real64,0.2_real64,potential_saved,cml,salt_alpha,salt_sink,salt_node_loss,salt_loss,s)
 call req(s==SALINITY_OK.and.maxval(abs(salt_alpha-[1.0_real64,.75_real64,.5_real64,0.0_real64]))<tol, &
      'same-view mass derives Maas-Hoffman root factors')
 call req(abs(sum(salt_node_loss)-salt_loss)<tol,'same-view node loss aggregates')
 base%root_extraction_sink=salt_sink;base%actual_uptake_total=sum(salt_sink)
 call compose_jarvis_root_uptake(cfg,.5_real64,base,.1_real64,0.0_real64,a,da,s,salt_loss)
 call req(s==ROOT_COMP_OK.and.da%applied.and.da%salinity_reduction_total>0.0_real64, &
      'mass-derived salinity loss composes through Jarvis')
 call req(a%actual_uptake_total>=base%actual_uptake_total.and.a%actual_uptake_total<=.5_real64, &
      'mass-derived Jarvis recovery remains bounded')
 base%root_extraction_sink=potential_saved;base%actual_uptake_total=sum(potential_saved)
 call compose_jarvis_root_uptake(cfg,.5_real64,base,0.0_real64,0.0_real64,a,da,s,.1_real64)
 call req(s==ROOT_COMP_OK.and.da%applied,'salinity stressor composes')
 call req(a%actual_uptake_total>.4_real64.and.a%actual_uptake_total<.5_real64,'salinity-only Jarvis recovery')
 call req(abs(da%salinity_reduction_total-(.5_real64-a%actual_uptake_total))<tol, &
      'salinity post-compensation attribution closes')
 cfg%stressor=ROOT_COMP_DROUGHT;cfg%alpha_critical=.7_real64
 call compose_jarvis_root_uptake(cfg,.5_real64,base,0.0_real64,0.0_real64,a,da,s,.1_real64)
 call req(s==ROOT_COMP_OK.and.abs(a%actual_uptake_total-.4_real64)<tol, &
      'drought selector leaves salinity loss in place')

 cfg%stressor=ROOT_COMP_DROUGHT
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.05_real64,0.0_real64,a,da,s)
 call req(s==ROOT_COMP_UNSUPPORTED,'unattributed stress fails closed')

 base%root_extraction_sink=[0.0_real64,0.0_real64,0.0_real64,0.03125_real64]
 base%actual_uptake_total=sum(base%root_extraction_sink)
 call compose_jarvis_root_uptake(cfg,0.625_real64,base,0.59375_real64,0.0_real64,a,da,s)
 call req(s==ROOT_COMP_OK.and.da%applied,'alptot exactly 0.05 is eligible')
 base%root_extraction_sink(4)=0.021_real64;base%actual_uptake_total=sum(base%root_extraction_sink)
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.476_real64,0.0_real64,a,da,s)
 call req(s==ROOT_COMP_OK.and..not.da%applied,'alptot below 0.05 guarded')

 base%root_extraction_sink=[0.05_real64,0.10_real64,0.15_real64,0.10_real64];base%actual_uptake_total=sum(base%root_extraction_sink)
 cfg%alpha_critical=0.2_real64
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.1_real64,0.0_real64,a,da,s)
 call req(abs(a%actual_uptake_total-0.5_real64)<tol,'full compensation capacity')
 call req(abs(da%drought_reduction_total)<tol,'full compensation clears drought attribution')

 call compose_jarvis_root_uptake(cfg,0.0_real64,base,0.0_real64,0.0_real64,a,da,s)
 call req(s==ROOT_COMP_INVALID,'ptra below existing uptake invalid')

 deallocate(base%root_extraction_sink)
 call compose_jarvis_root_uptake(cfg,0.0_real64,base,0.0_real64,0.0_real64,a,da,s)
 call req(s==ROOT_COMP_INVALID,'missing sink invalid')

 allocate(base%root_extraction_sink(4))
 base%root_extraction_sink=[0.05_real64,0.10_real64,0.15_real64,0.10_real64];base%actual_uptake_total=sum(base%root_extraction_sink)
 bd%drought_reduction_total=0.1_real64
 cfg%method=ROOT_COMP_OFF;cfg%alpha_critical=0.7_real64;cfg%stressor=ROOT_COMP_DROUGHT
 call apply_root_uptake_compensation(cfg,0.5_real64,base,bd,0.0_real64,a,da,s)
 call req(s==ROOT_COMP_EXEC_OK.and.all(a%root_extraction_sink==base%root_extraction_sink),'execution off preservation')
 cfg%method=ROOT_COMP_JARVIS
 call apply_root_uptake_compensation(cfg,0.5_real64,base,bd,0.0_real64,a,da,s)
 call req(s==ROOT_COMP_EXEC_OK.and.da%applied,'execution Jarvis applies')
 call req(abs(sum(a%root_extraction_sink)-a%actual_uptake_total)<tol,'execution single final sink identity')
 bd%drought_reduction_total=.05_real64
 call apply_root_uptake_compensation(cfg,.5_real64,base,bd,0.0_real64,a,da,s, &
      salinity_reduction_total=.05_real64)
 call req(s==ROOT_COMP_EXEC_OK.and.abs(da%salinity_reduction_total)>0.0_real64, &
      'execution carries salinity attribution')

 ! One node with drought=oxygen=1/2 loses 3/4, apportioned equally.
 ! Sequential losses (1/2,1/4) would be incorrect source attribution.
 call attribute_root_stress_losses([1._real64],[.5_real64],[.5_real64],dryloss,wetloss,s)
 call req(s==ROOT_COMP_OK.and.abs(dryloss-.375_real64)<tol.and.abs(wetloss-.375_real64)<tol,'source apportionment oracle')
 call attribute_root_stress_losses([1._real64],[.5_real64],[.5_real64],dryloss,wetloss,s, &
      [.5_real64],saltloss)
 call req(s==ROOT_COMP_OK.and.abs(dryloss-7._real64/24._real64)<tol.and. &
      abs(wetloss-7._real64/24._real64)<tol.and.abs(saltloss-7._real64/24._real64)<tol, &
      'three-stressor attribution oracle')
 ! Independent closed-form mixed-stressor oracle: total alpha=1/4,
 ! equal losses imply sqrt(alpha)=1/2 for each stressor. Drought
 ! compensation with alpha_critical=1/2 restores drought only.
 base%root_extraction_sink=[.0_real64,.0625_real64,.125_real64,.0625_real64]
 base%actual_uptake_total=.25_real64
 cfg%alpha_critical=.5_real64;cfg%stressor=ROOT_COMP_DROUGHT
 call compose_jarvis_root_uptake(cfg,1._real64,base,.375_real64,.375_real64,a,da,s)
 call req(s==ROOT_COMP_OK,'mixed oracle valid')
 call req(all(abs(a%root_extraction_sink-[0._real64,.125_real64,.25_real64,.125_real64])<tol),'mixed node oracle')
 call req(abs(da%drought_reduction_total)<tol.and.abs(da%oxygen_reduction_total-.5_real64)<tol,'mixed attribution oracle')
 cfg%alpha_critical=0._real64
 call compose_jarvis_root_uptake(cfg,1._real64,base,.375_real64,.375_real64,a,da,s)
 call req(s==ROOT_COMP_INVALID,'zero alpha invalid')
 cfg%alpha_critical=1.01_real64
 call compose_jarvis_root_uptake(cfg,1._real64,base,.375_real64,.375_real64,a,da,s)
 call req(s==ROOT_COMP_INVALID,'alpha above one invalid')
 cfg%alpha_critical=.5_real64
 call compose_jarvis_root_uptake(cfg,ieee_value(0._real64,ieee_quiet_nan),base,.375_real64,.375_real64,a,da,s)
 call req(s==ROOT_COMP_INVALID,'NaN demand invalid')
 base%root_extraction_sink=0._real64;base%actual_uptake_total=0._real64
 call compose_jarvis_root_uptake(cfg,0._real64,base,0._real64,0._real64,a,da,s)
 call req(s==ROOT_COMP_OK.and..not.da%applied,'zero demand safe')
 call compose_jarvis_root_uptake(cfg,1.e-16_real64,base,1.e-16_real64,0._real64,a,da,s)
 call req(s==ROOT_COMP_OK.and..not.da%applied,'tiny demand safe')
 print *,'PPA_WU05D2_JARVIS=PASS'
contains
 subroutine req(x,m)
  logical,intent(in)::x
  character(*),intent(in)::m
  if(.not.x)then
   print *,'FAIL ',m
   error stop 1
  endif
 end subroutine
end program
