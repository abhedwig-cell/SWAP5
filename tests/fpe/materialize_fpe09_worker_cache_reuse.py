from pathlib import Path
import subprocess

MVG = Path('src/solver/mod_b110_default_mvg_provider.f90')
BACKEND = Path('src/runtime/mod_fmr_serialized_reference_backend.f90')
EXPECTED = {
    MVG: '97d67eb373073b183be6d1bf5b756ecb5125dde2',
    BACKEND: 'e0432faa0e05a3c136ee5aed6fddb12ad631848d',
}


def git_blob(path: Path) -> str:
    return subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'FPE09_FAIL {label} anchor count={count}')
    return text.replace(old, new, 1)


for path, expected in EXPECTED.items():
    actual = git_blob(path)
    if actual != expected:
        raise SystemExit(f'FPE09_FAIL preimage lock {path}: {actual} != {expected}')
print('FPE09_MAT_G01_PREIMAGE_LOCK=PASS')

mvg = MVG.read_text()
mvg = replace_once(
    mvg,
    '  subroutine initialize_b110_default_mvg_parameters(parameters, cofgen_input)\n'
    '    type(b110_default_mvg_parameters_t), intent(out) :: parameters\n'
    '    real(real64), intent(in) :: cofgen_input(:,:)\n'
    '    integer :: i, n\n',
    '  subroutine initialize_b110_default_mvg_parameters(parameters, cofgen_input, storage_reused)\n'
    '    type(b110_default_mvg_parameters_t), intent(inout) :: parameters\n'
    '    real(real64), intent(in) :: cofgen_input(:,:)\n'
    '    logical, intent(out), optional :: storage_reused\n'
    '    integer :: i, n\n',
    'MvG signature')
mvg = replace_once(
    mvg,
    '    parameters%active_nodes = n\n'
    '    allocate(parameters%cofgen(B110_MCOF_REQUIRED,n))\n'
    '    parameters%cofgen = 0.0_real64\n',
    '    parameters%active_nodes = n\n'
    '    if (present(storage_reused)) storage_reused = .false.\n'
    '    if (allocated(parameters%cofgen)) then\n'
    '       if (size(parameters%cofgen,1) /= B110_MCOF_REQUIRED .or. size(parameters%cofgen,2) /= n) then\n'
    '          deallocate(parameters%cofgen)\n'
    '       else\n'
    '          if (present(storage_reused)) storage_reused = .true.\n'
    '       end if\n'
    '    end if\n'
    '    if (.not. allocated(parameters%cofgen)) allocate(parameters%cofgen(B110_MCOF_REQUIRED,n))\n'
    '    parameters%cofgen = 0.0_real64\n',
    'MvG exact-shape reuse')
MVG.write_text(mvg)

backend = BACKEND.read_text()
backend = replace_once(
    backend,
    '      if (associated(self%soil_parameters)) deallocate(self%soil_parameters)\n'
    '      if (associated(self%hydraulic_parameters)) deallocate(self%hydraulic_parameters)\n'
    '      if (associated(self%constitutive)) deallocate(self%constitutive)\n'
    '      if (associated(self%source_sink)) deallocate(self%source_sink)\n'
    '      if (associated(self%root_sink)) deallocate(self%root_sink)\n'
    '      allocate(self%soil_parameters, self%hydraulic_parameters, self%constitutive, self%source_sink, self%root_sink)\n'
    '      self%soil_parameters%parameter_set_id = parameters%parameter_set_id\n'
    '      self%soil_parameters%active_nodes = n\n'
    '      allocate(self%soil_parameters%z(n), self%soil_parameters%dz(n), self%soil_parameters%node_distance(n))\n',
    '      if (.not. associated(self%soil_parameters)) allocate(self%soil_parameters)\n'
    '      if (.not. associated(self%hydraulic_parameters)) allocate(self%hydraulic_parameters)\n'
    '      if (.not. associated(self%constitutive)) allocate(self%constitutive)\n'
    '      if (.not. associated(self%source_sink)) allocate(self%source_sink)\n'
    '      if (.not. associated(self%root_sink)) allocate(self%root_sink)\n'
    '      self%soil_parameters%parameter_set_id = parameters%parameter_set_id\n'
    '      self%soil_parameters%active_nodes = n\n'
    '      if (allocated(self%soil_parameters%z)) then\n'
    '        if (size(self%soil_parameters%z) /= n) deallocate(self%soil_parameters%z)\n'
    '      end if\n'
    '      if (allocated(self%soil_parameters%dz)) then\n'
    '        if (size(self%soil_parameters%dz) /= n) deallocate(self%soil_parameters%dz)\n'
    '      end if\n'
    '      if (allocated(self%soil_parameters%node_distance)) then\n'
    '        if (size(self%soil_parameters%node_distance) /= n) deallocate(self%soil_parameters%node_distance)\n'
    '      end if\n'
    '      if (.not. allocated(self%soil_parameters%z)) allocate(self%soil_parameters%z(n))\n'
    '      if (.not. allocated(self%soil_parameters%dz)) allocate(self%soil_parameters%dz(n))\n'
    '      if (.not. allocated(self%soil_parameters%node_distance)) allocate(self%soil_parameters%node_distance(n))\n',
    'backend parameter object and geometry reuse')
