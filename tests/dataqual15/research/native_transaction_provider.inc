  subroutine research_contact_lifecycle(self,head,theta,fraction,u,kind,macro_result,face_result,exchange_result,external_result,top_amount,valid)
    class(ppa_wu05a16_inner_macropore_provider_t),intent(in)::self
    real(real64),intent(in)::head(:),theta(:),fraction
    integer,intent(in)::u,kind
    type(macropore_continuation_state_t),intent(out),optional::macro_result
    real(real64),allocatable,intent(out),optional::face_result(:,:),exchange_result(:,:),external_result(:,:)
    real(real64),intent(out),optional::top_amount
    logical,intent(out),optional::valid
    type(macropore_rate_bundle_request_t)::request
    type(macropore_rate_bundle_result_t)::ordinary,off,on
    type(matrix_saturated_zone_view_t)::matrix_view
    type(soil_water_physical_state_t)::matrix
    type(macropore_geometry_result_t)::geometry
    type(macropore_standard_storage_view_t)::view
    type(macropore_standard_candidate_receipt_t)::receipt
    type(macropore_continuation_state_t)::candidate,history_off,history_on,completed,repeat_completion
    type(sorptivity_history_update_request_t)::template,history
    type(vertical_flux_reconstruction_request_t)::vertical
    type(vertical_flux_reconstruction_result_t)::faces
    type(macropore_top_partition_result_t)::top
    real(real64),allocatable::exchange(:,:),rapid(:),returned(:,:)
    real(real64)::history_difference
    logical::ok,aok,bok,unique
    integer::nd,n
    if(present(valid))valid=.false.
    call evaluate_current_rates(self,head,theta,request,ordinary,matrix_view,matrix,ok)
    if(.not.ok)error stop 'full lifecycle request'
    call self%evaluate_trial_geometry(theta,geometry,ok,head)
    if(.not.ok)error stop 'full lifecycle geometry'
    request%unsaturated%sorptivity%perched_top_node=26
    call evaluate_macropore_rate_bundle(request,off)
    request%unsaturated%sorptivity%perched_top_node=27
    call evaluate_macropore_rate_bundle(request,on)
    if(.not.off%valid.or..not.on%valid)error stop 'full lifecycle branch rates'
    exchange=(1d0-fraction)*off%qexc_to_matrix_rate+fraction*on%qexc_to_matrix_rate
    if(self%shrinkage%enabled)then
      call evaluate_macropore_geometry_return(self%accepted_macro,geometry,returned,ok)
      if(.not.ok)return
      exchange=exchange+returned/self%step_duration
    end if
    rapid=(1d0-fraction)*off%rapid_outflow_cp_cm+fraction*on%rapid_outflow_cp_cm
    top=off%top_partition
    top%accepted_vertical_cm=(1d0-fraction)*off%top_partition%accepted_vertical_cm+fraction*on%top_partition%accepted_vertical_cm
    top%accepted_lateral_cm=(1d0-fraction)*off%top_partition%accepted_lateral_cm+fraction*on%top_partition%accepted_lateral_cm
    top%redistributed_cm=(1d0-fraction)*off%top_partition%redistributed_cm+fraction*on%top_partition%redistributed_cm
    top%accepted_total_cm=sum(top%accepted_vertical_cm+top%accepted_lateral_cm)
    top%redistributed_total_cm=sum(top%redistributed_cm)
    top%returned_surface_cm=(1d0-fraction)*off%top_partition%returned_surface_cm+fraction*on%top_partition%returned_surface_cm
    top%receipt_residual_cm=top%accepted_total_cm+top%returned_surface_cm-top%requested_total_cm
    if(abs(top%receipt_residual_cm)>1d-10)error stop 'full lifecycle top budget'
    call build_macropore_standard_candidate(self%accepted_macro,geometry,top,exchange,rapid,self%step_duration, &
         geometry%top_node,self%z,self%dz,candidate,view,receipt,ok)
    write(u,'(a,a,i0,a,l1,a,es25.17e3)')'MACRO_STORAGE',',',kind,',',ok,',',receipt%macro_balance_residual_cm
    if(.not.ok)return
    nd=candidate%num_domains;n=candidate%num_nodes
    vertical%num_domains=nd;vertical%num_nodes=n;vertical%top_node=geometry%top_node
    vertical%step_duration=self%step_duration;vertical%bottom_domain=candidate%icp_bottom_domain
    vertical%top_inflow_rate=(top%accepted_vertical_cm+top%accepted_lateral_cm)/self%step_duration
    vertical%previous_water_cm=self%accepted_macro%water_domain_cp;vertical%current_water_cm=candidate%water_domain_cp
    vertical%exchange_to_matrix_rate=exchange;allocate(vertical%external_outflow_rate(nd,n));vertical%external_outflow_rate=0d0
    vertical%external_outflow_rate(1,:)=rapid/self%step_duration
    call reconstruct_vertical_flux(vertical,faces)
    write(u,'(a,a,i0,a,l1,a,es25.17e3)')'MACRO_VERTICAL',',',kind,',',faces%valid,',',faces%max_local_residual_rate
    if(.not.faces%valid)return
    template%num_domains=nd;template%num_nodes=n;template%top_node=geometry%top_node
    template%wall_correction=request%unsaturated%sorptivity%wall_correction
    template%domain_fraction=request%unsaturated%sorptivity%domain_fraction
    template%diameter=request%unsaturated%sorptivity%diameter
    call prepare_standard_sorptivity_history_request(template,geometry,view,matrix_view,self%step_duration,history,ok)
    if(.not.ok)error stop 'full lifecycle history contract'
    history_off=candidate;history_on=candidate
    call apply_sorptivity_history_update(history,self%accepted_macro,off%unsaturated,history_off,aok)
    call apply_sorptivity_history_update(history,self%accepted_macro,on%unsaturated,history_on,bok)
    history_difference=maxval(abs(history_off%absorption_time-history_on%absorption_time))
    write(u,'(a,a,i0,3(a,l1),a,es25.17e3)')'HISTORY_BRANCHES',',',kind,',',aok,',',bok,',', &
         history_off%same_values(history_on),',',history_difference
    if(.not.aok.or..not.bok)error stop 'full lifecycle history failure'
    call complete_contact_action_memory(history,self%accepted_macro,on%unsaturated,history_off,history_on, &
         26,fraction,completed,ok)
    if(.not.ok)error stop 'native action memory completion'
    call complete_contact_action_memory(history,self%accepted_macro,on%unsaturated,history_off,history_on, &
         26,fraction,repeat_completion,unique)
    unique=unique.and.completed%same_values(repeat_completion)
    write(u,'(a,a,i0,2(a,l1),3(a,es25.17e3))')'ACTION_HISTORY',',',kind,',',ok,',',unique,',',fraction, &
         ',',maxval(completed%absorption_time(:,26)),',',maxval(completed%theta_sorption_ref(:,26))
    if(.not.unique)error stop 'nonunique native action memory'

    if(present(macro_result))macro_result=completed
    if(present(face_result))face_result=faces%vertical_face_rate
    if(present(exchange_result))exchange_result=exchange
    if(present(external_result))external_result=vertical%external_outflow_rate
    if(present(top_amount))top_amount=receipt%accepted_top_cm
    if(present(valid))valid=.true.
    write(u,'(a,a,i0,a,es25.17e3)')'EXCHANGE_OPPOSITE_SIGN_AMOUNT' ,',',kind,',',receipt%internal_exchange_to_matrix_cm
  end subroutine

 subroutine research_contact_selector(self,head,theta,fraction,ok)
  class(ppa_wu05a16_inner_macropore_provider_t),intent(in)::self
  real(real64),intent(in)::head(:),theta(:)
  real(real64),intent(out)::fraction
  logical,intent(out)::ok
  type(macropore_rate_bundle_request_t)::request
  type(macropore_rate_bundle_result_t)::rates
  type(matrix_saturated_zone_view_t)::view
  type(soil_water_physical_state_t)::matrix
  call evaluate_current_rates(self,head,theta,request,rates,view,matrix,ok)
  if(.not.ok)return
  ok=request%unsaturated%sorptivity%perched_active.and.request%unsaturated%sorptivity%perched_bottom_node==27
  if(.not.ok)return
  fraction=0d0
  if(request%unsaturated%sorptivity%perched_top_node==27)fraction=1d0
  ok=request%unsaturated%sorptivity%perched_top_node==26.or.request%unsaturated%sorptivity%perched_top_node==27
 end subroutine
