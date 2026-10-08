module mod_crop_adaptive_root_profile_owner
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_wofost_rate_table, only: wofost_rate_table_t
  use mod_crop_root_profile_static, only: materialize_static_root_profile, CROP_ROOT_PROFILE_OK
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t, validate_crop_root_uptake_input, CROP_ROOT_INPUT_OK
  implicit none
  private

  integer, parameter, public :: ADAPTIVE_ROOT_PROFILE_OK = 0
  integer, parameter, public :: ADAPTIVE_ROOT_PROFILE_INVALID_STATE = 1
  integer, parameter, public :: ADAPTIVE_ROOT_PROFILE_INVALID_PARAMETERS = 2
  integer, parameter, public :: ADAPTIVE_ROOT_PROFILE_INVALID_FORCING = 3
  integer, parameter, public :: ADAPTIVE_ROOT_PROFILE_INVALID_GEOMETRY = 4
  integer, parameter, public :: ADAPTIVE_ROOT_PROFILE_INVALID_RESULT = 5

  type, public :: adaptive_root_profile_parameters_t
    real(real64) :: growth_adaptation_fraction = 0.0_real64 ! FGWRT
    real(real64) :: death_adaptation_fraction = 0.0_real64  ! FDWRT
    real(real64) :: minimum_root_biomass_per_cm = 0.0_real64 ! WRTMIN
    real(real64) :: specific_root_length_m_per_kg = 0.0_real64 ! SRL
  contains
    procedure, public :: ready => adaptive_root_profile_parameters_ready
  end type adaptive_root_profile_parameters_t

  type, extends(transaction_state_t), public :: adaptive_root_profile_state_t
    real(real64), allocatable :: root_biomass_by_node(:)
  contains
    procedure :: clone => adaptive_root_profile_clone
    procedure, public :: validate => adaptive_root_profile_validate
    procedure, public :: cumulative_root_fraction => adaptive_root_profile_cumulative
    procedure, public :: root_length_density => adaptive_root_profile_lrv
    procedure, public :: derive_root_uptake_input => adaptive_root_profile_derive_input
  end type adaptive_root_profile_state_t

  type, public :: adaptive_root_profile_daily_forcing_t
    integer :: old_rooted_nodes = 0
    integer :: rooted_nodes = 0
    real(real64) :: old_root_depth_cm = 0.0_real64
    real(real64) :: root_depth_cm = 0.0_real64
    real(real64) :: root_depth_extension_cm = 0.0_real64
    real(real64) :: root_biomass_end = 0.0_real64
    real(real64) :: root_growth = 0.0_real64
    real(real64) :: root_death = 0.0_real64
    real(real64), allocatable :: potential_root_sink(:)
    real(real64), allocatable :: root_sink_reduction(:)
  end type adaptive_root_profile_daily_forcing_t

  public :: initialize_adaptive_root_profile_state
  public :: evaluate_adaptive_root_profile_candidate

