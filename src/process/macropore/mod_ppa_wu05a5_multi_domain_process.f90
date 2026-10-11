module mod_ppa_wu05a5_multi_domain_process
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_macropore_continuation_state, only: macropore_continuation_state_t, &
       copy_macropore_continuation_state
  use mod_ppa_wu05a5_top_partition, only: macropore_top_partition_result_t, &
       apply_accepted_top_partition
  implicit none
  private

  type, public :: macropore_geometry_config_t
    integer :: num_domains = 0
    integer :: num_nodes = 0
    integer :: top_node = 1
    real(real64), allocatable :: static_volume_cp(:)
    real(real64), allocatable :: domain_fraction(:,:)
    integer, allocatable :: potential_bottom_domain(:)
    real(real64), allocatable :: dz(:)
    real(real64), allocatable :: characteristic_diameter(:)
  contains
    procedure, public :: valid => geometry_config_valid
  end type macropore_geometry_config_t

  type, public :: macropore_geometry_result_t
    logical :: valid = .false.
    integer :: num_domains = 0
    integer :: num_nodes = 0
    integer :: top_node = 0
    integer, allocatable :: bottom_domain(:)
    real(real64), allocatable :: dynamic_volume_cp(:)
    real(real64), allocatable :: total_volume_cp(:)
    real(real64), allocatable :: volume_domain_cp(:,:)
    real(real64), allocatable :: subsidence_cp(:)
    real(real64) :: surface_area_fraction = -1.0_real64
    real(real64) :: partition_residual_cm = huge(1.0_real64)
  end type macropore_geometry_result_t

  type, public :: macropore_multi_domain_receipt_t
    logical :: valid = .false.
    real(real64) :: accepted_top_cm = 0.0_real64
    real(real64) :: returned_surface_cm = 0.0_real64
    real(real64) :: internal_exchange_to_matrix_cm = 0.0_real64
    real(real64) :: geometry_return_to_matrix_cm = 0.0_real64
    real(real64) :: rapid_external_outflow_cm = 0.0_real64
    real(real64) :: macro_storage_change_cm = 0.0_real64
    real(real64) :: macro_balance_residual_cm = huge(1.0_real64)
    real(real64), allocatable :: matrix_exchange_rate(:)
  end type macropore_multi_domain_receipt_t

  public :: evaluate_macropore_geometry
  public :: evaluate_macropore_geometry_return
  public :: compose_macropore_candidate

