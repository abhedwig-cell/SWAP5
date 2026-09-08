#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess

EXPECTED = {
    'src/legacy/b1_10_port/headcalc.f90': '355bf276e3564bdf9128c23077dbe03da712a17c',
    'src/adapter/mod_reference_richards_legacy_binding.f90': '9e9d21ff7ae2b62c95b1b93c016ae95abb447137',
    'src/solver/mod_reference_richards_workspace.f90': '93285b2ca24669494c93c00403e3783fca6758e9',
}


def git_blob(path: str) -> str:
    return subprocess.check_output(['git', 'hash-object', path], text=True).strip()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'F-SI14 materializer {label}: expected 1 marker, found {count}')
    return text.replace(old, new, 1)


for path, expected in EXPECTED.items():
    actual = git_blob(path)
    if actual != expected:
        raise SystemExit(f'F-SI14 preimage mismatch {path}: {actual} != {expected}')

# -----------------------------------------------------------------------------
# Worker-owned provider temporaries: remove automatic numnod-sized arrays from
# HeadCalc and keep them with the reference worker workspace instead.
# -----------------------------------------------------------------------------
wp = Path('src/solver/mod_reference_richards_workspace.f90')
w = wp.read_text()
w = replace_once(
    w,
    '     real(real64), allocatable :: sink(:)\n     real(real64), allocatable :: source(:)\n',
    '     real(real64), allocatable :: sink(:)\n     real(real64), allocatable :: source(:)\n'
    '     real(real64), allocatable :: provider_theta(:)\n'
    '     real(real64), allocatable :: provider_k(:)\n'
    '     real(real64), allocatable :: provider_capacity(:)\n'
    '     real(real64), allocatable :: provider_dkdh(:)\n'
    '     real(real64), allocatable :: provider_root_sink(:)\n',
    'workspace fields')
w = replace_once(
    w,
    '       allocate(workspace%sink(active_nodes), workspace%source(active_nodes))\n',
    '       allocate(workspace%sink(active_nodes), workspace%source(active_nodes))\n'
    '       allocate(workspace%provider_theta(active_nodes), workspace%provider_k(active_nodes))\n'
    '       allocate(workspace%provider_capacity(active_nodes), workspace%provider_dkdh(active_nodes))\n'
    '       allocate(workspace%provider_root_sink(active_nodes))\n',
    'workspace allocation')
w = replace_once(
    w,
    '    workspace%sink = 0.0_real64\n    workspace%source = 0.0_real64\n',
    '    workspace%sink = 0.0_real64\n    workspace%source = 0.0_real64\n'
    '    workspace%provider_theta = 0.0_real64\n'
    '    workspace%provider_k = 0.0_real64\n'
    '    workspace%provider_capacity = 0.0_real64\n'
    '    workspace%provider_dkdh = 0.0_real64\n'
    '    workspace%provider_root_sink = 0.0_real64\n',
    'workspace reset')
w = replace_once(
    w,
    '    workspace%sink = qnan\n    workspace%source = qnan\n',
    '    workspace%sink = qnan\n    workspace%source = qnan\n'
    '    workspace%provider_theta = qnan\n'
    '    workspace%provider_k = qnan\n'
    '    workspace%provider_capacity = qnan\n'
    '    workspace%provider_dkdh = qnan\n'
    '    workspace%provider_root_sink = qnan\n',
    'workspace poison')
w = replace_once(
    w,
    '    if (allocated(workspace%sink)) deallocate(workspace%sink)\n    if (allocated(workspace%source)) deallocate(workspace%source)\n',
    '    if (allocated(workspace%sink)) deallocate(workspace%sink)\n'
    '    if (allocated(workspace%source)) deallocate(workspace%source)\n'
    '    if (allocated(workspace%provider_theta)) deallocate(workspace%provider_theta)\n'
    '    if (allocated(workspace%provider_k)) deallocate(workspace%provider_k)\n'
    '    if (allocated(workspace%provider_capacity)) deallocate(workspace%provider_capacity)\n'
    '    if (allocated(workspace%provider_dkdh)) deallocate(workspace%provider_dkdh)\n'
    '    if (allocated(workspace%provider_root_sink)) deallocate(workspace%provider_root_sink)\n',
    'workspace release')
w = replace_once(
    w,
    '    if (allocated(workspace%sink)) nreal = nreal + size(workspace%sink, kind=int64)\n'
    '    if (allocated(workspace%source)) nreal = nreal + size(workspace%source, kind=int64)\n',
    '    if (allocated(workspace%sink)) nreal = nreal + size(workspace%sink, kind=int64)\n'
    '    if (allocated(workspace%source)) nreal = nreal + size(workspace%source, kind=int64)\n'
    '    if (allocated(workspace%provider_theta)) nreal = nreal + size(workspace%provider_theta, kind=int64)\n'
    '    if (allocated(workspace%provider_k)) nreal = nreal + size(workspace%provider_k, kind=int64)\n'
    '    if (allocated(workspace%provider_capacity)) nreal = nreal + size(workspace%provider_capacity, kind=int64)\n'
    '    if (allocated(workspace%provider_dkdh)) nreal = nreal + size(workspace%provider_dkdh, kind=int64)\n'
    '    if (allocated(workspace%provider_root_sink)) nreal = nreal + size(workspace%provider_root_sink, kind=int64)\n',
    'workspace payload accounting')