backend = replace_once(
    backend,
    '      if (associated(self%qdra)) deallocate(self%qdra)\n'
    '      if (associated(self%qssdi)) deallocate(self%qssdi)\n'
    '      if (associated(self%qrot)) deallocate(self%qrot)\n'
    '      allocate(self%qdra(size(forcing%drainage_flux_by_level,1),n), self%qssdi(n), self%qrot(n))\n',
    '      if (associated(self%qdra)) then\n'
    '        if (size(self%qdra,1) /= size(forcing%drainage_flux_by_level,1) .or. size(self%qdra,2) /= n) deallocate(self%qdra)\n'
    '      end if\n'
    '      if (associated(self%qssdi)) then\n'
    '        if (size(self%qssdi) /= n) deallocate(self%qssdi)\n'
    '      end if\n'
    '      if (associated(self%qrot)) then\n'
    '        if (size(self%qrot) /= n) deallocate(self%qrot)\n'
    '      end if\n'
    '      if (.not. associated(self%qdra)) allocate(self%qdra(size(forcing%drainage_flux_by_level,1),n))\n'
    '      if (.not. associated(self%qssdi)) allocate(self%qssdi(n))\n'
    '      if (.not. associated(self%qrot)) allocate(self%qrot(n))\n',
    'backend forcing exact-shape reuse')
BACKEND.write_text(backend)

mvg_post = MVG.read_text()
backend_post = BACKEND.read_text()
assert 'intent(inout) :: parameters' in mvg_post
assert 'logical, intent(out), optional :: storage_reused' in mvg_post
assert 'if (.not. allocated(parameters%cofgen)) allocate(parameters%cofgen(B110_MCOF_REQUIRED,n))' in mvg_post
assert mvg_post.count('deallocate(parameters%cofgen)') == 1
assert 'if (.not. associated(self%soil_parameters)) allocate(self%soil_parameters)' in backend_post
assert 'if (.not. associated(self%hydraulic_parameters)) allocate(self%hydraulic_parameters)' in backend_post
assert 'if (.not. associated(self%qdra)) allocate(self%qdra(size(forcing%drainage_flux_by_level,1),n))' in backend_post
assert 'if (.not. associated(self%qssdi)) allocate(self%qssdi(n))' in backend_post
assert 'if (.not. associated(self%qrot)) allocate(self%qrot(n))' in backend_post
assert 'if (associated(self%soil_parameters)) deallocate(self%soil_parameters)' not in backend_post
assert 'allocate(self%qdra(size(forcing%drainage_flux_by_level,1),n), self%qssdi(n), self%qrot(n))' not in backend_post
print('FPE09_MAT_G02_MVG_EXACT_SHAPE_REUSE=PASS')
print('FPE09_MAT_G03_BACKEND_PARAMETER_CACHE_REUSE=PASS')
print('FPE09_MAT_G04_BACKEND_FORCING_CACHE_REUSE=PASS')
print('FPE09_MVG_POSTIMAGE=' + git_blob(MVG))
print('FPE09_BACKEND_POSTIMAGE=' + git_blob(BACKEND))
