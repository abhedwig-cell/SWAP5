#!/usr/bin/env python3
"""Build and run the exact B0 source with GNU Fortran for VQ bootstrap use.

This is a qualification runner, not a production SWAP implementation. It applies
only compiler-selection transformations equivalent to the supplied standalone
Linux Intel build: linux=true; multiswap=false; with_sss=false; with_animo=false.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import zipfile
from pathlib import Path

try:
    from .reference_identity import verify_b0_archive
except ImportError:
    from reference_identity import verify_b0_archive

SWAP_ORDER = """params.f90 description.f90 wofost_soil_interface.f90 interface_atmosphere.f90 arrays.f90 wofost_soil_declarations.f90 sptabulated.f90 variables.f90 WC_K_models_04_11.f90 interface_plant.f90 swap_base.f90 fixed.f90 snow.f90 wofostnut.f90 MOD_drainage.f90 temperature.f90 MOD_RIA.f90 MOD_MvG_functions.f90 irrigation.f90 MOD_meteo.f90 MOD_runon.f90 MOD_Kavg_Szym.f90 surfacewater.f90 divdra.f90 calcgwl.f90 macropore.f90 integral.f90 RWU_micro.f90 drainage.f90 timecontrol.f90 frozencond.f90 solute.f90 wofost.f90 boundtop.f90 soilwater.f90 MOD_cropdevelopment.f90 oxygenstress.f90 rootextraction.f90 swap_csv_output.f90 tillage.f90 swap.f90 MOD_out_PEARL_ANIMO.f90 tridag.f90 initialize.f90 readswap.f90 wofost_soil_watern.f90 hysteresis.f90 functions.f90 watstor.f90 macroporeoutput.f90 swapoutput.f90 wofost_soil_balancecheck.f90 wofost_soil_parameters.f90 wofost_soil_orgmatn.f90 swap_main.f90 fluxes.f90 wofost_soil_rateconstants.f90 wofost_soil_cropresidues.f90 wofost_soil_amendments.f90 macrorate.f90 headcalc.f90 management_soil.f90 boundbottom.f90""".split()

SYMBOLS = {"linux": True, "multiswap": False, "with_sss": False, "with_animo": False}


def run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def select_dec_branches(text: str) -> str:
    def eval_cond(expr: str) -> bool:
        e = expr.strip().lower()
        m = re.search(r"defined\s*\(\s*([a-z0-9_]+)\s*\)", e)
        if m:
            return SYMBOLS.get(m.group(1), False)
        m = re.search(r"\(\s*linux\s*==\s*([01])\s*\)", e)
        if m:
            return SYMBOLS["linux"] == bool(int(m.group(1)))
        raise ValueError(f"unsupported Intel DEC condition: {expr}")

    stack: list[tuple[bool, bool]] = []
    active = True
    selected: list[str] = []
    for line in text.splitlines(True):
        stripped = line.strip()
        upper = stripped.upper()
        if upper.startswith("!DEC$ IF "):
            cond = eval_cond(stripped[len("!DEC$ IF "):])
            stack.append((active, cond))
            active = active and cond
            continue
        if upper.startswith("!DEC$ ELSE"):
            parent, cond = stack[-1]
            active = parent and not cond
            continue
        if upper.startswith("!DEC$ END IF"):
            parent, _ = stack.pop()
            active = parent
            continue
        if active:
            selected.append(line)
    if stack:
        raise ValueError("unclosed Intel DEC conditional")
    return "".join(selected)


def build_gfortran(root: Path, build: Path) -> tuple[Path, list[str]]:
    gfortran = shutil.which("gfortran")
    if not gfortran:
        raise RuntimeError("gfortran_not_found")
    build.mkdir(parents=True, exist_ok=True)
    srcdir = root / "tools/SWAP/source"
    tt = build / "ttutil-src"
    sw = build / "swap-src"
    objtt = build / "ttutil-obj"
    objsw = build / "swap-obj"
    for directory in (tt, sw, objtt, objsw):
        directory.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(srcdir / "TTUTIL.ZIP") as archive:
        archive.extractall(tt)
    with zipfile.ZipFile(srcdir / "SWAP.ZIP") as archive:
        archive.extractall(sw)
    tt_src = tt / "TTUTIL"
    sw_src = sw / "SWAP"
    selected = build / "swap-selected"
    selected.mkdir(exist_ok=True)
    for source in sw_src.iterdir():
        if source.is_file():
            text = source.read_bytes().decode("cp1252")
            (selected / source.name).write_bytes(select_dec_branches(text).encode("cp1252"))

    common_tt = [gfortran, "-O2", "-finit-local-zero"]
    logs: list[str] = []
    for first in ("ttutilprefs.f90", "ttutil.f90"):
        completed = run(
            common_tt + ["-ffree-line-length-none", "-I", str(tt_src), "-c", str(tt_src / first)],
            objtt,
        )
        logs.append(completed.stdout)
        if completed.returncode:
            raise RuntimeError(f"ttutil_compile_failed:{first}\n{completed.stdout}")
    for source in sorted(tt_src.glob("*.f90")) + sorted(tt_src.glob("*.for")):
        if source.name in {"ttutilprefs.f90", "ttutil.f90"}:
            continue
        length = "-ffree-line-length-none" if source.suffix.lower() == ".f90" else "-ffixed-line-length-none"
        completed = run(
            common_tt + [length, "-I", str(tt_src), "-I", str(objtt), "-c", str(source)],
            objtt,
        )
        logs.append(completed.stdout)
        if completed.returncode:
            raise RuntimeError(f"ttutil_compile_failed:{source.name}\n{completed.stdout}")
    objects = sorted(objtt.glob("*.o"))
    completed = run(["ar", "rcs", "libttutil.a", *map(str, objects)], objtt)
    logs.append(completed.stdout)
    if completed.returncode:
        raise RuntimeError(f"ttutil_archive_failed\n{completed.stdout}")

    for module in objtt.glob("*.mod"):
        shutil.copy2(module, objsw / module.name)
    flags = [
        gfortran, "-O2", "-cpp", "-Dlinux", "-finit-local-zero", "-ffree-line-length-none",
        "-fallow-argument-mismatch", "-I", str(objsw), "-I", str(objtt),
    ]
    for name in SWAP_ORDER:
        completed = run(flags + ["-c", str(selected / name)], objsw)
        logs.append(completed.stdout)
        if completed.returncode:
            raise RuntimeError(f"swap_compile_failed:{name}\n{completed.stdout}")
    executable = build / "swap_b0_gfortran"
    completed = run(
        [gfortran, "-o", str(executable), *map(str, sorted(objsw.glob("*.o"))), str(objtt / "libttutil.a")],
        objsw,
    )
    logs.append(completed.stdout)
    if completed.returncode:
        raise RuntimeError(f"swap_link_failed\n{completed.stdout}")
    return executable, logs


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--work-dir", required=True, type=Path)
    parser.add_argument("--case", default="1.hupselbrook")
    parser.add_argument("--disable-csv", action="store_true", help="runner compatibility patch: SWCSV=1 -> 0")
    args = parser.parse_args()

    identity = verify_b0_archive(args.archive)
    result = {"identity": identity, "runner": "b0_exact_source_gfortran", "accepted": False}
    if not identity["qualified_identity"]:
        print(json.dumps(result, indent=2))
        return 2
    if args.work_dir.exists():
        shutil.rmtree(args.work_dir)
    args.work_dir.mkdir(parents=True)
    extracted = args.work_dir / "distribution"
    with zipfile.ZipFile(args.archive) as archive:
        archive.extractall(extracted)
    root = extracted / "SWAP_4.3.1"
    try:
        executable, _ = build_gfortran(root, args.work_dir / "build")
    except Exception as exc:
        result["failure"] = str(exc)
        print(json.dumps(result, indent=2))
        return 3

    case_src = root / "cases" / args.case
    case_run = args.work_dir / "run" / args.case
    shutil.copytree(case_src, case_run)
    patch = None
    if args.disable_csv:
        swp = case_run / "swap.swp"
        text = swp.read_text(encoding="cp1252")
        if "SWCSV = 1" not in text:
            raise RuntimeError("expected SWCSV = 1 not found")
        swp.write_text(text.replace("SWCSV = 1", "SWCSV = 0", 1), encoding="cp1252")
        patch = "SWCSV=1_to_0_output_only_runner_compatibility"
    completed = run([str(executable), "./swap.swp"], case_run)
    err = (case_run / "swap.err").read_text(errors="replace") if (case_run / "swap.err").exists() else ""
    success = completed.returncode == 100 and (case_run / "swap.ok").is_file() and not err.strip()
    result.update({
        "compiler": subprocess.check_output([gfortran := shutil.which("gfortran"), "--version"], text=True).splitlines()[0],
        "case": args.case,
        "compatibility_patch": patch,
        "process_returncode": completed.returncode,
        "swap_ok": (case_run / "swap.ok").is_file(),
        "swap_err_empty": not err.strip(),
        "run_dir": str(case_run),
        "accepted": success,
    })
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if success else 4


if __name__ == "__main__":
    raise SystemExit(main())
