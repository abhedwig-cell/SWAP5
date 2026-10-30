! Same-platform bounded disk adapter. Existing FMR/kernel restore owns water.
module mod_crop_soil_n_joint_restart_file
  use iso_fortran_env,only:real64,int64,int32,int8,iostat_end
  use mod_wofost_crop_native_codec,only:weather_native_event,weather_native_biomass,weather_native_owner,weather_native_crop_view
  use ieee_arithmetic,only:ieee_is_finite
  use mod_transaction_reference,only:transaction_state_t
  use mod_kernel_transactions,only:kernel_committed_state_t,kernel_parameter_identity_t, &
       kernel_reconstruct_committed_state_trusted
  use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
  use mod_fmr_serialized_reference_backend,only:fmr_b110_physical_state_t,fmr_b110_temporal_indicator_state_t, &
       fmr_new_b110_temporal_indicator_committed_state,fmr_b110_physical_parameters_t
  use mod_soil_temperature_contract,only:soil_temperature_field_view_t,build_soil_temperature_field_view, &
       initialize_soil_temperature_state,SOIL_TEMP_OK
  use mod_fmr_crop_soil_n_thermal_application,only:thermal_crop_soil_states_match,soil_n_thermal_template
  use mod_fmr_committed_restart,only:fmr_committed_restart_bundle_t,fmr_export_committed_restart, &
       fmr_restore_committed_restart,FMR_RESTART_OK
  use mod_b111_soil_n_reactive_owner
  use mod_b111_soil_n_mineral_owner,only:MINERAL_OK
  use mod_soil_n_pool_state,only:soil_n_pool_state_t
  use mod_fmr_b111_reactive_n_joint_application,only:reactive_n_joint_states_match,reactive_n_thermal_states_match
  use mod_fmr_crop_soil_n_joint_application,only:crop_soil_n_joint_states_match,JOINT_OK,JOINT_INVALID
  use mod_crop_soil_n_day
  use mod_crop_soil_n_configuration
  use mod_wofost81_crop_owner_state,only:wofost81_crop_owner_state_t
  use mod_crop_senescence_residue,only:crop_residue_pending_t
  use mod_crop_soil_n_senescence_day,only:pending_incorporation_valid
  use mod_fmr_production_application_bootstrap,only:fmr_weather_crop_application_continuation_t, &
    fmr_weather_crop_native_view_t,fmr_production_application_config_t,export_weather_crop_native_view, &
    reconstruct_weather_crop_native_view,FMR_APP_BOOT_OK
  use mod_kernel_committed_persistence,only:kernel_persistence_snapshot_t,export_kernel_committed_state, &
    restore_kernel_committed_state,KERNEL_PERSISTENCE_OK
  use mod_fmr_wofost_crop_transaction,only:fmr_wofost_crop_transaction_persistence_t,fmr_wofost_crop_transaction_state_t, &
    export_fmr_wofost_crop_transaction_persistence,reconstruct_fmr_wofost_crop_transaction_from_persistence
  use mod_fmr_wofost_accepted_window_lineage,only:fmr_wofost_window_persistence_t, &
    fmr_wofost_crop_event_identity_persistence_t,export_wofost_window_persistence,reconstruct_wofost_window_persistence, &
    export_wofost_crop_event_identity_persistence,reconstruct_wofost_crop_event_identity_from_persistence
  use mod_crop_weather_day_owner,only:reconstruct_weather_day_owner
  use mod_swap_daily_weather_file_adapter,only:swap_daily_weather_record_t
  use mod_wofost_crop_owner_state,only:classic_owner_t=>wofost_crop_owner_state_t
  use mod_wofost_actual_biomass_state,only:classic_biomass_t=>wofost_actual_biomass_state_t
  implicit none
  private
  character(8),parameter::MAGIC='S5NC0001',PENDING_MAGIC='S5NC0002'
  character(8),parameter::HEAT_MAGIC='S5NC0003',HEAT_PENDING_MAGIC='S5NC0004'
  character(8),parameter::HARVEST_MAGIC='S5NC0005',HARVEST_PENDING_MAGIC='S5NC0006'
  character(8),parameter::HEAT_HARVEST_MAGIC='S5NC0007',HEAT_HARVEST_PENDING_MAGIC='S5NC0008'
  integer,parameter::MAX_BYTES=10485760
  public::write_crop_soil_n_joint_restart_file,read_crop_soil_n_joint_restart_file
  public::write_weather_irrigation_joint_restart_file,read_weather_irrigation_joint_restart_file

