module mod_rfm_wall_hydraulic_history_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t, validate_process_hydraulic_view
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_rfm_physical_state, only: rfm_physical_state_t
  use mod_rfm_surface_sorptivity, only: evaluate_rfm_node_sorptivity
  implicit none
  private

  type, public :: rfm_wall_hydraulic_binding_result_t
    logical :: valid=.false.
    real(real64),allocatable :: endpoint_sorptivity_cm_sqrt_day(:)
    real(real64),allocatable :: endpoint_conductivity_cm_per_day(:)
    real(real64) :: mb_sorptivity_cm_sqrt_day=0.0_real64
    real(real64) :: mb_conductivity_cm_per_day=0.0_real64
  end type

  public :: bind_rfm_wall_hydraulics_from_accepted

contains

  subroutine bind_rfm_wall_hydraulics_from_accepted(accepted,endpoint_input_cm,endpoint_node_index,mb_wall_node_index, &
       view,constitutive,panels,result,skip_unused_mb_hydraulics,endpoint_panels,mb_panels)
    type(rfm_physical_state_t),intent(in)::accepted
    real(real64),intent(in)::endpoint_input_cm(:)
    integer,intent(in)::endpoint_node_index(:),mb_wall_node_index,panels
    type(process_hydraulic_view_t),intent(in)::view
    class(constitutive_hydraulics_provider_t),intent(in)::constitutive
    type(rfm_wall_hydraulic_binding_result_t),intent(out)::result
    logical,intent(in),optional::skip_unused_mb_hydraulics
    integer,intent(in),optional::endpoint_panels(:),mb_panels
    integer::i,n,node,panel_count
    logical::view_ok,available,sok,skip_mb
    real(real64)::s,k

    result=rfm_wall_hydraulic_binding_result_t()
    skip_mb=.false.;if(present(skip_unused_mb_hydraulics))skip_mb=skip_unused_mb_hydraulics
    if(.not.accepted%ready().or.panels<=0)return
    call validate_process_hydraulic_view(view,view_ok);if(.not.view_ok)return
    n=accepted%endpoint_count
    if(size(endpoint_input_cm)/=n.or.size(endpoint_node_index)/=n)return
    if(present(endpoint_panels))then
      if(size(endpoint_panels)/=n.or.any(endpoint_panels<=0))return
    end if
    if(present(mb_panels))then
      if(mb_panels<=0)return
    end if
    if(any(endpoint_input_cm<0.0_real64).or.any(.not.ieee_is_finite(endpoint_input_cm)))return
    if(any(endpoint_node_index<1).or.any(endpoint_node_index>view%active_nodes))return
    if(mb_wall_node_index<1.or.mb_wall_node_index>view%active_nodes)return
    allocate(result%endpoint_sorptivity_cm_sqrt_day(n),result%endpoint_conductivity_cm_per_day(n))
    do i=1,n
      node=endpoint_node_index(i)
      call constitutive%evaluate_point_conductivity(node,view%pressure_head(node),view%water_content(node),k,available)
      if(.not.available.or..not.ieee_is_finite(k).or.k<0.0_real64)return
      result%endpoint_conductivity_cm_per_day(i)=k
      if(accepted%endpoint_water_cm(i)>0.0_real64)then
        s=accepted%wall_sorptivity_cm_sqrt_day(i)
        if(.not.ieee_is_finite(s).or.s<0.0_real64)return
      else if(endpoint_input_cm(i)>0.0_real64)then
        panel_count=panels;if(present(endpoint_panels))panel_count=endpoint_panels(i)
        call evaluate_rfm_node_sorptivity(view,constitutive,node,panel_count,s,sok)
        if(.not.sok)return
      else
        s=0.0_real64
      end if
      result%endpoint_sorptivity_cm_sqrt_day(i)=s
    end do
    if(.not.skip_mb)then
      node=mb_wall_node_index
      call constitutive%evaluate_point_conductivity(node,view%pressure_head(node),view%water_content(node),k,available)
      if(.not.available.or..not.ieee_is_finite(k).or.k<0.0_real64)return
      panel_count=panels;if(present(mb_panels))panel_count=mb_panels
      call evaluate_rfm_node_sorptivity(view,constitutive,node,panel_count,s,sok);if(.not.sok)return
      result%mb_conductivity_cm_per_day=k
      result%mb_sorptivity_cm_sqrt_day=s
    end if
    result%valid=.true.
  end subroutine
end module mod_rfm_wall_hydraulic_history_binding
