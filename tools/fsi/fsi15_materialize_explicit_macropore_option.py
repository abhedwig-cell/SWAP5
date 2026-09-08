#!/usr/bin/env python3
from pathlib import Path
import subprocess

EXPECTED = {
    "src/solver/mod_soil_water_solver_contract.f90": "0a57b07712f93538cbfaf9130838682307cede09",
    "src/adapter/mod_reference_richards_legacy_binding.f90": "b17b65563fef826772923afe9c32ca7e0463ec14",
    "src/legacy/b1_10_port/headcalc.f90": "c46756412df7527d6298246570b2aa31bd983823",
}


def blob_sha(path: str) -> str:
    return subprocess.check_output(["git", "hash-object", path], text=True).strip()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"F-SI15 marker mismatch {label}: expected 1, found {count}")
    return text.replace(old, new, 1)


for path, expected in EXPECTED.items():
    actual = blob_sha(path)
    if actual != expected:
        raise SystemExit(f"F-SI15 preimage mismatch {path}: {actual} != {expected}")

# Common contract: make physical configuration a first-class category separate
# from numerical policy. F-SI15 introduces only the macropore activation flag;
# active macropore physics remains fail-closed in the reference adapter.
contract_path = Path("src/solver/mod_soil_water_solver_contract.f90")
contract = contract_path.read_text()
contract = replace_once(
    contract,
    "  type, public :: soil_water_numerical_config_t\n",
    "  type, public :: soil_water_physical_config_t\n"
    "     logical :: macropore_active = .false.\n"
    "  end type soil_water_physical_config_t\n\n"
    "  type, public :: soil_water_numerical_config_t\n",
    "contract physical type",
)
contract = replace_once(
    contract,
    "     type(soil_water_boundary_conditions_t) :: boundary\n"
    "     type(soil_water_numerical_config_t) :: numerical\n",
    "     type(soil_water_boundary_conditions_t) :: boundary\n"
    "     type(soil_water_physical_config_t) :: physical\n"
    "     type(soil_water_numerical_config_t) :: numerical\n",
    "request physical category",
)
contract_path.write_text(contract)

# Reference adapter: compatibility request construction may translate the legacy
# global once, but common-route admission and HeadCalc execution consume the
# explicit request physical configuration instead of the global selector.
adapter_path = Path("src/adapter/mod_reference_richards_legacy_binding.f90")
adapter = adapter_path.read_text()
adapter = replace_once(
    adapter,
    "     subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &\n"
    "                         numerical_config, explicit_step_duration, parameter_set)\n",
    "     subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &\n"
    "                         numerical_config, physical_config, explicit_step_duration, parameter_set)\n",
    "adapter HeadCalc interface signature",
)
adapter = replace_once(
    adapter,
    "       use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &\n"
    "            soil_water_numerical_config_t, soil_water_parameter_set_t\n",
    "       use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &\n"
    "            soil_water_numerical_config_t, soil_water_physical_config_t, soil_water_parameter_set_t\n",
    "adapter HeadCalc interface imports",
)
adapter = replace_once(
    adapter,
    "       type(soil_water_numerical_config_t), intent(in), optional :: numerical_config\n"
    "       real(8), intent(in), optional :: explicit_step_duration\n",
    "       type(soil_water_numerical_config_t), intent(in), optional :: numerical_config\n"
    "       type(soil_water_physical_config_t), intent(in), optional :: physical_config\n"
    "       real(8), intent(in), optional :: explicit_step_duration\n",
    "adapter HeadCalc physical dummy",
)
adapter = replace_once(
    adapter,
    "    if (swmacro /= 0) then\n"
    "       route = 'legacy-macropore-deferred'\n"
    "       return\n"
    "    end if\n",
    "    if (request%physical%macropore_active) then\n"
    "       route = 'explicit-macropore-deferred'\n"
    "       return\n"
    "    end if\n",
    "adapter admission authority",
)
adapter = replace_once(
    adapter,
    "    request%parameters => parameters\n"
    "    request%evaluation%constitutive => constitutive\n",
    "    request%parameters => parameters\n"
    "    request%physical%macropore_active = (swmacro /= 0)\n"
    "    request%evaluation%constitutive => constitutive\n",
    "legacy request physical translation",
)
adapter = replace_once(
    adapter,
    "       call headcalc(ws%legacy_worker, ws%richards, call_history, state_binding, &\n"
    "            request%evaluation, request%boundary, request%numerical, request%step_duration, request%parameters)\n",
    "       call headcalc(ws%legacy_worker, ws%richards, call_history, state_binding, &\n"
    "            request%evaluation, request%boundary, request%numerical, request%physical, &\n"
    "            request%step_duration, request%parameters)\n",
    "adapter explicit physical pass-through",
)
adapter_path.write_text(adapter)

