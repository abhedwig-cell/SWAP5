module mod_fmr_b111_pond_solute_route
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_persistent_pond
 use mod_fmr_serialized_reference_backend,only:fmr_water_flux_substep_trace_t
 use mod_solute_water_face_flux_reconstruction,only:reconstruct_interval_water_face_flux,WATER_FACE_FLUX_OK
 use mod_fmr_b111_matrix_solute_route
 use mod_solute_mobile_salt_state,only:mobile_salt_state_t
 use mod_solute_compartment_state,only:solute_compartment_state_t
 use mod_b111_reactive_solute_substep
 implicit none
 private
 public::consume_accepted_pond_trace
contains
 subroutine consume_accepted_pond_trace(committed,steps,supply,receipt)
  type(matrix_solute_state_t),intent(inout)::committed
  type(fmr_water_flux_substep_trace_t),intent(in)::steps(:)
  type(pond_step_t),intent(in)::supply
  type(persistent_pond_state_t)::pond_trial,pond_next
  type(persistent_pond_receipt_t)::pond_receipt
  type(pond_step_t)::pond_step
  type(matrix_solute_receipt_t),intent(out)::receipt
  type(matrix_solute_state_t)::trial
  type(b111_reactive_solute_substep_forcing_t)::p,f
  type(b111_reactive_solute_substep_receipt_t)::r
  type(mobile_salt_state_t)::mobile,next_mobile
  type(solute_compartment_state_t)::amount,next_amount
  real(real64),allocatable::water(:),faces(:),v(:)
  real(real64)::clock,dt,closure,scale,pond_clock,pond_depth,pond_mass
  integer(int64)::pond_revision
  integer(int64)::id,revision
  integer::k,n,code
  receipt=matrix_solute_receipt_t()
  if(.not.all(ieee_is_finite([supply%t0,supply%t1,supply%rain_rate,supply%rain_c, &
    supply%irrigation_rate,supply%irrigation_c,supply%dry_deposition_rate, &
    supply%runon_rate,supply%runon_c])))return
  if(.not.committed%ready().or.size(steps)<1.or.size(steps)>100000)return
  call committed%snapshot(clock,water,mobile,amount,revision)
  call committed%configuration(p,id)
  if(clock/=supply%t0.or.steps(size(steps))%t1/=supply%t1)return
  if(revision<0.or.revision>=100000000_int64)return
  n=size(water)
  if(n<1.or.n>4096)return
  v=matrix_parameter_vector(p)
  if(.not.allocated(v))return
  if(.not.all(ieee_is_finite(v)))return
  if(any(abs(v)>1d6))return
  if(any(p%dz_cm<1d-4).or.any(p%dz_cm>1d4))return
  if(any(p%face_distance_cm<1d-4).or.any(p%theta_sat_left<1d-8))return
  if(any(p%temperature_c< -50d0).or.any(p%temperature_c>60d0))return
  if(any(p%gampar<0d0).or.any(p%gampar>1d0))return
  if(any(p%rtheta<1d-8).or.any(p%bexp>10d0))return
  if(p%cref_mg_cm3<1d-8.or.p%frexp<.5d0.or.p%frexp>2d0)return
  if(any(mobile%concentration_mg_cm3>1d6).or.any(mobile%mass_mg_cm2>1d12).or. &
    any(amount%sorbed_matrix_mass>1d12))return
  if(amount%pond_mass>1d12.or.amount%aquifer_mass/=0d0.or.any(amount%age_amount/=0d0))return
  if(.not.steps(1)%pond_storage_available)return
  call initialize_persistent_pond(clock,steps(1)%pond_start_cm,amount%pond_mass,pond_trial,code)
  if(code/=POND_OK)return
  receipt%mass_before=sum(mobile%mass_mg_cm2)+amount%solute_total()
  do k=1,size(steps)
   receipt%status=MATRIX_CARRIER
   associate(t=>steps(k))
    if(.not.all(ieee_is_finite([t%t0,t%t1,t%top_flux,t%bottom_flux])))return
    if(abs(t%t0-clock)>0d0.or.t%t1<=t%t0.or.abs(t%t1)>1d8)return
    if(.not.allocated(t%water_start).or..not.allocated(t%water_end).or. &
       .not.allocated(t%root_sink).or..not.allocated(t%net_node_source).or. &
       .not.allocated(t%drainage_sink_by_level))return
    if(size(t%water_start)/=n.or.size(t%water_end)/=n.or.size(t%root_sink)/=n.or. &
       size(t%net_node_source)/=n.or.size(t%drainage_sink_by_level,2)/=n)return
    if(.not.all(ieee_is_finite(t%water_start)).or..not.all(ieee_is_finite(t%water_end)).or. &
       .not.all(ieee_is_finite(t%root_sink)).or..not.all(ieee_is_finite(t%net_node_source)).or. &
       .not.all(ieee_is_finite(t%drainage_sink_by_level)))return
    if(any(t%water_start<1d-8).or.any(t%water_start>1d0).or.any(t%water_end<1d-8).or. &
       any(t%water_end>1d0).or.any(t%root_sink<0d0).or.any(t%root_sink>1d6))return
    ! Bound finite inputs before summing source terms or dividing by dt.
    ! This is a carrier domain check, not a relaxed balance or retry policy.
    if(size(t%drainage_sink_by_level,1)>4096)return
    if(any(abs(t%drainage_sink_by_level)>1d6).or.any(abs(t%net_node_source)>1d10))return
    if(abs(t%bottom_flux)>1d6.or.abs(t%top_flux)>1d6)return
    dt=t%t1-t%t0
    if(dt<1d-100.or.dt>1d3)return
    scale=max(1d0,maxval(abs(t%net_node_source)))
    if(any(abs(t%net_node_source+sum(t%drainage_sink_by_level,dim=1)+t%root_sink)> &
       1024d0*epsilon(1d0)*scale))return
    if(any(abs(t%water_start-water)>1024d0*epsilon(1d0)))return
    if(allocated(t%macropore_matrix_exchange))then
     if(.not.all(ieee_is_finite(t%macropore_matrix_exchange)))return
     if(any(abs(t%macropore_matrix_exchange)>0d0))return
    end if
    if(allocated(t%macropore_matrix_exchange_domain))then
     if(size(t%macropore_matrix_exchange_domain,1)>0)return
    end if
    if(allocated(t%subsurface_source))then
     if(.not.all(ieee_is_finite(t%subsurface_source)))return
     if(any(abs(t%subsurface_source)>0d0))return
    end if
    call reconstruct_interval_water_face_flux(p%dz_cm,t%water_start,t%water_end, &
       t%net_node_source,-t%top_flux,-t%bottom_flux,dt,1d-10/dt,faces,closure,code)
    receipt%max_water_residual=max(receipt%max_water_residual,abs(closure)*dt)
    if(code/=WATER_FACE_FLUX_OK)return
    if(.not.t%pond_storage_available)return
    ! A chemical runon receipt requires source identity from the accepted
    ! converged water substep, never a caller-only unverified rate.
    if(supply%runon_rate>0d0.and..not.t%converged_gross_sources_available)return
    if(t%converged_gross_sources_available.and..not.t%converged_surface_available)return
    ! Reject gross forcing that the admitted pond water/solute receipt cannot
    ! represent; do not silently map runon or melt to chemically clean rain.
    if(t%converged_gross_sources_available)then
      if(.not.all(ieee_is_finite([t%converged_rain_rate_cm_day, &
        t%converged_irrigation_rate_cm_day,t%converged_snowmelt_rate_cm_day, &
        t%converged_runon_rate_cm_day])))return
      if(t%converged_rain_rate_cm_day/=supply%rain_rate.or. &
         t%converged_irrigation_rate_cm_day/=supply%irrigation_rate)return
      if(t%converged_snowmelt_rate_cm_day/=0d0.or. &
         t%converged_runon_rate_cm_day/=supply%runon_rate)return
    end if
    ! The incumbent pond water balance contains no gross evaporative or
    ! runoff loss. A converged hydraulic receipt proving either loss must
    ! reject this chemical trial rather than silently conserve the wrong
    ! water volume and export an unqualified solute mass.
    if(t%converged_surface_available)then
      if(.not.all(ieee_is_finite([t%converged_pond_evaporation_cm_day, &
          t%converged_runoff_depth_cm])))return
      ! The admitted B1.11 mixing denominator is preserved. Pond evaporation
      ! changes accepted water depth only, not dissolved solute mass.
      if(t%converged_pond_evaporation_cm_day<0d0.or.t%converged_runoff_depth_cm<0d0)return
    end if
    pond_step=supply;pond_step%t0=t%t0;pond_step%t1=t%t1
    pond_step%pond_evaporation_rate=0d0;pond_step%runoff_depth=0d0
    if(t%converged_surface_available) &
      pond_step%pond_evaporation_rate=t%converged_pond_evaporation_cm_day
    if(t%converged_surface_available) pond_step%runoff_depth=t%converged_runoff_depth_cm
    pond_step%depth_begin=t%pond_start_cm;pond_step%depth_end=t%pond_end_cm;pond_step%qtop=t%top_flux
    call advance_persistent_pond(pond_trial,pond_step,pond_next,pond_receipt)
    if(pond_receipt%status/=POND_OK)return
    call pond_trial%snapshot(pond_clock,pond_depth,pond_mass,pond_revision)
    amount%pond_mass=amount%pond_mass+pond_receipt%dry_input
    f=p;f%dt_day=dt;f%theta_previous=t%water_start;f%theta=t%water_end
    f%q_face_up_cm_day=-faces;f%root_sink_cm_day=t%root_sink;f%qdra_cm_day=t%drainage_sink_by_level
    f%rain_rate_cm_day=supply%rain_rate;f%rain_c_mg_cm3=supply%rain_c
    f%irrigation_rate_cm_day=supply%irrigation_rate;f%irrigation_c_mg_cm3=supply%irrigation_c
    f%runon_rate_cm_day=supply%runon_rate;f%runon_c_mg_cm3=supply%runon_c
    f%pond_end_cm=t%pond_end_cm;f%runoff_depth_cm=pond_step%runoff_depth
    f%macropore_area_fraction=0d0
    call advance_b111_reactive_solute_substep(mobile,amount,f,next_mobile,next_amount,r)
    receipt%status=MATRIX_PROCESS;receipt%process_status=r%status
    if(r%status/=B111_REACTIVE_OK)return
    scale=max(1d0,pond_receipt%soil_transfer,pond_receipt%mass_after)
    if(abs(r%pond_to_soil_mg_cm2-pond_receipt%soil_transfer)>4096d0*epsilon(1d0)*scale)return
    if(abs(next_amount%pond_mass-pond_receipt%mass_after)>4096d0*epsilon(1d0)*scale)return
    if(abs(r%runoff_output_mg_cm2-pond_receipt%runoff_output)>4096d0*epsilon(1d0)*scale)return
    ! Accepted1256 matrix companion is the sole persistent surface-mass owner.
    pond_trial=pond_next
    if(any(next_mobile%concentration_mg_cm3>1d6).or.any(next_mobile%mass_mg_cm2>1d12).or. &
      any(next_amount%sorbed_matrix_mass>1d12))return
    mobile=next_mobile;amount=next_amount;water=t%water_end;clock=t%t1
    receipt%external_in=receipt%external_in+r%external_input_mg_cm2+pond_receipt%dry_input
    receipt%external_out=receipt%external_out+r%external_output_mg_cm2
    receipt%decay_out=receipt%decay_out+r%decay_output_mg_cm2
    receipt%completed_substeps=k
   end associate
  end do
  call pond_trial%snapshot(pond_clock,pond_depth,pond_mass,pond_revision)
  receipt%mass_after=sum(mobile%mass_mg_cm2)+amount%solute_total()
  receipt%residual=receipt%mass_after-receipt%mass_before-receipt%external_in+receipt%external_out
  scale=max(1d0,receipt%mass_before,receipt%mass_after,receipt%external_in,receipt%external_out)
  if(abs(receipt%residual)>8192d0*epsilon(1d0)*scale)return
  call reconstruct_matrix_solute_trusted(p,id,revision+1,clock,water,mobile%concentration_mg_cm3, &
    mobile%mass_mg_cm2,amount%sorbed_matrix_mass,trial,code,surface_mass=amount%pond_mass)
  if(code/=MATRIX_OK)return
  committed=trial;receipt%status=MATRIX_OK
 end subroutine
end module
