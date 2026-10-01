program test_fmr_macropore_configuration
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_macropore_configuration, only: fmr_macropore_physical_config_t
  implicit none

  integer, parameter :: n=3, nd=1
  type(fmr_macropore_physical_config_t) :: cfg

  call setup(cfg)

  if (.not. cfg%valid_for_nodes(n)) error stop 'A8 config valid baseline'

  cfg%rate_template%rapid%enabled = .true.
  if (cfg%valid_for_nodes(n)) error stop 'A8 config rapid should reject'
  cfg%rate_template%rapid%enabled = .false.

  cfg%rate_template%limiter%potential_top_vertical_cm = 0.01_real64
  if (cfg%valid_for_nodes(n)) error stop 'A8 config top input should reject'
  cfg%rate_template%limiter%potential_top_vertical_cm = 0.0_real64

  cfg%rate_template%unsaturated%sorptivity%perched_active = .true.
  if (cfg%valid_for_nodes(n)) error stop 'A8 config perched should reject'
  cfg%rate_template%unsaturated%sorptivity%perched_active = .false.

  if (cfg%valid_for_nodes(n+1)) error stop 'A8 config node mismatch'

  print '(a)', 'PPA_WU05A8_FMR_CONFIG=PASS'

contains

  subroutine setup(config)
    type(fmr_macropore_physical_config_t), intent(out) :: config

    config%geometry%num_domains=nd
    config%geometry%num_nodes=n
    config%geometry%top_node=1
    allocate(config%geometry%static_volume_cp(n),config%geometry%domain_fraction(nd,n), &
         config%geometry%potential_bottom_domain(nd),config%geometry%dz(n), &
         config%geometry%characteristic_diameter(n))
    config%geometry%static_volume_cp=0.5_real64
    config%geometry%domain_fraction=1.0_real64
    config%geometry%potential_bottom_domain=n
    config%geometry%dz=10.0_real64
    config%geometry%characteristic_diameter=4.0_real64

    allocate(config%rate_template%unsaturated%sorptivity%bottom_domain(nd), &
         config%rate_template%unsaturated%sorptivity%top_water_node(nd), &
         config%rate_template%unsaturated%sorptivity%theta(n), &
         config%rate_template%unsaturated%sorptivity%theta_s(n), &
         config%rate_template%unsaturated%sorptivity%theta_r(n), &
         config%rate_template%unsaturated%sorptivity%dz(n), &
         config%rate_template%unsaturated%sorptivity%diameter(n), &
         config%rate_template%unsaturated%sorptivity%wall_correction(n), &
         config%rate_template%unsaturated%sorptivity%sorptivity_max(n), &
         config%rate_template%unsaturated%sorptivity%sorptivity_alpha(n), &
         config%rate_template%unsaturated%sorptivity%domain_fraction(nd,n), &
         config%rate_template%unsaturated%sorptivity%wet_fraction(nd,n), &
         config%rate_template%unsaturated%sorptivity%history_sorptivity(nd,n), &
         config%rate_template%unsaturated%sorptivity%history_theta_ref(nd,n), &
         config%rate_template%unsaturated%sorptivity%history_absorption_time(nd,n), &
         config%rate_template%unsaturated%pressure_head(n), &
         config%rate_template%unsaturated%elevation(n), &
         config%rate_template%unsaturated%conductivity(n), &
         config%rate_template%unsaturated%entry_head(n), &
         config%rate_template%unsaturated%groundwater_level_domain(nd), &
         config%rate_template%unsaturated%sorp_fac_parallel(n))

    config%rate_template%unsaturated%sorptivity%num_domains=nd
    config%rate_template%unsaturated%sorptivity%num_nodes=n
    config%rate_template%unsaturated%sorptivity%top_node=1
    config%rate_template%unsaturated%sorptivity%swmbf=1
    config%rate_template%unsaturated%sorptivity%matrix_top_saturated_node=n+1
    config%rate_template%unsaturated%sorptivity%step_duration=0.1_real64
    config%rate_template%unsaturated%sorptivity%flow_reduction=1.0_real64
    config%rate_template%unsaturated%sorptivity%bottom_domain=n
    config%rate_template%unsaturated%sorptivity%top_water_node=1
    config%rate_template%unsaturated%sorptivity%theta=0.2_real64
    config%rate_template%unsaturated%sorptivity%theta_s=0.45_real64
    config%rate_template%unsaturated%sorptivity%theta_r=0.05_real64
    config%rate_template%unsaturated%sorptivity%dz=10.0_real64
    config%rate_template%unsaturated%sorptivity%diameter=4.0_real64
    config%rate_template%unsaturated%sorptivity%wall_correction=0.95_real64
    config%rate_template%unsaturated%sorptivity%sorptivity_max=0.002_real64
    config%rate_template%unsaturated%sorptivity%sorptivity_alpha=0.5_real64
    config%rate_template%unsaturated%sorptivity%domain_fraction=1.0_real64
    config%rate_template%unsaturated%sorptivity%wet_fraction=1.0_real64
    config%rate_template%unsaturated%sorptivity%history_sorptivity=0.0_real64
    config%rate_template%unsaturated%sorptivity%history_theta_ref=0.0_real64
    config%rate_template%unsaturated%sorptivity%history_absorption_time=0.0_real64
    config%rate_template%unsaturated%shape_factor=1.0_real64
    config%rate_template%unsaturated%pressure_head=-100.0_real64
    config%rate_template%unsaturated%elevation=[-10.0_real64,-20.0_real64,-30.0_real64]
    config%rate_template%unsaturated%conductivity=0.0_real64
    config%rate_template%unsaturated%entry_head=-1.0_real64
    config%rate_template%unsaturated%groundwater_level_domain=-100.0_real64
    config%rate_template%unsaturated%sorp_fac_parallel=0.5_real64

    call setup_sat(config%rate_template%interflow_sat)
    call setup_sat(config%rate_template%matrix_sat)

    config%rate_template%rapid%num_nodes=n
    config%rate_template%rapid%top_water_node=1
    config%rate_template%rapid%bottom_domain_node=n
    config%rate_template%rapid%drain_type=2
    config%rate_template%rapid%enabled=.false.
    config%rate_template%rapid%saturated_top_fraction=1.0_real64
    config%rate_template%rapid%water_level_cm=-100.0_real64
    config%rate_template%rapid%domain_bottom_cm=-35.0_real64
    config%rate_template%rapid%drain_level_cm=-20.0_real64
    config%rate_template%rapid%ponding_cm=0.0_real64
    config%rate_template%rapid%step_duration=0.1_real64
    config%rate_template%rapid%area_exponent=3.0_real64
    config%rate_template%rapid%kd_reference=0.001_real64
    config%rate_template%rapid%resistance_reference_day=20.0_real64
    config%rate_template%rapid%flow_reduction=1.0_real64
    config%rate_template%rapid%water_storage_cm=0.1_real64
    config%rate_template%rapid%volume_under_drain_cm=0.0_real64
    allocate(config%rate_template%rapid%diameter(n),config%rate_template%rapid%dz(n), &
         config%rate_template%rapid%volume_main_domain_cp(n))
    config%rate_template%rapid%diameter=4.0_real64
    config%rate_template%rapid%dz=10.0_real64
    config%rate_template%rapid%volume_main_domain_cp=0.5_real64

    config%rate_template%limiter%num_domains=nd
    allocate(config%rate_template%limiter%accepted_storage_cm(nd), &
         config%rate_template%limiter%maximum_storage_cm(nd), &
         config%rate_template%limiter%minimum_storage_cm(nd), &
         config%rate_template%limiter%potential_top_vertical_cm(nd), &
         config%rate_template%limiter%potential_top_lateral_cm(nd), &
         config%rate_template%limiter%potential_interflow_sat_cm(nd), &
         config%rate_template%limiter%potential_matrix_sat_cm(nd), &
         config%rate_template%limiter%potential_outflow_cm(nd), &
         config%rate_template%limiter%redistribution_capacity_cm(nd), &
         config%rate_template%limiter%top_domain_fraction(nd))
    config%rate_template%limiter%accepted_storage_cm=0.1_real64
    config%rate_template%limiter%maximum_storage_cm=1.5_real64
    config%rate_template%limiter%minimum_storage_cm=0.0_real64
    config%rate_template%limiter%potential_top_vertical_cm=0.0_real64
    config%rate_template%limiter%potential_top_lateral_cm=0.0_real64
    config%rate_template%limiter%potential_interflow_sat_cm=0.0_real64
    config%rate_template%limiter%potential_matrix_sat_cm=0.0_real64
    config%rate_template%limiter%potential_outflow_cm=0.0_real64
    config%rate_template%limiter%redistribution_capacity_cm=1.4_real64
    config%rate_template%limiter%top_domain_fraction=1.0_real64
    config%rate_template%top_node=1

    config%history_template%num_domains=nd
    config%history_template%num_nodes=n
    config%history_template%top_node=1
    config%history_template%matrix_top_saturated_node=n+1
    config%history_template%step_duration=0.1_real64
    allocate(config%history_template%bottom_domain(nd),config%history_template%top_water_node(nd), &
         config%history_template%wall_correction(n),config%history_template%wet_fraction(nd,n), &
         config%history_template%domain_fraction(nd,n),config%history_template%diameter(n))
    config%history_template%bottom_domain=n
    config%history_template%top_water_node=1
    config%history_template%wall_correction=0.95_real64
    config%history_template%wet_fraction=1.0_real64
    config%history_template%domain_fraction=1.0_real64
    config%history_template%diameter=4.0_real64
  end subroutine setup

  subroutine setup_sat(sat)
    use mod_ppa_wu05a6_saturated_exchange_rate, only: saturated_exchange_request_t
    type(saturated_exchange_request_t), intent(out) :: sat
    sat%num_domains=nd
    sat%num_nodes=n
    sat%matrix_top_saturated_node=1
    sat%matrix_bottom_saturated_node=0
    sat%swsep=0
    sat%matrix_level=-100.0_real64
    sat%step_duration=0.1_real64
    sat%flow_reduction=1.0_real64
    sat%shape_factor=1.0_real64
    allocate(sat%bottom_domain(nd),sat%top_macro_saturated_node(nd),sat%macro_saturated_fraction(nd), &
         sat%macro_reference_level(nd),sat%z(n),sat%dz(n),sat%matrix_head(n), &
         sat%ksat_horizontal(n),sat%diameter(n),sat%domain_fraction(nd,n),sat%cdarcy(nd,n))
    sat%bottom_domain=n
    sat%top_macro_saturated_node=1
    sat%macro_saturated_fraction=1.0_real64
    sat%macro_reference_level=-100.0_real64
    sat%z=[-10.0_real64,-20.0_real64,-30.0_real64]
    sat%dz=10.0_real64
    sat%matrix_head=-100.0_real64
    sat%ksat_horizontal=0.0_real64
    sat%diameter=4.0_real64
    sat%domain_fraction=1.0_real64
    sat%cdarcy=0.0_real64
  end subroutine setup_sat

end program test_fmr_macropore_configuration
