module mod_ppa_wu05a6_sorptivity_rate
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  real(real64), parameter :: CRIT_SAT_DEF = 1.0e-8_real64
  real(real64), parameter :: Q_SORP_MAX = 1.0e3_real64

  type, public :: sorptivity_rate_request_t
    integer :: num_domains = 0
    integer :: num_nodes = 0
    integer :: top_node = 1
    integer :: swmbf = 1
    integer :: matrix_top_saturated_node = 1
    logical :: perched_active = .false.
    integer :: perched_top_node = 1
    integer :: perched_bottom_node = 0
    real(real64) :: step_duration = 0.0_real64
    real(real64) :: flow_reduction = 1.0_real64
    integer, allocatable :: bottom_domain(:)
    integer, allocatable :: top_water_node(:)
    real(real64), allocatable :: theta(:)
    real(real64), allocatable :: theta_s(:)
    real(real64), allocatable :: theta_r(:)
    real(real64), allocatable :: dz(:)
    real(real64), allocatable :: diameter(:)
    real(real64), allocatable :: wall_correction(:)
    real(real64), allocatable :: sorptivity_max(:)
    real(real64), allocatable :: sorptivity_alpha(:)
    real(real64), allocatable :: domain_fraction(:,:)
    real(real64), allocatable :: wet_fraction(:,:)
    real(real64), allocatable :: history_sorptivity(:,:)
    real(real64), allocatable :: history_theta_ref(:,:)
    real(real64), allocatable :: history_absorption_time(:,:)
  contains
    procedure, public :: valid => sorptivity_request_valid
  end type sorptivity_rate_request_t

  type, public :: sorptivity_rate_result_t
    logical :: valid = .false.
    real(real64), allocatable :: amount_cm(:,:)
    real(real64), allocatable :: rate_cm_per_day(:,:)
    real(real64), allocatable :: seed_sorptivity(:,:)
    real(real64), allocatable :: seed_theta_ref(:,:)
    logical, allocatable :: end_event(:,:)
  end type sorptivity_rate_result_t

  public :: evaluate_sorptivity_rate

