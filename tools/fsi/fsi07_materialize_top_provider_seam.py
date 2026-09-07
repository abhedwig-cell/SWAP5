#!/usr/bin/env python3
from pathlib import Path
import hashlib

HEAD = Path('src/legacy/b1_10_port/headcalc.f90')
STATE = Path('src/solver/mod_reference_richards_state_binding.f90')
EXPECTED = {
    HEAD: '4d1a723bb4948cc611cf15df47366c968be90ebf',
    STATE: '0f7d726f1231584599b3e6838bf8cc0fb53a6814',
}

def blob_sha(path: Path) -> str:
    b=path.read_bytes()
    return hashlib.sha1(f'blob {len(b)}\0'.encode()+b).hexdigest()

def one(s, old, new, label):
    n=s.count(old)
    if n != 1:
        raise SystemExit(f'F-SI07_TOP_PROVIDER FAIL {label}: expected 1 found {n}')
    return s.replace(old,new,1)

for p,sha in EXPECTED.items():
    actual=blob_sha(p)
    if actual != sha:
        raise SystemExit(f'F-SI07_TOP_PROVIDER FAIL source drift {p}: {actual} != {sha}')

s=STATE.read_text()
s=one(s,
'''  private

  type, public :: reference_richards_state_binding_t
''',
'''  private

  integer, parameter, public :: FSI_TOP_MODE_LEGACY_CONTEXT = -9001
  integer, parameter, public :: FSI_TOP_MODE_EXPLICIT_FLUX = -9002

  type, public :: reference_richards_state_binding_t
''','state top-mode constants')
STATE.write_text(s)

h=HEAD.read_text()
h=one(h,
'subroutine headcalc(worker, fsi_workspace, history, state_binding)\n',
'subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions)\n',
'HeadCalc provider signature')
h=one(h,
'''   use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, validate_reference_state_binding
''',
'''   use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, validate_reference_state_binding, &
        FSI_TOP_MODE_EXPLICIT_FLUX
   use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t
''','provider contract imports')
h=one(h,
'''   type(reference_richards_state_binding_t), pointer :: state
   logical :: legacy_state_binding, state_ok
!  local
''',
'''   type(reference_richards_state_binding_t), pointer :: state
   type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context
   type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions
   logical :: legacy_state_binding, state_ok, provider_top_active, provider_runoff_resolved
!  local
''','provider declarations')
h=one(h,
'''   else
      state => local_state_binding
      call capture_legacy_state(state)
   end if
   if (present(fsi_workspace)) then
''',
'''   else
      state => local_state_binding
      call capture_legacy_state(state)
   end if
   provider_top_active = .false.
   if (.not. legacy_state_binding .and. present(evaluation_context) .and. present(boundary_conditions)) then
      provider_top_active = associated(evaluation_context%top_boundary) .and. &
                            boundary_conditions%top_mode == FSI_TOP_MODE_EXPLICIT_FLUX
   end if
   provider_runoff_resolved = .false.
   if (present(fsi_workspace)) then
''','provider activation')
h=one(h,
'''subroutine boundtop_state_bridge(task)
   integer, intent(in) :: task
   type(reference_richards_state_binding_t) :: saved
   if (legacy_state_binding) then
''',
'''subroutine boundtop_state_bridge(task)
   integer, intent(in) :: task
   type(reference_richards_state_binding_t) :: saved
   real(8) :: provider_runoff_flux
   provider_runoff_resolved = .false.
   if (provider_top_active) then
      call evaluation_context%top_boundary%evaluate(state%h(1), state%theta(1), boundary_conditions, &
           state%qtop, state%hsurf, provider_runoff_flux)
      state%ftoph = .false.
      state%runots = provider_runoff_flux * dt
      state%flrunoff = abs(provider_runoff_flux) > 0.0d0
      provider_runoff_resolved = .true.
      return
   end if
   if (legacy_state_binding) then
''','provider boundtop path')
h=one(h,
'''   if (state%flrunoff .OR. ArMpSs > 0.0d0) call pondrunoff_state_bridge()
''',
'''   if ((state%flrunoff .OR. ArMpSs > 0.0d0) .AND. .NOT. provider_runoff_resolved) call pondrunoff_state_bridge()
''','provider-resolved runoff')
HEAD.write_text(h)
print('F-SI07_TOP_PROVIDER_SEAM MATERIALIZED')
