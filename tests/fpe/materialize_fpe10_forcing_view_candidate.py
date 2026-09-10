from pathlib import Path
import subprocess

EXPECTED = {
    'src/runtime/mod_fmr_serialized_reference_backend.f90': '64c3d9581c71fc7bf5e5f3764995d41280312a2e',
    'src/runtime/mod_fmr_serialized_multiswap_runtime.f90': 'be4005a97e35c498ffc40297409a75efe65ff5df',
    'src/runtime/mod_fmr_parallel_worker_pool.f90': '393e9bfbc4c078d259a5ec70aca78f50e54e8b35',
}


def blob(path):
    return subprocess.check_output(['git', 'rev-parse', f'HEAD:{path}'], text=True).strip()


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'FPE10_MATERIALIZE_FAIL {label}: expected 1 occurrence, got {count}')
    return text.replace(old, new, 1)


for path, expected in EXPECTED.items():
    actual = blob(path)
    if actual != expected:
        raise SystemExit(f'FPE10_MATERIALIZE_FAIL preimage lock {path}: {actual} != {expected}')
print('FPE10_VIEW_G01_PREIMAGE_LOCK=PASS')

# Backend: opt-in worker mode, trial-scoped direct association, no change to the
# default serialized reference behavior.
path = Path('src/runtime/mod_fmr_serialized_reference_backend.f90')
text = path.read_text()
text = replace_once(text,
"    real(real64), pointer :: qrot(:) => null()\n    integer :: bottom_mode = 7\n",
"    real(real64), pointer :: qrot(:) => null()\n    logical :: direct_forcing_views_enabled = .false.\n    integer :: bottom_mode = 7\n",
'backend mode field')

text = replace_once(text,
"  subroutine fmr_serialized_backend_initialize(self, top_boundary)\n    class(fmr_serialized_reference_backend_t), target, intent(inout) :: self\n    class(top_boundary_provider_t), target, intent(in) :: top_boundary\n    self%model%top_boundary => top_boundary\n",
"  subroutine fmr_serialized_backend_initialize(self, top_boundary, enable_direct_forcing_views)\n    class(fmr_serialized_reference_backend_t), target, intent(inout) :: self\n    class(top_boundary_provider_t), target, intent(in) :: top_boundary\n    logical, intent(in), optional :: enable_direct_forcing_views\n    logical :: requested_direct_views\n    requested_direct_views = .false.\n    if (present(enable_direct_forcing_views)) requested_direct_views = enable_direct_forcing_views\n    if (requested_direct_views .and. .not. self%model%direct_forcing_views_enabled) then\n      if (associated(self%model%qdra)) deallocate(self%model%qdra)\n      if (associated(self%model%qssdi)) deallocate(self%model%qssdi)\n      if (associated(self%model%qrot)) deallocate(self%model%qrot)\n    end if\n    self%model%direct_forcing_views_enabled = requested_direct_views\n    if (self%model%direct_forcing_views_enabled) then\n      nullify(self%model%qdra, self%model%qssdi, self%model%qrot)\n    end if\n    self%model%top_boundary => top_boundary\n",
'backend initialize opt-in')

text = replace_once(text,
"    type(fmr_b110_physical_forcing_t), intent(in) :: forcing\n    type(canonical_numerical_config_t), intent(in) :: config\n",
"    type(fmr_b110_physical_forcing_t), target, intent(in) :: forcing\n    type(canonical_numerical_config_t), intent(in) :: config\n",
'backend run_trial forcing target')

needle = "    self%model%temporal_indicator_budget = 0.0_real64\n    if (.not. self%initialized .or. column%backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE .or. &\n"
replacement = "    self%model%temporal_indicator_budget = 0.0_real64\n    if (self%model%direct_forcing_views_enabled) then\n      nullify(self%model%qdra, self%model%qssdi, self%model%qrot)\n    end if\n    if (.not. self%initialized .or. column%backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE .or. &\n"
text = replace_once(text, needle, replacement, 'clear stale direct views')

needle = "    call prepare_snow_outer_event(self%model, parameters, committed, forcing, t0, t1)\n    call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &\n         result, candidate, diagnostics)\n  end subroutine fmr_serialized_backend_run_trial\n"
replacement = "    if (self%model%direct_forcing_views_enabled) then\n      if (parameters%bottom_mode /= 7 .or. parameters%swkimpl /= 0 .or. parameters%swsophy /= 0 .or. &\n          parameters%root_extraction_active .or. parameters%snow_active .or. parameters%macropore_active .or. &\n          parameters%frost_active .or. parameters%hysteresis_active .or. &\n          parameters%tabulated_hydraulics_active .or. parameters%elasticity_active .or. &\n          allocated(parameters%snow) .or. .not. allocated(forcing%drainage_flux_by_level) .or. &\n          .not. allocated(forcing%subsurface_irrigation_source) .or. .not. allocated(forcing%root_extraction_sink)) then\n        result = kernel_result_t()\n        result%status = KERNEL_STATUS_NOT_ADMITTED\n        candidate = kernel_candidate_state_t()\n        diagnostics = kernel_diagnostics_t()\n        diagnostics%admission_rejections = 1\n        return\n      end if\n      self%model%qdra => forcing%drainage_flux_by_level\n      self%model%qssdi => forcing%subsurface_irrigation_source\n      self%model%qrot => forcing%root_extraction_sink\n    end if\n    call prepare_snow_outer_event(self%model, parameters, committed, forcing, t0, t1)\n    call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &\n         result, candidate, diagnostics)\n    if (self%model%direct_forcing_views_enabled) then\n      nullify(self%model%qdra, self%model%qssdi, self%model%qrot)\n    end if\n  end subroutine fmr_serialized_backend_run_trial\n"
text = replace_once(text, needle, replacement, 'trial-scoped forcing view')

