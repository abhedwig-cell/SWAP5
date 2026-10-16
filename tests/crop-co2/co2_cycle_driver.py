"""Add CO2 to the real empirical-oxygen production driver, retain incumbent checks."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'crop-cycle'))
from oxygen_cycle_driver import prepare as oxygen_driver

def prepare(root,target):
 oxygen_driver(root,target)
 s=target.read_text()
 def replace(a,b):
  nonlocal s
  assert s.count(a)==1,(s.count(a),a)
  s=s.replace(a,b)
 replace('  implicit none\n','''  use mod_crop_co2_response_resolver,only:construct_crop_co2_response_parameters,CROP_CO2_RESPONSE_OK
  use mod_crop_atmospheric_co2_forcing,only:construct_crop_atmospheric_co2_forcing,CROP_ATMOSPHERIC_CO2_OK
  implicit none
''')
 replace('    if(wet)then\n      tc%file_weather_root_parameters%empirical_oxygen_enabled=.true.', '''    if(wet)then
      tc%file_weather_co2_response=.true.
      call construct_crop_atmospheric_co2_forcing([1999],[500._real64],tc%file_weather_atmospheric_co2,st)
      call require(st==CROP_ATMOSPHERIC_CO2_OK,'annual authenticated-calendar CO2 forcing')
      call construct_crop_co2_response_parameters( &
        [300._real64,500._real64,900._real64],[.8_real64,1.1_real64,1.4_real64], &
        [350._real64,550._real64,1000._real64],[.9_real64,1.3_real64,1.6_real64], &
        [250._real64,450._real64,800._real64],[1._real64,.9_real64,.7_real64], &
        .true.,tc%file_weather_co2_parameters,st)
      call require(st==CROP_CO2_RESPONSE_OK,'three independent production response tables')
      tc%file_weather_root_parameters%empirical_oxygen_enabled=.true.''')
 replace("    do j=1,2\n      maximum_residual", '''    if(wet)then
      bad_tc=tc;bad_tc%file_weather_rooted=.false.;bad_tc%file_weather_dayend=.false.
      call bad_app%initialize(bad_tc,st)
      call require(st/=FMR_APP_BOOT_OK.and..not.bad_app%ready(),'CO2 cannot silently enable root-free profile')
      bad_tc=tc
      call construct_crop_atmospheric_co2_forcing([1999],[9._real64],bad_tc%file_weather_atmospheric_co2,st)
      call bad_app%initialize(bad_tc,st)
      call require(st/=FMR_APP_BOOT_OK.and..not.bad_app%ready(),'invalid atmospheric forcing rejects initialization')
    end if
    do j=1,2
      maximum_residual''')
 # The independent growth composition shares only the admitted WOFOST81 owner,
 # not the application response resolver. Literal historical factors enter it.
 replace('    integer::iday,st\n    logical::ok\n    call record%values', '    integer::iday,st\n    real(real64)::factors(3)\n    logical::ok\n    call record%values')
 replace('    call begin_wofost_one_day_crop_window(before,forcing,', '''    call source_co2_factors(factors)
    forcing%co2_efficiency_factor=factors(1);forcing%co2_amax_factor=factors(2)
    call begin_wofost_one_day_crop_window(before,forcing,''')
 replace('    call evaluate_crop_et_canopy_view(config%file_weather_canopy_parameters,state,cf,cv,cd)', '''    call source_co2_factors(factors)
    call evaluate_crop_et_canopy_view(config%file_weather_canopy_parameters,state,cf,cv,cd,factors(3))''')
 replace('    real(real64)::day,tmn,tmx,rain,et,limits(8),sink(numnod),neutral(numnod)', '    real(real64)::day,tmn,tmx,rain,et,limits(8),sink(numnod),neutral(numnod),factors(3)')
 # OFF discriminator on the actual same committed crop and accepted soil:
 # rebuild ET without CO2, then source sink. Wet-stress assertion remains.
 replace('    rate=sum(sink);unstressed=sum(neutral)', '''    rate=sum(sink);unstressed=sum(neutral)
    ec%co2_transpiration_factor=1._real64
    call evaluate_restricted_reference_et_demand(forcing_config%reference_et_parameters,ef,ec,er,ed)
    call require(ed%status==REF_ET_DEMAND_OK,'CO2 OFF independent ET discriminator')
    select type(physical)
    class is(fmr_b110_physical_state_t)
      call b111_root_sink(numnod,roots%rooted_nodes,config%file_weather_root_parameters%upper_layer_bottom_node, &
        .true.,physical%pressure_head,er%potential_transpiration_cm_per_day,roots%cumulative_root_fraction,limits,neutral)
    end select
    if(rate>0)call require(sum(neutral)>rate,'CO2 response actually reduces physical accepted uptake demand')''')
 replace('contains\n','''contains
  subroutine source_co2_factors(factors)
    real(real64),intent(out)::factors(3)
    interface
      subroutine b111_co2_response(co2,eff,amax,tra,factors)
        import real64
        real(real64),intent(in)::co2,eff(6),amax(6),tra(6)
        real(real64),intent(out)::factors(3)
      end subroutine
    end interface
    call b111_co2_response(500._real64, &
      [300._real64,.8_real64,500._real64,1.1_real64,900._real64,1.4_real64], &
      [350._real64,.9_real64,550._real64,1.3_real64,1000._real64,1.6_real64], &
      [250._real64,1._real64,450._real64,.9_real64,800._real64,.7_real64],factors)
  end subroutine
''')
 replace("  print '(a)','CROP_CYCLE_OXYGEN_PHYSICAL_LITERAL_RESTART=PASS'", "  print '(a)','CROP_CYCLE_OXYGEN_PHYSICAL_LITERAL_RESTART=PASS'\n  print '(a)','CROP_CO2_PHYSICAL_GROWTH_UPTAKE_RESTART=PASS'")
 target.write_text(s)
 return target
