#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
HEADCALC = ROOT / 'src/legacy/b1_10_port/headcalc.f90'
ADAPTER = ROOT / 'src/adapter/mod_reference_richards_legacy_binding.f90'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'F-SI08 materializer: {label} expected once, found {count}')
    return text.replace(old, new, 1)


h = HEADCALC.read_text()

h = replace_once(
    h,
    '   logical :: legacy_state_binding, state_ok, provider_top_active, provider_runoff_resolved\n',
    '   logical :: legacy_state_binding, state_ok, provider_top_active, provider_runoff_resolved\n'
    '   logical :: provider_constitutive_active, provider_source_sink_active\n',
    'provider flags declaration')

h = replace_once(
    h,
    '   real(8)                          :: factmax, factmax1, sump, sum1, sumold, deviat, q1\n',
    '   real(8)                          :: factmax, factmax1, sump, sum1, sumold, deviat, q1\n'
    '   real(8)                          :: provider_theta(numnod), provider_k(numnod)\n'
    '   real(8)                          :: provider_capacity(numnod), provider_dkdh(numnod)\n',
    'provider scratch declaration')

old = '''   provider_top_active = .false.\n   if (.not. legacy_state_binding .and. present(evaluation_context) .and. present(boundary_conditions)) then\n      provider_top_active = associated(evaluation_context%top_boundary) .and. &\n                            boundary_conditions%top_mode == FSI_TOP_MODE_EXPLICIT_FLUX\n   end if\n   provider_runoff_resolved = .false.\n'''
new = '''   provider_top_active = .false.\n   provider_constitutive_active = .false.\n   provider_source_sink_active = .false.\n   if (.not. legacy_state_binding .and. present(evaluation_context)) then\n      provider_constitutive_active = associated(evaluation_context%constitutive)\n      provider_source_sink_active = associated(evaluation_context%source_sink)\n      if (.not. provider_constitutive_active) error stop 'HeadCalc: explicit constitutive provider required'\n      if (.not. provider_source_sink_active) error stop 'HeadCalc: explicit source/sink provider required'\n   end if\n   if (.not. legacy_state_binding .and. present(evaluation_context) .and. present(boundary_conditions)) then\n      provider_top_active = associated(evaluation_context%top_boundary) .and. &\n                            boundary_conditions%top_mode == FSI_TOP_MODE_EXPLICIT_FLUX\n   end if\n   provider_runoff_resolved = .false.\n'''
h = replace_once(h, old, new, 'provider activation')

old = '''   do i = 1, numnod\n      fsi_ws%sink(i) = 0.0d0\n      do j = 1, nrlevs\n         fsi_ws%sink(i) = fsi_ws%sink(i) + qdra(j,i)\n      end do\n   end do \n   fsi_ws%source(1:numnod) = qssdi(1:numnod)\n'''
new = '''   if (provider_source_sink_active) then\n      call evaluation_context%source_sink%evaluate(state%h(1:numnod), state%theta(1:numnod), &\n           fsi_ws%source(1:numnod), fsi_ws%sink(1:numnod))\n   else\n      do i = 1, numnod\n         fsi_ws%sink(i) = 0.0d0\n         do j = 1, nrlevs\n            fsi_ws%sink(i) = fsi_ws%sink(i) + qdra(j,i)\n         end do\n      end do\n      fsi_ws%source(1:numnod) = qssdi(1:numnod)\n   end if\n'''
h = replace_once(h, old, new, 'source/sink initialization')

old = '''!  reset conductivities (state%k, state%kmean) to time level t\n   do i = 1, numnod\n      state%k(i) = hconduc(i,state%h(i),state%theta(i),rfcp(i))\n!\n      if (swmacro == 1)  state%k(i)     = FrArMtrx(i) * state%k(i)\n      if (i > 1)         state%kmean(i) = hcomean(swkmean,state%k(i-1),state%k(i),dz(i-1),dz(i), i, state%h(i-1), state%h(i))\n   end do\n   state%kmean(numnod+1) = state%k(numnod)\n'''
new = '''!  reset conductivities (state%k, state%kmean) to time level t\n   if (provider_constitutive_active) then\n      call evaluation_context%constitutive%evaluate(state%h(1:numnod), provider_theta, provider_k, &\n           provider_capacity, provider_dkdh)\n      state%k(1:numnod) = provider_k(1:numnod)\n   else\n      do i = 1, numnod\n         state%k(i) = hconduc(i,state%h(i),state%theta(i),rfcp(i))\n      end do\n   end if\n   do i = 1, numnod\n      if (swmacro == 1)  state%k(i)     = FrArMtrx(i) * state%k(i)\n      if (i > 1)         state%kmean(i) = hcomean(swkmean,state%k(i-1),state%k(i),dz(i-1),dz(i), i, state%h(i-1), state%h(i))\n   end do\n   state%kmean(numnod+1) = state%k(numnod)\n'''
h = replace_once(h, old, new, 'initial constitutive conductivity')

