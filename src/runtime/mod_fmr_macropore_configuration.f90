module mod_fmr_macropore_configuration
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_config_t
  use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t
  use mod_ppa_wu05a6_sorptivity_history, only: sorptivity_history_update_request_t
  implicit none
  private

  type, public :: fmr_macropore_physical_config_t
    type(macropore_geometry_config_t) :: geometry
    type(macropore_rate_bundle_request_t) :: rate_template
    type(sorptivity_history_update_request_t) :: history_template
  contains
    procedure, public :: valid_for_nodes => fmr_macropore_config_valid_for_nodes
  end type fmr_macropore_physical_config_t

contains

  pure logical function fmr_macropore_config_valid_for_nodes(self, active_nodes) result(ok)
    class(fmr_macropore_physical_config_t), intent(in) :: self
    integer, intent(in) :: active_nodes
    integer :: nd

    ok = .false.
    if (active_nodes <= 0) return
    if (.not. self%geometry%valid()) return
    if (self%geometry%num_nodes /= active_nodes) return

    nd = self%geometry%num_domains
    if (nd <= 0) return

    if (.not. self%rate_template%unsaturated%valid()) return
    if (.not. self%rate_template%interflow_sat%valid()) return
    if (.not. self%rate_template%matrix_sat%valid()) return
    if (.not. self%rate_template%rapid%valid()) return
    if (.not. self%rate_template%limiter%valid()) return
    if (.not. self%history_template%valid()) return

    if (self%rate_template%unsaturated%sorptivity%num_domains /= nd .or. &
        self%rate_template%unsaturated%sorptivity%num_nodes /= active_nodes) return
    if (self%rate_template%interflow_sat%num_domains /= nd .or. &
        self%rate_template%interflow_sat%num_nodes /= active_nodes) return
    if (self%rate_template%matrix_sat%num_domains /= nd .or. &
        self%rate_template%matrix_sat%num_nodes /= active_nodes) return
    if (self%rate_template%limiter%num_domains /= nd) return
    if (self%history_template%num_domains /= nd .or. &
        self%history_template%num_nodes /= active_nodes) return

    ! First FMR admission scope: standard route only.
    if (self%rate_template%unsaturated%sorptivity%swmbf /= 1) return

    ! No perched-zone physics until an explicit FMR carrier exists.
    if (self%rate_template%unsaturated%sorptivity%perched_active) return
    if (self%rate_template%interflow_sat%matrix_bottom_saturated_node /= 0) return

    ! No source-faithful surface-to-macropore forcing in this first FMR slice.
    if (any(abs(self%rate_template%limiter%potential_top_vertical_cm) > 1.0e-15_real64)) return
    if (any(abs(self%rate_template%limiter%potential_top_lateral_cm) > 1.0e-15_real64)) return

    ! Rapid drainage remains out of the first FMR admission slice.
    if (self%rate_template%rapid%enabled) return

    ! Template geometry/history must use the same top node.
    if (self%history_template%top_node /= self%geometry%top_node) return
    if (self%rate_template%top_node /= self%geometry%top_node) return

    ! Immutable geometry dimensions must agree with rate/history arrays.
    if (.not. allocated(self%rate_template%unsaturated%sorptivity%domain_fraction)) return
    if (.not. allocated(self%history_template%domain_fraction)) return
    if (any(shape(self%rate_template%unsaturated%sorptivity%domain_fraction) /= &
            [nd,active_nodes])) return
    if (any(shape(self%history_template%domain_fraction) /= [nd,active_nodes])) return

    ok = .true.
  end function fmr_macropore_config_valid_for_nodes

end module mod_fmr_macropore_configuration
