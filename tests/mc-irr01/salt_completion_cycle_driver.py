"""Accepted matrix salt in the existing authentic weather/root/native driver."""
from pathlib import Path
CASES=[('salt_root',3,1,'annual'),('salt_sensor',8,2,'single')]
def salt_cycle(root,target,criterion,dcs,kind):
 from sensor_batch_cycle_driver import sensor_batch
 from batch_activation_cycle_driver import rooted
 (sensor_batch(root,target,criterion,dcs,0.,kind)if criterion==8 else rooted(root,target,criterion,dcs,0.,kind))
 s=target.read_text()
 def replace(a,b,n=1):
  nonlocal s
  assert s.count(a)==n,(a,s.count(a));s=s.replace(a,b)
 replace('  implicit none\n','''  use mod_fmr_runtime_core,only:FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED
  use mod_fmr_serialized_reference_backend,only:fmr_initialize_mobile_salt_profile
  use mod_transaction_reference,only:TX_TEMPORAL_EXTERNAL_FULL_HALF
  implicit none
''')
 # Only the actual tested rooted profile and failure probe receive salt.
 a='    tc%file_weather_irrigation_field_capacity_head_cm=0._real64'
 extra='''
    tc%tiles(1)%template%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED
    tc%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    tc%numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    tc%numerical%transaction%temporal_tolerance=1._real64
    tc%base_salt_temporal_policy%enabled=.true.
    tc%base_salt_temporal_policy%head_tolerance_cm=.01_real64
    tc%base_salt_temporal_policy%water_tolerance_cm=1.e-6_real64
    tc%base_salt_temporal_policy%salt_tolerance_mg_cm2=1.e-7_real64
    tc%base_salt_temporal_policy%temperature_tolerance_c=.01_real64
    call fmr_initialize_mobile_salt_profile(tc%tiles(1)%initial_state,tc%tiles(1)%parameters%dz, &
      spread(2._real64,1,numnod),st)
    call require(st==0,'existing accepted salt initializer')
    allocate(tc%tiles(1)%base_forcing%c_drain_salt,tc%tiles(1)%base_forcing%soil_salt_boundary)
    tc%tiles(1)%base_forcing%c_drain_salt%available=.true.
    tc%tiles(1)%base_forcing%c_drain_salt%source_id=1_int64
    tc%tiles(1)%base_forcing%c_drain_salt%revision=0_int64
    tc%tiles(1)%base_forcing%c_drain_salt%unit_id=1
    tc%tiles(1)%base_forcing%c_drain_salt%valid_t0=0._real64
    tc%tiles(1)%base_forcing%c_drain_salt%valid_t1=11._real64
    tc%tiles(1)%base_forcing%c_drain_salt%concentration_mg_cm3=2._real64
    tc%tiles(1)%base_forcing%soil_salt_boundary%available=.true.
    tc%tiles(1)%base_forcing%soil_salt_boundary%source_id=1_int64
    tc%tiles(1)%base_forcing%soil_salt_boundary%revision=0_int64
    tc%tiles(1)%base_forcing%soil_salt_boundary%unit_id=1
    tc%tiles(1)%base_forcing%soil_salt_boundary%valid_t0=0._real64
    tc%tiles(1)%base_forcing%soil_salt_boundary%valid_t1=11._real64
    tc%tiles(1)%base_forcing%soil_salt_boundary%matrix_top_mg_cm3=0._real64
    tc%tiles(1)%base_forcing%soil_salt_boundary%matrix_bottom_mg_cm3=0._real64
    tc%file_weather_irrigation_sensor%salinity_excess_enabled=.true.
    tc%file_weather_irrigation_sensor%salinity_threshold=1._real64
    tc%file_weather_irrigation_sensor%salinity_excess_percent=50._real64
'''
 # Parameter exact names reconciled below.
 replace(a,a+extra,2)
 # Salt carrier/config identity is independently discriminating after native
 # restore, even with recomputed CRC and otherwise unchanged weather input.
 a="      call read_weather_irrigation_joint_restart_file(trim(native_path),tc,native_record,native_previous,saved,st)"
 b="""      if(trim(continuation_mode)=='native-reject-salt-policy')tc%base_salt_temporal_policy%salt_tolerance_mg_cm2=2.e-7_real64
      if(trim(continuation_mode)=='native-reject-salt-boundary')tc%tiles(1)%base_forcing%c_drain_salt%concentration_mg_cm3=3._real64
      if(trim(continuation_mode)=='native-reject-salt-threshold')tc%file_weather_irrigation_sensor%salinity_threshold=2._real64
      if(trim(continuation_mode)=='native-reject-salt-tscf')tc%tiles(1)%parameters%solute_tscf=.5_real64
"""+a
 replace(a,b)
 # Same accepted dynamic CML as literal historical cml(nodsen), with exact
 # source operation after LIMIT and before availability/rate.
 start=s.index('  subroutine literal_irrigation_selection(');end=s.index('  end subroutine',start)
 sub=s[start:end]
 sub=sub.replace('type is(fmr_b110_temporal_indicator_state_t)','class is(fmr_b110_physical_state_t)')
 # collapse old duplicate physical type selector in root integration.
 sub=sub.replace('''      type is(fmr_b110_physical_state_t)
        theta=sp%water_content(i)
''','')
 sub+='''    select type(sp)
    class is(fmr_b110_physical_state_t)
      i=config%file_weather_irrigation_sensor%sensor_node
      call require(allocated(sp%salt),'literal CML uses actual accepted salt')
      call require(sp%salt%ready(sp%active_nodes),'accepted salt mass valid')
      if(sp%salt%mass_mg_cm2(i)/(sp%water_content(i)*config%tiles(1)%parameters%dz(i))> &
        config%file_weather_irrigation_sensor%salinity_threshold)depth=depth* &
        (1._real64+.01_real64*config%file_weather_irrigation_sensor%salinity_excess_percent)
    class default
      call require(.false.,'actual salt state missing')
    end select
'''
 s=s[:start]+sub+s[end:]
 # New salt layout uses the original NONE continuation, not Richards history.
 start=s.index('  subroutine print_exact_postimage(');end=s.index('  subroutine initialize_crop(',start)
 sub=s[start:end];sub=sub.replace('type is(fmr_b110_temporal_indicator_state_t)','class is(fmr_b110_physical_state_t)')
 a=sub.index('      call physical%temporal_history_snapshot(');b=sub.index('    class default',a)
 sub=sub[:a]+'''      call require(allocated(physical%salt),'salt endpoint exists')
      do i=1,physical%active_nodes
        write(*,'(a,i0,1x,z16.16)')'SALT_MASS_BITS=',i,transfer(physical%salt%mass_mg_cm2(i),0_int64)
      end do
'''+sub[b:];s=s[:start]+sub+s[end:]
 s=s.replace('SENSOR_BATCH_FULL_SOURCE_MASS_NATIVE=PASS','SALT_COMPLETION_FULL_SOURCE_MASS_NATIVE=PASS').replace('BATCH_ROOT_FULL_ACTIVATION_SOURCE_MASS_NATIVE=PASS','SALT_COMPLETION_FULL_SOURCE_MASS_NATIVE=PASS')
 # Existing snapshot helpers include the complete actual salt state in all
 # failed-trial/replay/opaque comparisons; salt has no history continuation.
 s=s.replace("type is(fmr_b110_temporal_indicator_state_t)","class is(fmr_b110_physical_state_t)")
 s=s.replace("      call physical%temporal_history_snapshot(history,ok);call require(ok,'managed retained numerical history')", "      history=physical%salt%mass_mg_cm2")
 s=s.replace("      call physical%temporal_history_snapshot(history,ok);call require(ok,'actual soil temporal derivative')", "      history=physical%salt%mass_mg_cm2")
 s=s.replace("        call ps%temporal_history_snapshot(derivative,ok);call require(ok,'rooted actual Richards history')", "        derivative=ps%salt%mass_mg_cm2")
 # Authenticated TASK3 arithmetic must retain the source operation order.
 s=s.replace("depth=depth* &\n        (1._real64+.01_real64*config%file_weather_irrigation_sensor%salinity_excess_percent)", "depth=depth+ &\n        .01_real64*config%file_weather_irrigation_sensor%salinity_excess_percent*depth")
 target.write_text(s);return target
