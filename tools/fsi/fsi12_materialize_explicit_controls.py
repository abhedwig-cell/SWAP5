#!/usr/bin/env python3
from pathlib import Path
import re, subprocess

HEAD = Path('src/legacy/b1_10_port/headcalc.f90')
ADAPTER = Path('src/adapter/mod_reference_richards_legacy_binding.f90')
EXPECTED_HEAD = '420fe2996199e6d3f162b7669957e1a95919f353'
EXPECTED_ADAPTER = 'eb4b74ee422bc331ed3d6abaa40dd9f85b2551c0'

def blob(path):
    return subprocess.check_output(['git','hash-object',str(path)], text=True).strip()

def once(s, old, new, label):
    n=s.count(old)
    if n != 1:
        raise SystemExit(f'F-SI12 materializer: {label}: expected 1 marker, found {n}')
    return s.replace(old,new,1)

if blob(HEAD) != EXPECTED_HEAD:
    raise SystemExit('F-SI12 materializer: HeadCalc base blob mismatch')
if blob(ADAPTER) != EXPECTED_ADAPTER:
    raise SystemExit('F-SI12 materializer: adapter base blob mismatch')

h=HEAD.read_text()
h=once(h,
'''subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions)''',
'''subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &
                    numerical_config, explicit_step_duration)''','HeadCalc signature')
h=once(h,
'''   use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t''',
'''   use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &
        soil_water_numerical_config_t''','HeadCalc contract import')

start=h.index('   use variables,          only: fldaystart')
end=h.index('   ! inout',start)
imp=h[start:end]
renames={
 'dt':'legacy_dt => dt', 'swkimpl':'legacy_swkimpl => swkimpl', 'swkmean':'legacy_swkmean => swkmean',
 'maxit':'legacy_maxit => maxit', 'maxbacktr':'legacy_maxbacktr => maxbacktr',
 'critdevh2cp':'legacy_critdevh2cp => critdevh2cp', 'critdevh1cp':'legacy_critdevh1cp => critdevh1cp',
 'critdevponddt':'legacy_critdevponddt => critdevponddt', 'dtmin':'legacy_dtmin => dtmin',
 'CritDevBalCp':'legacy_CritDevBalCp => CritDevBalCp', 'CritDevBalTot':'legacy_CritDevBalTot => CritDevBalTot'
}
for name,repl in renames.items():
    imp,n=re.subn(r'\b'+re.escape(name)+r'\b',repl,imp,count=1,flags=re.IGNORECASE)
    if n != 1: raise SystemExit(f'F-SI12 materializer: import rename {name} count={n}')
h=h[:start]+imp+h[end:]

h=once(h,
'''   type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions
   logical :: legacy_state_binding, state_ok, provider_top_active, provider_runoff_resolved''',
'''   type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions
   type(soil_water_numerical_config_t), intent(in), optional :: numerical_config
   real(8), intent(in), optional :: explicit_step_duration
   logical :: legacy_state_binding, state_ok, provider_top_active, provider_runoff_resolved''','HeadCalc optional controls')
h=once(h,
'''   logical :: canonical_trial
   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror, solver_numbit''',
'''   logical :: canonical_trial
   integer                          :: swkimpl, swkmean, maxit, maxbacktr
   real(8)                          :: dt, dtmin, critdevh2cp, critdevh1cp, critdevponddt
   real(8)                          :: CritDevBalCp, CritDevBalTot
   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror, solver_numbit''','HeadCalc local controls')
setup='''   dt = legacy_dt
   swkimpl = legacy_swkimpl
   swkmean = legacy_swkmean
   maxit = legacy_maxit
   maxbacktr = legacy_maxbacktr
   dtmin = legacy_dtmin
   critdevh2cp = legacy_critdevh2cp
   critdevh1cp = legacy_critdevh1cp
   critdevponddt = legacy_critdevponddt
   CritDevBalCp = legacy_CritDevBalCp
   CritDevBalTot = legacy_CritDevBalTot
   if (.not. legacy_state_binding) then
      if (.not. present(numerical_config)) error stop 'HeadCalc: explicit numerical config required'
      if (.not. present(explicit_step_duration)) error stop 'HeadCalc: explicit step duration required'
      if (explicit_step_duration <= 0.0d0) error stop 'HeadCalc: explicit step duration must be positive'
      dt = explicit_step_duration
      swkimpl = numerical_config%conductivity_implicit_mode
      swkmean = numerical_config%conductivity_mean_method
      maxit = numerical_config%max_iterations
      maxbacktr = numerical_config%max_backtracking
      dtmin = numerical_config%min_step_duration
      CritDevBalCp = numerical_config%compartment_balance_tolerance
      CritDevBalTot = numerical_config%total_balance_tolerance
      critdevh2cp = numerical_config%head_abs_tolerance
      critdevh1cp = numerical_config%head_rel_tolerance
      critdevponddt = numerical_config%ponding_tolerance
   end if
'''
h=once(h,'   provider_top_active = .false.\n',setup+'   provider_top_active = .false.\n','HeadCalc effective control setup')
HEAD.write_text(h)

# Adapter: pass the existing request controls rather than relying on same-valued globals.
a=ADAPTER.read_text()
a=once(a,
'''     subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions)''',
'''     subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &
                         numerical_config, explicit_step_duration)''','adapter interface signature')
a=once(a,
'''       use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t''',
'''       use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &
            soil_water_numerical_config_t''','adapter interface import')
a=once(a,
'''       type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context
       type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions''',
'''       type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context
       type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions
       type(soil_water_numerical_config_t), intent(in), optional :: numerical_config
       real(8), intent(in), optional :: explicit_step_duration''','adapter interface controls')
a=once(a,
'''       call headcalc(ws%legacy_worker, ws%richards, call_history, state_binding, &
            request%evaluation, request%boundary)''',
'''       call headcalc(ws%legacy_worker, ws%richards, call_history, state_binding, &
            request%evaluation, request%boundary, request%numerical, request%step_duration)''','adapter HeadCalc call')
a=once(a,
'''    if (swkimpl /= 0) then
       route = 'legacy-implicit-k-deferred'
       return
    end if''',
'''    if (request%numerical%conductivity_implicit_mode /= 0) then
       route = 'legacy-implicit-k-deferred'
       return
    end if''','adapter request swkimpl gate')
for line in [
'    if (.not. same_real(request%step_duration, dt)) return\n',
'    if (request%numerical%max_iterations /= maxit) return\n',
'    if (request%numerical%max_backtracking /= maxbacktr) return\n',
'    if (request%numerical%conductivity_implicit_mode /= swkimpl) return\n',
'    if (request%numerical%conductivity_mean_method /= swkmean) return\n',
'    if (.not. same_real(request%numerical%min_step_duration, dtmin)) return\n',
'    if (.not. same_real(request%numerical%compartment_balance_tolerance, CritDevBalCp)) return\n',
'    if (.not. same_real(request%numerical%total_balance_tolerance, CritDevBalTot)) return\n',
'    if (.not. same_real(request%numerical%head_abs_tolerance, critdevh2cp)) return\n',
'    if (.not. same_real(request%numerical%head_rel_tolerance, critdevh1cp)) return\n',
'    if (.not. same_real(request%numerical%ponding_tolerance, critdevponddt)) return\n']:
    a=once(a,line,'',f'adapter remove legacy equality {line.strip()}')
ADAPTER.write_text(a)

print('F-SI12_MATERIALIZATION PASS')
print('headcalc_blob_before='+EXPECTED_HEAD)
print('adapter_blob_before='+EXPECTED_ADAPTER)
