"""Create research-only source overlays exposing the first serial SWAP trial failure.

The canonical sources remain untouched. Pair the outputs with
build_f_gc_strip01_research_context.py --source-override and the C2 seedprobe
fixture. These diagnostics currently target the serial worker path.
"""
import argparse
from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"expected one {label} anchor, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True, help="SWAP5 source checkout")
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)

    context_path = root / "src/runtime/mod_fmr_groundwater_application_context.f90"
    context = context_path.read_text()
    context = replace_once(
        context,
        "    logical :: published = .false.\n  contains",
        "    logical :: published = .false.\n"
        "    integer :: last_failed_cell = 0\n"
        "    integer :: last_failed_tile = 0\n"
        "    integer :: last_failed_participant_status = 0\n"
        "    integer :: last_failed_local_status = 0\n  contains",
        "context diagnostic fields",
    )
    context = replace_once(
        context,
        "    procedure, public :: trial_cell_heads => application_context_trial_cell_heads\n",
        "    procedure, public :: trial_cell_heads => application_context_trial_cell_heads\n"
        "    procedure, public :: last_trial_failure => application_context_last_trial_failure\n",
        "context diagnostic binding",
    )
    anchor = "  subroutine application_context_trial_cell_heads(self, cell_heads_m, cell_q_swap_m_per_s, status)\n"
    context = replace_once(
        context,
        anchor,
        "  subroutine application_context_last_trial_failure(self, cell_index, tile_index, participant_status, local_status)\n"
        "    class(fmr_groundwater_application_context_t), intent(in) :: self\n"
        "    integer, intent(out) :: cell_index, tile_index, participant_status, local_status\n"
        "    cell_index = self%last_failed_cell\n"
        "    tile_index = self%last_failed_tile\n"
        "    participant_status = self%last_failed_participant_status\n"
        "    local_status = self%last_failed_local_status\n"
        "  end subroutine application_context_last_trial_failure\n\n" + anchor,
        "context getter",
    )
    context = replace_once(
        context,
        "    cell_q_swap_m_per_s = 0.0_real64\n    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST\n",
        "    cell_q_swap_m_per_s = 0.0_real64\n"
        "    self%last_failed_cell = 0\n"
        "    self%last_failed_tile = 0\n"
        "    self%last_failed_participant_status = 0\n"
        "    self%last_failed_local_status = 0\n"
        "    status = FMR_GW_APP_CONTEXT_INVALID_REQUEST\n",
        "context diagnostic reset",
    )
    context = replace_once(
        context,
        "          if (local_status /= FMR_GW_REGISTRY_OK .or. .not. self%trials(idx)%valid) then\n"
        "            status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED",
        "          if (local_status /= FMR_GW_REGISTRY_OK .or. .not. self%trials(idx)%valid) then\n"
        "            self%last_failed_cell = i\n"
        "            self%last_failed_tile = idx\n"
        "            self%last_failed_participant_status = participant_status\n"
        "            self%last_failed_local_status = local_status\n"
        "            status = FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED",
        "serial participant failure capture",
    )
    (output / context_path.name).write_text(context)

    api_path = root / "src/adapter/mod_fmr_groundwater_application_c_api.f90"
    api = api_path.read_text()
    api = replace_once(
        api,
        "  public :: fgc49d_trial_cell_heads_c\n",
        "  public :: fgc49d_trial_cell_heads_c\n  public :: fgc49d_last_trial_failure_c\n",
        "C API diagnostic export",
    )
    anchor = "  integer(c_int) function fgc49d_trial_response_tangents_c(handle, n, tangents) &\n"
    diagnostic = (
        "  integer(c_int) function fgc49d_last_trial_failure_c(handle, cell_index, tile_index, participant_status, local_status) &\n"
        "       bind(C, name=\"fgc49d_last_trial_failure_c\") result(c_status)\n"
        "    integer(c_int64_t), value, intent(in) :: handle\n"
        "    integer(c_int), intent(out) :: cell_index, tile_index, participant_status, local_status\n"
        "    type(fmr_groundwater_application_context_t), pointer :: context\n"
        "    integer :: status, slot, local_cell, local_tile, local_participant, local_registry\n\n"
        "    cell_index = 0_c_int\n    tile_index = 0_c_int\n"
        "    participant_status = 0_c_int\n    local_status = 0_c_int\n"
        "    call resolve_context(int(handle, int64), context, slot, status)\n"
        "    if (status == FMR_GW_APP_C_API_OK) then\n"
        "      call context%last_trial_failure(local_cell, local_tile, local_participant, local_registry)\n"
        "      cell_index = int(local_cell, c_int)\n      tile_index = int(local_tile, c_int)\n"
        "      participant_status = int(local_participant, c_int)\n      local_status = int(local_registry, c_int)\n"
        "    end if\n    c_status = int(status, c_int)\n"
        "  end function fgc49d_last_trial_failure_c\n\n"
    )
    api = replace_once(api, anchor, diagnostic + anchor, "C API diagnostic function")
    (output / api_path.name).write_text(api)


if __name__ == "__main__":
    main()
