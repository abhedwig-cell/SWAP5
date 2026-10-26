  subroutine check_macro_trace(obs)
    use, intrinsic :: ieee_arithmetic,only:ieee_value,ieee_quiet_nan
    use mod_fmr_serialized_reference_backend,only:fmr_water_flux_substep_trace_t,fmr_macropore_trace_receipt_valid
    type(fmr_serialized_physical_observation_t),intent(in)::obs
    type(fmr_water_flux_substep_trace_t)::s,bad
    real(real64)::covered_total
    real(real64)::delta,expected,dt0,cellerr,materr,maxcell,maxmat,maxgross,gross,topamount,rapid,returned,pond
    integer::j,n0,k
    if(.not.obs%accepted_water_flux_trace_available.or..not.allocated(obs%accepted_water_flux_substeps)) &
      error stop 'macro trace missing accepted path'
    covered_total=0._real64
    maxcell=0._real64;maxmat=0._real64;maxgross=0._real64;topamount=0._real64;rapid=0._real64;returned=0._real64;pond=0._real64
    do j=1,size(obs%accepted_water_flux_substeps)
      s=obs%accepted_water_flux_substeps(j);n0=size(s%water_start);dt0=s%t1-s%t0
      if(.not.fmr_macropore_trace_receipt_valid(s,n0))error stop 'macro trace receipt invalid'
      if(size(s%macropore_water_start,1)<1)error stop 'macro trace missing domain'
      cellerr=maxval(abs(s%macropore_water_end(:,s%macropore_top_node:n0)- &
        s%macropore_water_start(:,s%macropore_top_node:n0) -dt0* &
        (s%macropore_vertical_face_rate(:,s%macropore_top_node:n0)- &
         s%macropore_vertical_face_rate(:,s%macropore_top_node+1:n0+1)- &
         s%macropore_matrix_exchange_domain(:,s%macropore_top_node:n0)- &
         s%macropore_external_outflow_rate(:,s%macropore_top_node:n0))))
      covered_total=covered_total+sum(s%covered_top_input_domain_cm)
      if(cellerr>1.e-10_real64)error stop 'independent macro per-cell budget'
      delta=sum(dz(1:n0)*s%matrix_area_fraction*(s%water_end-s%water_start))
      expected=dt0*(-s%top_flux+s%bottom_flux+sum(s%net_node_source))
      materr=abs(delta-expected)
      if(materr>1.e-10_real64)error stop 'independent matrix whole-column budget'
      if(abs(sum(s%macropore_vertical_face_rate(:,n0+1))*dt0)>1.e-10_real64) &
        error stop 'unbooked macro bottom export'
      if(s%macropore_top_node>1)then
        gross=abs(delta+sum(s%macropore_water_end-s%macropore_water_start)- &
          (dt0*(-s%top_flux+s%bottom_flux+sum(s%subsurface_source-s%drainage_sink-s%root_sink))+ &
          s%macropore_accepted_cm-s%macropore_rapid_outflow_cm))
        if(gross>1.e-10_real64)error stop 'independent covered internal column balance'
        maxgross=max(maxgross,gross)
      end if
      if(s%converged_surface_available)then
        delta=delta+sum(s%macropore_water_end-s%macropore_water_start)+s%pond_end_cm-s%pond_start_cm
        expected=dt0*(s%converged_surface_net_potential_cm_day+s%bottom_flux+ &
          sum(s%subsurface_source-s%drainage_sink-s%root_sink))+s%macropore_surface_return_cm+ &
          s%macropore_accepted_cm-s%converged_runoff_depth_cm-s%macropore_rapid_outflow_cm
        gross=abs(delta-expected)
        if(gross>1.e-10_real64)error stop 'independent declared-boundary whole-column water budget'
        maxgross=max(maxgross,gross)
      end if
      maxcell=max(maxcell,cellerr);maxmat=max(maxmat,materr)
      topamount=topamount+s%macropore_external_top_cm;rapid=rapid+s%macropore_rapid_outflow_cm
      returned=returned+s%macropore_returned_cm;pond=pond+s%macropore_pond_accepted_cm
      do k=1,12
        bad=s
        select case(k)
        case(1)
          bad%macropore_external_top_cm=bad%macropore_external_top_cm+1.e-4_real64
        case(2)
          bad%macropore_returned_cm=bad%macropore_returned_cm+1.e-4_real64
        case(3)
          bad%macropore_pond_returned_cm=bad%macropore_pond_returned_cm+1.e-4_real64
        case(4)
          bad%macropore_external_outflow_rate(1,1)=-1._real64
        case(5)
          bad%macropore_rapid_outflow_cm=bad%macropore_rapid_outflow_cm+1.e-4_real64
        case(6)
          bad%matrix_area_fraction(1)=0._real64
        case(7)
          bad%macropore_vertical_face_rate(1,1)=ieee_value(0._real64,ieee_quiet_nan)
        case(8)
          bad%macropore_rapid_outflow_cm=ieee_value(0._real64,ieee_quiet_nan)
        case(9)
          bad%covered_top_input_domain_cm(1)=bad%covered_top_input_domain_cm(1)+1.e-4_real64
        case(10)
          bad%covered_donor_node=n0
        case(11)
          bad%macropore_top_node=n0+1
        case(12)
          bad%macropore_matrix_exchange(1)=bad%macropore_matrix_exchange(1)+1.e-4_real64
        end select
        if(fmr_macropore_trace_receipt_valid(bad,n0))error stop 'macro receipt corruption accepted'
      end do
    end do
    if(wet.and.covered_total<=0._real64)error stop 'positive covering branch not executed'
    write(*,'(*(g0,1x))')'MACRO_TRACE_CHECK_PASS',size(obs%accepted_water_flux_substeps), &
      maxcell,maxmat,maxgross,topamount,rapid,returned,pond,covered_total
  end subroutine check_macro_trace
