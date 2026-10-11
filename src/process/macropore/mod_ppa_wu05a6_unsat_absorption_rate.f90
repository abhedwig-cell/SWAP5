module mod_ppa_wu05a6_unsat_absorption_rate
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a6_sorptivity_rate, only: sorptivity_rate_request_t, sorptivity_rate_result_t, &
       evaluate_sorptivity_rate
  implicit none
  private

  type, public :: unsat_absorption_request_t
    type(sorptivity_rate_request_t) :: sorptivity
    real(real64) :: shape_factor = 1.0_real64
    real(real64), allocatable :: pressure_head(:)
    real(real64), allocatable :: elevation(:)
    real(real64), allocatable :: conductivity(:)
    real(real64), allocatable :: entry_head(:)
    real(real64), allocatable :: groundwater_level_domain(:)
    real(real64), allocatable :: sorp_fac_parallel(:)
  contains
    procedure, public :: valid => unsat_request_valid
  end type unsat_absorption_request_t

  type, public :: unsat_absorption_result_t
    logical :: valid = .false.
    real(real64), allocatable :: sorptivity_amount_cm(:,:)
    real(real64), allocatable :: darcy_amount_cm(:,:)
    real(real64), allocatable :: selected_amount_cm(:,:)
    real(real64), allocatable :: selected_rate_cm_per_day(:,:)
    logical, allocatable :: selected_by_sorptivity(:,:)
    logical, allocatable :: end_event(:,:)
    real(real64), allocatable :: seed_sorptivity(:,:)
    real(real64), allocatable :: seed_theta_ref(:,:)
  end type unsat_absorption_result_t

  public :: evaluate_unsat_absorption

contains

  pure logical function unsat_request_valid(self) result(ok)
    class(unsat_absorption_request_t), intent(in) :: self
    integer :: n, nd

    ok = self%sorptivity%valid()
    if (.not. ok) return
    n = self%sorptivity%num_nodes
    nd = self%sorptivity%num_domains
    ok = self%shape_factor >= 0.0_real64 .and. allocated(self%pressure_head) .and. &
         allocated(self%elevation) .and. allocated(self%conductivity) .and. &
         allocated(self%entry_head) .and. allocated(self%groundwater_level_domain) .and. &
         allocated(self%sorp_fac_parallel)
    if (.not. ok) return
    ok = size(self%pressure_head) == n .and. size(self%elevation) == n .and. &
         size(self%conductivity) == n .and. size(self%entry_head) == n .and. &
         size(self%sorp_fac_parallel) == n .and. size(self%groundwater_level_domain) == nd
    if (.not. ok) return
    ok = all(self%conductivity >= 0.0_real64) .and. all(self%sorp_fac_parallel >= 0.0_real64) .and. &
         all(self%sorp_fac_parallel <= 1.0_real64)
  end function unsat_request_valid

  subroutine evaluate_unsat_absorption(request, result)
    type(unsat_absorption_request_t), intent(in) :: request
    type(unsat_absorption_result_t), intent(out) :: result

    type(sorptivity_rate_request_t) :: sorp_request
    type(sorptivity_rate_result_t) :: sorp_result
    integer :: id, ic, ic_top, ic_bottom, nd, n
    real(real64) :: hmp, delh, recres, raw_darcy, sat_fraction, sorp_fac, darcy_scaled, selected
    logical :: excluded_by_perched

    result = unsat_absorption_result_t()
    if (.not. request%valid()) return

    sorp_request = request%sorptivity
    sorp_request%flow_reduction = 1.0_real64
    call evaluate_sorptivity_rate(sorp_request,sorp_result)
    if (.not. sorp_result%valid) return

    nd = request%sorptivity%num_domains
    n = request%sorptivity%num_nodes
    allocate(result%sorptivity_amount_cm(nd,n),result%darcy_amount_cm(nd,n), &
         result%selected_amount_cm(nd,n),result%selected_rate_cm_per_day(nd,n), &
         result%selected_by_sorptivity(nd,n),result%end_event(nd,n), &
         result%seed_sorptivity(nd,n),result%seed_theta_ref(nd,n))

    result%sorptivity_amount_cm = sorp_result%amount_cm
    result%darcy_amount_cm = 0.0_real64
    result%selected_amount_cm = 0.0_real64
    result%selected_rate_cm_per_day = 0.0_real64
    result%selected_by_sorptivity = .false.
    result%end_event = .true.
    result%seed_sorptivity = sorp_result%seed_sorptivity
    result%seed_theta_ref = sorp_result%seed_theta_ref

    do id = 1, nd
      ic_bottom = min(request%sorptivity%bottom_domain(id),request%sorptivity%matrix_top_saturated_node-1)
      if (request%sorptivity%swmbf == 2 .and. id == 1) then
        ic_top = request%sorptivity%top_node
      else
        ic_top = request%sorptivity%top_water_node(id)
      end if
      if (ic_bottom < ic_top) cycle

      do ic = ic_top, ic_bottom
        excluded_by_perched = request%sorptivity%perched_active .and. &
             ic >= request%sorptivity%perched_top_node .and. ic <= request%sorptivity%perched_bottom_node
        if (excluded_by_perched) cycle

        darcy_scaled = 0.0_real64
        if (ic > request%sorptivity%top_water_node(id)) then
          hmp = max(0.0_real64,request%groundwater_level_domain(id)-request%elevation(ic))
          if (request%pressure_head(ic) < request%entry_head(ic)-1.0e-8_real64 .and. hmp > 1.0e-8_real64) then
            delh = max(0.0_real64,hmp-request%pressure_head(ic))
          else
            delh = 0.0_real64
          end if

          recres = request%shape_factor*8.0_real64*request%sorptivity%domain_fraction(id,ic) * &
               request%sorptivity%dz(ic)*request%conductivity(ic) / request%sorptivity%diameter(ic)**2
          raw_darcy = recres*delh*request%sorptivity%step_duration

          sat_fraction = max(0.0_real64,request%sorptivity%theta_s(ic)-request%sorptivity%theta(ic)) / &
               (request%sorptivity%theta_s(ic)-request%sorptivity%theta_r(ic))
          sorp_fac = request%sorp_fac_parallel(ic) + (1.0_real64-request%sorp_fac_parallel(ic)) * &
               (1.0_real64-sat_fraction**request%sorptivity%sorptivity_alpha(ic))
          darcy_scaled = sorp_fac*raw_darcy
        end if

        result%darcy_amount_cm(id,ic) = darcy_scaled

        if (result%sorptivity_amount_cm(id,ic) > darcy_scaled) then
          selected = result%sorptivity_amount_cm(id,ic)
          result%selected_by_sorptivity(id,ic) = .true.
          result%end_event(id,ic) = sorp_result%end_event(id,ic)
        else
          selected = darcy_scaled
          result%selected_by_sorptivity(id,ic) = .false.
          result%end_event(id,ic) = .true.
        end if

        selected = request%sorptivity%flow_reduction*selected
        result%selected_amount_cm(id,ic) = selected
        result%selected_rate_cm_per_day(id,ic) = selected/request%sorptivity%step_duration
      end do
    end do

    result%valid = .true.
  end subroutine evaluate_unsat_absorption

end module mod_ppa_wu05a6_unsat_absorption_rate
