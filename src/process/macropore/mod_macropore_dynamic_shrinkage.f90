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
    integer :: surface_crack_area_node = 1
    logical :: surface_crack_area_node_supplied = .false.
    real(real64) :: surface_crack_area_depth_cm = 0.0_real64
    logical :: surface_crack_area_depth_supplied = .false.
    real(real64), allocatable :: theta_s(:), theta_crack(:), geometry_factor(:), minimum_subsidence_cm(:)
    type(clay_kim_shrinkage_t), allocatable :: kim(:)
  contains
    procedure :: valid_for_nodes => dynamic_shrinkage_config_valid
  end type dynamic_shrinkage_config_t

  public :: prepare_clay_kim_option1
  public :: evaluate_clay_kim_shrinkage_fraction
  public :: evaluate_dynamic_crack_volume
  public :: evaluate_dynamic_crack_profile
  public :: find_dynamic_groundwater_cutoff
  public :: map_surface_crack_depth_to_node
  public :: derive_dynamic_minimum_subsidence

contains

  subroutine derive_dynamic_minimum_subsidence(config,dz,ok)
    type(dynamic_shrinkage_config_t),intent(inout)::config
    real(real64),intent(in)::dz(:)
    logical,intent(out)::ok
    real(real64)::shrink
    integer::n,ic
    logical::local_ok
    ok=.false.;n=size(dz)
    if(.not.config%enabled)then
      ok=.true.;return
    end if
    if(n<=0 .or. any(.not.ieee_is_finite(dz)) .or. any(dz<=0.0_real64))return
    if(.not.allocated(config%theta_s) .or. .not.allocated(config%theta_crack) .or. .not.allocated(config%kim))return
    if(size(config%theta_s)/=n .or. size(config%theta_crack)/=n .or. size(config%kim)/=n)return
    if(allocated(config%minimum_subsidence_cm))deallocate(config%minimum_subsidence_cm)
    allocate(config%minimum_subsidence_cm(n))
    config%minimum_subsidence_cm=0.0_real64
    do ic=1,n
      ! B1.11 MACROPORE initialization: SubsidCpMin = SHRINK(ThetCrMp)*Dz.
      call evaluate_clay_kim_shrinkage_fraction(config%theta_crack(ic),config%theta_s(ic),config%kim(ic),shrink,local_ok)
      if(.not.local_ok)return
      config%minimum_subsidence_cm(ic)=shrink*dz(ic)
    end do
    ok=.true.
  end subroutine derive_dynamic_minimum_subsidence

  pure subroutine map_surface_crack_depth_to_node(depth_cm,z,dz,top_node,node,ok)
    real(real64),intent(in)::depth_cm,z(:),dz(:)
    integer,intent(in)::top_node
    integer,intent(out)::node
    logical,intent(out)::ok
    integer::n,ic
    n=size(z);node=0;ok=.false.
    if(n<=0 .or. size(dz)/=n .or. top_node<1 .or. top_node>n)return
    if(.not.ieee_is_finite(depth_cm) .or. any(.not.ieee_is_finite(z)) .or. &
       any(.not.ieee_is_finite(dz)) .or. any(dz<=0.0_real64))return
    if(top_node>1)then
      node=top_node;ok=.true.;return
    end if
    ic=1
    do while((z(ic)-0.5_real64*dz(ic)+1.0e-2_real64)>depth_cm)
      ic=ic+1
      if(ic>n)return
    end do
    node=ic;ok=.true.
  end subroutine map_surface_crack_depth_to_node

  pure logical function dynamic_shrinkage_config_valid(self,n) result(ok)
    class(dynamic_shrinkage_config_t),intent(in)::self
    integer,intent(in)::n
    integer::i
    ok=.false.
    if(.not.self%enabled)then
      ok=.true.
      return
    end if
    if(.not.self%surface_crack_area_node_supplied)return
    if(.not.allocated(self%theta_s) .or. .not.allocated(self%theta_crack) .or. &
       .not.allocated(self%geometry_factor) .or. .not.allocated(self%minimum_subsidence_cm) .or. &
       .not.allocated(self%kim))return
    if(size(self%theta_s)/=n .or. size(self%theta_crack)/=n .or. size(self%geometry_factor)/=n .or. &
       size(self%minimum_subsidence_cm)/=n .or. size(self%kim)/=n)return
    if(n<=0)return
    if(self%surface_crack_area_node<1 .or. self%surface_crack_area_node>n)return
    if(.not.all(ieee_is_finite(self%theta_s)) .or. .not.all(ieee_is_finite(self%theta_crack)) .or. &
       .not.all(ieee_is_finite(self%geometry_factor)) .or. &
       .not.all(ieee_is_finite(self%minimum_subsidence_cm)))return
    if(any(self%theta_s<=0.0_real64) .or. any(self%theta_s>=1.0_real64) .or. &
       any(self%theta_crack<0.0_real64) .or. any(self%theta_crack>self%theta_s) .or. &
       any(self%geometry_factor<=0.0_real64) .or. any(self%minimum_subsidence_cm<0.0_real64))return
    do i=1,n
      if(.not.self%kim(i)%valid())return
    end do
    ok=.true.
  end function dynamic_shrinkage_config_valid

  pure logical function clay_kim_valid(self)
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

    ! B1.11 SHRINK, clay mode: void ratio from the pinned source relation.
    solid_volume_fraction = 1.0_real64-theta_s
    moisture_ratio = theta/solid_volume_fraction
    if (moisture_ratio > parameters%transition_moisture_ratio) then
      void_ratio = moisture_ratio
    else
      void_ratio = parameters%alpha_k*exp(-parameters%beta_k*moisture_ratio) + &
           parameters%gamma_k*moisture_ratio
      void_ratio = max(void_ratio,parameters%alpha_k)
    end if
    ! B1.11 SHRINK returns relative shrinkage from void ratio and solid fraction.
    shrink_fraction = theta_s-void_ratio*solid_volume_fraction
    ok = ieee_is_finite(shrink_fraction) .and. shrink_fraction >= 0.0_real64 .and. shrink_fraction < 1.0_real64
  end subroutine evaluate_clay_kim_shrinkage_fraction

  subroutine evaluate_dynamic_crack_profile(config,theta,theta_previous,dz,matrix_area_fraction,accepted_dynamic_volume, &
                                              candidate_dynamic_volume,ok,candidate_subsidence_cm,active_node)
    type(dynamic_shrinkage_config_t),intent(in)::config
    real(real64),intent(in)::theta(:),theta_previous(:),dz(:),matrix_area_fraction(:),accepted_dynamic_volume(:)
    real(real64),allocatable,intent(out)::candidate_dynamic_volume(:)
    logical,intent(out)::ok
    real(real64),allocatable,intent(out),optional::candidate_subsidence_cm(:)
    integer,intent(in),optional::active_node
    type(dynamic_crack_request_t)::request
    real(real64)::shrink
    logical::local_ok
    integer::n,ic

    ok=.false.
    n=size(theta)
    allocate(candidate_dynamic_volume(n))
    if(present(candidate_subsidence_cm))allocate(candidate_subsidence_cm(n))
    candidate_dynamic_volume=accepted_dynamic_volume
    if(present(candidate_subsidence_cm))candidate_subsidence_cm=0.0_real64
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
      request%neighbour_dynamic_volume_cm = accepted_dynamic_volume(max(1,ic-1)) + &
           accepted_dynamic_volume(min(n,ic+1))
      request%minimum_subsidence_cm=config%minimum_subsidence_cm(ic)
      if(present(candidate_subsidence_cm))then
        call evaluate_dynamic_crack_volume(request,shrink,candidate_dynamic_volume(ic),local_ok,candidate_subsidence_cm(ic))
      else
        call evaluate_dynamic_crack_volume(request,shrink,candidate_dynamic_volume(ic),local_ok)
      end if
      if(.not.local_ok)return
    end do
    if(present(active_node))then
      if(active_node<0 .or. active_node>n)return
      candidate_dynamic_volume(active_node+1:n)=0.0_real64
      if(present(candidate_subsidence_cm))candidate_subsidence_cm(active_node+1:n)=0.0_real64
    end if
    ok=.true.
  end subroutine evaluate_dynamic_crack_profile

  pure integer function find_dynamic_groundwater_cutoff(head,z,dz,bottom_mode) result(cutoff)
    real(real64),intent(in)::head(:),z(:),dz(:)
    integer,intent(in)::bottom_mode
    real(real64)::water_level,spacing
    integer::n,node,i
    n=size(head);cutoff=n+1
    if(n<1 .or. size(z)/=n .or. size(dz)/=n)return
    if(any(.not.ieee_is_finite(head)) .or. any(.not.ieee_is_finite(z)) .or. &
       any(.not.ieee_is_finite(dz)))return
    if(any(dz<=0.0_real64))return
    if(bottom_mode==1)then
      if(all(head>=0.0_real64))cutoff=1
      return
    end if
    if(head(n)<0.0_real64)return
    do node=n-1,1,-1
      if(head(node)<0.0_real64)then
        if(head(node+1)>=0.0_real64)then
          spacing=abs(z(node+1)-z(node))
          if(spacing<=0.0_real64)return
          water_level=z(node+1)+head(node+1)/(head(node+1)-head(node))*spacing
        else
          water_level=z(node)-0.5_real64*dz(node)-head(node)
          water_level=min(z(node),max(z(node)-0.5_real64*dz(node),water_level))
        end if
        i=max(node-2,1)
        do while(i<n .and. z(i)-0.5_real64*dz(i)>water_level)
          i=i+1
        end do
        cutoff=i
        return
      end if
    end do
    cutoff=1
  end function find_dynamic_groundwater_cutoff

  subroutine evaluate_dynamic_crack_volume(request, shrink_fraction, dynamic_volume_cm, ok, subsidence_result_cm)
    type(dynamic_crack_request_t), intent(in) :: request
    real(real64), intent(in) :: shrink_fraction
    real(real64), intent(out) :: dynamic_volume_cm
    logical, intent(out) :: ok
    real(real64),intent(out),optional::subsidence_result_cm
    real(real64) :: shrink_volume_cm, critical_theta, subsidence_cm

    ok = .false.
    dynamic_volume_cm = 0.0_real64
    if(present(subsidence_result_cm))subsidence_result_cm=0.0_real64
    if (.not. ieee_is_finite(shrink_fraction) .or. shrink_fraction < 0.0_real64 .or. shrink_fraction >= 1.0_real64) return
    if (.not. ieee_is_finite(request%theta) .or. .not. ieee_is_finite(request%theta_previous) .or. &
        .not. ieee_is_finite(request%theta_s) .or. .not. ieee_is_finite(request%theta_crack) .or. &
        .not. ieee_is_finite(request%dz_cm) .or. .not. ieee_is_finite(request%geometry_factor) .or. &
        .not. ieee_is_finite(request%matrix_area_fraction) .or. &
        .not. ieee_is_finite(request%prior_dynamic_volume_cm) .or. &
        .not. ieee_is_finite(request%neighbour_dynamic_volume_cm) .or. &
        .not. ieee_is_finite(request%minimum_subsidence_cm)) return
    if (request%theta_s <= 0.0_real64 .or. request%theta_s > 1.0_real64) return
    if (request%theta_crack < 0.0_real64 .or. request%theta_crack > request%theta_s) return
    if (request%dz_cm <= 0.0_real64 .or. request%geometry_factor <= 0.0_real64) return
    if (request%matrix_area_fraction <= 0.0_real64 .or. request%matrix_area_fraction > 1.0_real64) return
    if (request%prior_dynamic_volume_cm < 0.0_real64 .or. request%neighbour_dynamic_volume_cm < 0.0_real64 .or. &
        request%minimum_subsidence_cm < 0.0_real64) return

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
      if(dynamic_volume_cm<0.0_real64)then
        subsidence_cm=subsidence_cm+dynamic_volume_cm
        dynamic_volume_cm=0.0_real64
      end if
    else
      subsidence_cm=shrink_volume_cm
    end if
    if(present(subsidence_result_cm))subsidence_result_cm=subsidence_cm
    ok = .true.
  end subroutine evaluate_dynamic_crack_volume

end module mod_macropore_dynamic_shrinkage
