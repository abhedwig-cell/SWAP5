"""Generate a research-only HeadCalc copy; never edit production source."""
import hashlib
import sys
from pathlib import Path
src = Path('src/legacy/b1_10_port/headcalc.f90').read_text()
original = '''      if (SwKimpl == 1) fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + fsi_ws%dconductivity_dhead(NN) * 0.5d0'''
assert src.count(original) == 1
replacement = original + '''
      ! RESEARCH ONLY: approximate the derivative of the unchanged free-drainage residual.
      if (SwKimpl == 0 .and. provider_constitutive_active .and. swmacro == 0) then
         block
            real(8) :: probe_eps, probe_kp, probe_km
            logical :: probe_okp, probe_okm
            probe_eps = TOP03_PROBE_EPS * max(1.0d0,abs(state%h(NN)))
            select type (probe_hyd => evaluation_context%constitutive)
            type is (b110_default_mvg_provider_t)
               call evaluate_b110_default_mvg_conductivity(probe_hyd%parameters, NN, &
                    state%h(NN)+probe_eps, probe_kp, probe_okp)
               call evaluate_b110_default_mvg_conductivity(probe_hyd%parameters, NN, &
                    state%h(NN)-probe_eps, probe_km, probe_okm)
            class default
               error stop 'TOP03 probe requires default MVG'
            end select
            if (.not.probe_okp .or. .not.probe_okm) error stop 'TOP03 probe conductivity unavailable'
            fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + (probe_kp-probe_km)/(2.0d0*probe_eps)
         end block
      end if'''
step = float(sys.argv[2])
assert step in (1e-5, 1e-6)
src = src.replace(original, replacement.replace('TOP03_PROBE_EPS', str(step).replace('e', 'd')))
needle = '   use MOD_swap_base,      only:'
assert src.count(needle) == 1
src = src.replace(needle, '   use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, evaluate_b110_default_mvg_conductivity\n' + needle)
Path(sys.argv[1]).write_text(src)
print('TOP03_PROBE_ORIGINAL_SHA256=' + hashlib.sha256(Path('src/legacy/b1_10_port/headcalc.f90').read_bytes()).hexdigest())
print('TOP03_PROBE_EPS=' + str(step))
