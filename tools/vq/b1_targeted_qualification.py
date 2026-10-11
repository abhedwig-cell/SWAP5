#!/usr/bin/env python3
"""Source-bound targeted B0 -> B1.5p1 correction qualification.

This is verification infrastructure only. It compiles small strict reproducers
that are first bound to the exact B0/B1 source fragments. SWAP-007 can also run
full strict-FPE reference executables when supplied by the caller.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def require_fragment(path: Path, fragment: bytes, label: str) -> None:
    count = path.read_bytes().count(fragment)
    if count != 1:
        raise RuntimeError(f"{label}: expected source fragment once, found {count}")


def compile_run(gfortran: str, source: str, exe: Path, flags: list[str]) -> dict[str, object]:
    src = exe.with_suffix(".f90")
    src.write_text(source, encoding="utf-8")
    cp = run([gfortran, *flags, "-o", str(exe), str(src)])
    if cp.returncode:
        raise RuntimeError(f"compile failed for {exe.name}: {cp.stderr}{cp.stdout}")
    rp = run([str(exe)])
    return {
        "compile_rc": cp.returncode,
        "run_rc": rp.returncode,
        "stdout": rp.stdout,
        "stderr": rp.stderr,
        "source_sha256": sha256_file(src),
        "exe_sha256": sha256_file(exe),
    }


def qualify_001(gf: str, b0root: Path, b1root: Path, work: Path) -> dict[str, object]:
    require_fragment(
        b0root / "macropore.f90",
        b"      VlMpDm1Cp= VlMpDmCp(1,1:numnod)\r\n",
        "SWAP-001 B0",
    )
    require_fragment(
        b1root / "macropore.f90",
        b"      VlMpDm1Cp = 0.0d0\r\n      VlMpDm1Cp(1:numnod) = VlMpDmCp(1,1:numnod)\r\n",
        "SWAP-001 B1",
    )
    b0 = """program p
implicit none
integer,parameter::macp=5000
integer::numnod,j
real(8)::x(macp),y(1,macp)
numnod=112
x=-999d0
do j=1,macp;y(1,j)=dble(j);end do
x=y(1,1:numnod)
print *,\"B0_COMPLETED\"
end program
"""
    b1 = """program p
implicit none
integer,parameter::macp=5000
integer::numnod,j
real(8)::x(macp),y(1,macp)
numnod=112
x=-999d0
do j=1,macp;y(1,j)=dble(j);end do
x=0d0
x(1:numnod)=y(1,1:numnod)
if(any(x(1:numnod)/=y(1,1:numnod))) error stop 3
if(any(x(numnod+1:macp)/=0d0)) error stop 4
print *,\"B1_COMPLETED\",x(1),x(numnod),x(macp)
end program
"""
    r0 = compile_run(gf, b0, work / "s001_b0", ["-O0", "-fcheck=all"])
    r1 = compile_run(gf, b1, work / "s001_b1", ["-O0", "-fcheck=all"])
    passed = r0["run_rc"] != 0 and "Array bound mismatch" in str(r0["stderr"]) and r1["run_rc"] == 0
    return {"gate": "shape_mismatch_microreproducer", "passed": passed, "b0": r0, "b1": r1}


def qualify_005(gf: str, b0root: Path, b1root: Path, work: Path) -> dict[str, object]:
    require_fragment(
        b0root / "MOD_cropdevelopment.f90",
        b"            if ((cropstart(i+1) - cropend(i)) < 0.5d0 .AND. i < ifnd) then\r\n",
        "SWAP-005 B0",
    )
    require_fragment(
        b1root / "MOD_cropdevelopment.f90",
        b"            if (i < ifnd) then\r\n               if ((cropstart(i+1) - cropend(i)) < 0.5d0) then\r\n",
        "SWAP-005 B1",
    )
    common = """use,intrinsic::ieee_arithmetic
implicit none
real(8)::cropstart(2),cropend(1)
integer::i,ifnd
ifnd=1;i=1
cropstart(1)=1d0;cropstart(2)=ieee_value(0d0,ieee_signaling_nan);cropend(1)=10d0
"""
    b0 = "program p\n" + common + "if((cropstart(i+1)-cropend(i))<0.5d0 .AND. i<ifnd) error stop 9\nprint *,\"B0_COMPLETED\"\nend program\n"
    b1 = "program p\n" + common + "if(i<ifnd) then\n if((cropstart(i+1)-cropend(i))<0.5d0) error stop 9\nend if\nprint *,\"B1_COMPLETED\"\nend program\n"
    r0 = compile_run(gf, b0, work / "s005_b0", ["-O0", "-ffpe-trap=invalid"])
    r1 = compile_run(gf, b1, work / "s005_b1", ["-O0", "-ffpe-trap=invalid"])
    passed = r0["run_rc"] != 0 and "SIGFPE" in str(r0["stderr"]) and r1["run_rc"] == 0
    return {"gate": "non_short_circuit_snan_microreproducer", "passed": passed, "b0": r0, "b1": r1}


def qualify_006(gf: str, b0root: Path, b1root: Path, work: Path) -> dict[str, object]:
    require_fragment(
        b0root / "MOD_meteo.f90",
        b"         i = 1\r\n         do while (tend - cropstart(i) > 0.d0)\r\n",
        "SWAP-006 B0",
    )
    require_fragment(
        b1root / "MOD_meteo.f90",
        b"         do i = 1, ifnd\r\n            if (tend - cropstart(i) <= 0.0d0) exit\r\n",
        "SWAP-006 B1",
    )
    decl = """use,intrinsic::ieee_arithmetic
