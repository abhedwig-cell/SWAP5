"""Replay two own day-453 Andelst checkpoints with a read-only GWL trace."""
import argparse
from pathlib import Path
import shutil
import subprocess

import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'app/hybrid_water'))
from daily_host import build, records, replace, sha

CUT = 453
END = 459
FILES = ("macro.bin", "result.end")


def replay(reference, origin, prepared, output, corrected, split_final=False, budget_only=False,
           refresh_macro_final=False, solver_trace_day=458, trace_reuse_event=False,
           check_fresh_residual=False):
    output.mkdir()
    donor, _, case, _, _ = build(reference, output, checkpoint_day=CUT,
                              budget_retry=corrected or budget_only, shared_pond_transfer=corrected)
    donor_build = reference / "build"
    objects = donor_build / "swap-obj"
    ttutil = donor_build / "ttutil-obj"
    source_path = output / "swap.f90"
    source = source_path.read_text(encoding="cp1252")
    source = replace(source, "gwl, gwlm1, dt, t1900, dtold, h, theta, pond, qrot",
                     "gwl, gwlm1, dt, t1900, dtold, h, theta, pond, qrot, qbot, nodgwl")
    anchor = "      call SoilWater(3)"
    source = replace(source, anchor, anchor + """
      if (t1900 >= 36251d0 .and. t1900 < 36254d0) then
         write(*,'(a,5(1x,es25.17e3),1x,i0,*(1x,es25.17e3))') &
           'GWL_ACCEPTED', t1900, dt, gwlm1, gwl, qbot, nodgwl, h(50:85)
      end if""")
    if split_final:
        marker = "         ! process weather data for specific time"
        source = replace(source, marker,
                         "         if (t1900 >= 36252.9989d0 .and. t1900 < 36253d0) dt = min(dt, 0.0005d0)\n"
                         + marker)
    source_path.write_text(source, encoding="cp1252")
    subprocess.run(["gfortran", "-O2", "-cpp", "-Dlinux", "-finit-local-zero",
                    "-ffree-line-length-none", "-fallow-argument-mismatch", "-I", str(objects), "-I", str(ttutil),
                    "-c", "swap.f90"], cwd=output, check=True)
    solver = output / "headcalc.f90"
    source = (solver if solver.exists() else donor_build / "swap-selected/headcalc.f90").read_text(encoding="cp1252")
    trace_end = 35795 + solver_trace_day
    upper_node, lower_node = (58, 62) if solver_trace_day == 457 else (55, 80)
    for stage, call in [(1, "   call vector_F(1, hgrad)"), (2, "         call vector_F(2, hgrad)")]:
        source = replace(source, call, call + f"""
   if (t1900 >= {trace_end - 0.0011:.4f}d0 .and. t1900 < {trace_end}d0) then
      write(*,'(a,1x,i0,9(1x,es25.17e3))') 'GWL_SOLVER', {stage}, t1900, dt, qbot, &
         h({upper_node}), h({lower_node}), h(numnod), maxval(abs(F(1:NN))), sum(QExcMpMtx(1:NN)), nraidt
   end if""")
    if trace_reuse_event:
        source = replace(source, "   real(8), dimension(macp)         :: hold",
                         "   real(8), dimension(macp)         :: hold, macro_rate_heads")
        gate = "      if (iTask == 1 .OR. .NOT. flunsatok(3)) then"
        source = replace(source, gate, f"""      if (iTask == 2 .and. flunsatok(3) .and. &
          t1900 >= {trace_end - 0.0011:.4f}d0 .and. t1900 < {trace_end}d0) then
         write(*,'(a,2(1x,es25.17e3),4(1x,i0),1x,es25.17e3)') 'GWL_REUSE_EVENT', t1900, dt, numbit, itry, &
            count((h(1:numnod) >= 0d0) .neqv. (macro_rate_heads(1:numnod) >= 0d0)), &
            count((h(1:numnod) < 1d0) .neqv. (macro_rate_heads(1:numnod) < 1d0)), &
            maxval(abs(h(1:numnod) - macro_rate_heads(1:numnod)))
      end if
""" + gate)
        source = replace(source, "         call MACROPORE(2)",
                         "         macro_rate_heads(1:numnod) = h(1:numnod)\n         call MACROPORE(2)")
    if check_fresh_residual:
        source = replace(source, "   real(8), dimension(macp)         :: hold",
                         "   logical                        :: used_cached_macro_rates\n"
                         "   real(8), dimension(macp)         :: hold")
        call = "         call vector_F(2, hgrad)"
        source = replace(source, call,
                         "         used_cached_macro_rates = swmacro == 1 .and. flunsatok(3)\n" + call)
        marker = "      if (dabs(sum1) > CritDevBalTot) flnonconv = .TRUE."
        source = replace(source, marker, marker + """
      if (.not. flnonconv .and. used_cached_macro_rates) then
         flunsatok = .false.
         used_cached_macro_rates = .false.
         call vector_F(2, hgrad)
         sump = 0.5d0 * dot_product(F(1:NN), F(1:NN))
         sum1 = sum(F(1:NN))
         Fmax = maxval(dabs(F(1:NN)))
         goto 1
      end if""")
    if refresh_macro_final:
        refresh_start = f"{trace_end - 0.00005:.5f}" if solver_trace_day == 457 else "36252.9989"
        source = replace(source, "      if (iTask == 1 .OR. .NOT. flunsatok(3)) then",
                         "      if (iTask == 1 .OR. .NOT. flunsatok(3) .OR. &\n"
                         f"          (t1900 >= {refresh_start}d0 .AND. t1900 < {trace_end}d0)) then")
    solver.write_text(source, encoding="cp1252")
    subprocess.run(["gfortran", "-O2", "-cpp", "-Dlinux", "-finit-local-zero",
                    "-ffree-line-length-none", "-fallow-argument-mismatch", "-I", str(objects), "-I", str(ttutil),
                    "-c", "headcalc.f90"], cwd=output, check=True)
    replacements = {p.name: p for p in output.glob("*.o") if p.stem != "hybrid_step_budget"}
    extra = [str(output / "hybrid_step_budget.o")] if corrected or budget_only else []
    subprocess.run(["gfortran", "-o", str(donor),
                    *(str(replacements.get(p.name, p)) for p in sorted(objects.glob("*.o"))),
                    *extra, str(ttutil / "libttutil.a")], cwd=output, check=True)
    checkpoint = output / "first"
    checkpoint.mkdir()
    for name in FILES:
        shutil.copyfile(origin / name, checkpoint / name)
    run = output / "case"
    shutil.copytree(case, run)
    for name in ("swap.swp", "swap.bbc"):
        shutil.copyfile(prepared / name, run / name)
    control = run / "swap.swp"
    source = control.read_text(encoding="cp1252")
    # The legacy window originally ended on day 457.
    source = source.replace("TEND = 1999-04-02", "TEND = 1999-04-26")
    control.write_text(source, encoding="cp1252")
    last = solver_trace_day if solver_trace_day == 457 else END
    with (output / "stdout").open("wb") as log:
        result = subprocess.run([donor, "./swap.swp"], cwd=run, stdout=log, stderr=subprocess.STDOUT,
                                input=("".join(f"{day}\n" for day in range(CUT+1, last+1))+"0\n").encode(),
                                timeout=240)
    if result.returncode != 100 or not (run / "swap.ok").is_file():
        raise RuntimeError(f"Donor replay refused: {result.returncode}, see {output / 'stdout'}")
    if any(sha(origin / name) != sha(checkpoint / name) for name in FILES):
        raise RuntimeError("Replay altered the checkpoint")
    print(records((run / "result_output.csv").read_text().splitlines())[-6:])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("reference", "origin", "prepared", "output"):
        parser.add_argument("--"+name, type=Path, required=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--corrected", action="store_true")
    mode.add_argument("--budget-only", action="store_true")
    parser.add_argument("--split-final", action="store_true")
    parser.add_argument("--refresh-macro-final", action="store_true")
    parser.add_argument("--solver-trace-day", type=int, choices=(457, 458), default=458)
    parser.add_argument("--trace-reuse-event", action="store_true")
    parser.add_argument("--check-fresh-residual", action="store_true")
    a = parser.parse_args()
    if a.solver_trace_day == 457 and a.split_final:
        parser.error("The final half-step intervention applies to day 458")
    if a.check_fresh_residual and (a.refresh_macro_final or a.split_final):
        parser.error("Test the fresh residual check separately from the clock and half-step interventions")
    replay(a.reference.resolve(), a.origin.resolve(), a.prepared.resolve(), a.output.resolve(),
           a.corrected, a.split_final, a.budget_only, a.refresh_macro_final, a.solver_trace_day,
           a.trace_reuse_event, a.check_fresh_residual)


if __name__ == "__main__":
    main()
