module MOD_MvG
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, &
       b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  implicit none
  private

  type(b110_default_mvg_parameters_t), pointer :: bound_parameters => null()
  type(b110_default_mvg_provider_t) :: bound_provider
  integer :: active_nodes = 0
  real(real64) :: step_duration = 0.0_real64

  public :: gc_low01_bind_mvg
  public :: watcon, hconduc, moiscap, dhconduc, cofgen

contains

  subroutine gc_low01_bind_mvg(parameters, dt)
    type(b110_default_mvg_parameters_t), target, intent(in) :: parameters
    real(real64), intent(in) :: dt

    if (parameters%active_nodes <= 0) error stop 'LOW01 constitutive bridge: no active nodes'
    if (.not. allocated(parameters%cofgen)) error stop 'LOW01 constitutive bridge: no cofgen'
    if (parameters%ksatexm_extension_enabled) &
      error stop 'LOW01 constitutive bridge: KSATEXM is outside the bounded LOW01-B slice'
    if (dt <= 0.0_real64) error stop 'LOW01 constitutive bridge: invalid dt'

    bound_parameters => parameters
    active_nodes = parameters%active_nodes
    step_duration = dt
    call bind_b110_default_mvg_provider(bound_provider, parameters, dt)
  end subroutine gc_low01_bind_mvg

  subroutine evaluate_node(node, head, theta, conductivity, capacity, dkdh)
    integer, intent(in) :: node
    real(real64), intent(in) :: head
    real(real64), intent(out) :: theta, conductivity, capacity, dkdh
    real(real64), allocatable :: heads(:), water(:), k(:), c(:), d(:)

    if (.not. associated(bound_parameters)) error stop 'LOW01 constitutive bridge: not bound'
    if (node < 1 .or. node > active_nodes) error stop 'LOW01 constitutive bridge: node out of range'

    allocate(heads(active_nodes), water(active_nodes), k(active_nodes), c(active_nodes), d(active_nodes))
    heads = 0.0_real64
    heads(node) = head
    call bound_provider%evaluate(heads, water, k, c, d)
    theta = water(node)
    conductivity = k(node)
    capacity = c(node)
    dkdh = d(node)
  end subroutine evaluate_node

  real(real64) function watcon(node, head)
    integer, intent(in) :: node
    real(real64), intent(in) :: head
    real(real64) :: k, c, d
    call evaluate_node(node, head, watcon, k, c, d)
  end function watcon

  real(real64) function hconduc(node, head, water_content, frost_factor)
    integer, intent(in) :: node
    real(real64), intent(in) :: head, water_content, frost_factor
    real(real64) :: theta, c, d

    if (abs(frost_factor - 1.0_real64) > 0.0_real64) &
      error stop 'LOW01 constitutive bridge: frost outside bounded slice'
    call evaluate_node(node, head, theta, hconduc, c, d)
    if (abs(theta-water_content) > 1.0e-12_real64) &
      error stop 'LOW01 constitutive bridge: caller water content differs from provider'
  end function hconduc

  real(real64) function moiscap(node, head)
    integer, intent(in) :: node
    real(real64), intent(in) :: head
    real(real64) :: theta, k, d
    call evaluate_node(node, head, theta, k, moiscap, d)
  end function moiscap

  real(real64) function dhconduc(node, head, water_content, capacity, frost_factor)
    integer, intent(in) :: node
    real(real64), intent(in) :: head, water_content, capacity, frost_factor
    real(real64) :: theta, k, provider_capacity

    if (abs(frost_factor - 1.0_real64) > 0.0_real64) &
      error stop 'LOW01 constitutive bridge: frost outside bounded slice'
    call evaluate_node(node, head, theta, k, provider_capacity, dhconduc)
    if (abs(theta-water_content) > 1.0e-12_real64) &
      error stop 'LOW01 constitutive bridge: caller water content differs from provider'
    if (abs(provider_capacity-capacity) > 1.0e-12_real64) &
      error stop 'LOW01 constitutive bridge: caller capacity differs from provider'
  end function dhconduc

  real(real64) function cofgen(mode, node)
    integer, intent(in) :: mode, node
    if (.not. associated(bound_parameters)) error stop 'LOW01 constitutive bridge: not bound'
    if (node < 1 .or. node > active_nodes) error stop 'LOW01 constitutive bridge: node out of range'
    if (mode < 1 .or. mode > size(bound_parameters%cofgen,1)) &
      error stop 'LOW01 constitutive bridge: cofgen row out of range'
    cofgen = bound_parameters%cofgen(mode,node)
  end function cofgen

end module MOD_MvG
