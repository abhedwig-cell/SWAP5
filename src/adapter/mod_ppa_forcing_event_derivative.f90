! Candidate-only, read-only right-limit derivative. No runtime activation here.
module mod_ppa_forcing_event_derivative
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_solve_request_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_ppa_mvg_storage_binding, only: evaluate_bound_mvg_storage_difference
  implicit none
  private
  public :: evaluate_forcing_event_derivative
contains
  subroutine evaluate_forcing_event_derivative(request,derivative,available)
    type(soil_water_solve_request_t),intent(in)::request
    real(real64),intent(out)::derivative(:)
    logical,intent(out)::available
    real(real64),allocatable::water(:),k(:),capacity(:),dk(:),source(:),sink(:),flux(:),trial(:)
    integer::n,j
    logical::compatible
    derivative=0.0_real64
    available=.false.
    if(.not.associated(request%parameters))return
    n=request%parameters%active_nodes
    if(n<=0.or.size(derivative)/=n.or.request%base_state%active_nodes/=n)return
    if(request%boundary%top_mode/=FSI_TOP_MODE_EXPLICIT_FLUX.or.request%boundary%bottom_mode/=7)return
    if(request%numerical%conductivity_mean_method/=1.or.request%numerical%conductivity_implicit_mode/=0)return
    if(request%physical%macropore_active.or.associated(request%evaluation%macropore))return
    if(associated(request%evaluation%root_sink).or.associated(request%evaluation%dynamic_top_boundary))return
    if(.not.associated(request%evaluation%constitutive).or..not.associated(request%evaluation%source_sink).or. &
         .not.associated(request%evaluation%top_boundary))return
    select type(top=>request%evaluation%top_boundary)
    type is(fixed_flux_top_boundary_provider_t)
    class default
      return
    end select
    if(.not.allocated(request%base_state%pressure_head).or..not.allocated(request%base_state%water_content))return
    if(.not.allocated(request%parameters%dz).or..not.allocated(request%parameters%node_distance))return
    if(size(request%base_state%pressure_head)/=n.or.size(request%base_state%water_content)/=n)return
    if(size(request%parameters%dz)/=n.or.size(request%parameters%node_distance)/=n)return
    if(.not.all(ieee_is_finite(request%parameters%dz)).or. &
         .not.all(ieee_is_finite(request%parameters%node_distance)))return
    if(any(request%parameters%dz<1.0e-8_real64).or.any(request%parameters%dz>1.0e6_real64))return
    if(any(request%parameters%node_distance(2:n)<1.0e-8_real64).or. &
         any(request%parameters%node_distance(2:n)>1.0e6_real64))return
    if(.not.ieee_is_finite(request%boundary%top_flux))return
    if(abs(request%boundary%top_flux)>1.0e6_real64)return
    allocate(water(n),k(n),capacity(n),dk(n),source(n),sink(n),flux(n+1),trial(n))
    select type(provider=>request%evaluation%constitutive)
    type is(b110_default_mvg_provider_t)
      if(.not.ieee_is_finite(provider%step_duration))return
      if(provider%step_duration<=0.0_real64)return
      call evaluate_bound_mvg_storage_difference(provider,request%base_state%pressure_head, &
           request%base_state%water_content,request%base_state%pressure_head,trial,compatible)
      if(.not.compatible)return
      if(size(provider%parameters%cofgen,1)<42)return
      ! Deliberately bounded arithmetic envelope before provider power evaluation.
      if(any(request%base_state%pressure_head< -1.0e4_real64))return
      do j=1,n
        associate(c=>provider%parameters%cofgen(:,j))
          if(c(3)<=0.0_real64.or.c(3)>1.0e6_real64)return
          if(c(4)<1.0e-8_real64.or.c(4)>1.0_real64)return
          if(c(5)<0.0_real64.or.c(5)>1.0_real64)return
          if(c(6)<=1.0_real64.or.c(6)>3.0_real64.or.c(7)<0.1_real64)return
        end associate
      end do
      call provider%evaluate(request%base_state%pressure_head,water,k,capacity,dk)
    class default
      return
    end select
    if(.not.all(ieee_is_finite(k)).or..not.all(ieee_is_finite(capacity)))return
    if(any(k<=0.0_real64).or.any(k>1.0e6_real64).or.any(capacity<1.0e-20_real64))return
    select type(provider=>request%evaluation%source_sink)
    type is(b110_source_sink_provider_t)
      if(provider%active_nodes/=n.or.provider%drainage_levels<=0)return
      if(.not.associated(provider%drainage_flux_by_level).or. &
           .not.associated(provider%subsurface_irrigation_source).or..not.associated(provider%root_extraction_sink))return
      if(size(provider%drainage_flux_by_level,1)/=provider%drainage_levels.or. &
           size(provider%drainage_flux_by_level,2)/=n)return
      if(size(provider%subsurface_irrigation_source)/=n.or.size(provider%root_extraction_sink)/=n)return
      if(.not.all(ieee_is_finite(provider%drainage_flux_by_level)).or. &
           .not.all(ieee_is_finite(provider%subsurface_irrigation_source)).or. &
           .not.all(ieee_is_finite(provider%root_extraction_sink)))return
      if(any(provider%root_extraction_sink/=0.0_real64))return
      if(any(abs(provider%drainage_flux_by_level)>1.0e6_real64).or. &
           any(abs(provider%subsurface_irrigation_source)>1.0e6_real64))return
      call provider%evaluate(request%base_state%pressure_head,water,source,sink)
    class default
      return
    end select
    flux(1)=request%boundary%top_flux
    do j=2,n
      flux(j)=-0.5_real64*(k(j-1)+k(j))* &
           ((request%base_state%pressure_head(j-1)-request%base_state%pressure_head(j))/ &
           request%parameters%node_distance(j)+1.0_real64)
    end do
    flux(n+1)=-k(n)
    trial=(flux(2:n+1)-flux(1:n)+source-sink)/(capacity*request%parameters%dz)
    if(.not.all(ieee_is_finite(trial)))return
    derivative=trial
    available=.true.
  end subroutine
end module
