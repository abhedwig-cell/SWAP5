  subroutine check_macro_root_drain(obs,roots,drainage)
    type(fmr_serialized_physical_observation_t),intent(in)::obs
    logical,intent(in)::roots,drainage
    real(real64)::root_amount,drain_amount,root_oracle_error,dt0
    integer::j
    if(.not.obs%accepted_water_flux_trace_available)error stop 'joint trace missing'
    root_amount=0._real64;drain_amount=0._real64;root_oracle_error=0._real64
    do j=1,size(obs%accepted_water_flux_substeps)
      associate(s=>obs%accepted_water_flux_substeps(j))
      dt0=s%t1-s%t0
      root_amount=root_amount+sum(s%root_sink)*dt0
      drain_amount=drain_amount+sum(s%drainage_sink)*dt0
      if(roots)then
        if(.not.s%substep_root_available)error stop 'joint did not execute root process'
        ! This fixture has rain/irrigation with no canopy evaporation. The
        ! already qualified wet-canopy regime supplies the prescribed wet
        ! transpiration (.025), rather than the uncoupled dry request (.05).
        ! All four heads lie above the Feddes drought thresholds; oxygen is off.
        root_oracle_error=max(root_oracle_error,abs(s%root_potential_cm_day-.025_real64), &
          abs(sum(s%root_sink)-.025_real64))
      end if
      end associate
    end do
    if(roots.and.(root_amount<=0._real64.or.root_oracle_error>1.e-12_real64))error stop 'Rutter/root demand coupling'
    if(.not.roots.and.root_amount/=0._real64)error stop 'unexpected joint root sink'
    if(drainage.and.(drain_amount<=0._real64))error stop 'response drainage not positive'
    if(.not.drainage.and.drain_amount/=0._real64)error stop 'unexpected joint drainage'
    print '(a,3(1x,es25.17e3))','MACRO_ROOT_DRAIN_CHECK_PASS',root_amount,drain_amount,root_oracle_error
  end subroutine
