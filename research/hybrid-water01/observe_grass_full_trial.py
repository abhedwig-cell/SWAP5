"""Observe a same-duration native full trial without changing its selection."""
import argparse
from pathlib import Path

ANCHOR = """    real(real64)::normalized
    if(.not.self%water_flux_temporal%enabled)then"""
OBSERVATION = """    real(real64)::normalized
    if (attempt_dt==0.0002_real64) then
      select type(full=>full_state)
      class is(fmr_b110_physical_state_t)
        select type(half=>half_state)
        class is(fmr_b110_physical_state_t)
          write(*,'(a,*(1x,es25.17e3))') 'GRASS_FULL_TRIAL_THETA', full%water_content
          write(*,'(a,*(1x,es25.17e3))') 'GRASS_FULL_TRIAL_HEAD', full%pressure_head
          write(*,'(a,*(1x,es25.17e3))') 'GRASS_HALF_TRIAL_THETA', half%water_content
          write(*,'(a,*(1x,es25.17e3))') 'GRASS_FULL_TRIAL_BALANCE', attempt_dt, &
            full_outcome%mass_in, full_outcome%mass_out, full%ponding_depth
        end select
      end select
    end if
    if(.not.self%water_flux_temporal%enabled)then"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("worktree", type=Path)
    args = parser.parse_args()
    path = args.worktree / "src/runtime/mod_fmr_serialized_reference_backend.f90"
    source = path.read_text(encoding="utf-8")
    if source.count(ANCHOR) != 1:
        raise ValueError("expected the unchanged temporal assessment entry")
    path.write_text(source.replace(ANCHOR, OBSERVATION), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