implicit none
real(8)::cropstart(2),cropend(2),tend,tstart
integer::i,ifnd,croptype(2)
logical::f
ifnd=1;tend=20d0;tstart=1d0;f=.false.
cropstart(1)=2d0;cropend(1)=10d0;croptype(1)=1
cropstart(2)=ieee_value(0d0,ieee_signaling_nan);cropend(2)=cropstart(2);croptype(2)=1
"""
    body = """if(cropstart(i)<1d0) exit
if(tend+0.1d0>cropstart(i) .AND. tstart-0.1d0<cropend(i)) then
 if(croptype(i)==2) f=.true.
end if
"""
    b0 = "program p\n" + decl + "i=1\ndo while(tend-cropstart(i)>0d0)\n" + body + "i=i+1\nend do\nprint *,\"B0_COMPLETED\"\nend program\n"
    b1 = "program p\n" + decl + "do i=1,ifnd\nif(tend-cropstart(i)<=0d0) exit\n" + body + "end do\nprint *,\"B1_COMPLETED\"\nend program\n"
    r0 = compile_run(gf, b0, work / "s006_b0", ["-O0", "-ffpe-trap=invalid"])
    r1 = compile_run(gf, b1, work / "s006_b1", ["-O0", "-ffpe-trap=invalid"])
    passed = r0["run_rc"] != 0 and "SIGFPE" in str(r0["stderr"]) and r1["run_rc"] == 0
    return {"gate": "sentinel_snan_microreproducer", "passed": passed, "b0": r0, "b1": r1}


def qualify_007(b0root: Path, b1root: Path, work: Path, b0exe: Path | None, b1exe: Path | None, case: Path | None) -> dict[str, object]:
    require_fragment(
        b0root / "oxygenstress.f90",
        b"            if (dabs(fi_a) > 0.d0) then\r\n                lnew = dabs(l - (fi / fi_a))\r\n",
        "SWAP-007 B0",
    )
    require_fragment(
        b1root / "oxygenstress.f90",
        b"            if (dabs(fi_a) > dmax1(tiny(1.0d0), dabs(fi)/huge(1.0d0))) then\r\n",
        "SWAP-007 B1",
    )
    result: dict[str, object] = {"gate": "strict_fpe_full_grass", "source_bound": True, "passed": None}
    if b0exe and b1exe and case:
        for tag, exe in (("b0", b0exe), ("b1", b1exe)):
            run_dir = work / f"s007_{tag}_grass"
            shutil.copytree(case, run_dir)
            rp = run([str(exe.resolve()), "./swap.swp"], run_dir)
            err_path = run_dir / "swap.err"
            err = err_path.read_text(errors="replace") if err_path.exists() else ""
            result[tag] = {
                "run_rc": rp.returncode,
                "stdout": rp.stdout,
                "stderr": rp.stderr,
                "swap_ok": (run_dir / "swap.ok").is_file(),
                "swap_err_empty": not err.strip(),
                "exe_sha256": sha256_file(exe),
            }
        b0 = result["b0"]
        b1 = result["b1"]
        assert isinstance(b0, dict) and isinstance(b1, dict)
        result["passed"] = (
            b0["run_rc"] != 100
            and ("oxygenstress" in str(b0["stderr"]).lower() or "SIGFPE" in str(b0["stderr"]))
            and b1["run_rc"] == 100
            and b1["swap_ok"]
            and b1["swap_err_empty"]
        )
    return result


def qualify_008(gf: str, b0root: Path, b1root: Path, work: Path) -> dict[str, object]:
    b0src = b0root / "tridag.f90"
    b1src = b1root / "tridag.f90"
    require_fragment(b0src, b"      real(8), intent(out) :: a(np,mp),al(np,mpl)\r\n", "SWAP-008 B0 bandec")
    require_fragment(b0src, b"      real(8), intent(out) :: b(n)\r\n", "SWAP-008 B0 banbks")
    require_fragment(b1src, b"      real(8), intent(inout) :: a(np,mp)\r\n", "SWAP-008 B1 bandec")
    require_fragment(b1src, b"      real(8), intent(inout) :: b(n)\r\n", "SWAP-008 B1 banbks")
    stubs = """module MOD_arrays