contains

  logical function adaptive_root_profile_parameters_ready(self) result(ready)
    class(adaptive_root_profile_parameters_t), intent(in) :: self
    ready = .false.
    if (.not. finite_between(self%growth_adaptation_fraction,0.0_real64,1.0_real64)) return
    if (.not. finite_between(self%death_adaptation_fraction,0.0_real64,1.0_real64)) return
    if (.not. ieee_is_finite(self%minimum_root_biomass_per_cm) .or. self%minimum_root_biomass_per_cm < 0.0_real64) return
    if (.not. ieee_is_finite(self%specific_root_length_m_per_kg) .or. self%specific_root_length_m_per_kg < 0.0_real64) return
    ready = .true.
  end function adaptive_root_profile_parameters_ready

  integer function adaptive_root_profile_validate(self) result(status)
    class(adaptive_root_profile_state_t), intent(in) :: self
    status = ADAPTIVE_ROOT_PROFILE_INVALID_STATE
    if (.not. allocated(self%root_biomass_by_node)) return
    if (size(self%root_biomass_by_node) <= 0) return
    if (any(.not. ieee_is_finite(self%root_biomass_by_node))) return
    if (any(self%root_biomass_by_node < 0.0_real64)) return
    status = ADAPTIVE_ROOT_PROFILE_OK
  end function adaptive_root_profile_validate

  subroutine adaptive_root_profile_clone(self, copy)
    class(adaptive_root_profile_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(adaptive_root_profile_state_t :: copy)
    select type (typed => copy)
    type is (adaptive_root_profile_state_t)
      if (allocated(self%root_biomass_by_node)) typed%root_biomass_by_node = self%root_biomass_by_node
    class default
      error stop 'adaptive root profile clone failure'
    end select
  end subroutine adaptive_root_profile_clone

  subroutine initialize_adaptive_root_profile_state(density_table, zbotcp_cm, maximum_root_depth_cm, &
                                                     root_depth_cm, root_biomass, state, status)
    type(wofost_rate_table_t), intent(in) :: density_table
    real(real64), intent(in) :: zbotcp_cm(:), maximum_root_depth_cm, root_depth_cm, root_biomass
    type(adaptive_root_profile_state_t), intent(out) :: state
    integer, intent(out) :: status
    real(real64), allocatable :: cumulative(:)
    integer :: rooted_nodes, node, profile_status

    state = adaptive_root_profile_state_t()
    status = ADAPTIVE_ROOT_PROFILE_INVALID_FORCING
    if (.not. ieee_is_finite(root_biomass) .or. root_biomass < 0.0_real64) return

    call materialize_static_root_profile(density_table,zbotcp_cm,maximum_root_depth_cm,root_depth_cm, &
         rooted_nodes,cumulative,profile_status)
    if (profile_status /= CROP_ROOT_PROFILE_OK) then
      status = ADAPTIVE_ROOT_PROFILE_INVALID_GEOMETRY
      return
    end if
    allocate(state%root_biomass_by_node(size(zbotcp_cm)))
    state%root_biomass_by_node = 0.0_real64
    if (rooted_nodes > 0) then
      do node=1,rooted_nodes
        state%root_biomass_by_node(node) = (cumulative(node+1)-cumulative(node))*root_biomass
      end do
    end if
    status = state%validate()
  end subroutine initialize_adaptive_root_profile_state

  subroutine evaluate_adaptive_root_profile_candidate(parameters, committed, forcing, ztopcp_cm, zbotcp_cm, dz_cm, &
                                                       candidate, status)
    type(adaptive_root_profile_parameters_t), intent(in) :: parameters
    type(adaptive_root_profile_state_t), intent(in) :: committed
    type(adaptive_root_profile_daily_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: ztopcp_cm(:), zbotcp_cm(:), dz_cm(:)
    type(adaptive_root_profile_state_t), intent(out) :: candidate
    integer, intent(out) :: status

    integer :: node, n
    real(real64) :: wrt_old, qrotrtz, qredrtz_pos
    real(real64) :: grrt_oldnod, grrt_newnod, extension_fraction
    real(real64) :: available_sink, death_weight, growth_weight, minimum_biomass
    real(real64) :: denominator

    candidate = committed
    status = ADAPTIVE_ROOT_PROFILE_INVALID_PARAMETERS
    if (.not. parameters%ready()) return
    status = committed%validate()
    if (status /= ADAPTIVE_ROOT_PROFILE_OK) return
    n = size(committed%root_biomass_by_node)
    if (.not. geometry_valid(n,ztopcp_cm,zbotcp_cm,dz_cm)) then
      status = ADAPTIVE_ROOT_PROFILE_INVALID_GEOMETRY
      return
    end if
    if (.not. forcing_valid(n,forcing)) then
      status = ADAPTIVE_ROOT_PROFILE_INVALID_FORCING
      return
    end if

    wrt_old = forcing%root_biomass_end - forcing%root_growth + forcing%root_death
    if (.not. ieee_is_finite(wrt_old) .or. wrt_old <= 0.0_real64) then
      status = ADAPTIVE_ROOT_PROFILE_INVALID_FORCING
      return
    end if

    grrt_newnod = 0.0_real64
    if (forcing%root_depth_extension_cm > 0.0_real64 .and. forcing%root_growth > 0.0_real64) then
      denominator = forcing%old_root_depth_cm + ztopcp_cm(forcing%old_rooted_nodes)
      if (denominator <= 0.0_real64) then
        status = ADAPTIVE_ROOT_PROFILE_INVALID_GEOMETRY
        return
      end if
      grrt_newnod = min((committed%root_biomass_by_node(forcing%old_rooted_nodes)/denominator) * &
                        forcing%root_depth_extension_cm, forcing%root_growth)
    end if
    grrt_oldnod = forcing%root_growth - grrt_newnod

    qrotrtz = 0.0_real64
    qredrtz_pos = 0.0_real64
    do node=1,forcing%rooted_nodes
      qrotrtz = qrotrtz + forcing%potential_root_sink(node) - max(0.0_real64,forcing%root_sink_reduction(node))
      qredrtz_pos = qredrtz_pos + max(0.0_real64,forcing%root_sink_reduction(node))
    end do

    do node=1,forcing%old_rooted_nodes
      if (forcing%root_growth > 0.0_real64 .and. grrt_oldnod > 0.0_real64) then
        if (qrotrtz > 0.0_real64) then
          available_sink = max(0.0_real64,forcing%potential_root_sink(node) - &
                                        max(0.0_real64,forcing%root_sink_reduction(node)))
          growth_weight = (1.0_real64-parameters%growth_adaptation_fraction) * &
                          committed%root_biomass_by_node(node)/wrt_old + &
                          parameters%growth_adaptation_fraction * available_sink/qrotrtz
        else
          growth_weight = committed%root_biomass_by_node(node)/wrt_old
        end if
        candidate%root_biomass_by_node(node) = candidate%root_biomass_by_node(node) + growth_weight*grrt_oldnod
      end if

      if (forcing%root_death > 0.0_real64) then
        if (qredrtz_pos > 0.0_real64) then
          death_weight = (1.0_real64-parameters%death_adaptation_fraction) * &
                         candidate%root_biomass_by_node(node)/(wrt_old+grrt_oldnod) + &
                         parameters%death_adaptation_fraction * max(0.0_real64,forcing%root_sink_reduction(node))/qredrtz_pos
        else
          death_weight = candidate%root_biomass_by_node(node)/(wrt_old+grrt_oldnod)
        end if
        candidate%root_biomass_by_node(node) = candidate%root_biomass_by_node(node) - death_weight*forcing%root_death
        minimum_biomass = min(dz_cm(node),forcing%old_root_depth_cm+ztopcp_cm(node)) * &
                          parameters%minimum_root_biomass_per_cm
        candidate%root_biomass_by_node(node) = max(minimum_biomass,candidate%root_biomass_by_node(node))
      end if
    end do

    if (forcing%root_depth_extension_cm > 0.0_real64 .and. grrt_newnod > 0.0_real64) then
      do node=forcing%old_rooted_nodes,forcing%rooted_nodes
        extension_fraction = 0.0_real64
        if (forcing%old_root_depth_cm + zbotcp_cm(node) < 0.0_real64) then
          extension_fraction = (min(dz_cm(node),forcing%root_depth_cm+ztopcp_cm(node)) - &
                                max(0.0_real64,forcing%old_root_depth_cm+ztopcp_cm(node))) / &
                                forcing%root_depth_extension_cm
        end if
        candidate%root_biomass_by_node(node) = candidate%root_biomass_by_node(node) + &
                                                extension_fraction*grrt_newnod
      end do
    end if

    if (any(.not. ieee_is_finite(candidate%root_biomass_by_node)) .or. any(candidate%root_biomass_by_node<0.0_real64)) then
      status = ADAPTIVE_ROOT_PROFILE_INVALID_RESULT
      return
    end if
    status = ADAPTIVE_ROOT_PROFILE_OK
  end subroutine evaluate_adaptive_root_profile_candidate

  subroutine adaptive_root_profile_cumulative(self, rooted_nodes, cumulative, status)
    class(adaptive_root_profile_state_t), intent(in) :: self
    integer, intent(in) :: rooted_nodes
    real(real64), allocatable, intent(out) :: cumulative(:)
    integer, intent(out) :: status
    integer :: node
    real(real64) :: total

    if (allocated(cumulative)) deallocate(cumulative)
    status = self%validate()
    if (status /= ADAPTIVE_ROOT_PROFILE_OK) return
    if (rooted_nodes <= 0 .or. rooted_nodes > size(self%root_biomass_by_node)) then
      status = ADAPTIVE_ROOT_PROFILE_INVALID_GEOMETRY
      return
    end if
    total = sum(self%root_biomass_by_node(1:rooted_nodes))
    if (.not. ieee_is_finite(total) .or. total <= 0.0_real64) then
      status = ADAPTIVE_ROOT_PROFILE_INVALID_RESULT
      return
    end if
    allocate(cumulative(rooted_nodes+1))
    cumulative(1)=0.0_real64
    do node=1,rooted_nodes
      cumulative(node+1)=cumulative(node)+self%root_biomass_by_node(node)/total
    end do
    cumulative(rooted_nodes+1)=1.0_real64
    status=ADAPTIVE_ROOT_PROFILE_OK
  end subroutine adaptive_root_profile_cumulative

  subroutine adaptive_root_profile_derive_input(self, rooted_nodes, active_nodes, input, status)
    class(adaptive_root_profile_state_t), intent(in) :: self
    integer, intent(in) :: rooted_nodes, active_nodes
    type(crop_root_uptake_input_t), intent(out) :: input
    integer, intent(out) :: status
    real(real64), allocatable :: cumulative(:)
    integer :: local_status

    input = crop_root_uptake_input_t()
    status = self%validate()
    if (status /= ADAPTIVE_ROOT_PROFILE_OK) return
    if (active_nodes /= size(self%root_biomass_by_node) .or. rooted_nodes < 0 .or. rooted_nodes > active_nodes) then
      status = ADAPTIVE_ROOT_PROFILE_INVALID_GEOMETRY
      return
    end if
    input%crop_emerged = .true.
    input%potential_transpiration = 0.0_real64
    input%rooted_nodes = rooted_nodes
    if (rooted_nodes > 0) then
      call self%cumulative_root_fraction(rooted_nodes,cumulative,local_status)
      if(local_status/=ADAPTIVE_ROOT_PROFILE_OK)then
        status=local_status;return
      end if
      input%cumulative_root_fraction=cumulative
    end if
    call validate_crop_root_uptake_input(input,active_nodes,local_status)
    if(local_status/=CROP_ROOT_INPUT_OK)then
      input=crop_root_uptake_input_t()
      status=ADAPTIVE_ROOT_PROFILE_INVALID_RESULT
      return
    end if
    status=ADAPTIVE_ROOT_PROFILE_OK
  end subroutine adaptive_root_profile_derive_input

  subroutine adaptive_root_profile_lrv(self, rooted_nodes, dz_cm, parameters, lrv, status)
    class(adaptive_root_profile_state_t), intent(in) :: self
    integer, intent(in) :: rooted_nodes
    real(real64), intent(in) :: dz_cm(:)
    type(adaptive_root_profile_parameters_t), intent(in) :: parameters
    real(real64), allocatable, intent(out) :: lrv(:)
    integer, intent(out) :: status
    integer :: node

    if (allocated(lrv)) deallocate(lrv)
    status=ADAPTIVE_ROOT_PROFILE_INVALID_PARAMETERS
    if (.not.parameters%ready()) return
    status=self%validate()
    if(status/=ADAPTIVE_ROOT_PROFILE_OK)return
    if(size(dz_cm)/=size(self%root_biomass_by_node).or.rooted_nodes<0.or.rooted_nodes>size(dz_cm))then
      status=ADAPTIVE_ROOT_PROFILE_INVALID_GEOMETRY;return
    end if
    if(any(.not.ieee_is_finite(dz_cm)).or.any(dz_cm<=0.0_real64))then
      status=ADAPTIVE_ROOT_PROFILE_INVALID_GEOMETRY;return
    end if
    allocate(lrv(size(dz_cm)));lrv=0.0_real64
    do node=1,rooted_nodes
      lrv(node)=self%root_biomass_by_node(node)*parameters%specific_root_length_m_per_kg/(1.0e6_real64*dz_cm(node))
    end do
    status=ADAPTIVE_ROOT_PROFILE_OK
  end subroutine adaptive_root_profile_lrv

  logical function forcing_valid(n,forcing) result(valid)
    integer, intent(in) :: n
    type(adaptive_root_profile_daily_forcing_t), intent(in) :: forcing
    real(real64) :: values(6)
    valid=.false.
    values=[forcing%old_root_depth_cm,forcing%root_depth_cm,forcing%root_depth_extension_cm, &
            forcing%root_biomass_end,forcing%root_growth,forcing%root_death]
    if(any(.not.ieee_is_finite(values)).or.any(values<0.0_real64))return
    if(forcing%old_rooted_nodes<=0.or.forcing%rooted_nodes<forcing%old_rooted_nodes.or.forcing%rooted_nodes>n)return
    if(forcing%root_depth_cm<forcing%old_root_depth_cm)return
    if(abs((forcing%root_depth_cm-forcing%old_root_depth_cm)-forcing%root_depth_extension_cm) > &
       256.0_real64*epsilon(1.0_real64)*max(1.0_real64,forcing%root_depth_cm))return
    if(.not.allocated(forcing%potential_root_sink).or..not.allocated(forcing%root_sink_reduction))return
    if(size(forcing%potential_root_sink)/=n.or.size(forcing%root_sink_reduction)/=n)return
    if(any(.not.ieee_is_finite(forcing%potential_root_sink)).or.any(.not.ieee_is_finite(forcing%root_sink_reduction)))return
    valid=.true.
  end function forcing_valid

  logical function geometry_valid(n,ztopcp_cm,zbotcp_cm,dz_cm) result(valid)
    integer, intent(in) :: n
    real(real64), intent(in) :: ztopcp_cm(:),zbotcp_cm(:),dz_cm(:)
    integer :: i
    valid=.false.
    if(size(ztopcp_cm)/=n.or.size(zbotcp_cm)/=n.or.size(dz_cm)/=n)return
    if(any(.not.ieee_is_finite(ztopcp_cm)).or.any(.not.ieee_is_finite(zbotcp_cm)).or. &
       any(.not.ieee_is_finite(dz_cm)).or.any(dz_cm<=0.0_real64))return
    do i=1,n
      if(zbotcp_cm(i)>=ztopcp_cm(i))return
    end do
    valid=.true.
  end function geometry_valid

  logical function finite_between(value,lo,hi) result(valid)
    real(real64), intent(in) :: value,lo,hi
    valid=ieee_is_finite(value).and.value>=lo.and.value<=hi
  end function finite_between

end module mod_crop_adaptive_root_profile_owner
