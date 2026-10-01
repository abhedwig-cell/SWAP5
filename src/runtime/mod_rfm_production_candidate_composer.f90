module mod_rfm_production_candidate_composer
 use,intrinsic::iso_fortran_env,only:real64
 use,intrinsic::ieee_arithmetic,only:ieee_is_finite
 use mod_rfm_physical_state,only:rfm_physical_state_t,copy_rfm_physical_state
 use mod_rfm_preferential_router,only:rfm_preferential_routing_result_t,RFM_PREF_ROUTER_AVAILABLE
 use mod_rfm_endpoint_release,only:rfm_endpoint_release_request_t,rfm_endpoint_release_result_t,evaluate_rfm_endpoint_release
 use mod_rfm_ic_storage_geometry,only:rfm_ic_storage_geometry_result_t,derive_rfm_ic_water_column
 use mod_rfm_ic_hydrostatic_head,only:rfm_ic_hydrostatic_head_result_t,derive_rfm_ic_hydrostatic_head
 use mod_rfm_whole_column_candidate_ledger,only:rfm_whole_column_candidate_request_t,rfm_whole_column_candidate_result_t, &
      evaluate_rfm_whole_column_candidate_ledger
 implicit none
 private
 type,public::rfm_production_candidate_request_t
  real(real64)::step_duration_day=0.0_real64,effective_supply_rate_cm_per_day=0.0_real64
  real(real64)::matrix_supply_rate_cm_per_day=0.0_real64,candidate_tau_surface_day=0.0_real64
  real(real64),allocatable::endpoint_area_fraction(:),endpoint_bottom_depth_cm(:),endpoint_contact_thickness_cm(:)
  integer,allocatable::endpoint_node_index(:)
  real(real64),allocatable::node_depth_cm(:),node_thickness_cm(:),matrix_pressure_head_cm(:)
  real(real64),allocatable::endpoint_sorptivity_cm_sqrt_day(:),endpoint_conductivity_cm_per_day(:)
  real(real64)::exchange_length_cm=0.0_real64,chi_wall=0.0_real64
 end type
 type,public::rfm_production_candidate_result_t
  logical::valid=.false.
  type(rfm_physical_state_t)::candidate_rfm
  type(rfm_endpoint_release_result_t)::endpoint_release
  type(rfm_whole_column_candidate_result_t)::ledger
  real(real64),allocatable::matrix_source_rate_per_day(:)
  real(real64)::deep_receipt_cm=0.0_real64
 end type
 public::compose_rfm_production_candidate
