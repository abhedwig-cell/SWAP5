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
if len(sys.argv) > 3 and sys.argv[3] == 'both':
    needle_top = '!  layers 2 to (NN-1)\n   do i = 2, NN-1\n      fsi_ws%dfdh_main(i)'
    assert src.count(needle_top) == 1
    block = "! RESEARCH ONLY: derivative of imposed-head arithmetic-mean top-face conductivity.\n   if (provider_dynamic_top_active .and. provider_constitutive_active .and. swmacro == 0) then\n      if (provider_dynamic_top_result%external_surface_head_imposed .and. swkmean == 1) then\n         block\n            real(8) :: probe_eps, probe_kp, probe_km\n            logical :: probe_okp, probe_okm\n            probe_eps = TOP03_PROBE_EPS * max(1.0d0,abs(state%h(1)))\n            select type (probe_hyd => evaluation_context%constitutive)\n            type is (b110_default_mvg_provider_t)\n               call evaluate_b110_default_mvg_conductivity(probe_hyd%parameters, 1, &\n                    state%h(1)+probe_eps, probe_kp, probe_okp)\n               call evaluate_b110_default_mvg_conductivity(probe_hyd%parameters, 1, &\n                    state%h(1)-probe_eps, probe_km, probe_okm)\n            class default\n               error stop 'TOP03 probe requires default MVG'\n            end select\n            if (.not.probe_okp .or. .not.probe_okm) error stop 'TOP03 top probe conductivity unavailable'\n            fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) - &\n                 0.5d0 * (probe_kp-probe_km)/(2.0d0*probe_eps) * fsi_ws%head_gradient(1)\n         end block\n      end if\n   end if\n\n"
    src = src.replace(needle_top, block.replace('TOP03_PROBE_EPS', str(step).replace('e', 'd')) + needle_top)
Path(sys.argv[1]).write_text(src)
print('TOP03_PROBE_ORIGINAL_SHA256=' + hashlib.sha256(Path('src/legacy/b1_10_port/headcalc.f90').read_bytes()).hexdigest())
print('TOP03_PROBE_EPS=' + str(step))
