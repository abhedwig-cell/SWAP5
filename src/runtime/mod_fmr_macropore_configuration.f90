module mod_fmr_macropore_configuration
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_config_t
  use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t
  use mod_ppa_wu05a6_sorptivity_history, only: sorptivity_history_update_request_t
  implicit none
  private

  public :: initialize_fmr_macropore_standard_config

  type, public :: fmr_macropore_physical_config_t
    type(macropore_geometry_config_t) :: geometry
    type(macropore_rate_bundle_request_t) :: rate_template
    type(sorptivity_history_update_request_t) :: history_template
  contains
    procedure, public :: valid_for_nodes => fmr_macropore_config_valid_for_nodes
  end type fmr_macropore_physical_config_t

contains


  subroutine initialize_fmr_macropore_standard_config(config, top_node, static_volume_cp, domain_fraction, &
       potential_bottom_domain, z, dz, diameter, theta_s, theta_r, wall_correction, sorptivity_max, &
       sorptivity_alpha, conductivity, entry_head, sorp_fac_parallel, ksat_horizontal, cdarcy, &
       flow_reduction, shape_factor, swsep, ok, rapid_enabled, rapid_drain_type, rapid_drain_level_cm, &
       rapid_area_exponent, rapid_kd_reference, rapid_resistance_reference_day, perched_enabled, &
       critical_under_saturated_volume_cm)
    type(fmr_macropore_physical_config_t), intent(out) :: config
    integer, intent(in) :: top_node
    real(real64), intent(in) :: static_volume_cp(:), domain_fraction(:,:), z(:), dz(:), diameter(:)
    integer, intent(in) :: potential_bottom_domain(:)
    real(real64), intent(in) :: theta_s(:), theta_r(:), wall_correction(:), sorptivity_max(:), sorptivity_alpha(:)
    real(real64), intent(in) :: conductivity(:), entry_head(:), sorp_fac_parallel(:), ksat_horizontal(:)
    real(real64), intent(in) :: cdarcy(:,:)
    real(real64), intent(in) :: flow_reduction, shape_factor
    integer, intent(in) :: swsep
    logical, intent(out) :: ok
    logical, intent(in), optional :: rapid_enabled
    integer, intent(in), optional :: rapid_drain_type
    real(real64), intent(in), optional :: rapid_drain_level_cm, rapid_area_exponent, rapid_kd_reference, &
         rapid_resistance_reference_day, critical_under_saturated_volume_cm
    logical, intent(in), optional :: perched_enabled

    integer :: n, nd, id
    real(real64) :: bottom_level
    logical :: rapid_on, perched_on
    real(real64) :: perched_crit

    config = fmr_macropore_physical_config_t()
    ok = .false.
    rapid_on = .false.
    if (present(rapid_enabled)) rapid_on = rapid_enabled
    perched_on = .false.
    if (present(perched_enabled)) perched_on = perched_enabled
    perched_crit = 0.0_real64
    if (present(critical_under_saturated_volume_cm)) perched_crit = critical_under_saturated_volume_cm
    if (perched_crit < 0.0_real64) return

    n = size(static_volume_cp)
    if (n <= 0) return
    nd = size(domain_fraction,1)
    if (nd <= 0 .or. size(domain_fraction,2) /= n) return
    if (top_node < 1 .or. top_node > n) return
    if (size(potential_bottom_domain) /= nd) return
    if (size(z) /= n .or. size(dz) /= n .or. size(diameter) /= n) return
    if (size(theta_s) /= n .or. size(theta_r) /= n .or. size(wall_correction) /= n) return
    if (size(sorptivity_max) /= n .or. size(sorptivity_alpha) /= n) return
    if (size(conductivity) /= n .or. size(entry_head) /= n .or. size(sorp_fac_parallel) /= n) return
    if (size(ksat_horizontal) /= n .or. any(shape(cdarcy) /= [nd,n])) return
    if (flow_reduction < 0.0_real64 .or. shape_factor < 0.0_real64) return

    config%geometry%num_domains = nd
    config%geometry%num_nodes = n
    config%geometry%top_node = top_node
    config%geometry%static_volume_cp = static_volume_cp
    config%geometry%domain_fraction = domain_fraction
    config%geometry%potential_bottom_domain = potential_bottom_domain
    config%geometry%dz = dz
    config%geometry%characteristic_diameter = diameter
    if (.not. config%geometry%valid()) return

    config%rate_template%unsaturated%sorptivity%num_domains = nd
    config%rate_template%unsaturated%sorptivity%num_nodes = n
    config%rate_template%unsaturated%sorptivity%top_node = top_node
    config%rate_template%unsaturated%sorptivity%swmbf = 1
    config%rate_template%unsaturated%sorptivity%matrix_top_saturated_node = n + 1
    config%rate_template%unsaturated%sorptivity%perched_active = .false.
    config%rate_template%unsaturated%sorptivity%step_duration = 1.0_real64
    config%rate_template%unsaturated%sorptivity%flow_reduction = flow_reduction
    config%rate_template%unsaturated%sorptivity%bottom_domain = potential_bottom_domain
    config%rate_template%unsaturated%sorptivity%top_water_node = potential_bottom_domain
    config%rate_template%unsaturated%sorptivity%theta = theta_r
    config%rate_template%unsaturated%sorptivity%theta_s = theta_s
    config%rate_template%unsaturated%sorptivity%theta_r = theta_r
    config%rate_template%unsaturated%sorptivity%dz = dz
    config%rate_template%unsaturated%sorptivity%diameter = diameter
    config%rate_template%unsaturated%sorptivity%wall_correction = wall_correction
    config%rate_template%unsaturated%sorptivity%sorptivity_max = sorptivity_max
    config%rate_template%unsaturated%sorptivity%sorptivity_alpha = sorptivity_alpha
    config%rate_template%unsaturated%sorptivity%domain_fraction = domain_fraction
    config%rate_template%unsaturated%sorptivity%wet_fraction = 0.0_real64*domain_fraction
    config%rate_template%unsaturated%sorptivity%history_sorptivity = 0.0_real64*domain_fraction
    config%rate_template%unsaturated%sorptivity%history_theta_ref = 0.0_real64*domain_fraction
    config%rate_template%unsaturated%sorptivity%history_absorption_time = 0.0_real64*domain_fraction

    config%rate_template%unsaturated%shape_factor = shape_factor
    config%rate_template%unsaturated%pressure_head = -1.0_real64 + 0.0_real64*z
    config%rate_template%unsaturated%elevation = z
    config%rate_template%unsaturated%conductivity = conductivity
    config%rate_template%unsaturated%entry_head = entry_head
    config%rate_template%unsaturated%groundwater_level_domain = z(potential_bottom_domain)
    config%rate_template%unsaturated%sorp_fac_parallel = sorp_fac_parallel

    bottom_level = z(potential_bottom_domain(1)) - 0.5_real64*dz(potential_bottom_domain(1))
    call initialize_saturated_template(config%rate_template%interflow_sat)
    call initialize_saturated_template(config%rate_template%matrix_sat)

    config%rate_template%rapid%num_nodes = n
    config%rate_template%rapid%top_water_node = potential_bottom_domain(1)
    config%rate_template%rapid%bottom_domain_node = potential_bottom_domain(1)
    config%rate_template%rapid%drain_type = 2
    if (present(rapid_drain_type)) config%rate_template%rapid%drain_type = rapid_drain_type
    config%rate_template%rapid%enabled = rapid_on
    config%rate_template%rapid%saturated_top_fraction = 0.0_real64
    config%rate_template%rapid%water_level_cm = bottom_level
    config%rate_template%rapid%domain_bottom_cm = bottom_level
    config%rate_template%rapid%drain_level_cm = bottom_level
    if (present(rapid_drain_level_cm)) config%rate_template%rapid%drain_level_cm = rapid_drain_level_cm
    config%rate_template%rapid%ponding_cm = 0.0_real64
    config%rate_template%rapid%step_duration = 1.0_real64
    config%rate_template%rapid%area_exponent = 3.0_real64
    if (present(rapid_area_exponent)) config%rate_template%rapid%area_exponent = rapid_area_exponent
    config%rate_template%rapid%kd_reference = 1.0_real64
    if (present(rapid_kd_reference)) config%rate_template%rapid%kd_reference = rapid_kd_reference
    config%rate_template%rapid%resistance_reference_day = 1.0_real64
    if (present(rapid_resistance_reference_day)) &
         config%rate_template%rapid%resistance_reference_day = rapid_resistance_reference_day
    config%rate_template%rapid%flow_reduction = flow_reduction
    config%rate_template%rapid%water_storage_cm = 0.0_real64
    config%rate_template%rapid%volume_under_drain_cm = 0.0_real64
    config%rate_template%rapid%diameter = diameter
    config%rate_template%rapid%dz = dz
    config%rate_template%rapid%volume_main_domain_cp = static_volume_cp*domain_fraction(1,:)

    config%rate_template%limiter%num_domains = nd
    config%rate_template%limiter%accepted_storage_cm = 0.0_real64*real(potential_bottom_domain,real64)
    config%rate_template%limiter%maximum_storage_cm = &
         [(sum(static_volume_cp(top_node:potential_bottom_domain(id))* &
               domain_fraction(id,top_node:potential_bottom_domain(id))), id=1,nd)]
    config%rate_template%limiter%minimum_storage_cm = 0.0_real64*real(potential_bottom_domain,real64)
    config%rate_template%limiter%potential_top_vertical_cm = 0.0_real64*real(potential_bottom_domain,real64)
    config%rate_template%limiter%potential_top_lateral_cm = 0.0_real64*real(potential_bottom_domain,real64)
    config%rate_template%limiter%potential_interflow_sat_cm = 0.0_real64*real(potential_bottom_domain,real64)
    config%rate_template%limiter%potential_matrix_sat_cm = 0.0_real64*real(potential_bottom_domain,real64)
    config%rate_template%limiter%potential_outflow_cm = 0.0_real64*real(potential_bottom_domain,real64)
    config%rate_template%limiter%redistribution_capacity_cm = config%rate_template%limiter%maximum_storage_cm
    config%rate_template%limiter%top_domain_fraction = domain_fraction(:,top_node)
    config%rate_template%top_node = top_node
    config%rate_template%perched_detection_enabled = perched_on
    config%rate_template%critical_under_saturated_volume_cm = perched_crit

    config%history_template%num_domains = nd
    config%history_template%num_nodes = n
    config%history_template%top_node = top_node
    config%history_template%matrix_top_saturated_node = n + 1
    config%history_template%step_duration = 1.0_real64
    config%history_template%bottom_domain = potential_bottom_domain
    config%history_template%top_water_node = potential_bottom_domain
    config%history_template%wall_correction = wall_correction
    config%history_template%wet_fraction = 0.0_real64*domain_fraction
    config%history_template%domain_fraction = domain_fraction
    config%history_template%diameter = diameter

    ok = config%valid_for_nodes(n)

  contains

    subroutine initialize_saturated_template(sat)
      use mod_ppa_wu05a6_saturated_exchange_rate, only: saturated_exchange_request_t
      type(saturated_exchange_request_t), intent(out) :: sat

      sat%num_domains = nd
      sat%num_nodes = n
      sat%matrix_top_saturated_node = 1
      sat%matrix_bottom_saturated_node = 0
      sat%matrix_partial_top_active = .true.
      sat%swsep = swsep
      sat%matrix_level = bottom_level
      sat%step_duration = 1.0_real64
      sat%flow_reduction = flow_reduction
      sat%shape_factor = shape_factor
      sat%bottom_domain = potential_bottom_domain
      sat%top_macro_saturated_node = potential_bottom_domain
      sat%macro_saturated_fraction = 0.0_real64*real(potential_bottom_domain,real64)
      sat%macro_reference_level = z(potential_bottom_domain)
      sat%z = z
      sat%dz = dz
      sat%matrix_head = -1.0_real64 + 0.0_real64*z
      sat%ksat_horizontal = ksat_horizontal
      sat%diameter = diameter
      sat%domain_fraction = domain_fraction
      sat%cdarcy = cdarcy
    end subroutine initialize_saturated_template

  end subroutine initialize_fmr_macropore_standard_config

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

    ! The immutable template remains neutral. PERCH21 derives perched topology
    ! from the current matrix hydraulic state when explicitly enabled.
    if (self%rate_template%unsaturated%sorptivity%perched_active) return
    if (self%rate_template%interflow_sat%matrix_bottom_saturated_node /= 0) return
    if (self%rate_template%critical_under_saturated_volume_cm < 0.0_real64) return

    ! Dynamic A9 top forcing is interval-owned; the immutable template remains neutral.
    if (any(abs(self%rate_template%limiter%potential_top_vertical_cm) > 1.0e-15_real64)) return
    if (any(abs(self%rate_template%limiter%potential_top_lateral_cm) > 1.0e-15_real64)) return

    ! A10 rapid drainage may be enabled only with a drain level aligned to a
    ! compartment boundary. This keeps below-drain volume reconstruction exact.
    if (self%rate_template%rapid%enabled) then
      if (.not. rapid_drain_level_aligned(self%rate_template%rapid%drain_level_cm, &
           self%rate_template%unsaturated%elevation, self%geometry%dz)) return
    end if

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

  pure logical function rapid_drain_level_aligned(level, z, dz) result(aligned)
    real(real64), intent(in) :: level
    real(real64), intent(in) :: z(:), dz(:)
    integer :: ic

    aligned = .false.
    if (size(z) /= size(dz) .or. size(z) <= 0) return
    do ic = 1, size(z)
      if (abs(level-(z(ic)+0.5_real64*dz(ic))) <= 1.0e-10_real64 .or. &
          abs(level-(z(ic)-0.5_real64*dz(ic))) <= 1.0e-10_real64) then
        aligned = .true.
        return
      end if
    end do
  end function rapid_drain_level_aligned

end module mod_fmr_macropore_configuration
