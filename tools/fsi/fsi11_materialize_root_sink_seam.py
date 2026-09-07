#!/usr/bin/env python3
from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HEADCALC = ROOT / 'src/legacy/b1_10_port/headcalc.f90'
EXPECTED_PREIMAGE_BLOB = 'be5978827095445b15de7baf607728792de6a366'


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit('F-SI11_MATERIALIZE FAIL: ' + message)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    require(text.count(old) == 1, f'{label} marker count={text.count(old)}')
    return text.replace(old, new, 1)


def main() -> int:
    blob = subprocess.check_output(
        ['git', 'rev-parse', 'HEAD:src/legacy/b1_10_port/headcalc.f90'],
        cwd=ROOT, text=True).strip()
    if blob != EXPECTED_PREIMAGE_BLOB:
        # Idempotent rerun is allowed only after the intended seam is already present.
        current = HEADCALC.read_text()
        if ('provider_root_sink_active' in current and
            'evaluation_context%root_sink%evaluate' in current and
            'root_sink_term = provider_root_sink(node)' in current):
            print('F-SI11_MATERIALIZE ALREADY_APPLIED')
            return 0
        raise SystemExit(f'F-SI11_MATERIALIZE FAIL: unexpected HeadCalc preimage blob {blob}')

    text = HEADCALC.read_text()

    text = replace_once(
        text,
        '   logical :: provider_constitutive_active, provider_source_sink_active\n',
        '   logical :: provider_constitutive_active, provider_source_sink_active, provider_root_sink_active\n',
        'provider logical declaration')

    text = replace_once(
        text,
        '   real(8)                          :: provider_capacity(numnod), provider_dkdh(numnod)\n',
        '   real(8)                          :: provider_capacity(numnod), provider_dkdh(numnod)\n'
        '   real(8)                          :: provider_root_sink(numnod)\n',
        'provider vector declaration')

    text = replace_once(
        text,
        '   provider_constitutive_active = .false.\n'
        '   provider_source_sink_active = .false.\n'
        '   if (.not. legacy_state_binding .and. present(evaluation_context)) then\n'
        '      provider_constitutive_active = associated(evaluation_context%constitutive)\n'
        '      provider_source_sink_active = associated(evaluation_context%source_sink)\n'
        '      if (.not. provider_constitutive_active) error stop \'HeadCalc: explicit constitutive provider required\'\n'
        '      if (.not. provider_source_sink_active) error stop \'HeadCalc: explicit source/sink provider required\'\n'
        '   end if\n',
        '   provider_constitutive_active = .false.\n'
        '   provider_source_sink_active = .false.\n'
        '   provider_root_sink_active = .false.\n'
        '   if (.not. legacy_state_binding .and. present(evaluation_context)) then\n'
        '      provider_constitutive_active = associated(evaluation_context%constitutive)\n'
        '      provider_source_sink_active = associated(evaluation_context%source_sink)\n'
        '      provider_root_sink_active = associated(evaluation_context%root_sink)\n'
        '      if (.not. provider_constitutive_active) error stop \'HeadCalc: explicit constitutive provider required\'\n'
        '      if (.not. provider_source_sink_active) error stop \'HeadCalc: explicit source/sink provider required\'\n'
        '      if (provider_root_sink_active .and. SwKimpl /= 0) &\n'
        '           error stop \'HeadCalc: root-sink provider requires swkimpl=0 in F-SI11\'\n'
        '   end if\n',
        'provider activation block')

    text = replace_once(
        text,
        '      fsi_ws%source(1:numnod) = qssdi(1:numnod)\n'
        '   end if\n\n'
        '!  special case: groundwater level specified\n',
        '      fsi_ws%source(1:numnod) = qssdi(1:numnod)\n'
        '   end if\n'
        '   provider_root_sink = 0.0d0\n'
        '   if (provider_root_sink_active) then\n'
        '      call evaluation_context%root_sink%evaluate(state%h(1:numnod), state%theta(1:numnod), &\n'
        '           provider_root_sink(1:numnod))\n'
        '   end if\n\n'
        '!  special case: groundwater level specified\n',
        'root provider evaluation')

    text = replace_once(
        text,
        'real(8) function root_sink_term(node)\n'
        '   integer, intent(in) :: node\n'
        '   if (provider_source_sink_active) then\n'
        '      root_sink_term = 0.0d0\n'
        '   else\n'
        '      root_sink_term = qrot(node)\n'
        '   end if\n'
        'end function root_sink_term\n',
        'real(8) function root_sink_term(node)\n'
        '   integer, intent(in) :: node\n'
        '   if (provider_source_sink_active) then\n'
        '      if (provider_root_sink_active) then\n'
        '         root_sink_term = provider_root_sink(node)\n'
        '      else\n'
        '         root_sink_term = 0.0d0\n'
        '      end if\n'
        '   else\n'
        '      root_sink_term = qrot(node)\n'
        '   end if\n'
        'end function root_sink_term\n',
        'root sink arithmetic seam')

    require(text.count('evaluation_context%root_sink%evaluate') == 1, 'root provider evaluate count')
    require(text.count('root_sink_term = provider_root_sink(node)') == 1, 'root sink use count')
    require(text.count('root_sink_term(i)') >= 3, 'legacy residual addition sites unexpectedly changed')
    HEADCALC.write_text(text)
    print('F-SI11_MATERIALIZE PASS')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
