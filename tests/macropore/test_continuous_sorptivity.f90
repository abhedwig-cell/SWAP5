program test_continuous_sorptivity
  use iso_fortran_env, only: real64,real128
  use mod_ppa_wu05a6_sorptivity_rate
  use mod_ppa_wu05a6_unsat_absorption_rate
  implicit none
  type(sorptivity_rate_request_t)::r
  type(sorptivity_rate_result_t)::legacy,explicit_legacy,corrected,previous
  type(unsat_absorption_request_t)::u
  type(unsat_absorption_result_t)::ur
  real(real64)::deficit,expected
  real(real128)::oracle,dtq,tq,aq
  integer::k
  r%num_domains=1;r%num_nodes=1;r%top_node=1;r%swmbf=1
  r%matrix_top_saturated_node=2;r%step_duration=0.01_real64
  r%bottom_domain=[1];r%top_water_node=[1]
  r%theta_s=[0.5_real64];r%theta_r=[0.1_real64];r%theta=[0.4_real64]
  r%dz=[1.0_real64];r%diameter=[10.0_real64];r%wall_correction=[1.0_real64]
  r%sorptivity_max=[2.0_real64];r%sorptivity_alpha=[0.5_real64]
  allocate(r%domain_fraction(1,1),r%wet_fraction(1,1),r%history_sorptivity(1,1), &
    r%history_theta_ref(1,1),r%history_absorption_time(1,1))
  r%domain_fraction=1;r%wet_fraction=1;r%history_sorptivity=0
  r%history_theta_ref=0;r%history_absorption_time=0
  do k=1,12
    deficit=10.0_real64**(-k);r%theta=r%theta_s-deficit
    call evaluate_sorptivity_rate(r,legacy)
    call evaluate_sorptivity_rate(r,explicit_legacy,.false.)
    call check(legacy%valid.and.explicit_legacy%valid,'valid archived')
    call check(all(legacy%amount_cm==explicit_legacy%amount_cm),'default exact')
    call check(all(legacy%end_event.eqv.explicit_legacy%end_event),'default history exact')
    call evaluate_sorptivity_rate(r,corrected,.true.)
    expected=2*sqrt((r%theta_s(1)-r%theta(1))/0.4_real64)*0.4_real64*sqrt(r%step_duration)
    call check(abs(corrected%amount_cm(1,1)-expected)<1e-14_real64*expected,'power-law oracle')
    call check(.not.corrected%end_event(1,1),'positive history retained')
    if(k>8)call check(legacy%amount_cm(1,1)==0,'archived deficit cutoff')
  end do
  r%theta=0.5_real64-1e-8_real64*(1+1e-5_real64)
  call evaluate_sorptivity_rate(r,previous,.true.)
  r%theta=0.5_real64-1e-8_real64*(1-1e-5_real64)
  call evaluate_sorptivity_rate(r,corrected,.true.)
  call check(abs(corrected%amount_cm(1,1)/previous%amount_cm(1,1)-1)<2e-5_real64,'cutoff continuity')
  r%theta=0.4_real64;r%history_absorption_time=1;r%history_theta_ref=0.5_real64
  r%step_duration=1e-20_real64
  call evaluate_sorptivity_rate(r,corrected,.true.)
  call evaluate_sorptivity_rate(r,legacy)
  dtq=real(r%step_duration,real128);tq=1;aq=2*sqrt(0.25_real128)
  oracle=aq*0.4_real128*dtq/(sqrt(tq+dtq)+sqrt(tq))
  call check(abs(corrected%amount_cm(1,1)-real(oracle,real64))<1e-14_real64*real(oracle,real64),'real128 tiny dt')
  call check(legacy%amount_cm(1,1)==0,'legacy cancellation witness')
  u%sorptivity=r;u%pressure_head=[-1.0_real64];u%elevation=[-1.0_real64]
  u%conductivity=[1.0_real64];u%entry_head=[0.0_real64]
  u%groundwater_level_domain=[0.0_real64];u%sorp_fac_parallel=[1.0_real64]
  call evaluate_unsat_absorption(u,ur)
  call check(ur%valid.and.ur%selected_amount_cm(1,1)==0,'zero width legacy exact')
  u%entry_transition_width_cm=1e-4_real64
  call evaluate_unsat_absorption(u,ur)
  call check(ur%valid.and.ur%selected_amount_cm(1,1)>0,'composed corrected route')
  r%theta=r%theta_s
  call evaluate_sorptivity_rate(r,corrected,.true.)
  call check(all(corrected%amount_cm==0).and.all(corrected%end_event),'saturated zero')
  r%step_duration=0
  call evaluate_sorptivity_rate(r,corrected,.true.)
  call check(.not.corrected%valid,'invalid dt rejects')
  print *, 'CONTINUOUS_SORPTIVITY_PASS'
contains
  subroutine check(ok,message)
    logical,intent(in)::ok
    character(*),intent(in)::message
    if(.not.ok)then
      print *,message
      error stop 1
    end if
  end subroutine
end program
