module mod_b110_default_mvg_directional_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t
  implicit none
  private

  real(real64), parameter :: B110_H_CRIT = -1.0e-2_real64
  real(real64), parameter :: B110_EXTREME_DRY_HEAD = -1.0e14_real64
  real(real64), parameter :: B110_SAT_K_SWITCH = 1.0_real64 - 1.0e-6_real64

  public :: evaluate_b110_default_mvg_state_direction

contains

  subroutine evaluate_b110_default_mvg_state_direction(provider, pressure_head, pressure_head_direction, &
                                                        water_content_direction, conductivity_direction, &
                                                        available, route)
    type(b110_default_mvg_provider_t), intent(in) :: provider
    real(real64), intent(in) :: pressure_head(:), pressure_head_direction(:)
    real(real64), intent(out) :: water_content_direction(:), conductivity_direction(:)
    logical, intent(out) :: available
    character(len=*), intent(out) :: route

    integer :: i, n
    logical :: node_ok
    real(real64) :: dthetadh, dkdh

    available = .false.
    route = 'b110-mvg-direction-unavailable'
    water_content_direction = 0.0_real64
    conductivity_direction = 0.0_real64
    if (.not. associated(provider%parameters)) then
       route = 'b110-mvg-parameters-unbound'
       return
    end if
    n = provider%parameters%active_nodes
    if (n <= 0 .or. .not. allocated(provider%parameters%cofgen)) then
       route = 'b110-mvg-parameters-invalid'
       return
    end if
    if (size(pressure_head) /= n .or. size(pressure_head_direction) /= n .or. &
        size(water_content_direction) /= n .or. size(conductivity_direction) /= n) then
       route = 'b110-mvg-direction-shape-invalid'
       return
    end if
    if (any(.not. ieee_is_finite(pressure_head)) .or. any(.not. ieee_is_finite(pressure_head_direction))) then
       route = 'b110-mvg-direction-nonfinite'
       return
    end if

    do i = 1, n
       call b110_smooth_derivatives(provider%parameters%cofgen(:,i), pressure_head(i), dthetadh, dkdh, node_ok)
       if (.not. node_ok) then
          route = 'b110-mvg-nonsmooth-constitutive-branch'
          water_content_direction = 0.0_real64
          conductivity_direction = 0.0_real64
          return
       end if
       water_content_direction(i) = dthetadh * pressure_head_direction(i)
       conductivity_direction(i) = dkdh * pressure_head_direction(i)
    end do
    if (any(.not. ieee_is_finite(water_content_direction)) .or. &
        any(.not. ieee_is_finite(conductivity_direction))) then
       route = 'b110-mvg-state-direction-nonfinite'
       water_content_direction = 0.0_real64
       conductivity_direction = 0.0_real64
       return
    end if

    available = .true.
    route = 'b110-mvg-analytic-smooth-direction'
  end subroutine evaluate_b110_default_mvg_state_direction

  subroutine b110_smooth_derivatives(c, head, dthetadh, dkdh, ok)
    real(real64), intent(in) :: c(:), head
    real(real64), intent(out) :: dthetadh, dkdh
    logical, intent(out) :: ok

    real(real64) :: theta, relsat, invm, one_minus_term, term1
    real(real64) :: a, dterm_gain, dK_drelsat
    real(real64) :: alpha, u, x, dx_dh, se, dse_dh, r, denom, g, dg_dh, term2
    real(real64) :: raw_theta, h105

    ok = .false.
    dthetadh = 0.0_real64
    dkdh = 0.0_real64
    if (size(c) < 42 .or. .not. ieee_is_finite(head)) return
    if (c(25) <= 0.0_real64 .or. c(3) < 0.0_real64 .or. c(7) <= 0.0_real64) return
    alpha = c(4)
    if (alpha <= 0.0_real64) return

    ! Differentiate the exact water-retention branches used by B1.10 watcon.
    ! Branch boundaries are intentionally unavailable: F-SI37 is a fixed-smooth-
    ! route derivative and may not differentiate through constitutive switches.
    if (head > 0.0_real64) then
       theta = c(2)
       dthetadh = 0.0_real64
    else if (head == 0.0_real64) then
       return
    else if (c(9) > B110_H_CRIT) then
       if (head > B110_H_CRIT) then
          raw_theta = c(26) + c(27)*(head-B110_H_CRIT)
          if (raw_theta > c(2)) then
             theta = c(2)
             dthetadh = 0.0_real64
          else if (raw_theta == c(2)) then
             return
          else
             theta = raw_theta
             dthetadh = c(27)
          end if
       else if (head == B110_H_CRIT) then
          return
       else
          u = abs(alpha*head)
          theta = c(1) + c(25)/(1.0_real64 + u**c(6))**c(7)
          dthetadh = c(6)*c(7)*alpha*c(25)*u**(c(6)-1.0_real64) / &
               (1.0_real64 + u**c(6))**(c(7)+1.0_real64)
       end if
    else
       h105 = 1.05_real64*c(9)
       if (head > h105) then
          theta = c(2) + c(42)*head/(1.0_real64+c(41)*head)
          dthetadh = c(42)/(1.0_real64+c(41)*head)**2
       else if (head == h105) then
          return
       else
          u = abs(alpha*head)
          theta = c(1) + c(25)/((1.0_real64 + u**c(6))**c(7)*c(28))
          dthetadh = c(6)*c(7)*alpha*c(25)*u**(c(6)-1.0_real64) / &
               ((1.0_real64 + u**c(6))**(c(7)+1.0_real64)*c(28))
       end if
    end if
    if (.not. ieee_is_finite(theta) .or. .not. ieee_is_finite(dthetadh)) return

    ! Differentiate the exact conductivity branch used by B1.10 hconduc. The
    ! existing value-provider dconductivity_dhead slot deliberately remains
    ! unchanged/reserved; this sibling capability owns derivative semantics.
    if (c(9) > B110_H_CRIT) then
       if (head < B110_EXTREME_DRY_HEAD) then
          dkdh = 0.0_real64
          ok = .true.
          return
       else if (head == B110_EXTREME_DRY_HEAD) then
          return
       end if
       relsat = (theta-c(1))/c(25)
       if (.not. ieee_is_finite(relsat)) return
       if (relsat > B110_SAT_K_SWITCH) then
          dkdh = 0.0_real64
          ok = .true.
          return
       else if (relsat == B110_SAT_K_SWITCH) then
          return
       end if
       if (relsat <= 0.0_real64 .or. relsat >= 1.0_real64) return

       invm = c(32)
       a = 1.0_real64 - relsat**invm
       if (a <= 0.0_real64) return
       term1 = a**c(7)
       one_minus_term = 1.0_real64-term1
       dterm_gain = a**(c(7)-1.0_real64) * relsat**(invm-1.0_real64)
       dK_drelsat = c(3) * ( &
            c(5)*relsat**(c(5)-1.0_real64)*one_minus_term**2 + &
            relsat**c(5)*2.0_real64*one_minus_term*dterm_gain )
       dkdh = dK_drelsat*dthetadh/c(25)
    else
       if (head > c(9)) then
          dkdh = 0.0_real64
          ok = .true.
          return
       else if (head == c(9)) then
          return
       end if

       u = abs(alpha*head)
       if (u <= 0.0_real64) return
       x = (1.0_real64 + u**c(6))**(-c(7))
       dx_dh = c(6)*c(7)*alpha*u**(c(6)-1.0_real64) * &
            (1.0_real64 + u**c(6))**(-c(7)-1.0_real64)
       se = x/c(28)
       dse_dh = dx_dh/c(28)
       r = x
       invm = c(32)
       a = 1.0_real64-r**invm
       if (se <= 0.0_real64 .or. a <= 0.0_real64) return
       term1 = a**c(7)
       term2 = (1.0_real64-c(28)**invm)**c(7)
       denom = 1.0_real64-term2
       if (denom == 0.0_real64) return
       g = (1.0_real64-term1)/denom
       dg_dh = a**(c(7)-1.0_real64)*r**(invm-1.0_real64)*dx_dh/denom
       dkdh = c(3) * ( &
            c(5)*se**(c(5)-1.0_real64)*dse_dh*g**2 + &
            se**c(5)*2.0_real64*g*dg_dh )
    end if

    ok = ieee_is_finite(dkdh)
  end subroutine b110_smooth_derivatives

end module mod_b110_default_mvg_directional_provider