contains
  function base_tag(tag)result(base)
    character(8),intent(in)::tag
    character(8)::base
    base=tag
    select case(tag)
    case('S5NC0009');base=MAGIC
    case('S5NC0010');base=PENDING_MAGIC
    case('S5NC0011');base=HEAT_MAGIC
    case('S5NC0012');base=HEAT_PENDING_MAGIC
    case('S5NC0013');base=HARVEST_MAGIC
    case('S5NC0014');base=HARVEST_PENDING_MAGIC
    case('S5NC0015');base=HEAT_HARVEST_MAGIC
    case('S5NC0016');base=HEAT_HARVEST_PENDING_MAGIC
    end select
  end function
  logical function b112_tag(tag)result(selected)
    character(8),intent(in)::tag
    selected=base_tag(tag)/=tag
  end function
  function encode_b112_tag(tag)result(selected)
    character(8),intent(in)::tag
    character(8)::selected
    integer::number,io
    read(tag(5:8),*,iostat=io)number
    selected='INVALID!'
    if(io/=0)return
    if(number<1.or.number>8)return
    write(selected,'("S5NC",I4.4)')number+8
  end function
  logical function pending_tag(tag)result(pending)
    character(8),intent(in)::tag
    pending=base_tag(tag)==PENDING_MAGIC.or.base_tag(tag)==HEAT_PENDING_MAGIC.or.base_tag(tag)==HARVEST_PENDING_MAGIC.or.base_tag(tag)==HEAT_HARVEST_PENDING_MAGIC
  end function
  logical function thermal_tag(tag)result(thermal)
    character(8),intent(in)::tag
    thermal=base_tag(tag)==HEAT_MAGIC.or.base_tag(tag)==HEAT_PENDING_MAGIC.or.base_tag(tag)==HEAT_HARVEST_MAGIC.or.base_tag(tag)==HEAT_HARVEST_PENDING_MAGIC
  end function
  logical function harvest_tag(tag)result(harvest)
    character(8),intent(in)::tag
    harvest=base_tag(tag)==HARVEST_MAGIC.or.base_tag(tag)==HARVEST_PENDING_MAGIC.or.base_tag(tag)==HEAT_HARVEST_MAGIC.or.base_tag(tag)==HEAT_HARVEST_PENDING_MAGIC
  end function
  subroutine write_crop_soil_n_joint_restart_file(path,column,template,water_parameter_id,water,coupled,status)
    character(*),intent(in)::path
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    integer(int64),intent(in)::water_parameter_id
    type(kernel_committed_state_t),intent(in)::water
    type(crop_soil_state_t),intent(in)::coupled
    type(reactive_state_t)::chemical
    type(wofost81_crop_owner_state_t)::crop
    type(crop_n_configuration_t)::cp
    real(real64),allocatable::cv(:),ov(:)
    integer(int64)::crop_id
    integer,intent(out)::status
    type(fmr_committed_restart_bundle_t)::b
    type(reactive_parameters_t)::p
    type(soil_n_pool_state_t)::s
    real(real64),allocatable::v(:),derivative(:)
    real(real64)::theta
    real(real64)::time
    integer(int64)::id,revision
    integer::u,io,mode,n
    type(crop_residue_pending_t)::pending
    logical::has_pending
    character(8)::tag
    logical::ok,has_history
    logical::thermal
    type(kernel_parameter_identity_t)::identity
    type(soil_temperature_field_view_t)::heat
    status=JOINT_INVALID
    if(column%state_handle/=1)return
    if(.not.pending_incorporation_valid(coupled))return
    call coupled%pending_snapshot(pending,has_pending)
    tag=MAGIC;if(has_pending)tag=PENDING_MAGIC
    thermal=soil_n_thermal_template(template)
    if(thermal)then
      if(.not.thermal_crop_soil_states_match(water,coupled))return
      call water%certified_parameter_identity(identity,ok);if(.not.ok)return
      tag=HEAT_MAGIC;if(has_pending)tag=HEAT_PENDING_MAGIC
    else
      if(.not.crop_soil_n_joint_states_match(water,coupled))return
    end if
    call coupled%snapshot(chemical,crop);call coupled%configuration(cp,crop_id)
    if(crop%harvested())then
      tag=HARVEST_MAGIC;if(has_pending)tag=HARVEST_PENDING_MAGIC
      if(thermal)then
        tag=HEAT_HARVEST_MAGIC;if(has_pending)tag=HEAT_HARVEST_PENDING_MAGIC
      end if
    end if
    if(allocated(cp%b112_return))tag=encode_b112_tag(tag)
    cv=crop_n_configuration_vector(cp);ov=pack_crop_n_continuation(crop)
    if(size(cv)==0.or.size(ov)==0)return
    call fmr_export_committed_restart([column],[template],[water],water_parameter_id,b,ok,io)
    if(.not.ok.or.io/=FMR_RESTART_OK)return
    call chemical%configuration(p,id);v=reactive_parameter_vector(p)
    if(.not.allocated(v))return
    call chemical%snapshot(time,theta,s,revision)
    n=size(p%mineral%dz_cm);mode=-1;has_history=.false.
    select type(q=>b%records(1)%physical_state)
    type is(fmr_b110_physical_state_t)
      mode=0;allocate(derivative(0))
    type is(fmr_b110_temporal_indicator_state_t)
      mode=1;call q%temporal_history_snapshot(derivative,has_history)
      if(.not.has_history)then
        if(allocated(derivative))deallocate(derivative)
        allocate(derivative(0))
      end if
    end select
    if(mode<0)return
    open(newunit=u,file=path,access='stream',form='unformatted',status='replace',iostat=io)
    if(io/=0)return
    writing: block
      associate(r=>b%records(1))
        write(u,iostat=io)tag,b%schema_version,b%parameter_set_identity, &
             r%schema_version,r%kernel_schema_version,r%column_id,r%parameter_ref,r%forcing_handle, &
             r%template_identity,r%lineage_id,r%revision,r%committed_time,r%time_bound, &
             mode,n,has_history
        if(io/=0)exit writing
        select type(q=>r%physical_state)
        class is(fmr_b110_physical_state_t)
          write(u,iostat=io)q%pressure_head,q%water_content,q%ponding_depth,q%groundwater_level
        end select
        if(io/=0)exit writing
        if(has_history)write(u,iostat=io)derivative
        if(io/=0)exit writing
        if(thermal)then
          select type(q=>r%physical_state)
          class is(fmr_b110_physical_state_t)
            call build_soil_temperature_field_view(q%soil_temperature,heat,io)
          end select
          if(io/=SOIL_TEMP_OK)exit writing
          write(u,iostat=io)identity%parameter_set_id,identity%active_nodes,identity%heat_enabled,identity%valid, &
            identity%z,identity%dz,heat%temperature_c
          if(io/=0)exit writing
        end if
        write(u,iostat=io)id,revision,time,size(v),v,theta,s%fom_kg_m3,s%biomass_kg_m3,s%humus_kg_m3,s%ammonium_n_kg_m2,s%nitrate_n_kg_m2
        if(io/=0)exit writing
        write(u,iostat=io)crop_id,size(cv),cv,size(ov),ov
        if(io/=0)exit writing
        if(has_pending)write(u,iostat=io)pending%clock,pending%dry_matter_kg_ha,pending%nitrogen_kg_ha,pending%application_age
      end associate
    end block writing
    close(u)
    if(io/=0)return
    call append_crc(path,io)
    if(io==0)status=JOINT_OK
  end subroutine

  subroutine read_crop_soil_n_joint_restart_file(path,column,template,water_parameter_id,chemical_parameter_id,crop_parameter_id,p,cp, &
       water,coupled,status,heat_parameters)
    character(*),intent(in)::path
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    integer(int64),intent(in)::water_parameter_id,chemical_parameter_id,crop_parameter_id
    type(crop_n_configuration_t),intent(in)::cp
    type(reactive_parameters_t),intent(in)::p
    type(kernel_committed_state_t),intent(inout)::water
    type(crop_soil_state_t),intent(inout)::coupled
    type(fmr_b110_physical_parameters_t),intent(in),optional::heat_parameters
    type(crop_soil_state_t)::coupled_trial
    type(wofost81_crop_owner_state_t)::crop_trial
    real(real64),allocatable::cv(:),ov(:),crop_expected(:)
    integer(int64)::crop_id
    integer,intent(out)::status
    type(fmr_committed_restart_bundle_t)::b
    type(kernel_committed_state_t)::temporary,water_trial(1)
    type(fmr_b110_physical_state_t)::physical
    type(reactive_state_t)::chemical_trial
    real(real64),allocatable::derivative(:),v(:),expected(:)
    real(real64)::theta
    type(soil_n_pool_state_t)::s
    real(real64)::time
    integer(int64)::id,revision
    integer(int32)::checksum
    integer::u,io,mode,n,count
    integer(int8)::extra
    type(crop_residue_pending_t)::pending
    character(8)::tag
    logical::ok,has_history
    logical::thermal
    type(kernel_parameter_identity_t)::identity
    real(real64),allocatable::temperatures(:)
    type(kernel_committed_state_t)::certified_water
    status=JOINT_INVALID
    if(column%state_handle/=1)return
    if(water%ready())return
    if(coupled%ready())return
    crop_expected=crop_n_configuration_vector(cp)
    if(size(crop_expected)==0)return
    if(.not.all(ieee_is_finite(crop_expected)))return
    if(.not.reactive_parameters_valid(p))return
    expected=reactive_parameter_vector(p)
    if(.not.allocated(expected))return
    if(.not.all(ieee_is_finite(expected)))return
    call check_crc(path,io)
    if(io/=0)return
    open(newunit=u,file=path,access='stream',form='unformatted',status='old',iostat=io)
    if(io/=0)return
    allocate(b%records(1))
    ! All decoding remains tentative. Every exit reaches the common close.
    decoding: block
      associate(r=>b%records(1))
        read(u,iostat=io)tag,b%schema_version,b%parameter_set_identity, &
             r%schema_version,r%kernel_schema_version,r%column_id,r%parameter_ref,r%forcing_handle, &
             r%template_identity,r%lineage_id,r%revision,r%committed_time,r%time_bound, &
             mode,n,has_history
        if(io/=0)exit decoding
        io=1
        thermal=thermal_tag(tag)
        if(b112_tag(tag).neqv.allocated(cp%b112_return))exit decoding
        if((base_tag(tag)/=MAGIC.and.base_tag(tag)/=PENDING_MAGIC.and..not.thermal.and..not.harvest_tag(tag)).or. &
          n/=size(p%mineral%dz_cm).or.n<1.or.(mode/=0.and.mode/=1))exit decoding
        if(thermal.neqv.soil_n_thermal_template(template))exit decoding
        if(thermal.and..not.present(heat_parameters))exit decoding
        if(mode==0.and.has_history)exit decoding
        physical%active_nodes=n
        allocate(physical%pressure_head(n),physical%water_content(n),s%fom_kg_m3(size(p%mineral%inventory%nfrac_fom)))
        read(u,iostat=io)physical%pressure_head,physical%water_content,physical%ponding_depth,physical%groundwater_level
        if(io/=0)exit decoding
        if(has_history)then
          allocate(derivative(n));read(u,iostat=io)derivative
          if(io/=0)exit decoding
          io=1
          if(.not.all(ieee_is_finite(derivative)))exit decoding
        end if
        if(thermal)then
          allocate(identity%z(n),identity%dz(n),temperatures(n))
          read(u,iostat=io)identity%parameter_set_id,identity%active_nodes,identity%heat_enabled,identity%valid, &
            identity%z,identity%dz,temperatures
          if(io/=0)exit decoding
          io=1
          if(identity%active_nodes/=n.or..not.identity%heat_enabled.or..not.identity%valid)exit decoding
          if(.not.all(ieee_is_finite(identity%z)).or..not.all(ieee_is_finite(identity%dz)))exit decoding
          allocate(physical%soil_temperature)
          call initialize_soil_temperature_state(temperatures,physical%soil_temperature,io)
          if(io/=SOIL_TEMP_OK)exit decoding
        end if
        if(mode==1)then
          if(has_history)then
            call fmr_new_b110_temporal_indicator_committed_state(temporary,1_int64,physical,0.0_real64,ok,derivative)
          else
            call fmr_new_b110_temporal_indicator_committed_state(temporary,1_int64,physical,0.0_real64,ok)
          end if
          io=1
          if(.not.ok)exit decoding
          call temporary%snapshot(r%physical_state,ok)
          if(.not.ok)exit decoding
        else
          allocate(r%physical_state,source=physical)
        end if
        read(u,iostat=io)id,revision,time,count
        if(io/=0)exit decoding
        io=1
        if(id/=chemical_parameter_id.or.count/=size(expected))exit decoding
        allocate(v(count));read(u,iostat=io)v,theta,s%fom_kg_m3,s%biomass_kg_m3,s%humus_kg_m3,s%ammonium_n_kg_m2,s%nitrate_n_kg_m2
        if(io/=0)exit decoding
        read(u,iostat=io)crop_id,count
        if(io/=0)exit decoding
        io=1
        if(crop_id/=crop_parameter_id.or.count/=size(crop_expected))exit decoding
        allocate(cv(count));read(u,iostat=io)cv,count
        if(io/=0)exit decoding
        io=1
        if(.not.all(ieee_is_finite(cv)))exit decoding
        if(any(abs(cv-crop_expected)>0d0).or.count<9.or.count>2048)exit decoding
        allocate(ov(count));read(u,iostat=io)ov
        if(io/=0)exit decoding
        if(pending_tag(tag))then
          read(u,iostat=io)pending%clock,pending%dry_matter_kg_ha,pending%nitrogen_kg_ha,pending%application_age
          if(io/=0)exit decoding
        end if
        read(u,iostat=io)checksum
        if(io/=0)exit decoding
        call unpack_crop_n_continuation(ov,crop_trial,io)
        if(io/=CROP_SOIL_OK)exit decoding
        io=1
        if(crop_trial%nitrogen%b112_residue_profile.neqv.b112_tag(tag))exit decoding
        if(crop_trial%harvested().neqv.harvest_tag(tag))exit decoding
        if(.not.all(ieee_is_finite(v)))exit decoding
        if(any(abs(v-expected)>0.0_real64))exit decoding
        read(u,iostat=io)extra
        if(io/=iostat_end)then
          io=1;exit decoding
        end if
        call fmr_restore_committed_restart(b,water_parameter_id,[column],[template],water_trial,ok,io)
        if(.not.ok.or.io/=FMR_RESTART_OK)then
          io=1;exit decoding
        end if
        if(thermal)then
          call kernel_reconstruct_committed_state_trusted(certified_water,r%lineage_id,r%revision,r%physical_state, &
            r%committed_time,r%time_bound,ok,io,heat_parameters,identity)
          if(.not.ok.or.io/=0)then
            io=1;exit decoding
          end if
          water_trial(1)=certified_water
        end if
        call reconstruct_reactive_trusted(p,id,revision,time,theta,s,chemical_trial,io)
        if(io/=MINERAL_OK)exit decoding
        io=1
        if(thermal)then
          if(.not.reactive_n_thermal_states_match(water_trial(1),chemical_trial))exit decoding
        else
          if(.not.reactive_n_joint_states_match(water_trial(1),chemical_trial))exit decoding
        end if
        io=0
      end associate
    end block decoding
    close(u)
    if(io/=0)return
    if(pending_tag(tag))then
      call initialize_crop_soil(chemical_trial,crop_trial,cp,crop_parameter_id,coupled_trial,io,pending)
    else
      call initialize_crop_soil(chemical_trial,crop_trial,cp,crop_parameter_id,coupled_trial,io)
    end if
    if(io/=CROP_SOIL_OK)return
    if(thermal)then
      if(.not.thermal_crop_soil_states_match(water_trial(1),coupled_trial))return
    else
      if(.not.crop_soil_n_joint_states_match(water_trial(1),coupled_trial))return
    end if
    if(.not.pending_incorporation_valid(coupled_trial))return
    water=water_trial(1);coupled=coupled_trial;status=JOINT_OK
  end subroutine

  ! Additional tag in this existing CRC-protected same-platform native
  ! adapter. Parameter IDs/expected configuration remain caller authority,
  ! just as for the existing water/crop-N tags. No second codec or owner.
  subroutine write_weather_irrigation_joint_restart_file(path,bundle,status)
    character(*),intent(in)::path
    type(fmr_weather_crop_application_continuation_t),intent(in)::bundle
    integer,intent(out)::status
    type(fmr_weather_crop_native_view_t)::v
    type(fmr_weather_crop_application_continuation_t)::checked
    type(swap_daily_weather_record_t)::record,previous
    integer::u,io,st
    status=1
    call export_weather_crop_native_view(bundle,v,st);if(st/=FMR_APP_BOOT_OK)return
    call reconstruct_weather_crop_native_view(v,checked,st);if(st/=FMR_APP_BOOT_OK)return
    if(.not.weather_native_profile(v%configuration))return
    record=v%record;previous=v%previous_record
    open(newunit=u,file=path,access='stream',form='unformatted',status='replace',iostat=io)
    if(io/=0)return
    write(u,iostat=io)'S5WI0001'
    if(io==0)call weather_native_payload(u,.false.,v,record,previous,io)
    close(u)
    if(io/=0)return
    call append_crc(path,status)
  end subroutine

  subroutine read_weather_irrigation_joint_restart_file(path,configuration,record,previous,bundle,status)
    character(*),intent(in)::path
    type(fmr_production_application_config_t),intent(in)::configuration
    type(swap_daily_weather_record_t),intent(in)::record,previous
    type(fmr_weather_crop_application_continuation_t),intent(out)::bundle
    integer,intent(out)::status
    type(fmr_weather_crop_native_view_t)::v
    character(8)::tag
    integer(int32)::checksum
    integer(int8)::extra
    integer::u,io
    bundle=fmr_weather_crop_application_continuation_t();status=1
    if(.not.weather_native_profile(configuration))return
    call check_crc(path,io);if(io/=0)return
    v%configuration=configuration;v%record=record;v%previous_record=previous
    open(newunit=u,file=path,access='stream',form='unformatted',status='old',action='read',iostat=io)
    if(io/=0)return
    read(u,iostat=io)tag
    if(io==0.and.tag=='S5WI0001')then
      call weather_native_payload(u,.true.,v,record,previous,io)
      if(io==0)read(u,iostat=io)checksum
      if(io==0)then
        read(u,iostat=io)extra
        if(io==iostat_end)then
          call reconstruct_weather_crop_native_view(v,bundle,io)
        else
          io=1
        end if
      end if
    else
      io=1
    end if
    close(u)
    if(io==FMR_APP_BOOT_OK)status=0
  end subroutine

  logical function weather_native_profile(c)result(ok)
    type(fmr_production_application_config_t),intent(in)::c
    ok=.false.
    if(.not.allocated(c%tiles))return
    if(size(c%tiles)/=1)return
    ! Reuse the existing managed profiles; selector admission stays with
    ! the bootstrap. The payload/CRC and parameter/source bindings are shared.
    if(.not.c%file_weather_irrigation)return
    if(c%file_weather_rooted)then
      if(c%file_weather_root_depth_mode/=2)return
    else
      if(c%file_weather_irrigation_sensor%timing_criterion<7.or. &
         c%file_weather_irrigation_depth%depth_criterion/=2)return
    end if
    if(c%file_weather_co2_response.or.c%file_weather_daily_demand.or.c%file_weather_swrain/=0)return
    if(c%explicit_pmdirect_interception.or.c%base_salt_temporal_policy%enabled)return
    select case(c%file_weather_irrigation_sensor%timing_criterion)
    case(2:4,6:8)
    case default
      return
    end select
    if(c%tiles(1)%parameters%bottom_mode/=7)return
    if(c%tiles(1)%template%solute_state_layout_id/=0_int64)return
    ok=.true.
  end function

  subroutine weather_native_payload(u,reading,v,record,previous,io)
    integer,intent(in)::u
    logical,intent(in)::reading
    type(fmr_weather_crop_native_view_t),intent(inout)::v
    type(swap_daily_weather_record_t),intent(in)::record,previous
    integer,intent(out)::io
    type(fmr_wofost_window_persistence_t)::current,prior
    integer(int64)::source,epoch,revision
    real(real64)::day,tmin,tmax
    logical::ok
    integer::st
    io=0
    call weather_native_config(u,reading,v%configuration,io);if(io/=0)return
    call weather_native_record(u,reading,record,io);if(io/=0)return
    call weather_native_record(u,reading,previous,io);if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%initial_crop_daystart_committed,v%irrigation_schema,v%irrigation_selection_day, &
        v%irrigation_time,v%irrigation_delivered_cm,v%irrigation,v%weather_revision,v%crop_lineage,v%crop_revision, &
        source,epoch,revision,day,tmin,tmax
      if(io/=0)return
      call reconstruct_weather_day_owner(v%weather,source,epoch,revision,day,tmin,tmax,st)
      if(st/=0)then;io=1;return;end if
    else
      call v%weather%snapshot(source,epoch,revision,day,tmin,tmax,ok)
      if(.not.ok)then;io=1;return;end if
      write(u,iostat=io)v%initial_crop_daystart_committed,v%irrigation_schema,v%irrigation_selection_day, &
        v%irrigation_time,v%irrigation_delivered_cm,v%irrigation,v%weather_revision,v%crop_lineage,v%crop_revision, &
        source,epoch,revision,day,tmin,tmax
    end if
    if(io/=0)return
    call weather_native_soil(u,reading,v%soil,v%configuration,io);if(io/=0)return
    call weather_native_crop(u,reading,v%crop,io);if(io/=0)return
    if(.not.reading)then
      call export_wofost_window_persistence(v%current_window,current,st);if(st/=0)then;io=1;return;end if
      call export_wofost_window_persistence(v%previous_window,prior,st);if(st/=0)then;io=1;return;end if
    end if
    call weather_native_window(u,reading,current,io);if(io/=0)return
    call weather_native_window(u,reading,prior,io);if(io/=0)return
    if(reading)then
      call reconstruct_wofost_window_persistence(current,v%current_window,st);if(st/=0)then;io=1;return;end if
      call reconstruct_wofost_window_persistence(prior,v%previous_window,st);if(st/=0)then;io=1;return;end if
    end if
    v%valid=.true.
  end subroutine

  ! Bind native restart to immutable forcing bytes using the existing reader.
  ! The decoder can compare these bytes but cannot manufacture a valid record.
  subroutine weather_native_record(u,reading,record,io)
    integer,intent(in)::u
    logical,intent(in)::reading
    type(swap_daily_weather_record_t),intent(in)::record
    integer,intent(out)::io
    character(:),allocatable::expected,bytes
    integer::day,stored_day,n
    logical::ok,stored
    call record%source_identity(expected,day,ok);io=0
    stored=ok;n=len(expected);stored_day=day
    if(reading)then
      read(u,iostat=io)stored,stored_day,n
      if(io/=0)return
      if((stored.neqv.ok).or.stored_day/=day.or.n/=len(expected).or.n<0.or.n>MAX_BYTES)then;io=1;return;end if
      allocate(character(n)::bytes)
      if(n>0)read(u,iostat=io)bytes
      if(io/=0)return
      if(bytes/=expected)io=1
    else
      write(u,iostat=io)stored,stored_day,n
      if(io==0.and.n>0)write(u,iostat=io)expected
    end if
  end subroutine

  ! Parameter IDs retain their existing immutable-parameter meaning. Bind
  ! additionally all weekly/root policy and numerical choices consumed here.
  subroutine weather_native_config(u,reading,c,io)
    integer,intent(in)::u
    logical,intent(in)::reading
    type(fmr_production_application_config_t),intent(in)::c
    integer,intent(out)::io
    integer::scratch,n
    real(real64),allocatable::x(:),y(:),values(:)
    logical::ok
    integer(int8),allocatable::expected(:),stored(:)
    associate(p=>c%tiles(1)%parameters,t=>c%tiles(1)%template)
    open(newunit=scratch,status='scratch',access='stream',form='unformatted',iostat=io)
    if(io/=0)return
    write(scratch,iostat=io)c%file_weather_epoch_day,c%initial_time,c%numerical, &
      p%parameter_set_id,t,c%file_weather_daystart,c%file_weather_dayend, &
      c%file_weather_rooted,c%file_weather_root_depth_mode,c%file_weather_adaptive_root_profile, &
      c%file_weather_swrd2_parameters,c%file_weather_root_parameters, &
      c%file_weather_latitude,c%file_weather_emergence_dry_weight,c%file_weather_maximum_root_depth_cm, &
      c%file_weather_stem_area_coefficient,c%file_weather_storage_area_coefficient, &
      c%file_weather_irrigation_sensor, &
      c%file_weather_irrigation_depth%timing_criterion,c%file_weather_irrigation_depth%depth_criterion, &
      c%file_weather_irrigation_depth%tcs2_knot_count,c%file_weather_irrigation_depth%tcs2_dvs, &
      c%file_weather_irrigation_depth%tcs2_fraction,c%file_weather_irrigation_depth%tcs3_knot_count, &
      c%file_weather_irrigation_depth%tcs3_dvs,c%file_weather_irrigation_depth%tcs3_fraction, &
      c%file_weather_irrigation_depth%tcs4_knot_count,c%file_weather_irrigation_depth%tcs4_dvs, &
      c%file_weather_irrigation_depth%tcs4_depletion_mm,c%file_weather_irrigation_depth%tcs6_threshold_mm, &
      c%file_weather_irrigation_depth%dcs1_knot_count,c%file_weather_irrigation_depth%dcs1_dvs, &
      c%file_weather_irrigation_depth%dcs1_adjustment_mm,c%file_weather_irrigation_depth%dcs2_knot_count, &
      c%file_weather_irrigation_depth%dcs2_dvs,c%file_weather_irrigation_depth%dcs2_depth_cm, &
      c%file_weather_irrigation_depth%rainfall_threshold_cm,c%file_weather_irrigation_depth%depth_limit_enabled, &
      c%file_weather_irrigation_depth%minimum_depth_cm,c%file_weather_irrigation_depth%maximum_depth_cm, &
      c%file_weather_irrigation_field_capacity_head_cm, &
      p%active_nodes,p%z,p%dz,p%node_distance,p%cofgen,p%soil_temperature_active
    if(io/=0)then;close(scratch);return;end if
    ! Keep the original native byte contract exactly for disabled TCSFIX.
    ! Bind enabled options as an extension within this existing config block.
    ! The expected config is caller-owned; mismatched extension/domain fails
    ! before any reconstructed owner is published. No second codec or tag.
    if(c%file_weather_irrigation_depth%fixed_interval_enabled)then
      write(scratch,iostat=io)'TCSFIX01',c%file_weather_irrigation_depth%fixed_interval_days
      if(io/=0)then;close(scratch);return;end if
    end if
    if(c%file_weather_irrigation_historical_activation)then
      write(scratch,iostat=io)'IRRWIN01',c%file_weather_irrigation_schedule_enabled, &
        c%file_weather_irrigation_startirr,c%file_weather_irrigation_endirr
      if(io/=0)then;close(scratch);return;end if
      call c%file_weather_irrigation_crop_calendar%snapshot_periods(x,y,ok)
      write(scratch,iostat=io)ok,size(x),x,y
      if(io/=0)then;close(scratch);return;end if
    end if
    call c%file_weather_root_depth%snapshot_values(x,y,ok)
    write(scratch,iostat=io)ok,size(x),x,y
    if(io/=0)then;close(scratch);return;end if
    call c%file_weather_root_density%snapshot_values(x,y,ok)
    write(scratch,iostat=io)ok,size(x),x,y
    if(io/=0)then;close(scratch);return;end if
    call c%file_weather_canopy_parameters%configuration_values(values,ok)
    write(scratch,iostat=io)ok,size(values),values
    if(io/=0)then;close(scratch);return;end if
    if(c%file_weather_adaptive_root_profile)then
      call c%file_weather_root_profile%initial_density%snapshot_values(x,y,ok)
      write(scratch,iostat=io)c%file_weather_root_profile%adaptation,c%file_weather_root_profile%maximum_root_depth_cm, &
        c%file_weather_root_profile%ztop_cm,c%file_weather_root_profile%zbot_cm,c%file_weather_root_profile%dz_cm, &
        ok,size(x),x,y
      if(io/=0)then;close(scratch);return;end if
    end if
    inquire(unit=scratch,size=n);allocate(expected(n),stored(n))
    read(scratch,pos=1,iostat=io)expected;close(scratch)
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)stored
      if(io==0)then
        if(any(stored/=expected))io=1
      end if
    else
      write(u,iostat=io)expected
    end if
    end associate
  end subroutine

  subroutine weather_native_soil(u,reading,snapshot,c,io)
    integer,intent(in)::u
    logical,intent(in)::reading
    type(kernel_persistence_snapshot_t),intent(inout)::snapshot
    type(fmr_production_application_config_t),intent(in)::c
    integer,intent(out)::io
    type(kernel_committed_state_t)::water,temporary
    type(fmr_b110_physical_state_t)::physical
    class(transaction_state_t),allocatable::state
    type(kernel_parameter_identity_t)::identity
    type(soil_temperature_field_view_t)::heat
    real(real64),allocatable::derivative(:),temperatures(:)
    integer(int64)::layout,lineage,revision
    real(real64)::time
    logical::ok,bound,history,thermal
    integer::n,st
    io=1
    if(.not.reading)then
      call restore_kernel_committed_state(snapshot,c%tiles(1)%template%template_id,water,ok,st)
      if(.not.ok.or.st/=0)return
      call water%certified_parameter_identity(identity,ok);if(.not.ok)return
      call snapshot%snapshot_physical(state,ok);if(.not.ok)return
      select type(state)
      type is(fmr_b110_temporal_indicator_state_t)
        physical=state%fmr_b110_physical_state_t
        call state%temporal_history_snapshot(derivative,history)
      class default
        return
      end select
      n=physical%active_nodes;layout=snapshot%layout_id();lineage=snapshot%current_lineage_id()
      revision=snapshot%current_revision();call snapshot%current_time(time,ok);if(.not.ok)return
      bound=snapshot%time_is_bound();thermal=allocated(physical%soil_temperature)
      write(u,iostat=io)layout,lineage,revision,time,bound,n,history,thermal,identity%parameter_set_id, &
        identity%active_nodes,identity%heat_enabled,identity%valid
      if(io/=0)return
      write(u,iostat=io)physical%pressure_head,physical%water_content,physical%ponding_depth,physical%groundwater_level, &
        identity%z,identity%dz
      if(io/=0)return
      if(history)write(u,iostat=io)derivative
      if(io/=0)return
      if(thermal)then
        call build_soil_temperature_field_view(physical%soil_temperature,heat,st)
        if(st/=0)then;io=1;return;end if
        write(u,iostat=io)heat%temperature_c
      end if
    else
      read(u,iostat=io)layout,lineage,revision,time,bound,n,history,thermal,identity%parameter_set_id, &
        identity%active_nodes,identity%heat_enabled,identity%valid
      if(io/=0)return
      io=1
      if(n/=c%tiles(1)%parameters%active_nodes.or.n<1.or.n>10000)return
      if(layout/=c%tiles(1)%template%template_id)return
      if(identity%parameter_set_id/=c%tiles(1)%parameters%parameter_set_id.or.identity%active_nodes/=n.or..not.identity%valid)return
      if(thermal.neqv.c%tiles(1)%parameters%soil_temperature_active)return
      if(identity%heat_enabled.neqv.thermal)return
      physical%active_nodes=n
      allocate(physical%pressure_head(n),physical%water_content(n),identity%z(n),identity%dz(n))
      read(u,iostat=io)physical%pressure_head,physical%water_content,physical%ponding_depth,physical%groundwater_level, &
        identity%z,identity%dz
      if(io/=0)return
      io=1
      if(any(identity%z/=c%tiles(1)%parameters%z).or.any(identity%dz/=c%tiles(1)%parameters%dz))return
      if(history)then
        allocate(derivative(n));read(u,iostat=io)derivative;if(io/=0)return
        io=1;if(.not.all(ieee_is_finite(derivative)))return
        call fmr_new_b110_temporal_indicator_committed_state(temporary,1_int64,physical,0._real64,ok,derivative)
      else
        call fmr_new_b110_temporal_indicator_committed_state(temporary,1_int64,physical,0._real64,ok)
      end if
      if(.not.ok)return
      if(thermal)then
        allocate(temperatures(n));read(u,iostat=io)temperatures;if(io/=0)return
        allocate(physical%soil_temperature)
        call initialize_soil_temperature_state(temperatures,physical%soil_temperature,st)
        io=1;if(st/=0)return
        if(history)then
          call fmr_new_b110_temporal_indicator_committed_state(temporary,1_int64,physical,0._real64,ok,derivative)
        else
          call fmr_new_b110_temporal_indicator_committed_state(temporary,1_int64,physical,0._real64,ok)
        end if
        if(.not.ok)return
      end if
      call temporary%snapshot(state,ok);if(.not.ok)return
      call kernel_reconstruct_committed_state_trusted(water,lineage,revision,state,time,bound,ok,st, &
        c%tiles(1)%parameters,identity)
      io=1;if(.not.ok.or.st/=0)return
      call export_kernel_committed_state(water,layout,snapshot,ok,st)
      if(ok.and.st==0)io=0
    end if
  end subroutine

  subroutine weather_native_crop(u,reading,snapshot,io)
    integer,intent(in)::u
    logical,intent(in)::reading
    type(kernel_persistence_snapshot_t),intent(inout)::snapshot
    integer,intent(out)::io
    type(fmr_wofost_crop_transaction_persistence_t)::v
    type(fmr_wofost_crop_transaction_state_t)::crop
    class(transaction_state_t),allocatable::physical
    type(kernel_committed_state_t)::committed
    integer(int64)::layout,lineage,revision
    real(real64)::time
    logical::ok,bound
    integer::st
    io=1
    if(.not.reading)then
      call snapshot%snapshot_physical(physical,ok);if(.not.ok)return
      select type(physical)
      type is(fmr_wofost_crop_transaction_state_t)
        call export_fmr_wofost_crop_transaction_persistence(physical,v,ok,st);if(.not.ok.or.st/=0)return
      class default
        return
      end select
      layout=snapshot%layout_id();lineage=snapshot%current_lineage_id();revision=snapshot%current_revision()
      call snapshot%current_time(time,ok);if(.not.ok)return
      bound=snapshot%time_is_bound()
      write(u,iostat=io)layout,lineage,revision,time,bound
    else
      read(u,iostat=io)layout,lineage,revision,time,bound
    end if
    if(io/=0)return
    call weather_native_crop_view(u,reading,v,io);if(io/=0)return
    if(reading)then
      io=1;if(layout/=904001_int64)return
      call reconstruct_fmr_wofost_crop_transaction_from_persistence(v,crop,ok,st);if(.not.ok.or.st/=0)return
      allocate(physical,source=crop)
      call kernel_reconstruct_committed_state_trusted(committed,lineage,revision,physical,time,bound,ok,st)
      if(.not.ok.or.st/=0)return
      call export_kernel_committed_state(committed,layout,snapshot,ok,st)
      if(ok.and.st==0)io=0
    end if
  end subroutine
  subroutine weather_native_window(u,reading,v,io)
    integer,intent(in)::u
    logical,intent(in)::reading
    type(fmr_wofost_window_persistence_t),intent(inout)::v
    integer,intent(out)::io
    logical::present_value
    integer::n,st
    type(fmr_wofost_crop_event_identity_persistence_t)::event
    io=0
    if(reading)then
      read(u,iostat=io)v%initialized
    else
      write(u,iostat=io)v%initialized
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%lineage_id
    else
      write(u,iostat=io)v%lineage_id
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%start_revision
    else
      write(u,iostat=io)v%start_revision
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%next_revision
    else
      write(u,iostat=io)v%next_revision
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%accepted_intervals
    else
      write(u,iostat=io)v%accepted_intervals
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%t0
    else
      write(u,iostat=io)v%t0
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%t1
    else
      write(u,iostat=io)v%t1
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%covered_t
    else
      write(u,iostat=io)v%covered_t
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%actual_root_uptake_integral
    else
      write(u,iostat=io)v%actual_root_uptake_integral
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%potential_transpiration_integral
    else
      write(u,iostat=io)v%potential_transpiration_integral
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%deepest_root_oxygen_factor_available
    else
      write(u,iostat=io)v%deepest_root_oxygen_factor_available
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%deepest_root_oxygen_factor_integral
    else
      write(u,iostat=io)v%deepest_root_oxygen_factor_integral
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%rootzone_drought_uptake_factor_available
    else
      write(u,iostat=io)v%rootzone_drought_uptake_factor_available
    end if
    if(io/=0)return
    if(reading)then
      read(u,iostat=io)v%rootzone_drought_uptake_factor_integral
    else
      write(u,iostat=io)v%rootzone_drought_uptake_factor_integral
    end if
    if(io/=0)return
    present_value=allocated(v%potential_root_sink_integral)
    if(reading)then
      read(u,iostat=io)present_value
    else
      write(u,iostat=io)present_value
    end if
    if(io/=0)return
    if(present_value)then
      n=0
      if(.not.reading)n=size(v%potential_root_sink_integral)
      if(reading)then
        read(u,iostat=io)n
      else
        write(u,iostat=io)n
      end if
      if(io/=0)return
      if(n<0.or.n>10000)then;io=1;return;end if
      if(reading)then
        if(allocated(v%potential_root_sink_integral))deallocate(v%potential_root_sink_integral)
        allocate(v%potential_root_sink_integral(n),stat=io);if(io/=0)return
        read(u,iostat=io)v%potential_root_sink_integral
      else
        write(u,iostat=io)v%potential_root_sink_integral
      end if
      if(io/=0)return
    end if
    present_value=allocated(v%root_sink_reduction_integral)
    if(reading)then
      read(u,iostat=io)present_value
    else
      write(u,iostat=io)present_value
    end if
    if(io/=0)return
    if(present_value)then
      n=0
      if(.not.reading)n=size(v%root_sink_reduction_integral)
      if(reading)then
        read(u,iostat=io)n
      else
        write(u,iostat=io)n
      end if
      if(io/=0)return
      if(n<0.or.n>10000)then;io=1;return;end if
      if(reading)then
        if(allocated(v%root_sink_reduction_integral))deallocate(v%root_sink_reduction_integral)
        allocate(v%root_sink_reduction_integral(n),stat=io);if(io/=0)return
        read(u,iostat=io)v%root_sink_reduction_integral
      else
        write(u,iostat=io)v%root_sink_reduction_integral
      end if
      if(io/=0)return
    end if
    if(reading)then
      read(u,iostat=io)v%event_delivered
    else
      write(u,iostat=io)v%event_delivered
    end if
    if(io/=0)return
  end subroutine




  function crc32(bytes) result(crc)
    integer(int8),intent(in)::bytes(:)
    integer(int32)::crc
    integer::i,j
    crc=not(0_int32)
    do i=1,size(bytes)
      crc=ieor(crc,iand(int(bytes(i),int32),int(z'FF',int32)))
      do j=1,8
        if(btest(crc,0))then
          crc=ieor(shiftr(crc,1),int(z'EDB88320',int32))
        else
          crc=shiftr(crc,1)
        end if
      end do
    end do
    crc=not(crc)
  end function

  subroutine append_crc(path,status)
    character(*),intent(in)::path
    integer,intent(out)::status
    integer(int8),allocatable::bytes(:)
    integer::u,n,io
    integer(int32)::crc
    status=1
    inquire(file=path,size=n,iostat=io)
    if(io/=0.or.n<1.or.n>MAX_BYTES-4)return
    allocate(bytes(n))
    open(newunit=u,file=path,access='stream',form='unformatted',status='old',action='readwrite',iostat=io)
    if(io/=0)return
    read(u,iostat=io)bytes
    if(io==0)then
      crc=crc32(bytes);write(u,pos=n+1,iostat=io)crc
    end if
    close(u)
    if(io==0)status=0
  end subroutine

  subroutine check_crc(path,status)
    character(*),intent(in)::path
    integer,intent(out)::status
    integer(int8),allocatable::bytes(:)
    integer::u,n,io
    integer(int32)::actual,expected
    status=1
    inquire(file=path,size=n,iostat=io)
    if(io/=0.or.n<12.or.n>MAX_BYTES)return
    allocate(bytes(n-4))
    open(newunit=u,file=path,access='stream',form='unformatted',status='old',action='read',iostat=io)
    if(io/=0)return
    read(u,iostat=io)bytes,expected
    close(u)
    if(io/=0)return
    actual=crc32(bytes)
    if(actual==expected)status=0
  end subroutine
end module
