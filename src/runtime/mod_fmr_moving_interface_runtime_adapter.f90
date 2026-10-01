module mod_fmr_moving_interface_runtime_adapter
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_moving_interface_manager, only: moving_interface_active_view_t, moving_interface_manager_diagnostics_t, &
       moving_interface_manager_context_t, derive_moving_interface_active_view, &
       prepare_moving_interface_reduced_request_persistent, materialize_moving_interface_full_candidate_persistent, &
       finalize_moving_interface_result_persistent, MI_MANAGER_ROUTE_FULL_BYPASS
  implicit none
  private

  type, public :: fmr_moving_interface_runtime_adapter_t
    type(moving_interface_manager_context_t) :: context
    type(reference_richards_legacy_workspace_t) :: reduced_workspace
    type(b110_default_mvg_parameters_t), pointer :: reduced_hydraulics => null()
    type(b110_default_mvg_provider_t), pointer :: reduced_constitutive => null()
    type(b110_source_sink_provider_t), pointer :: reduced_source_sink => null()
    real(real64), pointer :: reduced_qdra(:,:) => null()
    real(real64), pointer :: reduced_qssdi(:) => null()
    real(real64), pointer :: reduced_qrot(:) => null()
    real(real64), pointer :: tail_pressure_head(:) => null()
    real(real64), pointer :: tail_water_content(:) => null()
    integer :: prepared_active_nodes = 0
    integer(int64) :: source_parameter_set_id = -1_int64
  contains
    procedure, public :: solve => fmr_moving_interface_runtime_solve
    procedure, public :: release => fmr_moving_interface_runtime_release
  end type fmr_moving_interface_runtime_adapter_t

