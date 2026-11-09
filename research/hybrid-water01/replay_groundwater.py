"""Replay two own day-453 Andelst checkpoints with a read-only GWL trace."""
import argparse
from pathlib import Path
import shutil
import subprocess

from run_daily_kernel import build, records, replace, sha

CUT = 453
END = 459
FILES = ("macro.bin", "result.end")


def replay(reference, origin, prepared, output, corrected, split_final=False, budget_only=False, refresh_macro_final=False):
    output.mkdir()
    donor, _, case, _ = build(reference, output, checkpoint_day=CUT,
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
    for stage, call in [(1, "   call vector_F(1, hgrad)"), (2, "         call vector_F(2, hgrad)")]:
        source = replace(source, call, call + f"""
   if (t1900 >= 36252.9989d0 .and. t1900 < 36253d0) then
      write(*,'(a,1x,i0,9(1x,es25.17e3))') 'GWL_SOLVER', {stage}, t1900, dt, qbot, &
         h(55), h(80), h(numnod), maxval(abs(F(1:NN))), sum(QExcMpMtx(1:NN)), nraidt
   end if""")
    if refresh_macro_final:
        source = replace(source, "      if (iTask == 1 .OR. .NOT. flunsatok(3)) then",
                         "      if (iTask == 1 .OR. .NOT. flunsatok(3) .OR. &\n"
                         "          (t1900 >= 36252.9989d0 .AND. t1900 < 36253d0)) then")
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
    with (output / "stdout").open("wb") as log:
        result = subprocess.run([donor, "./swap.swp"], cwd=run, stdout=log, stderr=subprocess.STDOUT,
                                input=("".join(f"{day}\n" for day in range(CUT+1, END+1))+"0\n").encode(),
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
    a = parser.parse_args()
    replay(a.reference.resolve(), a.origin.resolve(), a.prepared.resolve(), a.output.resolve(), a.corrected, a.split_final, a.budget_only, a.refresh_macro_final)


if __name__ == "__main__":
    main()