# HeadCalc: keep legacy direct semantics intact, but on the explicit route use a
# local physical selector and never consult legacy matrix/surface fractions when
# macropores are inactive. The active explicit route remains fail-closed.
headcalc_path = Path("src/legacy/b1_10_port/headcalc.f90")
headcalc = headcalc_path.read_text()
headcalc = replace_once(
    headcalc,
    "subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &\n"
    "                    numerical_config, explicit_step_duration, parameter_set)\n",
    "subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions, &\n"
    "                    numerical_config, physical_config, explicit_step_duration, parameter_set)\n",
    "HeadCalc signature",
)
headcalc = replace_once(
    headcalc,
    "   use MOD_swap_base,      only: swmacro, i_instance\n",
    "   use MOD_swap_base,      only: legacy_swmacro => swmacro, i_instance\n",
    "HeadCalc legacy swmacro alias",
)
headcalc = replace_once(
    headcalc,
    "   use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &\n"
    "        soil_water_numerical_config_t, soil_water_parameter_set_t\n",
    "   use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t, &\n"
    "        soil_water_numerical_config_t, soil_water_physical_config_t, soil_water_parameter_set_t\n",
    "HeadCalc physical import",
)
headcalc = replace_once(
    headcalc,
    "   use MOD_swap_mp,        only: armpss, frarmtrx, qexcmpmtx, dfdhmp, ictopmp                        ! all input\n",
    "   use MOD_swap_mp,        only: legacy_armpss => armpss, legacy_frarmtrx => frarmtrx, qexcmpmtx, dfdhmp, ictopmp ! all input\n",
    "HeadCalc macropore fraction aliases",
)
headcalc = replace_once(
    headcalc,
    "   type(soil_water_numerical_config_t), intent(in), optional :: numerical_config\n"
    "   real(8), intent(in), optional :: explicit_step_duration\n",
    "   type(soil_water_numerical_config_t), intent(in), optional :: numerical_config\n"
    "   type(soil_water_physical_config_t), intent(in), optional :: physical_config\n"
    "   real(8), intent(in), optional :: explicit_step_duration\n",
    "HeadCalc physical dummy",
)
headcalc = replace_once(
    headcalc,
    "   integer                          :: numnod\n"
    "   integer                          :: swbotb, swkimpl, swkmean, maxit, maxbacktr\n",
    "   integer                          :: numnod\n"
    "   integer                          :: swmacro, swbotb, swkimpl, swkmean, maxit, maxbacktr\n",
    "HeadCalc local swmacro",
)
headcalc = replace_once(
    headcalc,
    "   swbotb = legacy_swbotb\n",
    "   swmacro = legacy_swmacro\n"
    "   swbotb = legacy_swbotb\n",
    "HeadCalc legacy physical initialization",
)
headcalc = replace_once(
    headcalc,
    "   if (.not. legacy_state_binding) then\n"
    "      if (.not. present(boundary_conditions)) error stop 'HeadCalc: explicit boundary conditions required'\n",
    "   if (.not. legacy_state_binding) then\n"
    "      if (.not. present(physical_config)) error stop 'HeadCalc: explicit physical config required'\n"
    "      if (physical_config%macropore_active) error stop 'HeadCalc: active explicit macropore route not admitted'\n"
    "      swmacro = 0\n"
    "      if (.not. present(boundary_conditions)) error stop 'HeadCalc: explicit boundary conditions required'\n",
    "HeadCalc explicit physical authority",
)

