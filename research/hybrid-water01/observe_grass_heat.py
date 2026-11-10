"""Prepare an output-only Grassgrowth heat observation on the canonical owner."""
import argparse
from pathlib import Path

ANCHOR = "      max_conductive_residual=max(max_conductive_residual,abs(step_conductive_residual))"
OBSERVATION = """
      ! The two boundaries use upward-positive water rates.
      block
       real(real64) :: air0(size(heat%dz_cm)),air1(size(heat%dz_cm)),capacity0(size(heat%dz_cm)),capacity1(size(heat%dz_cm))
       real(real64) :: solid(size(heat%dz_cm)),average_temperature(size(heat%dz_cm))
       real(real64) :: water_stock,water_capacity,air_capacity,mixture_stock,top_in,bottom_in,source_in,water_residual
       integer :: n
       n=size(heat%dz_cm)
       air0=max(0d0,heat%theta_sat-heat%water_start)
       air1=max(0d0,heat%theta_sat-heat%water_end)
       solid=2.128d0*heat%f_quartz+2.385d0*heat%f_clay+2.496d0*heat%f_organic
       capacity0=solid+4.18d0*heat%water_start+0.001212d0*air0
       capacity1=solid+4.18d0*heat%water_end+0.001212d0*air1
       average_temperature=0.5d0*(heat%temperature_start_c+heat%temperature_end_c)
       water_stock=sum(heat%dz_cm*(heat%water_end-heat%water_start))
       water_capacity=4.18d0*sum(heat%dz_cm*average_temperature*(heat%water_end-heat%water_start))
       air_capacity=0.001212d0*sum(heat%dz_cm*average_temperature*(air1-air0))
       mixture_stock=sum(heat%dz_cm*(capacity1*heat%temperature_end_c-capacity0*heat%temperature_start_c))
       top_in=-step_dt*q%top_flux
       bottom_in=step_dt*q%bottom_flux
       source_in=step_dt*sum(max(0d0,q%subsurface_source))
       water_residual=water_stock-top_in-bottom_in-step_dt*sum(q%net_node_source)
       write(*,'(a,1x,i0,15(1x,es25.17e3))') 'GRASS_HEAT_ACCEPTED',day_index,q%t0,q%t1,water_stock,water_residual, &
         heat%legacy_storage_change_j_cm2,heat%legacy_boundary_energy_j_cm2,mixture_stock,water_capacity,air_capacity, &
         top_in,bottom_in,source_in,4.18d0*min(0d0,top_in)*heat%temperature_end_c(1), &
         4.18d0*min(0d0,bottom_in)*heat%temperature_end_c(n), &
         4.18d0*step_dt*sum((min(0d0,q%subsurface_source)-q%drainage_sink-q%root_sink)*heat%temperature_end_c)
      end block
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("worktree", type=Path)
    args = parser.parse_args()
    owner = args.worktree / "app/grass_project/initial_interval.f90"
    source = owner.read_text(encoding="utf-8")
    if source.count(ANCHOR) != 1 or "GRASS_HEAT_ACCEPTED" in source:
        raise ValueError("expected the canonical conductive Grassgrowth owner")
    owner.write_text(source.replace(ANCHOR, ANCHOR + OBSERVATION), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