contains

  pure logical function sorptivity_request_valid(self) result(ok)
    class(sorptivity_rate_request_t), intent(in) :: self
    integer :: nd, n

    nd = self%num_domains
    n = self%num_nodes
    ok = nd > 0 .and. n > 0 .and. self%top_node >= 1 .and. self%top_node <= n .and. &
         self%step_duration > 0.0_real64 .and. self%flow_reduction >= 0.0_real64
    if (.not. ok) return

    ok = allocated(self%bottom_domain) .and. allocated(self%top_water_node) .and. &
         allocated(self%theta) .and. allocated(self%theta_s) .and. allocated(self%theta_r) .and. &
         allocated(self%dz) .and. allocated(self%diameter) .and. allocated(self%wall_correction) .and. &
         allocated(self%sorptivity_max) .and. allocated(self%sorptivity_alpha) .and. &
         allocated(self%domain_fraction) .and. allocated(self%wet_fraction) .and. &
         allocated(self%history_sorptivity) .and. allocated(self%history_theta_ref) .and. &
         allocated(self%history_absorption_time)
    if (.not. ok) return

    ok = size(self%bottom_domain) == nd .and. size(self%top_water_node) == nd .and. &
         size(self%theta) == n .and. size(self%theta_s) == n .and. size(self%theta_r) == n .and. &
         size(self%dz) == n .and. size(self%diameter) == n .and. size(self%wall_correction) == n .and. &
         size(self%sorptivity_max) == n .and. size(self%sorptivity_alpha) == n .and. &
         all(shape(self%domain_fraction) == [nd,n]) .and. all(shape(self%wet_fraction) == [nd,n]) .and. &
         all(shape(self%history_sorptivity) == [nd,n]) .and. &
         all(shape(self%history_theta_ref) == [nd,n]) .and. &
         all(shape(self%history_absorption_time) == [nd,n])
    if (.not. ok) return

    ok = all(self%theta_s > self%theta_r) .and. all(self%dz > 0.0_real64) .and. &
         all(self%diameter > 0.0_real64) .and. all(self%wall_correction >= 0.0_real64) .and. &
         all(self%sorptivity_max >= 0.0_real64) .and. all(self%sorptivity_alpha > 0.0_real64) .and. &
         all(self%domain_fraction >= 0.0_real64) .and. all(self%wet_fraction >= 0.0_real64) .and. &
         all(self%wet_fraction <= 1.0_real64)
  end function sorptivity_request_valid

  subroutine evaluate_sorptivity_rate(request, result)
    type(sorptivity_rate_request_t), intent(in) :: request
    type(sorptivity_rate_result_t), intent(out) :: result

    integer :: id, ic, ic_top, ic_bottom, n, nd
    real(real64) :: sat_def, time, theta_ref, sorp_seed, active, amount
    logical :: excluded_by_perched

    result = sorptivity_rate_result_t()
    if (.not. request%valid()) return

    nd = request%num_domains
    n = request%num_nodes
    allocate(result%amount_cm(nd,n), result%rate_cm_per_day(nd,n), &
         result%seed_sorptivity(nd,n), result%seed_theta_ref(nd,n), result%end_event(nd,n))
    result%amount_cm = 0.0_real64
    result%rate_cm_per_day = 0.0_real64
    result%seed_sorptivity = request%history_sorptivity
    result%seed_theta_ref = request%history_theta_ref
    result%end_event = .true.

    do id = 1, nd
      ic_bottom = min(request%bottom_domain(id), request%matrix_top_saturated_node-1)
      if (request%swmbf == 2 .and. id == 1) then
        ic_top = request%top_node
      else
        ic_top = request%top_water_node(id)
      end if
      if (ic_bottom < ic_top) cycle

      do ic = ic_top, ic_bottom
        excluded_by_perched = request%perched_active .and. &
             ic >= request%perched_top_node .and. ic <= request%perched_bottom_node
        if (excluded_by_perched) cycle

        sat_def = max(0.0_real64, request%theta_s(ic)-request%theta(ic))
        if (sat_def < CRIT_SAT_DEF) cycle

        time = request%history_absorption_time(id,ic)
        theta_ref = request%history_theta_ref(id,ic)
        sorp_seed = request%history_sorptivity(id,ic)

        if (time < 1.0e-8_real64) then
          theta_ref = request%theta_s(ic)
          sorp_seed = request%sorptivity_max(ic) * &
               (max(0.0_real64,request%theta_s(ic)-request%theta(ic)) / &
               (request%theta_s(ic)-request%theta_r(ic)))**request%sorptivity_alpha(ic)
          active = sorp_seed
          result%seed_theta_ref(id,ic) = theta_ref
          result%seed_sorptivity(id,ic) = sorp_seed
        else if (theta_ref-request%theta(ic) > CRIT_SAT_DEF) then
          active = request%sorptivity_max(ic) * &
               ((theta_ref-request%theta(ic)) / &
               (request%theta_s(ic)-request%theta_r(ic)))**request%sorptivity_alpha(ic)
        else
          active = 0.0_real64
        end if

        amount = active*request%domain_fraction(id,ic) * &
             (4.0_real64*request%wall_correction(ic)*request%dz(ic)/request%diameter(ic)) * &
             (sqrt(time+request%step_duration)-sqrt(time))

        if ((request%swmbf == 1 .or. id > 1) .and. ic == request%top_water_node(id)) then
          amount = request%wet_fraction(id,ic)*amount
        end if

        amount = min(Q_SORP_MAX*request%step_duration*request%dz(ic), max(0.0_real64,amount))
        if (amount/request%step_duration > 1.0e-7_real64) result%end_event(id,ic) = .false.

        result%amount_cm(id,ic) = request%flow_reduction*amount
        result%rate_cm_per_day(id,ic) = result%amount_cm(id,ic)/request%step_duration
      end do
    end do

    result%valid = .true.
  end subroutine evaluate_sorptivity_rate

end module mod_ppa_wu05a6_sorptivity_rate
