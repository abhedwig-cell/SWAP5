program test_integrated_wet_wall
 use iso_fortran_env,only:real64
 use mod_macropore_standard_rate_adapter,only:integrate_matrix_wet_wall
 use mod_ppa_wu05a6_saturated_exchange_rate
 use mod_ppa_wu05a6_saturated_sources
 implicit none
 real(real64)::h(3),z(3)=[-0.5_real64,-1.5_real64,-2.5_real64],dz(3)=1
 real(real64)::macro(1,3),wet(3),overlap(1,3)
 logical::ok
 type(saturated_exchange_request_t)::request,inactive,legacy_request
 type(saturated_exchange_result_t)::before,after,legacy,control
 type(saturated_sources_result_t)::sources
 macro=1;h=-1.25_real64-z
 call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 call check(ok.and.maxval(abs(wet-[0.0_real64,0.75_real64,1.0_real64]))<1e-15_real64,'hydrostatic exact areas')
 call check(all(overlap(1,:)==wet),'full macro overlap')
 macro=0.5_real64
 call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 call check(ok.and.overlap(1,2)==0.5_real64,'exact lower wet intersection')
 h=[1.0_real64,-1e-8_real64,1.0_real64];macro=1
 call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 call check(ok.and.abs(wet(2)-1)<3e-8_real64,'vanishing dry pocket is continuous')
 h(2)=0
 call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 call check(ok.and.wet(2)==1,'zero-pressure point has no dry wall length')
 h=-1
 call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 call check(ok.and.all(wet==0).and.all(overlap==0),'dry matrix')
 h=1
 call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 call check(ok.and.all(wet==1).and.all(overlap==1),'wet matrix')
 macro=-1
 call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 call check(.not.ok.and.all(wet==0).and.all(overlap==0),'invalid input atomic empty output')
 ! Exercise the actual Darcy and source-booking owners with a vanishing dry pocket.
 macro=1;h=[1.0_real64,-1e-8_real64,1.0_real64]
 call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 request%num_domains=1;request%num_nodes=3;request%step_duration=0.01_real64
 request%matrix_top_saturated_node=1;request%matrix_bottom_saturated_node=3
 request%matrix_partial_top_active=.false.;request%matrix_level=-1.5_real64
 request%bottom_domain=[3];request%top_macro_saturated_node=[1]
 request%macro_saturated_fraction=[1.0_real64];request%macro_reference_level=[0.0_real64]
 request%z=z;request%dz=dz;request%matrix_head=h
 request%ksat_horizontal=[1.0_real64,1.0_real64,1.0_real64]
 request%diameter=[10.0_real64,10.0_real64,10.0_real64]
 allocate(request%domain_fraction(1,3),request%cdarcy(1,3));request%domain_fraction=1;request%cdarcy=2
 request%matrix_wet_fraction=wet;request%wet_wall_overlap=overlap
 call evaluate_saturated_exchange(request,before,.true.)
 call check(before%valid.and.before%qexc_to_matrix_rate_cm_per_day(1,2)>0,'negative-centre wetted wall transfers water')
 legacy_request=request;deallocate(legacy_request%matrix_wet_fraction,legacy_request%wet_wall_overlap)
 call evaluate_saturated_exchange(legacy_request,legacy)
 call evaluate_saturated_exchange(request,control)
 call check(legacy%valid.and.control%valid,'legacy controls valid')
 call check(all(legacy%qexc_to_matrix_rate_cm_per_day==control%qexc_to_matrix_rate_cm_per_day),'default rate ignores optional wall partition')
 h(2)=0;call integrate_matrix_wet_wall(h,z,dz,macro,wet,overlap,ok)
 request%matrix_head=h;request%matrix_wet_fraction=wet;request%wet_wall_overlap=overlap
 call evaluate_saturated_exchange(request,after,.true.)
 call check(after%valid.and.abs(after%qexc_to_matrix_rate_cm_per_day(1,2)- &
   before%qexc_to_matrix_rate_cm_per_day(1,2))<1e-7_real64,'actual Darcy rate continuous at disappearing pocket')
 inactive=request;inactive%matrix_bottom_saturated_node=0
 call evaluate_saturated_sources(request,inactive,sources,.true.)
 call check(sources%valid,'real saturated source booking valid')
 call check(all(sources%qexc_sat_to_matrix_rate==sources%qout_matrix_sat_rate- &
   sources%qin_interflow_rate-sources%qin_matrix_sat_rate),'signed transfer fully booked')
 request%matrix_wet_fraction=2
 call evaluate_saturated_exchange(request,after,.true.)
 call check(.not.after%valid,'out-of-range wall fraction rejects')
 print *,'INTEGRATED_WET_WALL_AND_REAL_RATE_PASS'
contains
 subroutine check(ok,msg)
 logical,intent(in)::ok
 character(*),intent(in)::msg
 if(.not.ok)then
 print *,msg
 error stop 1
 end if
 end subroutine
end program