old = '''!     store fsi_ws%old_head and get moiscap\n      do i = 1, NN\n         fsi_ws%old_head(i)   = state%h(i)\n         state%dimoca(i) = moiscap(i, state%h(i))\n      end do\n'''
new = '''!     store fsi_ws%old_head and get moiscap\n      do i = 1, NN\n         fsi_ws%old_head(i) = state%h(i)\n      end do\n      if (provider_constitutive_active) then\n         call evaluation_context%constitutive%evaluate(state%h(1:numnod), provider_theta, provider_k, &\n              provider_capacity, provider_dkdh)\n         state%dimoca(1:NN) = provider_capacity(1:NN)\n      else\n         do i = 1, NN\n            state%dimoca(i) = moiscap(i, state%h(i))\n         end do\n      end if\n'''
h = replace_once(h, old, new, 'capacity evaluation')

old = '''!        update state%theta\n         do i = 1, NN\n           state%theta(i) = watcon(i,state%h(i))\n         end do\n'''
new = '''!        update state%theta\n         if (provider_constitutive_active) then\n            call evaluation_context%constitutive%evaluate(state%h(1:numnod), provider_theta, provider_k, &\n                 provider_capacity, provider_dkdh)\n            state%theta(1:NN) = provider_theta(1:NN)\n         else\n            do i = 1, NN\n               state%theta(i) = watcon(i,state%h(i))\n            end do\n         end if\n'''
h = replace_once(h, old, new, 'water-content evaluation')

old = '         state%kmean(numnod+1) = hconduc(numnod,state%h(numnod),state%theta(numnod),rfcp(numnod))\n'
new = '''         if (provider_constitutive_active) then\n            state%kmean(numnod+1) = provider_k(numnod)\n         else\n            state%kmean(numnod+1) = hconduc(numnod,state%h(numnod),state%theta(numnod),rfcp(numnod))\n         end if\n'''
h = replace_once(h, old, new, 'free-drainage constitutive evaluation')

pattern = re.compile(r'\+\s*qrot\(([^)]+)\)')
matches = pattern.findall(h)
if len(matches) != 6:
    raise SystemExit(f'F-SI08 materializer: expected 6 qrot residual terms, found {len(matches)}: {matches}')
h = pattern.sub(lambda m: '+ root_sink_term(' + m.group(1) + ')', h)

marker = 'contains\n\n\nsubroutine capture_legacy_state(s)\n'
insert = '''contains\n\n\nreal(8) function root_sink_term(node)\n   integer, intent(in) :: node\n   if (provider_source_sink_active) then\n      root_sink_term = 0.0d0\n   else\n      root_sink_term = qrot(node)\n   end if\nend function root_sink_term\n\nsubroutine capture_legacy_state(s)\n'''
h = replace_once(h, marker, insert, 'root sink bridge')

HEADCALC.write_text(h)


a = ADAPTER.read_text()
a = replace_once(
    a,
    '  subroutine build_legacy_reference_request(request, parameters, constitutive, top_boundary)\n',
    '  subroutine build_legacy_reference_request(request, parameters, constitutive, top_boundary, source_sink)\n',
    'builder signature')
a = replace_once(
    a,
    '    use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, constitutive_hydraulics_provider_t, &\n         top_boundary_provider_t\n',
    '    use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, constitutive_hydraulics_provider_t, &\n         top_boundary_provider_t, source_sink_provider_t\n',
    'builder provider imports')
a = replace_once(
    a,
    '    class(top_boundary_provider_t), target, intent(in), optional :: top_boundary\n\n    request%parameters => parameters\n',
    '    class(top_boundary_provider_t), target, intent(in), optional :: top_boundary\n'
    '    class(source_sink_provider_t), target, intent(in), optional :: source_sink\n\n'
    '    request%parameters => parameters\n',
    'builder source/sink declaration')
a = replace_once(
    a,
    '    request%evaluation%constitutive => constitutive\n    if (present(top_boundary)) then\n',
    '    request%evaluation%constitutive => constitutive\n'
    '    if (present(source_sink)) request%evaluation%source_sink => source_sink\n'
    '    if (present(top_boundary)) then\n',
    'builder source/sink binding')

old = '''    ok = .false.\n    route = 'legacy-request-invalid'\n    call validate_soil_water_request(request, common_ok)\n    if (.not. common_ok) return\n'''
new = '''    ok = .false.\n    route = 'legacy-request-invalid'\n    if (.not. associated(request%evaluation%constitutive)) then\n       route = 'constitutive-provider-required'\n       return\n    end if\n    call validate_soil_water_request(request, common_ok)\n    if (.not. common_ok) return\n'''
a = replace_once(a, old, new, 'constitutive fail-closed route')

a = replace_once(
    a,
    "    if (.not. associated(request%evaluation%top_boundary)) then\n       route = 'explicit-top-provider-required'\n       return\n    end if\n",
    "    if (.not. associated(request%evaluation%top_boundary)) then\n       route = 'explicit-top-provider-required'\n       return\n    end if\n"
    "    if (.not. associated(request%evaluation%source_sink)) then\n       route = 'source-sink-provider-required'\n       return\n    end if\n",
    'source/sink fail-closed route')

ADAPTER.write_text(a)

print('F-SI08_PROVIDER_CONTEXT_MATERIALIZED')