contains

  subroutine fmr_moving_interface_runtime_solve(self, full_solver, full_workspace, full_request, full_hydraulics, &
                                                 full_qdra, full_qssdi, full_qrot, sources_verified_zero, &
                                                 selected, diagnostics, ok)
    class(fmr_moving_interface_runtime_adapter_t), intent(inout) :: self
    type(reference_richards_legacy_solver_t), intent(inout) :: full_solver
    type(reference_richards_legacy_workspace_t), intent(inout) :: full_workspace
    type(soil_water_solve_request_t), intent(in) :: full_request
    type(b110_default_mvg_parameters_t), intent(in) :: full_hydraulics
    real(real64), target, intent(in) :: full_qdra(:,:), full_qssdi(:), full_qrot(:)
    logical, intent(in) :: sources_verified_zero
    type(soil_water_solve_result_t), intent(out) :: selected
    type(moving_interface_manager_diagnostics_t), intent(out) :: diagnostics
    logical, intent(out) :: ok

    type(moving_interface_active_view_t) :: view
    type(soil_water_solve_result_t) :: reduced_result, full_result, empty_full
    integer :: nf, na, first_tail, i, nt
    logical :: prepared, materialized, reduced_valid
    character(len=64) :: reason

    selected = soil_water_solve_result_t()
    diagnostics = moving_interface_manager_diagnostics_t()
    ok = .false.

    nf = full_request%base_state%active_nodes
    if (nf <= 1 .or. full_hydraulics%active_nodes /= nf) then
      call full_bypass('invalid-full-shape')
      return
    end if
    if (.not. allocated(full_hydraulics%cofgen) .or. size(full_hydraulics%cofgen,2) /= nf) then
      call full_bypass('hydraulics-shape-mismatch')
      return
    end if
    if (full_request%boundary%top_mode /= FSI_TOP_MODE_EXPLICIT_FLUX .or. &
        full_request%boundary%bottom_mode /= 2 .or. full_request%boundary%bottom_flux /= 0.0_real64 .or. &
        full_request%numerical%conductivity_implicit_mode /= 0 .or. &
        full_request%numerical%conductivity_mean_method /= 1) then
      call full_bypass('runtime-envelope-ineligible')
      return
    end if
    if (associated(full_request%evaluation%root_sink) .or. associated(full_request%evaluation%dynamic_top_boundary) .or. &
        associated(full_request%evaluation%macropore)) then
      call full_bypass('runtime-process-ineligible')
      return
    end if
    if (full_hydraulics%ksatexm_extension_enabled .or. full_hydraulics%elastic_storage_active) then
      call full_bypass('hydraulic-option-ineligible')
      return
    end if
    if (size(full_qssdi) /= nf .or. size(full_qrot) /= nf .or. size(full_qdra,2) /= nf .or. &
        size(full_qdra,1) <= 0) then
      call full_bypass('source-shape-ineligible')
      return
    end if
    if (.not. sources_verified_zero) then
      call full_bypass('active-source-sink-ineligible')
      return
    end if

    first_tail = saturated_tail_start(full_request, full_hydraulics)
    if (first_tail <= 1 .or. first_tail > nf) then
      call full_bypass('reduced-view-ineligible')
      return
    end if

    call derive_moving_interface_active_view(full_request%base_state, first_tail, view, prepared, reason)
    if (.not. prepared .or. .not. view%eligible) then
      call full_bypass(trim(reason))
      return
    end if

    call prepare_moving_interface_reduced_request_persistent(full_request, view, self%context, prepared, reason)
    if (.not. prepared) then
      call full_fallback(trim(reason))
      return
    end if

    na = view%active_nodes
    call prepare_reduced_provider(na, prepared)
    if (.not. prepared) then
      call full_fallback('reduced-provider-prepare-failed')
      return
    end if

    self%context%reduced_request%evaluation%constitutive => self%reduced_constitutive
    self%context%reduced_request%evaluation%source_sink => self%reduced_source_sink
    nullify(self%context%reduced_request%evaluation%root_sink)
    nullify(self%context%reduced_request%evaluation%dynamic_top_boundary)
    nullify(self%context%reduced_request%evaluation%macropore)

    call full_solver%solve(self%context%reduced_request, self%reduced_workspace, reduced_result)
    reduced_valid = reduced_result%status == SW_SOLVE_CONVERGED

    if (reduced_valid) then
      nt = nf-na
      if (.not. associated(self%tail_pressure_head)) then
        allocate(self%tail_pressure_head(nt), self%tail_water_content(nt))
      else if (size(self%tail_pressure_head) /= nt) then
        deallocate(self%tail_pressure_head)
        nullify(self%tail_pressure_head)
        if (associated(self%tail_water_content)) then
          deallocate(self%tail_water_content)
          nullify(self%tail_water_content)
        end if
        allocate(self%tail_pressure_head(nt), self%tail_water_content(nt))
      end if
      self%tail_pressure_head(1) = reduced_result%candidate_state%pressure_head(na) + &
           full_request%parameters%node_distance(na+1)
      do i = 2, nt
        self%tail_pressure_head(i) = self%tail_pressure_head(i-1) + full_request%parameters%node_distance(na+i)
      end do
      self%tail_water_content = full_hydraulics%cofgen(2,na+1:nf)
      if (any(self%tail_pressure_head < 0.0_real64)) reduced_valid = .false.
    end if

    if (reduced_valid) then
      call materialize_moving_interface_full_candidate_persistent(full_request%base_state, reduced_result, &
           self%tail_pressure_head, self%tail_water_content, self%context, materialized, reason)
      reduced_valid = materialized
    end if

    if (reduced_valid) then
      empty_full = soil_water_solve_result_t()
      call finalize_moving_interface_result_persistent(empty_full, .true., view, self%reduced_workspace%richards%generation, &
           'none', self%context, diagnostics)
      selected = self%context%full_candidate
      ok = selected%status == SW_SOLVE_CONVERGED
      return
    end if

    call full_fallback('reduced-solve-or-reconstruction-failed')

  contains

    subroutine full_bypass(bypass_reason)
      character(len=*), intent(in) :: bypass_reason
      view = moving_interface_active_view_t()
      view%full_nodes = max(0,nf)
      view%active_nodes = max(0,nf)
      view%tail_start_node = max(0,nf)
      view%interface_face = max(0,nf)
      view%eligible = .false.
      call full_solver%solve(full_request, full_workspace, full_result)
      call finalize_moving_interface_result_persistent(full_result, .false., view, 0_int64, bypass_reason, self%context, diagnostics)
      diagnostics%fallback_reason = bypass_reason
      diagnostics%route = MI_MANAGER_ROUTE_FULL_BYPASS
      selected = self%context%full_candidate
      ok = selected%status == SW_SOLVE_CONVERGED
    end subroutine full_bypass

    subroutine full_fallback(fallback_reason)
      character(len=*), intent(in) :: fallback_reason
      call full_solver%solve(full_request, full_workspace, full_result)
      call finalize_moving_interface_result_persistent(full_result, .false., view, &
           self%reduced_workspace%richards%generation, fallback_reason, self%context, diagnostics)
      selected = self%context%full_candidate
      ok = selected%status == SW_SOLVE_CONVERGED
    end subroutine full_fallback

    subroutine prepare_reduced_provider(n, local_ok)
      integer, intent(in) :: n
      logical, intent(out) :: local_ok
      integer :: levels

      local_ok = .false.
      levels = size(full_qdra,1)
      if (n <= 0 .or. n >= nf) return

      if (.not. associated(self%reduced_hydraulics)) allocate(self%reduced_hydraulics)
      if (self%prepared_active_nodes /= n .or. self%source_parameter_set_id /= full_request%parameters%parameter_set_id) then
        call initialize_b110_default_mvg_parameters(self%reduced_hydraulics, full_hydraulics%cofgen(:,1:n))
        self%prepared_active_nodes = n
        self%source_parameter_set_id = full_request%parameters%parameter_set_id
      end if
      if (.not. associated(self%reduced_constitutive)) allocate(self%reduced_constitutive)
      call bind_b110_default_mvg_provider(self%reduced_constitutive, self%reduced_hydraulics, full_request%step_duration)

      if (.not. associated(self%reduced_qdra)) then
        allocate(self%reduced_qdra(levels,n), self%reduced_qssdi(n), self%reduced_qrot(n))
        self%reduced_qdra = 0.0_real64
        self%reduced_qssdi = 0.0_real64
        self%reduced_qrot = 0.0_real64
      else if (size(self%reduced_qdra,1) /= levels .or. size(self%reduced_qdra,2) /= n) then
        deallocate(self%reduced_qdra)
        if (associated(self%reduced_qssdi)) deallocate(self%reduced_qssdi)
        if (associated(self%reduced_qrot)) deallocate(self%reduced_qrot)
        allocate(self%reduced_qdra(levels,n), self%reduced_qssdi(n), self%reduced_qrot(n))
        self%reduced_qdra = 0.0_real64
        self%reduced_qssdi = 0.0_real64
        self%reduced_qrot = 0.0_real64
      end if
      if (.not. associated(self%reduced_source_sink)) allocate(self%reduced_source_sink)
      call bind_b110_source_sink_provider(self%reduced_source_sink, self%reduced_qdra, self%reduced_qssdi, self%reduced_qrot)
      local_ok = .true.
    end subroutine prepare_reduced_provider

  end subroutine fmr_moving_interface_runtime_solve

  integer function saturated_tail_start(request, hydraulics) result(first)
    type(soil_water_solve_request_t), intent(in) :: request
    type(b110_default_mvg_parameters_t), intent(in) :: hydraulics
    integer :: i, n
    logical :: saturated_i

    n = request%base_state%active_nodes
    first = n + 1
    if (n <= 0 .or. .not. allocated(request%base_state%pressure_head) .or. &
        .not. allocated(request%base_state%water_content)) return
    if (.not. allocated(hydraulics%cofgen) .or. size(hydraulics%cofgen,2) /= n) return

    do i = n, 1, -1
      saturated_i = request%base_state%pressure_head(i) >= 0.0_real64 .and. &
           abs(request%base_state%water_content(i)-hydraulics%cofgen(2,i)) <= 1.0e-10_real64
      if (saturated_i) then
        first = i
      else
        exit
      end if
    end do
    if (first <= n .and. first > 1) then
      do i = 1, first-1
        saturated_i = request%base_state%pressure_head(i) >= 0.0_real64 .and. &
             abs(request%base_state%water_content(i)-hydraulics%cofgen(2,i)) <= 1.0e-10_real64
        if (saturated_i) then
          first = -1
          exit
        end if
      end do
    end if
  end function saturated_tail_start

  subroutine fmr_moving_interface_runtime_release(self)
    class(fmr_moving_interface_runtime_adapter_t), intent(inout) :: self
    if (associated(self%reduced_hydraulics)) then
      deallocate(self%reduced_hydraulics)
      nullify(self%reduced_hydraulics)
    end if
    if (associated(self%reduced_constitutive)) then
      deallocate(self%reduced_constitutive)
      nullify(self%reduced_constitutive)
    end if
    if (associated(self%reduced_source_sink)) then
      deallocate(self%reduced_source_sink)
      nullify(self%reduced_source_sink)
    end if
    if (associated(self%reduced_qdra)) then
      deallocate(self%reduced_qdra)
      nullify(self%reduced_qdra)
    end if
    if (associated(self%reduced_qssdi)) then
      deallocate(self%reduced_qssdi)
      nullify(self%reduced_qssdi)
    end if
    if (associated(self%reduced_qrot)) then
      deallocate(self%reduced_qrot)
      nullify(self%reduced_qrot)
    end if
    if (associated(self%tail_pressure_head)) then
      deallocate(self%tail_pressure_head)
      nullify(self%tail_pressure_head)
    end if
    if (associated(self%tail_water_content)) then
      deallocate(self%tail_water_content)
      nullify(self%tail_water_content)
    end if
    self%prepared_active_nodes = 0
    self%source_parameter_set_id = -1_int64
  end subroutine fmr_moving_interface_runtime_release

end module mod_fmr_moving_interface_runtime_adapter
