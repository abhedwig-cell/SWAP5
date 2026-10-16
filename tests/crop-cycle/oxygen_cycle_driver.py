"""Extend the retained real seven-day driver; existing assertions stay intact."""
from pathlib import Path

def prepare(root, target):
    s=(root/'tests/fmig431/test_crop_file_weather_production.f90').read_text()
    def replace(old,new):
        nonlocal s
        assert s.count(old)==1,old
        s=s.replace(old,new)
    replace('  call test_rooted_weather_production()','  call test_rooted_weather_production(oxygen=.true.)')
    replace('  call test_rooted_weather_production(.true.)','  call test_rooted_weather_production(.true.,.true.)')
    replace('  subroutine test_rooted_weather_production(at_dayend)', '  subroutine test_rooted_weather_production(at_dayend,oxygen)')
    replace('    logical,intent(in),optional::at_dayend','    logical,intent(in),optional::at_dayend,oxygen')
    replace('    logical::ok,dayend','    logical::ok,dayend,wet\n    real(real64)::expected_rate,neutral_rate,maximum_residual,total_reduction\n    integer::stress_cases')
    replace('    dayend=.false.','    wet=.false.\n    if(present(oxygen))wet=oxygen\n    dayend=.false.')
    replace('    call construct_crop_et_canopy_parameters(0.8_real64', '''    if(wet)then
      tc%file_weather_root_parameters%empirical_oxygen_enabled=.true.
      tc%file_weather_root_parameters%upper_layer_bottom_node=2
      tc%file_weather_root_parameters%hlim1=-10.0_real64
      tc%file_weather_root_parameters%hlim2u=-100.0_real64
      tc%file_weather_root_parameters%hlim2l=-150.0_real64
    end if
    call construct_crop_et_canopy_parameters(0.8_real64''')
    replace('    do j=1,2\n      call ta%initialize', '''    if(wet)then
      bad_tc=tc;bad_tc%file_weather_root_parameters%hlim2u=-10.0_real64
      call bad_app%initialize(bad_tc,st)
      call require(st/=FMR_APP_BOOT_OK.and..not.bad_app%ready(),'invalid wet stress thresholds reject before initialization')
      bad_tc=tc;bad_tc%file_weather_root_parameters%upper_layer_bottom_node=numnod+1
      call bad_app%initialize(bad_tc,st)
      call require(st/=FMR_APP_BOOT_OK.and..not.bad_app%ready(),'invalid wet stress layer rejects before initialization')
    end if
    do j=1,2
      maximum_residual=0;total_reduction=0;stress_cases=0
      call ta%initialize''')
    replace('          call ta%run_weather_interval(wr,real(d,real64)+real(q,real64)/64.0_real64,', '''          if(wet)call oxygen_segment_oracle(ta,cs,tc,wr,expected_rate,neutral_rate)
          call ta%run_weather_interval(wr,real(d,real64)+real(q,real64)/64.0_real64,''')
    replace('          uptake=uptake+rr(1)%actual_transpiration_amount', '''          if(wet)then
            call require(abs(rr(1)%actual_transpiration_amount-expected_rate/64.0_real64)<=1.e-13_real64, &
              'accepted Full Richards uptake equals literal B111 wet/dry sink integral')
            maximum_residual=max(maximum_residual,abs(rr(1)%mass%residual))
            if(neutral_rate>expected_rate)stress_cases=stress_cases+1
            total_reduction=total_reduction+(neutral_rate-expected_rate)/64.0_real64
          end if
          uptake=uptake+rr(1)%actual_transpiration_amount''')
    replace("      call ta%close(st);call require(st==FMR_APP_BOOT_OK,'close rooted physical application')", '''      if(wet)then
        call require(stress_cases>0.and.total_reduction>0,'physical wet stress has independent OFF discriminator')
        if(j==2)write(*,'(a,i0,a,es24.16,a,es24.16)')'OXYGEN_CYCLE_STRESSED_SEGMENTS=',stress_cases, &
          ' reduction_cm=',total_reduction,' max_mass_residual_cm=',maximum_residual
      end if
      call ta%close(st);call require(st==FMR_APP_BOOT_OK,'close rooted physical application')''')
    replace("  print '(a)', 'CROP_FILE_WEATHER_PRODUCTION=PASS'", "  print '(a)', 'CROP_FILE_WEATHER_PRODUCTION=PASS'\n  print '(a)','CROP_CYCLE_OXYGEN_PHYSICAL_LITERAL_RESTART=PASS'")
    imports='''  use mod_crop_root_uptake_input_contract,only:crop_root_uptake_input_t
  use mod_crop_et_canopy_view_provider,only:crop_et_canopy_state_view_t,crop_et_canopy_forcing_t, &
    crop_et_canopy_view_t,crop_et_canopy_diagnostics_t,evaluate_crop_et_canopy_view
  use mod_reference_et_demand_process,only:reference_et_demand_forcing_t,reference_et_demand_result_t, &
    reference_et_demand_diagnostics_t,evaluate_restricted_reference_et_demand,REF_ET_DEMAND_OK
'''
    # Host already has an inner import for root_input; duplicate host import is valid.
    replace('  implicit none\n',imports+'  implicit none\n')
    replace('\ncontains\n','\ncontains\n'+(Path(__file__).parent/'oxygen_segment_oracle.inc').read_text())
    target.write_text(s)
    return target