contains

  pure logical function geometry_config_valid(self) result(ok)
    class(macropore_geometry_config_t), intent(in) :: self
    integer :: ic

    ok = self%num_domains > 0 .and. self%num_nodes > 0 .and. &
         self%top_node >= 1 .and. self%top_node <= self%num_nodes
    if (.not. ok) return
    ok = allocated(self%static_volume_cp) .and. allocated(self%domain_fraction) .and. &
         allocated(self%potential_bottom_domain) .and. allocated(self%dz) .and. &
         allocated(self%characteristic_diameter)
    if (.not. ok) return
    ok = size(self%static_volume_cp) == self%num_nodes .and. &
         all(shape(self%domain_fraction) == [self%num_domains,self%num_nodes]) .and. &
         size(self%potential_bottom_domain) == self%num_domains .and. &
         size(self%dz) == self%num_nodes .and. size(self%characteristic_diameter) == self%num_nodes
    if (.not. ok) return
    ok = all(self%static_volume_cp >= 0.0_real64) .and. all(self%domain_fraction >= 0.0_real64) .and. &
         all(self%dz > 0.0_real64) .and. all(self%characteristic_diameter > 0.0_real64)
    if (.not. ok) return
    ok = all(self%potential_bottom_domain >= self%top_node) .and. &
         all(self%potential_bottom_domain <= self%num_nodes)
    if (.not. ok) return
    do ic = self%top_node, self%num_nodes
      if (abs(sum(self%domain_fraction(:,ic))-1.0_real64) > 1.0e-12_real64) then
        ok = .false.
        return
      end if
    end do
  end function geometry_config_valid

  subroutine evaluate_macropore_geometry(config, dynamic_volume_cp, result)
    type(macropore_geometry_config_t), intent(in) :: config
    real(real64), intent(in) :: dynamic_volume_cp(:)
    type(macropore_geometry_result_t), intent(out) :: result

    real(real64) :: min_volume, residual
    integer :: id, ic, bottom_main

    result = macropore_geometry_result_t()
    if (.not. config%valid()) return
    if (size(dynamic_volume_cp) /= config%num_nodes) return
    if (any(dynamic_volume_cp < 0.0_real64)) return

    result%num_domains = config%num_domains
    result%num_nodes = config%num_nodes
    result%top_node = config%top_node
    allocate(result%bottom_domain(config%num_domains), result%dynamic_volume_cp(config%num_nodes), &
         result%total_volume_cp(config%num_nodes), &
         result%volume_domain_cp(config%num_domains,config%num_nodes))

    result%dynamic_volume_cp = dynamic_volume_cp
    result%total_volume_cp = max(0.0_real64, config%static_volume_cp + dynamic_volume_cp)
    result%volume_domain_cp = 0.0_real64

    bottom_main = 0
    do ic = config%num_nodes, config%top_node, -1
      if (bottom_main == 0) then
        min_volume = (1.0_real64 - &
             (1.0_real64-0.001_real64/config%characteristic_diameter(ic))**2) * config%dz(ic)
        if (result%total_volume_cp(ic) < min_volume .and. config%static_volume_cp(ic) < 1.0e-5_real64) &
             result%total_volume_cp(ic) = 0.0_real64
        if (result%total_volume_cp(ic) > 0.0_real64) bottom_main = ic
      end if
    end do
    if (bottom_main == 0) bottom_main = config%top_node
    if (config%num_domains > 1) bottom_main = max(bottom_main,config%potential_bottom_domain(2))

    result%bottom_domain(1) = bottom_main
    do id = 2, config%num_domains
      result%bottom_domain(id) = min(config%potential_bottom_domain(id),bottom_main)
    end do

    do id = 1, config%num_domains
      do ic = config%top_node, result%bottom_domain(id)
        result%volume_domain_cp(id,ic) = config%domain_fraction(id,ic)*result%total_volume_cp(ic)
      end do
    end do

    residual = 0.0_real64
    do ic = config%top_node, config%num_nodes
      residual = max(residual,abs(sum(result%volume_domain_cp(:,ic))-result%total_volume_cp(ic)))
    end do
    result%partition_residual_cm = residual
    result%valid = residual <= 1.0e-12_real64
  end subroutine evaluate_macropore_geometry

  subroutine compose_macropore_candidate(accepted_macro, geometry, top_partition, exchange_rate_domain_cp, &
       rapid_outflow_cp_cm, step_duration, candidate_macro, receipt, ok)
    type(macropore_continuation_state_t), intent(in) :: accepted_macro
    type(macropore_geometry_result_t), intent(in) :: geometry
    type(macropore_top_partition_result_t), intent(in) :: top_partition
    real(real64), intent(in) :: exchange_rate_domain_cp(:,:)
    real(real64), intent(in) :: rapid_outflow_cp_cm(:)
    real(real64), intent(in) :: step_duration
    type(macropore_continuation_state_t), intent(inout) :: candidate_macro
    type(macropore_multi_domain_receipt_t), intent(out) :: receipt
    logical, intent(out) :: ok

    real(real64), allocatable :: initial_water(:,:), geometry_return(:,:)
    real(real64) :: amount, available
    integer :: id, ic

    receipt = macropore_multi_domain_receipt_t()
    ok = .false.
    if (.not. accepted_macro%ready() .or. .not. geometry%valid .or. .not. top_partition%valid) return
    if (step_duration <= 0.0_real64) return
    if (accepted_macro%num_domains /= geometry%num_domains .or. &
        accepted_macro%num_nodes /= geometry%num_nodes) return
    if (top_partition%num_domains /= geometry%num_domains .or. top_partition%top_node /= geometry%top_node) return
    if (.not. all(shape(exchange_rate_domain_cp) == [geometry%num_domains,geometry%num_nodes])) return
    if (size(rapid_outflow_cp_cm) /= geometry%num_nodes) return
    if (any(rapid_outflow_cp_cm < 0.0_real64)) return

    call copy_macropore_continuation_state(accepted_macro,candidate_macro,ok)
    if (.not. ok) return

    allocate(initial_water(geometry%num_domains,geometry%num_nodes), &
         receipt%matrix_exchange_rate(geometry%num_nodes))
    initial_water = accepted_macro%water_domain_cp
    receipt%matrix_exchange_rate = 0.0_real64

    call evaluate_macropore_geometry_return(accepted_macro,geometry,geometry_return,ok)
    if (.not.ok) return

    candidate_macro%icp_bottom_domain = geometry%bottom_domain
    candidate_macro%dynamic_volume_cp = geometry%dynamic_volume_cp
    candidate_macro%volume_domain_cp = geometry%volume_domain_cp

    ! Geometry shrinkage/deactivation cannot destroy water; return displaced water to matrix.
    candidate_macro%water_domain_cp = candidate_macro%water_domain_cp - geometry_return
    receipt%geometry_return_to_matrix_cm = sum(geometry_return)
    receipt%matrix_exchange_rate = receipt%matrix_exchange_rate + sum(geometry_return,dim=1)/step_duration

    call apply_accepted_top_partition(top_partition,candidate_macro,ok)
    if (.not. ok) return
    receipt%accepted_top_cm = top_partition%accepted_total_cm
    receipt%returned_surface_cm = top_partition%returned_surface_cm

    ! Positive exchange is macropore -> matrix; negative exchange is matrix -> macropore.
    do id = 1, geometry%num_domains
      do ic = geometry%top_node, geometry%num_nodes
        if (ic > geometry%bottom_domain(id) .and. abs(exchange_rate_domain_cp(id,ic)) > 1.0e-14_real64) return
        amount = exchange_rate_domain_cp(id,ic)*step_duration
        if (amount >= 0.0_real64) then
          if (amount > candidate_macro%water_domain_cp(id,ic)+1.0e-12_real64) return
          candidate_macro%water_domain_cp(id,ic) = max(0.0_real64,candidate_macro%water_domain_cp(id,ic)-amount)
        else
          available = max(0.0_real64,candidate_macro%volume_domain_cp(id,ic)-candidate_macro%water_domain_cp(id,ic))
          if (-amount > available+1.0e-12_real64) return
          candidate_macro%water_domain_cp(id,ic) = candidate_macro%water_domain_cp(id,ic)-amount
        end if
      end do
    end do
    receipt%matrix_exchange_rate = receipt%matrix_exchange_rate + sum(exchange_rate_domain_cp,dim=1)
    receipt%internal_exchange_to_matrix_cm = sum(exchange_rate_domain_cp)*step_duration + &
         receipt%geometry_return_to_matrix_cm

    ! Rapid drainage is external and belongs only to main domain 1.
    do ic = geometry%top_node, geometry%num_nodes
      amount = rapid_outflow_cp_cm(ic)
      if (ic > geometry%bottom_domain(1) .and. amount > 1.0e-14_real64) return
      if (amount > candidate_macro%water_domain_cp(1,ic)+1.0e-12_real64) return
      candidate_macro%water_domain_cp(1,ic) = max(0.0_real64,candidate_macro%water_domain_cp(1,ic)-amount)
    end do
    receipt%rapid_external_outflow_cm = sum(rapid_outflow_cp_cm)

    receipt%macro_storage_change_cm = sum(candidate_macro%water_domain_cp)-sum(initial_water)
    receipt%macro_balance_residual_cm = receipt%macro_storage_change_cm - &
         (receipt%accepted_top_cm-receipt%internal_exchange_to_matrix_cm-receipt%rapid_external_outflow_cm)
    receipt%valid = abs(receipt%macro_balance_residual_cm) <= 1.0e-10_real64
    ok = receipt%valid
  end subroutine compose_macropore_candidate

  subroutine evaluate_macropore_geometry_return(accepted_macro,geometry,geometry_return,ok)
    type(macropore_continuation_state_t),intent(in)::accepted_macro
    type(macropore_geometry_result_t),intent(in)::geometry
    real(real64),allocatable,intent(out)::geometry_return(:,:)
    logical,intent(out)::ok
    integer::id,ic

    ok=.false.
    if(.not.accepted_macro%ready() .or. .not.geometry%valid)return
    if(accepted_macro%num_domains/=geometry%num_domains .or. &
       accepted_macro%num_nodes/=geometry%num_nodes)return
    if(.not.allocated(geometry%bottom_domain) .or. .not.allocated(geometry%volume_domain_cp))return
    if(size(geometry%bottom_domain)/=geometry%num_domains .or. &
       any(shape(geometry%volume_domain_cp)/=[geometry%num_domains,geometry%num_nodes]))return
    allocate(geometry_return(geometry%num_domains,geometry%num_nodes))
    geometry_return=0.0_real64
    do id=1,geometry%num_domains
      do ic=geometry%top_node,geometry%num_nodes
        if(ic>geometry%bottom_domain(id))then
          geometry_return(id,ic)=accepted_macro%water_domain_cp(id,ic)
        else
          geometry_return(id,ic)=max(0.0_real64,accepted_macro%water_domain_cp(id,ic)- &
               geometry%volume_domain_cp(id,ic))
        end if
      end do
    end do
    ok=.true.
  end subroutine evaluate_macropore_geometry_return

end module mod_ppa_wu05a5_multi_domain_process