wp.write_text(w)

# -----------------------------------------------------------------------------
# HeadCalc: explicit route consumes existing request parameter geometry. Legacy
# direct route remains bound to MOD_grid through renamed legacy imports.
# -----------------------------------------------------------------------------
hp = Path('src/legacy/b1_10_port/headcalc.f90')
h = hp.read_text()
h = replace_once(
    h,
    'subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &\n'
    '                    numerical_config, explicit_step_duration)\n',
    'subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &\n'
    '                    numerical_config, explicit_step_duration, parameter_set)\n',
    'HeadCalc signature')
h = replace_once(
    h,
    '   use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &\n'
    '        soil_water_numerical_config_t\n',
    '   use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &\n'
    '        soil_water_numerical_config_t, soil_water_parameter_set_t\n',
    'HeadCalc contract import')
h = replace_once(
    h,
    '   use MOD_grid,           only: numnod, z, dz, disnod\n',
    '   use MOD_grid,           only: legacy_numnod => numnod, legacy_z => z, legacy_dz => dz, legacy_disnod => disnod\n',
    'HeadCalc legacy grid import')
h = replace_once(
    h,
    '   real(8), intent(in), optional :: explicit_step_duration\n',
    '   real(8), intent(in), optional :: explicit_step_duration\n'
    '   type(soil_water_parameter_set_t), target, intent(in), optional :: parameter_set\n',
    'HeadCalc parameter-set dummy')
h = replace_once(
    h,
    '   logical :: legacy_state_binding, state_ok, provider_top_active, provider_runoff_resolved\n',
    '   logical :: legacy_state_binding, state_ok, provider_top_active, provider_runoff_resolved\n'
    '   logical :: explicit_geometry\n',
    'HeadCalc geometry flag')
h = replace_once(
    h,
    '   integer                          :: swbotb, swkimpl, swkmean, maxit, maxbacktr\n',
    '   integer                          :: numnod\n'
    '   integer                          :: swbotb, swkimpl, swkmean, maxit, maxbacktr\n',
    'HeadCalc local node count')
for decl in [
    '   real(8)                          :: provider_theta(numnod), provider_k(numnod)\n',
    '   real(8)                          :: provider_capacity(numnod), provider_dkdh(numnod)\n',
    '   real(8)                          :: provider_root_sink(numnod)\n',
]:
    h = replace_once(h, decl, '', 'remove automatic provider scratch')

old_init = '''   canonical_trial = present(worker)\n   if (canonical_trial) then\n      ctx => worker\n   else\n      ctx => local_worker\n   end if\n   if (ctx%active_nodes /= numnod) call a23bu_initialize_worker(ctx, numnod)\n   if (present(history)) then\n      hist => history\n   else\n      hist => local_history\n   end if\n   legacy_state_binding = .not. present(state_binding)\n'''
new_init = '''   legacy_state_binding = .not. present(state_binding)\n   explicit_geometry = .not. legacy_state_binding\n   if (explicit_geometry) then\n      if (.not. present(parameter_set)) error stop 'HeadCalc: explicit parameter geometry required'\n      numnod = parameter_set%active_nodes\n      if (numnod <= 0) error stop 'HeadCalc: explicit active_nodes must be positive'\n      if (.not. allocated(parameter_set%z) .or. .not. allocated(parameter_set%dz) .or. &\n          .not. allocated(parameter_set%node_distance)) error stop 'HeadCalc: incomplete explicit grid geometry'\n      if (size(parameter_set%z) /= numnod .or. size(parameter_set%dz) /= numnod .or. &\n          size(parameter_set%node_distance) /= numnod) error stop 'HeadCalc: explicit grid geometry shape mismatch'\n   else\n      numnod = legacy_numnod\n   end if\n   canonical_trial = present(worker)\n   if (canonical_trial) then\n      ctx => worker\n   else\n      ctx => local_worker\n   end if\n   if (ctx%active_nodes /= numnod) call a23bu_initialize_worker(ctx, numnod)\n   if (present(history)) then\n      hist => history\n   else\n      hist => local_history\n   end if\n'''
h = replace_once(h, old_init, new_init, 'HeadCalc geometry authority initialization')

for name in ['provider_theta', 'provider_k', 'provider_capacity', 'provider_dkdh', 'provider_root_sink']:
    h = re.sub(rf'\b{name}\b', f'fsi_ws%{name}', h)

