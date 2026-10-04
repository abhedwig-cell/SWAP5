program test_ppa_wu05d2_jarvis
 use iso_fortran_env,only:real64
 use mod_root_water_uptake_process,only:root_water_uptake_flux_result_t
 use mod_root_uptake_compensation
 use mod_root_uptake_compensation_execution
 use mod_root_water_uptake_process,only:root_water_uptake_diagnostics_t
 implicit none
 type(root_water_uptake_flux_result_t)::base,a,b
 type(root_compensation_config_t)::cfg
 type(root_compensation_diagnostics_t)::da,db
 type(root_water_uptake_diagnostics_t)::bd
 integer::s
 real(real64),parameter::tol=1.e-14_real64
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

 cfg%stressor=4
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.1_real64,0.0_real64,a,da,s)
 call req(s==ROOT_COMP_UNSUPPORTED,'salinity fail closed')

 cfg%stressor=ROOT_COMP_DROUGHT
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.05_real64,0.0_real64,a,da,s)
 call req(s==ROOT_COMP_UNSUPPORTED,'unattributed stress fails closed')

 base%root_extraction_sink=[0.001_real64,0.001_real64,0.001_real64,0.022_real64]
 base%actual_uptake_total=sum(base%root_extraction_sink)
 call compose_jarvis_root_uptake(cfg,0.5_real64,base,0.475_real64,0.0_real64,a,da,s)
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
