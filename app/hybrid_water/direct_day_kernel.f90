! Invocation-private C bridge to the unchanged SWAP5 daily executor.
module direct_day_kernel
 use iso_c_binding
 use probe_kernel_donor
 use mod_fmr_soil_water_application_host,only:fmr_resolve_soil_water_application_model, &
  fmr_soil_water_application_selection_t,FMR_APPLICATION_HOST_OK,FMR_APPLICATION_ROUTE_REGISTERED_ALTERNATIVE
 implicit none
 type,extends(model_t)::direct_model_t
  real(real64),allocatable::reply(:)
 contains
  procedure::advance=>direct_advance
 end type
 type::context_t
  type(kernel_executor_t)::executor
  type(direct_model_t),pointer::model=>null()
  type(parameters_t)::parameters
  type(forcing_t)::forcing
  type(kernel_committed_state_t),allocatable::committed(:)
  logical,allocatable::refused(:)
  integer::nodes
  real(real64)::epoch
 end type
contains
 subroutine direct_advance(self,state,t0,t1,outcome)
  class(direct_model_t),intent(inout)::self
  class(transaction_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1
  type(trial_outcome_t),intent(out)::outcome
  integer::n
  outcome=trial_outcome_t()
  select type(state)
  type is(state_t)
   if(.not.allocated(state%pressure).or..not.allocated(self%reply))return
   n=size(state%pressure)
   if(size(self%reply)/=n+12)return
   if(.not.all(ieee_is_finite(self%reply)))return
   if(self%reply(1)/=state%ticket+1)return
   state%stock=self%reply(2)
   state%pressure=self%reply(7:6+n)
   state%component_stock=self%reply(7+n:12+n)
   state%ticket=int(self%reply(1))
   outcome%solver_ok=.true.
   outcome%mass_accounting_complete=.true.
   outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
   outcome%mass_in=self%reply(3)
   outcome%mass_out=self%reply(4)
   outcome%bottom_interface_exchange_available=.true.
   outcome%bottom_outward_exchange_native=self%reply(5)
   outcome%terminal_bottom_outward_flux_native=self%reply(6)
  end select
 end subroutine
 subroutine dk_new(ncol,nodes,epoch,first,totals,stocks,heads,handle,status)bind(C)
  integer(c_int),value::ncol,nodes
  real(c_double),value::epoch
  integer(c_int),intent(in)::first(ncol)
  real(c_double),intent(in)::totals(ncol),stocks(6,ncol),heads(nodes,ncol)
  type(c_ptr),intent(out)::handle
  integer(c_int),intent(out)::status
  type(context_t),pointer::c
  class(transaction_state_t),allocatable::initial
  integer::i,resolver_status
  type(fmr_soil_water_application_selection_t)::selection
  character(len=32),parameter::keys(1)=[character(len=32)::"HYBRID_SALTFARM_WATER"]
  logical::ok
  handle=c_null_ptr;status=-1
  if(ncol<1.or.nodes<1.or.nodes>10000)return
  if(.not.ieee_is_finite(epoch).or.any(first<0))return
  if(.not.all(ieee_is_finite(totals)))return
  if(.not.all(ieee_is_finite(stocks)).or..not.all(ieee_is_finite(heads)))return
  call fmr_resolve_soil_water_application_model(keys(1),keys,selection,resolver_status)
  if(resolver_status/=FMR_APPLICATION_HOST_OK.or..not.selection%explicit_selection.or. &
    selection%route/=FMR_APPLICATION_ROUTE_REGISTERED_ALTERNATIVE.or.selection%registered_index<1)return
  allocate(c);allocate(c%model);c%nodes=nodes;c%epoch=epoch
  allocate(c%committed(ncol),c%refused(ncol));c%refused=.false.
  call c%executor%bind_model(c%model)
  do i=1,ncol
   allocate(initial,source=state_t(column=i,ticket=first(i),stock=totals(i), &
     component_stock=stocks(:,i),pressure=heads(:,i)))
   call c%committed(i)%initialize(int(i,int64),initial,ok,epoch+first(i))
   deallocate(initial)
   if(.not.ok)then
    deallocate(c%model);deallocate(c);status=-2;return
   end if
  end do
  handle=c_loc(c);status=0
 end subroutine
 subroutine dk_request(handle,column,day,times,status)bind(C)
  type(c_ptr),value::handle
  integer(c_int),value::column,day
  real(c_double),intent(out)::times(2)
  integer(c_int),intent(out)::status
  type(context_t),pointer::c
  logical::ok
  status=-1;times=0
  if(.not.c_associated(handle))return
  call c_f_pointer(handle,c)
  if(column<1.or.column>size(c%committed))return
  if(c%refused(column))return
  call c%committed(column)%current_time(times(1),ok)
  if(.not.ok.or.times(1)/=c%epoch+day-1)return
  times(2)=times(1)+1;status=0
 end subroutine
 subroutine dk_apply(handle,column,day,n,reply,values,status)bind(C)
  type(c_ptr),value::handle
  integer(c_int),value::column,day,n
  real(c_double),intent(in)::reply(n)
  real(c_double),intent(out)::values(4)
  integer(c_int),intent(out)::status
  type(context_t),pointer::c
  type(kernel_reference_floor_candidate_t)::candidate
  type(kernel_reference_floor_result_t)::result
  type(kernel_diagnostics_t)::diagnostics
  real(c_double)::times(2),accepted
  logical::ok
  call dk_request(handle,column,day,times,status)
  values=0
  if(status/=0)return
  call c_f_pointer(handle,c)
  status=-1
  if(n/=c%nodes+12)return
  c%model%reply=reply
  call c%executor%sample_reference_floor_interval(c%parameters,c%committed(column),c%forcing, &
    times(1),times(2),1e-10_real64,result,candidate,diagnostics)
  deallocate(c%model%reply)
  if(.not.candidate%ready().or..not.result%mass%complete)then
   call c%committed(column)%current_time(accepted,ok)
   if(.not.ok.or.accepted/=times(1))then
    status=-3;return
   end if
   c%refused(column)=.true.;status=0
  else
   call c%executor%commit_reference_floor_candidate(c%committed(column),candidate,diagnostics,ok)
   if(.not.ok)then
    status=-4;return
   end if
   call c%committed(column)%current_time(accepted,ok)
   if(.not.ok.or.accepted/=times(2))then
    status=-5;return
   end if
   status=1
  end if
  values=[real(c%committed(column)%current_revision(),real64),result%mass%residual, &
    result%bottom_outward_exchange_native,accepted]
 end subroutine
 subroutine dk_free(handle)bind(C)
  type(c_ptr),value::handle
  type(context_t),pointer::c
  if(.not.c_associated(handle))return
  call c_f_pointer(handle,c)
  deallocate(c%model);deallocate(c)
 end subroutine
end module
