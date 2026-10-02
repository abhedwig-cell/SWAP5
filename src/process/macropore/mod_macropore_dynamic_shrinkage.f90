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

  type, public :: dynamic_shrinkage_config_t
    logical :: enabled = .false.
    real(real64), allocatable :: theta_s(:), theta_crack(:), geometry_factor(:), minimum_subsidence_cm(:)
    type(clay_kim_shrinkage_t), allocatable :: kim(:)
  contains
    procedure :: valid_for_nodes => dynamic_shrinkage_config_valid
  end type dynamic_shrinkage_config_t

  public :: prepare_clay_kim_option1
  public :: evaluate_clay_kim_shrinkage_fraction
  public :: evaluate_dynamic_crack_volume
  public :: evaluate_dynamic_crack_profile

contains

  logical function dynamic_shrinkage_config_valid(self,n) result(ok)
    class(dynamic_shrinkage_config_t),intent(in)::self
    integer,intent(in)::n
    integer::i
    ok=.false.
    if(.not.self%enabled)then
      ok=.true.
      return
    end if
    if(.not.allocated(self%theta_s) .or. .not.allocated(self%theta_crack) .or. &
       .not.allocated(self%geometry_factor) .or. .not.allocated(self%minimum_subsidence_cm) .or. &
       .not.allocated(self%kim))return
    if(size(self%theta_s)/=n .or. size(self%theta_crack)/=n .or. size(self%geometry_factor)/=n .or. &
       size(self%minimum_subsidence_cm)/=n .or. size(self%kim)/=n)return
    if(any(self%theta_s<=0.0_real64) .or. any(self%theta_s>=1.0_real64) .or. &
       any(self%theta_crack<0.0_real64) .or. any(self%theta_crack>self%theta_s) .or. &
       any(self%geometry_factor<=0.0_real64) .or. any(self%minimum_subsidence_cm<0.0_real64))return
    do i=1,n
      if(.not.self%kim(i)%valid())return
    end do
    ok=.true.
  end function dynamic_shrinkage_config_valid

  logical function clay_kim_valid(self)
    class(clay_kim_shrinkage_t), intent(in) :: self
    clay_kim_valid = ieee_is_finite(self%alpha_k) .and. ieee_is_finite(self%beta_k) .and. &
         ieee_is_finite(self%gamma_k) .and. ieee_is_finite(self%transition_moisture_ratio) .and. &
         self%alpha_k > 0.0_real64 .and. abs(self%beta_k) > tiny(1.0_real64) .and. &
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
    if (shr_par_a <= 0.0_real64 .or. abs(shr_par_b) <= tiny(1.0_real64)) return
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

  subroutine evaluate_dynamic_crack_profile(config,theta,theta_previous,dz,matrix_area_fraction,accepted_dynamic_volume, &
                                              candidate_dynamic_volume,ok)
    type(dynamic_shrinkage_config_t),intent(in)::config
    real(real64),intent(in)::theta(:),theta_previous(:),dz(:),matrix_area_fraction(:),accepted_dynamic_volume(:)
    real(real64),allocatable,intent(out)::candidate_dynamic_volume(:)
    logical,intent(out)::ok
    type(dynamic_crack_request_t)::request
    real(real64)::shrink
    logical::local_ok
    integer::n,ic

    ok=.false.
    n=size(theta)
    allocate(candidate_dynamic_volume(n))
    candidate_dynamic_volume=accepted_dynamic_volume
    if(.not.config%valid_for_nodes(n))return
    if(.not.config%enabled)then
      ok=.true.
      return
    end if
    if(size(theta_previous)/=n .or. size(dz)/=n .or. size(matrix_area_fraction)/=n .or. &
       size(accepted_dynamic_volume)/=n)return
    do ic=1,n
      call evaluate_clay_kim_shrinkage_fraction(theta(ic),config%theta_s(ic),config%kim(ic),shrink,local_ok)
      if(.not.local_ok)return
      request=dynamic_crack_request_t()
      request%theta=theta(ic)
      request%theta_previous=theta_previous(ic)
      request%theta_s=config%theta_s(ic)
      request%theta_crack=config%theta_crack(ic)
      request%dz_cm=dz(ic)
      request%geometry_factor=config%geometry_factor(ic)
      request%matrix_area_fraction=matrix_area_fraction(ic)
      request%prior_dynamic_volume_cm=accepted_dynamic_volume(ic)
      if(ic>1)request%neighbour_dynamic_volume_cm=request%neighbour_dynamic_volume_cm+accepted_dynamic_volume(ic-1)
      if(ic<n)request%neighbour_dynamic_volume_cm=request%neighbour_dynamic_volume_cm+accepted_dynamic_volume(ic+1)
      request%minimum_subsidence_cm=config%minimum_subsidence_cm(ic)
      call evaluate_dynamic_crack_volume(request,shrink,candidate_dynamic_volume(ic),local_ok)
      if(.not.local_ok)return
    end do
    ok=.true.
  end subroutine evaluate_dynamic_crack_profile

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