copy_block = """      if (associated(self%qdra)) then
        if (size(self%qdra,1) /= size(forcing%drainage_flux_by_level,1) .or. size(self%qdra,2) /= n) deallocate(self%qdra)
      end if
      if (associated(self%qssdi)) then
        if (size(self%qssdi) /= n) deallocate(self%qssdi)
      end if
      if (associated(self%qrot)) then
        if (size(self%qrot) /= n) deallocate(self%qrot)
      end if
      if (.not. associated(self%qdra)) allocate(self%qdra(size(forcing%drainage_flux_by_level,1),n))
      if (.not. associated(self%qssdi)) allocate(self%qssdi(n))
      if (.not. associated(self%qrot)) allocate(self%qrot(n))
      self%qdra = forcing%drainage_flux_by_level
      self%qssdi = forcing%subsurface_irrigation_source
      self%qrot = forcing%root_extraction_sink
"""
view_block = """      if (self%direct_forcing_views_enabled) then
        if (.not. associated(self%qdra) .or. .not. associated(self%qssdi) .or. .not. associated(self%qrot)) return
        if (size(self%qdra,1) /= size(forcing%drainage_flux_by_level,1) .or. size(self%qdra,2) /= n .or. &
            size(self%qssdi) /= n .or. size(self%qrot) /= n) return
      else
        if (associated(self%qdra)) then
          if (size(self%qdra,1) /= size(forcing%drainage_flux_by_level,1) .or. size(self%qdra,2) /= n) deallocate(self%qdra)
        end if
        if (associated(self%qssdi)) then
          if (size(self%qssdi) /= n) deallocate(self%qssdi)
        end if
        if (associated(self%qrot)) then
          if (size(self%qrot) /= n) deallocate(self%qrot)
        end if
        if (.not. associated(self%qdra)) allocate(self%qdra(size(forcing%drainage_flux_by_level,1),n))
        if (.not. associated(self%qssdi)) allocate(self%qssdi(n))
        if (.not. associated(self%qrot)) allocate(self%qrot(n))
        self%qdra = forcing%drainage_flux_by_level
        self%qssdi = forcing%subsurface_irrigation_source
        self%qrot = forcing%root_extraction_sink
      end if
"""
text = replace_once(text, copy_block, view_block, 'prepare interval copy/view branch')
path.write_text(text)

# Scalar execution seam: TARGET only scopes the nested backend view; the view is
# released before this subroutine returns.
path = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90')
text = path.read_text()
old = "    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)\n    type(kernel_committed_state_t), intent(inout) :: state_registry(:)\n"
# The file contains this declaration twice (batch API and scalar seam). Only the
# scalar seam must carry TARGET; select by splitting at the scalar subroutine.
marker = '  subroutine fmr_execute_serialized_physical_column('
pos = text.index(marker)
head, tail = text[:pos], text[pos:]
tail = replace_once(tail, old,
"    type(fmr_b110_physical_forcing_t), target, intent(in) :: forcing_registry(:)\n    type(kernel_committed_state_t), intent(inout) :: state_registry(:)\n",
'scalar forcing registry target')
path.write_text(head + tail)

# Parallel pool owns the full active lifetime and explicitly opts worker
# backends into direct views. One-worker delegation remains untouched.
path = Path('src/runtime/mod_fmr_parallel_worker_pool.f90')
text = path.read_text()
text = replace_once(text,
"    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)\n    type(kernel_committed_state_t), intent(inout) :: state_registry(:)\n",
"    type(fmr_b110_physical_forcing_t), target, intent(in) :: forcing_registry(:)\n    type(kernel_committed_state_t), intent(inout) :: state_registry(:)\n",
'parallel forcing registry target')
text = replace_once(text,
"      call backends(w)%initialize(top_boundary)\n      worker_runtime(w) = fmr_serialized_batch_diagnostics_t()\n",
"      call backends(w)%initialize(top_boundary, enable_direct_forcing_views=.true.)\n      worker_runtime(w) = fmr_serialized_batch_diagnostics_t()\n",
'parallel opt-in')
path.write_text(text)

print('FPE10_VIEW_G02_BACKEND_TRIAL_SCOPED_VIEW=PASS')
print('FPE10_VIEW_G03_SERIAL_REFERENCE_DEFAULT_UNCHANGED=PASS')
print('FPE10_VIEW_G04_PARALLEL_V1_EXPLICIT_OPT_IN=PASS')