# Route all direct fraction reads through helpers. Legacy direct calls return the
# original globals exactly; explicit inactive calls return unity/zero without
# reading those globals.
headcalc = headcalc.replace("FrArMtrx(", "matrix_fraction(")
headcalc = headcalc.replace("ArMpSs", "macropore_surface_fraction()")

headcalc = replace_once(
    headcalc,
    "   MaxIt1 = MaxIt\n"
    "   if (fldtmin .OR. fldecmprat) MaxIt1 = 2*MaxIt\n",
    "   MaxIt1 = MaxIt\n"
    "   if (fldtmin) MaxIt1 = 2*MaxIt\n"
    "   if (legacy_state_binding) then\n"
    "      if (fldecmprat) MaxIt1 = 2*MaxIt\n"
    "   else if (swmacro == 1) then\n"
    "      if (fldecmprat) MaxIt1 = 2*MaxIt\n"
    "   end if\n",
    "inactive macropore retry flag isolation",
)
headcalc = replace_once(
    headcalc,
    "      if (swmacro == 1 .AND. IcTopMp == 1) then\n"
    "         deviat = state%pond - state%pondm1 + epd*dt + reva*dt - (nraidt+nird+Melt)*dt - runon*dt + state%runots - state%qtop * dt + macropore_surface_fraction() * (nraidt+nird+Melt)*dt + QMpLatSs\n"
    "         if (abs(deviat) > CritDevPondDt) then\n"
    "            flnonconv3 = .TRUE.\n"
    "            flnonconv  = .TRUE.\n"
    "         end if\n"
    "      end if\n"
    "      if (swmacro == 1 .AND. fldecMPmbf) then\n"
    "         flnonconv = .TRUE.\n"
    "      end if\n",
    "      if (swmacro == 1) then\n"
    "         if (IcTopMp == 1) then\n"
    "            deviat = state%pond - state%pondm1 + epd*dt + reva*dt - (nraidt+nird+Melt)*dt - runon*dt + state%runots - state%qtop * dt + macropore_surface_fraction() * (nraidt+nird+Melt)*dt + QMpLatSs\n"
    "            if (abs(deviat) > CritDevPondDt) then\n"
    "               flnonconv3 = .TRUE.\n"
    "               flnonconv  = .TRUE.\n"
    "            end if\n"
    "         end if\n"
    "         if (fldecMPmbf) flnonconv = .TRUE.\n"
    "      end if\n",
    "inactive macropore convergence reads",
)
headcalc = replace_once(
    headcalc,
    "   if ((state%flrunoff .OR. macropore_surface_fraction() > 0.0d0) .AND. .NOT. provider_runoff_resolved) call pondrunoff_state_bridge()\n",
    "   if (.NOT. provider_runoff_resolved) then\n"
    "      if (state%flrunoff .OR. macropore_surface_fraction() > 0.0d0) call pondrunoff_state_bridge()\n"
    "   end if\n",
    "inactive macropore surface fraction short circuit",
)
headcalc = replace_once(
    headcalc,
    "real(8) function grid_z(node)\n",
    "real(8) function matrix_fraction(node)\n"
    "   integer, intent(in) :: node\n"
    "   if (legacy_state_binding .or. swmacro == 1) then\n"
    "      matrix_fraction = legacy_frarmtrx(node)\n"
    "   else\n"
    "      matrix_fraction = 1.0d0\n"
    "   end if\n"
    "end function matrix_fraction\n\n"
    "real(8) function macropore_surface_fraction()\n"
    "   if (legacy_state_binding .or. swmacro == 1) then\n"
    "      macropore_surface_fraction = legacy_armpss\n"
    "   else\n"
    "      macropore_surface_fraction = 0.0d0\n"
    "   end if\n"
    "end function macropore_surface_fraction\n\n"
    "real(8) function grid_z(node)\n",
    "HeadCalc inactive fraction helpers",
)
headcalc_path.write_text(headcalc)

print("F-SI15_MATERIALIZER PASS")
for path in EXPECTED:
    print(path, blob_sha(path))