contains
 subroutine compose_rfm_production_candidate(accepted,routing,request,tolerance,result)
  type(rfm_physical_state_t),intent(in)::accepted
  type(rfm_preferential_routing_result_t),intent(in)::routing
  type(rfm_production_candidate_request_t),intent(in)::request
  real(real64),intent(in)::tolerance
  type(rfm_production_candidate_result_t),intent(out)::result
  type(rfm_endpoint_release_request_t)::er
  type(rfm_ic_storage_geometry_result_t)::g
  type(rfm_ic_hydrostatic_head_result_t)::h
  type(rfm_whole_column_candidate_request_t)::lr
  real(real64),allocatable::input(:),trial_storage(:),dh(:)
  real(real64)::effective,matrix,ic,mb
  integer::i,n,node
  logical::ok
  result=rfm_production_candidate_result_t()
  if(.not.accepted%ready().or.routing%status/=RFM_PREF_ROUTER_AVAILABLE)return
  if(.not.ieee_is_finite(request%step_duration_day).or.request%step_duration_day<=0.0_real64)return
  if(.not.ieee_is_finite(tolerance).or.tolerance<0.0_real64)return
  n=accepted%endpoint_count
  if(.not.allocated(routing%endpoint_amount).or.size(routing%endpoint_amount)/=n)return
  if(.not.allocated(request%endpoint_area_fraction).or.size(request%endpoint_area_fraction)/=n)return
  if(.not.allocated(request%endpoint_bottom_depth_cm).or.size(request%endpoint_bottom_depth_cm)/=n)return
  if(.not.allocated(request%endpoint_contact_thickness_cm).or.size(request%endpoint_contact_thickness_cm)/=n)return
  if(.not.allocated(request%endpoint_node_index).or.size(request%endpoint_node_index)/=n)return
  if(.not.allocated(request%endpoint_sorptivity_cm_sqrt_day).or.size(request%endpoint_sorptivity_cm_sqrt_day)/=n)return
  if(.not.allocated(request%endpoint_conductivity_cm_per_day).or.size(request%endpoint_conductivity_cm_per_day)/=n)return
  if(.not.allocated(request%node_depth_cm).or..not.allocated(request%node_thickness_cm).or. &
     .not.allocated(request%matrix_pressure_head_cm))return
  if(size(request%node_depth_cm)/=size(request%node_thickness_cm).or. &
     size(request%node_depth_cm)/=size(request%matrix_pressure_head_cm))return
  if(.not.ieee_is_finite(request%exchange_length_cm).or.request%exchange_length_cm<=0.0_real64)return
  if(.not.ieee_is_finite(request%chi_wall).or.request%chi_wall<0.0_real64)return
  effective=request%effective_supply_rate_cm_per_day*request%step_duration_day
  matrix=request%matrix_supply_rate_cm_per_day*request%step_duration_day
  ic=sum(routing%endpoint_amount)*request%step_duration_day
  mb=routing%mb_amount*request%step_duration_day
  if(min(effective,matrix,ic,mb)<0.0_real64)return
  if(abs(effective-matrix-ic-mb)>tolerance)return
  allocate(input(n),trial_storage(n),dh(n))
  input=routing%endpoint_amount*request%step_duration_day
  trial_storage=accepted%endpoint_water_cm+input
  do i=1,n
   node=request%endpoint_node_index(i)
   if(node<1.or.node>size(request%node_depth_cm))return
   call derive_rfm_ic_water_column(trial_storage(i),request%endpoint_area_fraction(i), &
        request%endpoint_contact_thickness_cm(i),tolerance,g)
   if(.not.g%valid)return
   call derive_rfm_ic_hydrostatic_head(request%endpoint_bottom_depth_cm(i),request%endpoint_contact_thickness_cm(i), &
        g%water_column_height_cm,request%node_depth_cm(node),request%matrix_pressure_head_cm(node),h)
   if(.not.h%valid)return
   dh(i)=h%macro_to_matrix_head_difference_cm
  end do
  er%step_duration_day=request%step_duration_day
  allocate(er%accepted_storage_cm(n),er%contact_thickness_cm(n),er%exchange_length_cm(n),er%chi_wall(n), &
       er%wall_sorptivity_cm_sqrt_day(n),er%matrix_conductivity_cm_per_day(n), &
       er%macro_to_matrix_head_difference_cm(n),er%accepted_wall_age_day(n))
  er%accepted_storage_cm=trial_storage
  er%contact_thickness_cm=request%endpoint_contact_thickness_cm
  er%exchange_length_cm=request%exchange_length_cm
  er%chi_wall=request%chi_wall
  er%wall_sorptivity_cm_sqrt_day=request%endpoint_sorptivity_cm_sqrt_day
  er%matrix_conductivity_cm_per_day=request%endpoint_conductivity_cm_per_day
  er%macro_to_matrix_head_difference_cm=dh
  er%accepted_wall_age_day=accepted%wall_age_day
  call evaluate_rfm_endpoint_release(er,tolerance,result%endpoint_release)
  if(.not.result%endpoint_release%valid)return
  call copy_rfm_physical_state(accepted,result%candidate_rfm,ok);if(.not.ok)return
  result%candidate_rfm%endpoint_water_cm=result%endpoint_release%candidate_storage_cm
  result%candidate_rfm%wall_age_day=result%endpoint_release%candidate_wall_age_day
  result%candidate_rfm%wall_sorptivity_cm_sqrt_day=result%endpoint_release%candidate_wall_sorptivity_cm_sqrt_day
  result%candidate_rfm%mb_water_cm=0.0_real64
  result%candidate_rfm%tau_surface_day=request%candidate_tau_surface_day
  allocate(result%matrix_source_rate_per_day(size(request%node_depth_cm)));result%matrix_source_rate_per_day=0.0_real64
  do i=1,n
   node=request%endpoint_node_index(i)
   result%matrix_source_rate_per_day(node)=result%matrix_source_rate_per_day(node)+ &
    result%endpoint_release%release_to_matrix_cm(i)/(request%node_thickness_cm(node)*request%step_duration_day)
  end do
  ! A26I leading MB route: fast-through film has no lateral wall exchange.
  result%deep_receipt_cm=mb
  lr%effective_input_cm=effective;lr%matrix_input_cm=matrix;lr%ic_input_cm=ic;lr%mb_input_cm=mb
  lr%endpoint_storage_start_cm=sum(accepted%endpoint_water_cm)
  lr%endpoint_to_matrix_cm=result%endpoint_release%release_total_cm
  lr%endpoint_storage_end_cm=sum(result%candidate_rfm%endpoint_water_cm)
  lr%mb_wall_to_matrix_cm=0.0_real64;lr%mb_deep_receipt_cm=mb;lr%mb_storage_end_cm=0.0_real64
  call evaluate_rfm_whole_column_candidate_ledger(lr,tolerance,result%ledger)
  if(.not.result%ledger%valid)return
  result%valid=.true.
 end subroutine
end module
