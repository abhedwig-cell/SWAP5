 subroutine manual_thermal_fallow(b,w,n,forcing,t0,t1,items,r)
  type(fmr_serialized_reference_backend_t),intent(inout)::b
  type(kernel_committed_state_t),intent(inout)::w
  type(crop_soil_state_t),intent(inout)::n
  type(fmr_b110_physical_forcing_t),intent(in)::forcing
  real(real64),intent(in)::t0,t1
  type(soil_n_material_input_t),intent(in)::items(:)
  type(material_joint_result_t),intent(out)::r
  type(kernel_checkpoint_t)::checkpoint
  type(kernel_candidate_state_t)::candidate
  type(fmr_serialized_physical_observation_t)::obs
  type(crop_soil_state_t)::staged
  type(reactive_state_t)::soil
  type(wofost81_crop_owner_state_t)::crop
  type(mineral_state_t)::base
  type(mineral_daily_carrier_t)::carrier
  type(soil_n_day_environment_t)::original_environment
  logical::ok,committed
  integer::code
  r=material_joint_result_t()
  call stage_crop_soil_materials(n,t0,items,split,staged,r%materials)
  call require(r%materials%status==0,'manual material staging')
  call w%capture_checkpoint(checkpoint,ok);call require(ok,'manual thermal checkpoint')
  call b%run_trial(column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,t0,t1, &
   checkpoint,r%joint%water,candidate,r%joint%diagnostics,trace_accepted_water_flux_substeps=.true., &
   trace_accepted_soil_n_heat=.true.)
  call require(r%joint%water%completed.and.candidate%ready(),'manual actual Richards heat trial')
  obs=b%observation()
  call b%commit_trial_candidate(w,candidate,r%joint%diagnostics,committed,code)
  call require(committed.and.code==0,'manual actual accepted Richards heat')
  ! This function executes the independently extracted original depth reducer.
  original_environment=soil_n_day_environment_t(t0,t1,accepted_literal_temperature(w,t0,t1))
  call staged%snapshot(soil,crop);call soil%mineral_snapshot(base)
  call aggregate_mineral_trace(base,obs%accepted_water_flux_substeps,carrier,code)
  call require(code==0,'manual accepted water carrier')
  call advance_crop_soil_fallow_day(staged,t0,t1,carrier%water_end,carrier%outflow,carrier%in_bottom, &
   carrier%in_lateral,carrier%root_water,forcing%root_potential_transpiration,r%joint%chemical, &
   original_environment,surface_water=carrier%surface_water)
  call require(r%joint%chemical%status==0,'manual literal-temperature chemistry')
  call check_crop_soil_material_day(staged,r%joint%chemical,r%materials)
  call require(r%materials%status==0,'manual material whole N')
  call require(r%joint%diagnostics%max_abs_step_mass_residual<=HARD_MASS_GATE,'manual hard water balance')
  n=staged;r%status=JOINT_OK;r%joint%status=JOINT_OK
 end subroutine
