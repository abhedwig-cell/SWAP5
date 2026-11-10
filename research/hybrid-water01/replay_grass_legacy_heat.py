"""Run an output-only SWAP 4.3.1 Grassgrowth thermal prefix through day 63."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def insert(source, anchor, after):
    if source.count(anchor) != 1:
        raise ValueError(f"legacy source anchor changed: {anchor}")
    return source.replace(anchor, anchor + after)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    ref = args.reference.resolve() / "build"
    out = args.output.resolve()
    out.mkdir()
    original = ref / "swap-selected/temperature.f90"
    source = original.read_text(encoding="cp1252")
    source = insert(source, "      character(len=200)                        :: message", """
      logical, save :: observed_first = .false.""")
    source = insert(source, "           tsoil(1:numnod) = thomx(1:numnod)", """
           if (.not. observed_first) then
              write(*,'(a,*(1x,es25.17e3))') 'LEGACY_HEAT_INITIAL', tmpold(1:numnod)
              observed_first = .true.
           end if
           write(*,'(a,*(1x,es25.17e3))') 'LEGACY_HEAT_STEP', t1900, dt, tav, TeTop, &
                ssnow, heacap(1), heacon(1), tsoil(1), tsoil(27), tsoil(numnod)
           if (abs(t1900+dt-anint(t1900+dt)) < 1d-8) then
              write(*,'(a,*(1x,es25.17e3))') 'LEGACY_HEAT_PROFILE', t1900+dt, tsoil(1:numnod)
           end if""")
    observed = out / "temperature.f90"
    observed.write_text(source, encoding="cp1252")
    objects = ref / "swap-obj"
    ttutil = ref / "ttutil-obj"
    flags = ["-O2", "-cpp", "-Dlinux", "-finit-local-zero", "-ffree-line-length-none",
             "-fallow-argument-mismatch", "-I", str(objects), "-I", str(ttutil)]
    subprocess.run(["gfortran", *flags, "-c", observed.name], cwd=out, check=True)
    exe = out / "grass_b0_observed.exe"
    retained = sorted(p for p in objects.glob("*.o") if p.name != "temperature.o")
    subprocess.run(["gfortran", "-o", str(exe), "temperature.o", *map(str, retained),
                    str(ttutil / "libttutil.a")], cwd=out, check=True)
    project = Path(__file__).resolve().parents[2] / "reference/swap-4.3.1/projects/2.grassgrowth"
    originals = {}
    for name in ("swap.swp", "grass.crp", "260.met", "swap.bbc", "swap.dra"):
        path = project / name
        originals[name] = digest(path)
        (out / name).write_bytes(path.read_bytes())
    case = out / "swap.swp"
    raw = case.read_bytes()
    assert raw.count(b"TEND = 1984-12-31") == 1
    case.write_bytes(raw.replace(b"TEND = 1984-12-31", b"TEND = 1980-03-03"))
    with (out / "stdout").open("wb") as stream:
        completed = subprocess.run([exe, "./swap.swp"], cwd=out, stdin=subprocess.DEVNULL,
                                   stdout=stream, stderr=subprocess.STDOUT, timeout=120)
    if completed.returncode != 100 or not (out / "swap.ok").is_file():
        raise RuntimeError(f"legacy prefix did not finish: {completed.returncode}; see stdout")
    receipt = {
        "compiler": subprocess.check_output(["gfortran", "--version"], text=True).splitlines()[0],
        "base_temperature_sha256": digest(original),
        "observed_temperature_sha256": digest(observed),
        "retained_legacy_executable_sha256": digest(ref / "swap_b0_gfortran.exe"),
        "executable_sha256": digest(exe),
        "original_input_sha256": originals,
        "shortened_swap_swp_sha256": digest(case),
        "stdout_sha256": digest(out / "stdout"),
    }
    (out / "RESULT.json").write_text(json.dumps(receipt, indent=2) + "\n")


if __name__ == "__main__":
    main()