integer,parameter::macp=5000
end module
subroutine swap_error(w,m)
character(*),intent(in)::w,m
error stop 99
end subroutine
"""
    harness = """program p
implicit none
integer,parameter::n=3,m1=1,m2=1,np=3,mp=3,mpl=1
real(8)::a(np,mp),ao(n,n),al(np,mpl),b(n),bo(n),d,res(n)
integer::indx(n)
a=0d0
a(1,2)=4d0;a(1,3)=1d0;a(2,1)=1d0;a(2,2)=4d0;a(2,3)=1d0;a(3,1)=1d0;a(3,2)=3d0
ao=reshape([4d0,1d0,0d0,1d0,4d0,1d0,0d0,1d0,3d0],[3,3])
bo=[1d0,2d0,3d0];b=bo
call bandec(a,n,m1,m2,np,mp,al,mpl,indx,d)
call banbks(a,n,m1,m2,np,mp,al,mpl,indx,b)
res=matmul(ao,b)-bo
if(maxval(abs(res))>1d-12) error stop 2
write(*,'(A,3(1X,ES24.16),A,ES12.4)') 'PASS solution',b,' maxres=',maxval(abs(res))
end program
"""
    observed: dict[str, object] = {}
    for tag, source in (("b0", b0src), ("b1", b1src)):
        d = work / f"s008_{tag}"
        d.mkdir()
        (d / "stubs.f90").write_text(stubs)
        (d / "harness.f90").write_text(harness)
        commands = [
            [gf, "-O2", "-c", str(d / "stubs.f90"), "-J", str(d), "-o", str(d / "stubs.o")],
            [gf, "-O2", "-I", str(d), "-c", str(source), "-J", str(d), "-o", str(d / "tridag.o")],
            [gf, "-O2", "-I", str(d), "-c", str(d / "harness.f90"), "-J", str(d), "-o", str(d / "harness.o")],
            [gf, "-o", str(d / "test_band"), str(d / "stubs.o"), str(d / "tridag.o"), str(d / "harness.o")],
        ]
        for command in commands:
            cp = run(command)
            if cp.returncode:
                raise RuntimeError(f"SWAP-008 compile/link failure: {cp.stderr}{cp.stdout}")
        rp = run([str(d / "test_band")])
        observed[tag] = {
            "run_rc": rp.returncode,
            "stdout": rp.stdout,
            "stderr": rp.stderr,
            "exe_sha256": sha256_file(d / "test_band"),
        }
    b0 = observed["b0"]
    b1 = observed["b1"]
    assert isinstance(b0, dict) and isinstance(b1, dict)
    observed.update({
        "gate": "defined_intent_contract_plus_solver_equivalence",
        "contract_difference": "B0 consumes incoming arrays declared INTENT(OUT); B1 declares those arrays INTENT(INOUT)",
        "passed": b0["run_rc"] == 0 and b1["run_rc"] == 0 and b0["stdout"] == b1["stdout"] and "PASS solution" in str(b1["stdout"]),
    })
    return observed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--b0-source-root", type=Path, required=True)
    parser.add_argument("--b1-source-root", type=Path, required=True)
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--b0-fpe-exe", type=Path)
    parser.add_argument("--b1-fpe-exe", type=Path)
    parser.add_argument("--grass-case", type=Path)
    args = parser.parse_args()

    gfortran = shutil.which("gfortran")
    if not gfortran:
        raise SystemExit("gfortran not found")
    if args.work_dir.exists():
        shutil.rmtree(args.work_dir)
    args.work_dir.mkdir(parents=True)

    result = {
        "compiler": subprocess.check_output([gfortran, "--version"], text=True).splitlines()[0],
        "corrections": {
            "SWAP-001": qualify_001(gfortran, args.b0_source_root, args.b1_source_root, args.work_dir),
            "SWAP-005": qualify_005(gfortran, args.b0_source_root, args.b1_source_root, args.work_dir),
            "SWAP-006": qualify_006(gfortran, args.b0_source_root, args.b1_source_root, args.work_dir),
            "SWAP-007": qualify_007(args.b0_source_root, args.b1_source_root, args.work_dir, args.b0_fpe_exe, args.b1_fpe_exe, args.grass_case),
            "SWAP-008": qualify_008(gfortran, args.b0_source_root, args.b1_source_root, args.work_dir),
        },
    }
    result["qualified_targeted"] = all(item.get("passed") is True for item in result["corrections"].values())
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["qualified_targeted"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