# Access grid geometry through route-aware accessors. Word boundaries prevent
# rewriting the renamed legacy_* imports or the accessor names themselves.
h = re.sub(r'\bz\(', 'grid_z(', h)
h = re.sub(r'\bdz\(', 'grid_dz(', h)
h = re.sub(r'\bdisnod\(', 'grid_disnod(', h)

accessor_marker = 'contains\n\n\nreal(8) function root_sink_term(node)\n'
accessors = '''contains\n\nreal(8) function grid_z(node)\n   integer, intent(in) :: node\n   if (explicit_geometry) then\n      grid_z = parameter_set%z(node)\n   else\n      grid_z = legacy_z(node)\n   end if\nend function grid_z\n\nreal(8) function grid_dz(node)\n   integer, intent(in) :: node\n   if (explicit_geometry) then\n      grid_dz = parameter_set%dz(node)\n   else\n      grid_dz = legacy_dz(node)\n   end if\nend function grid_dz\n\nreal(8) function grid_disnod(node)\n   integer, intent(in) :: node\n   if (explicit_geometry) then\n      grid_disnod = parameter_set%node_distance(node)\n   else\n      grid_disnod = legacy_disnod(node)\n   end if\nend function grid_disnod\n\n\nreal(8) function root_sink_term(node)\n'''
h = replace_once(h, accessor_marker, accessors, 'HeadCalc geometry accessors')
hp.write_text(h)

# -----------------------------------------------------------------------------
# Reference adapter: pass the request parameter set into HeadCalc; size worker,
# workspace, candidate arrays from request active_nodes; remove MOD_grid equality
# validation from the explicit common route. Legacy request builder remains global.
# -----------------------------------------------------------------------------
ap = Path('src/adapter/mod_reference_richards_legacy_binding.f90')
a = ap.read_text()
a = replace_once(
    a,
    '     subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &\n'
    '                         numerical_config, explicit_step_duration)\n',
    '     subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &\n'
    '                         numerical_config, explicit_step_duration, parameter_set)\n',
    'adapter HeadCalc interface signature')
a = replace_once(
    a,
    '       use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &\n'
    '            soil_water_numerical_config_t\n',
    '       use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &\n'
    '            soil_water_numerical_config_t, soil_water_parameter_set_t\n',
    'adapter HeadCalc interface import')
a = replace_once(
    a,
    '       real(8), intent(in), optional :: explicit_step_duration\n',
    '       real(8), intent(in), optional :: explicit_step_duration\n'
    '       type(soil_water_parameter_set_t), target, intent(in), optional :: parameter_set\n',
    'adapter HeadCalc parameter dummy')
a = replace_once(
    a,
    '    type(reference_richards_state_binding_t) :: state_binding\n',
    '    type(reference_richards_state_binding_t) :: state_binding\n'
    '    integer :: n\n',
    'adapter local active node count')
a = replace_once(
    a,
    '    if (.not. ok) then\n       result%status = SW_SOLVE_FAILED\n       return\n    end if\n\n    select type (ws => workspace)\n',
    '    if (.not. ok) then\n       result%status = SW_SOLVE_FAILED\n       return\n    end if\n    n = request%parameters%active_nodes\n\n    select type (ws => workspace)\n',
    'adapter bind request node count')
for old, new, label in [
    ('       if (ws%legacy_worker%active_nodes /= numnod) then\n          call a23bu_initialize_worker(ws%legacy_worker, numnod)\n       end if\n',
     '       if (ws%legacy_worker%active_nodes /= n) then\n          call a23bu_initialize_worker(ws%legacy_worker, n)\n       end if\n', 'worker sizing'),
    ('       call initialize_reference_workspace(ws%richards, numnod)\n',
     '       call initialize_reference_workspace(ws%richards, n)\n', 'workspace sizing'),
    ('            request%evaluation, request%boundary, request%numerical, request%step_duration)\n',
     '            request%evaluation, request%boundary, request%numerical, request%step_duration, request%parameters)\n', 'HeadCalc parameter pass'),
    ('       result%candidate_state%active_nodes = numnod\n',
     '       result%candidate_state%active_nodes = n\n', 'result node count'),
    ('       allocate(result%candidate_state%pressure_head(numnod), result%candidate_state%water_content(numnod))\n',
     '       allocate(result%candidate_state%pressure_head(n), result%candidate_state%water_content(n))\n', 'result allocation'),
]:
    a = replace_once(a, old, new, label)

for obsolete in [
    '    if (request%parameters%active_nodes /= numnod) return\n',
    '    if (maxval(abs(request%parameters%z-z(1:numnod))) > 0.0_real64) return\n',
    '    if (maxval(abs(request%parameters%dz-dz(1:numnod))) > 0.0_real64) return\n',
    '    if (maxval(abs(request%parameters%node_distance-disnod(1:numnod))) > 0.0_real64) return\n',
]:
    a = replace_once(a, obsolete, '', 'remove explicit MOD_grid equality guard')
ap.write_text(a)

print('F-SI14_GRID_GEOMETRY_MATERIALIZATION PASS')
