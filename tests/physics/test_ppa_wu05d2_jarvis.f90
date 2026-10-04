program test_ppa_wu05d2_jarvis
 use iso_fortran_env,only:real64
 use mod_root_water_uptake_process,only:root_water_uptake_flux_result_t
 use mod_root_uptake_compensation
 implicit none
 type(root_water_uptake_flux_result_t)::base,a,b
 type(root_compensation_config_t)::cfg
 type(root_compensation_diagnostics_t)::da,db
 integer::s
 allocate(base%root_extraction_sink(4))
 base%root_extraction_sink=[0.05_real64,0.10_real64,0.15_real64,0.10_real64]
 base%actual_uptake_total=sum(base%root_extraction_sink)
 cfg%method=ROOT_COMP_OFF
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.1_real64,0.0_real64,a,da,s)
 call req(s==ROOT_COMP_OK.and.all(a%root_extraction_sink==base%root_extraction_sink),'off identity')
 cfg%method=ROOT_COMP_JARVIS
 cfg%stressor=ROOT_COMP_DROUGHT
 cfg%alpha_critical=0.7_real64
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.1_real64,0.0_real64,a,da,s)
 call req(s==ROOT_COMP_OK.and.da%applied,'drought applies')
 call req(abs(sum(a%root_extraction_sink)-a%actual_uptake_total)<1e-14_real64,'mass identity')
 call req(a%actual_uptake_total>=base%actual_uptake_total.and.a%actual_uptake_total<=0.5_real64,'bounds')
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.1_real64,0.0_real64,b,db,s)
 call req(all(a%root_extraction_sink==b%root_extraction_sink),'fresh retry identity')
 cfg%stressor=ROOT_COMP_OXYGEN
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.0_real64,0.1_real64,a,da,s)
 call req(s==ROOT_COMP_OK.and.da%applied,'oxygen applies')
 cfg%stressor=ROOT_COMP_ALL
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.06_real64,0.04_real64,a,da,s)
 call req(s==ROOT_COMP_OK.and.da%applied,'all admitted stressors applies')
 cfg%stressor=4
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.1_real64,0.0_real64,a,da,s)
 call req(s==ROOT_COMP_UNSUPPORTED,'salinity fail closed')
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
