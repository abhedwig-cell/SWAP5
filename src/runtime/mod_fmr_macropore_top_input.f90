module mod_fmr_macropore_top_input
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_config_t, macropore_geometry_result_t
  implicit none
  private

  type, public :: fmr_macropore_top_input_forcing_t
    logical :: supplied = .false.
    real(real64) :: net_rain_rate_cm_per_day = 0.0_real64
    real(real64) :: net_irrigation_rate_cm_per_day = 0.0_real64
    real(real64) :: melt_rate_cm_per_day = 0.0_real64
    real(real64) :: lateral_overland_rate_cm_per_day = 0.0_real64
  contains
    procedure, public :: valid => fmr_macropore_top_input_valid
  end type fmr_macropore_top_input_forcing_t

  public :: prepare_fmr_macropore_top_input

contains

  pure logical function fmr_macropore_top_input_valid(self) result(ok)
    class(fmr_macropore_top_input_forcing_t), intent(in) :: self
    real(real64) :: values(4)

    values = [self%net_rain_rate_cm_per_day, self%net_irrigation_rate_cm_per_day, &
         self%melt_rate_cm_per_day, self%lateral_overland_rate_cm_per_day]
    ok = all(ieee_is_finite(values)) .and. all(values >= 0.0_real64)
    if (.not. ok) return
    if (.not. self%supplied) ok = all(values == 0.0_real64)
  end function fmr_macropore_top_input_valid

  subroutine prepare_fmr_macropore_top_input(forcing, geometry_config, geometry, step_duration, &
       requested_vertical_cm, requested_lateral_cm, ok)
    type(fmr_macropore_top_input_forcing_t), intent(in) :: forcing
    type(macropore_geometry_config_t), intent(in) :: geometry_config
    type(macropore_geometry_result_t), intent(in) :: geometry
    real(real64), intent(in) :: step_duration
    real(real64), allocatable, intent(out) :: requested_vertical_cm(:)
    real(real64), allocatable, intent(out) :: requested_lateral_cm(:)
    logical, intent(out) :: ok

    integer :: nd, top
    real(real64) :: direct_rate, top_volume, top_area_fraction
    real(real64), allocatable :: domain_top_volume(:)

    ok = .false.
    if (.not. forcing%valid()) return
    if (.not. geometry_config%valid() .or. .not. geometry%valid) return
    if (step_duration <= 0.0_real64 .or. .not. ieee_is_finite(step_duration)) return
    if (geometry_config%top_node /= 1 .or. geometry%top_node /= geometry_config%top_node) return
    if (geometry%num_domains /= geometry_config%num_domains .or. &
        geometry%num_nodes /= geometry_config%num_nodes) return

    nd = geometry%num_domains
    top = geometry%top_node
    allocate(requested_vertical_cm(nd), requested_lateral_cm(nd), domain_top_volume(nd))
    requested_vertical_cm = 0.0_real64
    requested_lateral_cm = 0.0_real64

    if (.not. forcing%supplied) then
      ok = .true.
      return
    end if

    domain_top_volume = geometry%volume_domain_cp(:,top)
    top_volume = sum(domain_top_volume)
    direct_rate = forcing%net_rain_rate_cm_per_day + forcing%net_irrigation_rate_cm_per_day + &
         forcing%melt_rate_cm_per_day

    if ((direct_rate > 0.0_real64 .or. forcing%lateral_overland_rate_cm_per_day > 0.0_real64) .and. &
        top_volume <= 1.0e-30_real64) return

    if(geometry%surface_area_fraction>=0.0_real64)then
      top_area_fraction=geometry%surface_area_fraction
    else
      top_area_fraction = top_volume / geometry_config%dz(top)
    end if
    if (.not. ieee_is_finite(top_area_fraction) .or. top_area_fraction < 0.0_real64) return

    if(geometry%surface_area_fraction>=0.0_real64)then
      requested_vertical_cm=geometry_config%domain_fraction(:,top)*top_area_fraction*direct_rate*step_duration
      requested_lateral_cm=geometry_config%domain_fraction(:,top)* &
           forcing%lateral_overland_rate_cm_per_day*step_duration
    else
      requested_vertical_cm = domain_top_volume / geometry_config%dz(top) * direct_rate * step_duration
      if (top_volume > 1.0e-30_real64) then
        requested_lateral_cm = domain_top_volume / top_volume * &
             forcing%lateral_overland_rate_cm_per_day * step_duration
      end if
    end if

    if (any(.not. ieee_is_finite(requested_vertical_cm)) .or. &
        any(.not. ieee_is_finite(requested_lateral_cm))) return
    if (any(requested_vertical_cm < 0.0_real64) .or. any(requested_lateral_cm < 0.0_real64)) return

    if (abs(sum(requested_vertical_cm) - top_area_fraction*direct_rate*step_duration) > 1.0e-12_real64) return
    if (abs(sum(requested_lateral_cm) - forcing%lateral_overland_rate_cm_per_day*step_duration) > 1.0e-12_real64) return

    ok = .true.
  end subroutine prepare_fmr_macropore_top_input

end module mod_fmr_macropore_top_input
