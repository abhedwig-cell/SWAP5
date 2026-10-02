module mod_macropore_dynamic_shrinkage
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  type, public :: clay_kim_shrinkage_t
    real(real64) :: alpha_k = 0.0_real64
    real(real64) :: beta_k = 0.0_real64
    real(real64) :: gamma_k = 0.0_real64
    real(real64) :: transition_moisture_ratio = 0.0_real64
  contains
    procedure :: valid => clay_kim_valid
  end type clay_kim_shrinkage_t

  type, public :: dynamic_crack_request_t
    real(real64) :: theta = 0.0_real64
    real(real64) :: theta_previous = 0.0_real64
    real(real64) :: theta_s = 0.0_real64
    real(real64) :: theta_crack = 0.0_real64
    real(real64) :: dz_cm = 0.0_real64
    real(real64) :: geometry_factor = 0.0_real64
    real(real64) :: matrix_area_fraction = 1.0_real64
    real(real64) :: prior_dynamic_volume_cm = 0.0_real64
    real(real64) :: neighbour_dynamic_volume_cm = 0.0_real64
    real(real64) :: minimum_subsidence_cm = 0.0_real64
  end type dynamic_crack_request_t

  public :: prepare_clay_kim_option1
  public :: evaluate_clay_kim_shrinkage_fraction
  public :: evaluate_dynamic_crack_volume

contains

  logical function clay_kim_valid(self)
    class(clay_kim_shrinkage_t), intent(in) :: self
    clay_kim_valid = ieee_is_finite(self%alpha_k) .and. ieee_is_finite(self%beta_k) .and. &
         ieee_is_finite(self%gamma_k) .and. ieee_is_finite(self%transition_moisture_ratio) .and. &
         self%alpha_k > 0.0_real64 .and. self%beta_k /= 0.0_real64 .and. &
         self%transition_moisture_ratio >= 0.0_real64
  end function clay_kim_valid

  subroutine prepare_clay_kim_option1(theta_s, shr_par_a, shr_par_b, shr_par_c, parameters, ok)
    real(real64), intent(in) :: theta_s, shr_par_a, shr_par_b, shr_par_c
    type(clay_kim_shrinkage_t), intent(out) :: parameters
    logical, intent(out) :: ok
    real(real64) :: argument

    parameters = clay_kim_shrinkage_t()
    ok = .false.
    if (.not. ieee_is_finite(theta_s) .or. theta_s <= 0.0_real64 .or. theta_s >= 1.0_real64) return
    if (.not. ieee_is_finite(shr_par_a) .or. .not. ieee_is_finite(shr_par_b) .or. &
        .not. ieee_is_finite(shr_par_c)) return
    if (shr_par_a <= 0.0_real64 .or. shr_par_b == 0.0_real64) return
    argument = (shr_par_c-1.0_real64)/(shr_par_a*shr_par_b)
    if (argument <= 0.0_real64) return
    parameters%alpha_k = shr_par_a
    parameters%beta_k = shr_par_b
    parameters%gamma_k = shr_par_c
    parameters%transition_moisture_ratio = -log(argument)/shr_par_b
    if (parameters%transition_moisture_ratio > theta_s/(1.0_real64-theta_s)-0.01_real64) return
    ok = parameters%valid()
  end subroutine prepare_clay_kim_option1

  subroutine evaluate_clay_kim_shrinkage_fraction(theta, theta_s, parameters, shrink_fraction, ok)
    real(real64), intent(in) :: theta, theta_s
    type(clay_kim_shrinkage_t), intent(in) :: parameters
    real(real64), intent(out) :: shrink_fraction
    logical, intent(out) :: ok
    real(real64) :: moisture_ratio, void_ratio, solid_volume_fraction

    ok = .false.
    shrink_fraction = 0.0_real64
    if (.not. parameters%valid()) return
    if (.not. ieee_is_finite(theta) .or. .not. ieee_is_finite(theta_s)) return
    if (theta < 0.0_real64 .or. theta_s <= 0.0_real64 .or. theta_s >= 1.0_real64 .or. theta > theta_s) return

    ! Exact B1.11 SHRINK source semantics: MoisR = Theta / (1-ThetaS).
    solid_volume_fraction = 1.0_real64-theta_s
    moisture_ratio = theta/solid_volume_fraction
    if (moisture_ratio > parameters%transition_moisture_ratio) then
      void_ratio = moisture_ratio
    else
      void_ratio = parameters%alpha_k*exp(-parameters%beta_k*moisture_ratio) + &
           parameters%gamma_k*moisture_ratio
      void_ratio = max(void_ratio,parameters%alpha_k)
    end if
    ! Exact B1.11 line 1573.
    shrink_fraction = theta_s-void_ratio*solid_volume_fraction
    ok = ieee_is_finite(shrink_fraction) .and. shrink_fraction >= 0.0_real64 .and. shrink_fraction < 1.0_real64
  end subroutine evaluate_clay_kim_shrinkage_fraction

  subroutine evaluate_dynamic_crack_volume(request, shrink_fraction, dynamic_volume_cm, ok)
    type(dynamic_crack_request_t), intent(in) :: request
    real(real64), intent(in) :: shrink_fraction
    real(real64), intent(out) :: dynamic_volume_cm
    logical, intent(out) :: ok
    real(real64) :: shrink_volume_cm, critical_theta, subsidence_cm

    ok = .false.
    dynamic_volume_cm = 0.0_real64
    if (.not. ieee_is_finite(shrink_fraction) .or. shrink_fraction < 0.0_real64 .or. shrink_fraction >= 1.0_real64) return
    if (request%theta_s <= 0.0_real64 .or. request%theta_s > 1.0_real64) return
    if (request%theta_crack < 0.0_real64 .or. request%theta_crack > request%theta_s) return
    if (request%dz_cm <= 0.0_real64 .or. request%geometry_factor <= 0.0_real64) return
    if (request%matrix_area_fraction <= 0.0_real64 .or. request%matrix_area_fraction > 1.0_real64) return
    if (request%prior_dynamic_volume_cm < 0.0_real64 .or. request%neighbour_dynamic_volume_cm < 0.0_real64) return

    if (request%theta >= request%theta_s-1.0e-4_real64) then
      ok = .true.
      return
    end if

    shrink_volume_cm = shrink_fraction*request%dz_cm
    if (request%theta > request%theta_previous-1.0e-8_real64 .and. &
        (request%prior_dynamic_volume_cm > 0.0_real64 .or. request%neighbour_dynamic_volume_cm > 0.0_real64)) then
      critical_theta = request%theta_s
    else
      critical_theta = request%theta_crack
    end if

    if (request%theta < critical_theta) then
      subsidence_cm = (1.0_real64-(1.0_real64-shrink_fraction)**(1.0_real64/request%geometry_factor))*request%dz_cm
      subsidence_cm = max(subsidence_cm, request%minimum_subsidence_cm)
      if (subsidence_cm >= request%dz_cm) return
      dynamic_volume_cm = request%matrix_area_fraction*(shrink_volume_cm-subsidence_cm)*request%dz_cm / &
           (request%dz_cm-subsidence_cm)
      dynamic_volume_cm = max(0.0_real64,dynamic_volume_cm)
    end if
    ok = .true.
  end subroutine evaluate_dynamic_crack_volume

end module mod_macropore_dynamic_shrinkage
