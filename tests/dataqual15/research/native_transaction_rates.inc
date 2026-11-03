  subroutine research_contact_rates(self,head,theta,fraction,domain_rate,ok)
    class(ppa_wu05a16_inner_macropore_provider_t),intent(in)::self
    real(real64),intent(in)::head(:),theta(:),fraction
    real(real64),allocatable,intent(out)::domain_rate(:,:)
    logical,intent(out)::ok
    type(macropore_rate_bundle_request_t)::request
    type(macropore_rate_bundle_result_t)::ordinary,off,on
    type(matrix_saturated_zone_view_t)::view
    type(soil_water_physical_state_t)::matrix
    type(macropore_geometry_result_t)::geometry
    real(real64),allocatable::returned(:,:)
    ok=.false.
    if(fraction<0d0.or.fraction>1d0)return
    call evaluate_current_rates(self,head,theta,request,ordinary,view,matrix,ok)
    if(.not.ok)return
    ok=.false.
    if(.not.request%unsaturated%sorptivity%perched_active)return
    if(request%unsaturated%sorptivity%perched_bottom_node/=27)return
    ! Proposed set-valued completion of the partly saturated top-cell exclusion.
    ! Rebuild both whole rate bundles, including donor limiters, for every call.
    request%unsaturated%sorptivity%perched_top_node=26
    call evaluate_macropore_rate_bundle(request,off)
    request%unsaturated%sorptivity%perched_top_node=27
    call evaluate_macropore_rate_bundle(request,on)
    if(.not.off%valid.or..not.on%valid)return
    domain_rate=(1d0-fraction)*off%qexc_to_matrix_rate+fraction*on%qexc_to_matrix_rate
    if(self%shrinkage%enabled)then
      call self%evaluate_trial_geometry(theta,geometry,ok,head)
      if(.not.ok)return
      call evaluate_macropore_geometry_return(self%accepted_macro,geometry,returned,ok)
      if(.not.ok)return
      domain_rate=domain_rate+returned/self%step_duration
    end if
    ok=.true.
  end subroutine
