"""Add first-water-step observations after the existing Grassgrowth heat observer."""
import argparse
from pathlib import Path

ANCHOR = "       water_residual=water_stock-top_in-bottom_in-step_dt*sum(q%net_node_source)"
OBSERVATION = """
         if (q%t0==0d0) then
          write(*,'(a,*(1x,es25.17e3))') 'GRASS_WATER_FIRST', q%t1, segment_rain_rate, q%top_flux, q%bottom_flux, &
           water_stock, forcing%soil_temperature%air_temperature_c, forcing%boesten_evaporation%precipitation_rate_cm_per_day
          write(*,'(a,*(1x,es25.17e3))') 'GRASS_WATER_INITIAL_THETA', heat%water_start
          write(*,'(a,*(1x,es25.17e3))') 'GRASS_WATER_FIRST_THETA', heat%water_end
         end if
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("worktree", type=Path)
    args = parser.parse_args()
    owner = args.worktree / "app/grass_project/initial_interval.f90"
    source = owner.read_text(encoding="utf-8")
    if source.count(ANCHOR) != 1 or "GRASS_WATER_FIRST" in source:
        raise ValueError("expected the existing Grassgrowth heat observer")
    owner.write_text(source.replace(ANCHOR, ANCHOR + OBSERVATION), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
