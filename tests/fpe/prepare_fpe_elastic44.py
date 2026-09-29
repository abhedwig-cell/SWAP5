#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, sys
from pathlib import Path

X_RD = 179362.75550490862
Y_RD = 418659.84937244334

def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"F_PE_ELASTIC44_FAIL cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = mod
    spec.loader.exec_module(mod)
    return mod

def f64(x: float) -> str:
    s = format(float(x), ".17g")
    if "." not in s and "e" not in s.lower():
        s += ".0"
    return s + "_real64"

def fstr(x: object) -> str:
    return str(x).replace("'", "''")

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", required=True)
    ap.add_argument("--artifact-dir", required=True)
    ap.add_argument("--work-dir", required=True)
    ap.add_argument("--fixture", required=True)
    a = ap.parse_args()

    root = Path(a.repo_root)
    tools = root / "tools"
    if str(tools) not in sys.path:
        sys.path.insert(0, str(tools))

    e24 = load("fpe_elastic24_profile_retrieval", tools / "fpe_elastic24_profile_retrieval.py")
    e36 = load("fpe_elastic36_rd_point_profile_interchange", tools / "fpe_elastic36_rd_point_profile_interchange.py")
    e41 = load("fpe_elastic41_rd_application_handoff", tools / "fpe_elastic41_rd_application_handoff.py")

    gpkg_hits = list(Path(a.artifact_dir).rglob("*.gpkg"))
    if len(gpkg_hits) != 1:
        raise SystemExit(f"F_PE_ELASTIC44_FAIL gpkg hits={len(gpkg_hits)}")
    gpkg = gpkg_hits[0]

    work = Path(a.work_dir)
    work.mkdir(parents=True, exist_ok=True)
    row = work / "host.rows"
    prov = work / "host.provenance.json"

    inactive_row = work / "inactive.rows"
    inactive_prov = work / "inactive.provenance.json"
    inactive = e41.prepare_handoff(False, Path("does-not-exist.gpkg"), X_RD, Y_RD, inactive_row, inactive_prov)
    if inactive["status"] != "INACTIVE" or inactive_row.exists() or inactive_prov.exists():
        raise SystemExit("F_PE_ELASTIC44_FAIL inactive ELASTIC41 source independence")
    print("F_PE_ELASTIC44_A2_INACTIVE_NO_SOURCE_IO=PASS")

    result = e41.prepare_handoff(True, gpkg, X_RD, Y_RD, row, prov)
    if result["status"] != "OK" or not row.is_file() or not prov.is_file():
        raise SystemExit("F_PE_ELASTIC44_FAIL ELASTIC41 handoff")
    manifest = json.loads(prov.read_text(encoding="utf-8"))
    pid = int(manifest["normalsoilprofile_id"])
    profile = e24.retrieve_profile(gpkg, pid)
    direct_prov, direct_rows = e36.compose(gpkg, X_RD, Y_RD)
    if row.read_text(encoding="utf-8") != direct_rows:
        raise SystemExit("F_PE_ELASTIC44_FAIL ELASTIC41/36 row identity")
    if manifest["normalsoilprofile_id"] != direct_prov["normalsoilprofile_id"]:
        raise SystemExit("F_PE_ELASTIC44_FAIL ELASTIC41/36 profile identity")
    print("F_PE_ELASTIC44_A3_ELASTIC41_HANDOFF_IDENTITY=PASS")

    bad_row = work / "bad.rows"
    bad_prov = work / "bad.provenance.json"
    try:
        e41.prepare_handoff(True, work / "missing.gpkg", X_RD, Y_RD, bad_row, bad_prov)
    except e41.Elastic41Error:
        pass
    else:
        raise SystemExit("F_PE_ELASTIC44_FAIL missing source accepted")
    if bad_row.exists() or bad_prov.exists():
        raise SystemExit("F_PE_ELASTIC44_FAIL partial output after source failure")

    try:
        e41.prepare_handoff(True, gpkg, -1.0e9, -1.0e9, bad_row, bad_prov)
    except e41.Elastic41Error:
        pass
    else:
        raise SystemExit("F_PE_ELASTIC44_FAIL outside point accepted")
    if bad_row.exists() or bad_prov.exists():
        raise SystemExit("F_PE_ELASTIC44_FAIL partial output after spatial failure")
    print("F_PE_ELASTIC44_A7_PREPROCESS_FAIL_CLOSED=PASS")

    cfg = work / "request.cfg"
    cfg.write_text("ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR\n", encoding="utf-8")

    z = []
    dz = []
    for h in profile["horizons"]:
        top = float(h["top_depth_m"])
        bottom = float(h["bottom_depth_m"])
        z.append(-0.5 * (top + bottom) * 100.0)
        dz.append((bottom - top) * 100.0)

    zarr = "[" + ",".join(f64(v) for v in z) + "]"
    dzarr = "[" + ",".join(f64(v) for v in dz) + "]"
    n = len(z)

    lines = [
        "program test_fpe_elastic44_application_host",
        "  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite",
        "  use, intrinsic :: iso_fortran_env, only: int64, real64",
        "  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t",
        "  use mod_fmr_elastic_storage_application_host, only: &",
        "       fmr_elastic_storage_application_host_diagnostics_t, fmr_compose_elastic_storage_application, &",
        "       FMR_ELAS_HOST_OK, FMR_ELAS_HOST_INACTIVE, FMR_ELAS_HOST_DISCOVERY_REJECTED, &",
        "       FMR_ELAS_HOST_ROW_PATH_REQUIRED, FMR_ELAS_HOST_BINDING_REJECTED",
        "  implicit none",
        "  type(fmr_b110_physical_parameters_t) :: base,bound,again,conflict",
        "  type(fmr_elastic_storage_application_host_diagnostics_t) :: diag",
        "  character(len=64) :: mode",
        "  mode='normal'",
        "  if(command_argument_count()>0) call get_command_argument(1,mode)",
        f"  call init_base(base,{n},{zarr},{dzarr})",
        "  if(trim(mode)=='conflict')then",
        f"    call fmr_compose_elastic_storage_application('{fstr(cfg.as_posix())}','{fstr(row.as_posix())}',base,bound,diag)",
        "    call req(diag%status==FMR_ELAS_HOST_DISCOVERY_REJECTED,'source conflict status')",
        "    call req(same_relevant(base,bound),'source conflict preservation')",
        "    write(*,'(A)')'F_PE_ELASTIC44_A6_SOURCE_CONFLICT=PASS'",
        "    stop",
        "  end if",
        "  call fmr_compose_elastic_storage_application('','does-not-exist.rows',base,bound,diag)",
        "  call req(diag%status==FMR_ELAS_HOST_INACTIVE,'inactive status')",
        "  call req(same_relevant(base,bound),'inactive identity')",
        "  write(*,'(A)')'F_PE_ELASTIC44_A1_DEFAULT_OFF_IDENTITY=PASS'",
        f"  call fmr_compose_elastic_storage_application('{fstr(cfg.as_posix())}','',base,bound,diag)",
        "  call req(diag%status==FMR_ELAS_HOST_ROW_PATH_REQUIRED,'row path required')",
        "  call req(same_relevant(base,bound),'row path missing preservation')",
        f"  call fmr_compose_elastic_storage_application('{fstr(cfg.as_posix())}','{fstr(row.as_posix())}',base,bound,diag)",
        "  call req(diag%status==FMR_ELAS_HOST_OK,'host active status')",
        "  call req(diag%generated_prior_applied,'host generated prior applied')",
        "  call req(bound%elasticity_active,'host elasticity active')",
        "  call req(all(ieee_is_finite(bound%cofgen(24,1:bound%active_nodes))),'host finite priors')",
        "  call req(all(bound%cofgen(24,1:bound%active_nodes)>0.0_real64),'host positive priors')",
        f"  call req(diag%generated_prior_requested,'host request propagated')",
        "  write(*,'(A)')'F_PE_ELASTIC44_A4_REAL_BINDING=PASS'",
        f"  call fmr_compose_elastic_storage_application('{fstr(cfg.as_posix())}','{fstr(row.as_posix())}',base,again,diag)",
        "  call req(diag%status==FMR_ELAS_HOST_OK.and.same_relevant(bound,again),'repeat identity')",
        "  write(*,'(A)')'F_PE_ELASTIC44_A8_DETERMINISTIC_POSTIMAGE=PASS'",
        "  conflict=base",
        "  conflict%elasticity_active=.true.",
        "  conflict%cofgen(24,1:conflict%active_nodes)=1.0e-6_real64",
        f"  call fmr_compose_elastic_storage_application('{fstr(cfg.as_posix())}','{fstr(row.as_posix())}',conflict,bound,diag)",
        "  call req(diag%status==FMR_ELAS_HOST_BINDING_REJECTED,'explicit owner conflict status')",
        "  call req(same_relevant(conflict,bound),'explicit owner preserved')",
        "  write(*,'(A)')'F_PE_ELASTIC44_A5_EXPLICIT_OWNER_PRESERVED=PASS'",
        f"  write(*,'(A,I0)')'F_PE_ELASTIC44_SELECTED_PROFILE=',{pid}",
        "  write(*,'(A)')'F_PE_ELASTIC44=PASS'",
        "contains",
        "  subroutine init_base(p,n,zv,dzv)",
        "    type(fmr_b110_physical_parameters_t),intent(out)::p",
        "    integer,intent(in)::n",
        "    real(real64),intent(in)::zv(n),dzv(n)",
        "    p%active_nodes=n",
        "    allocate(p%cofgen(24,n),p%z(n),p%dz(n))",
        "    p%cofgen=0.0_real64; p%cofgen(1,:)=0.05_real64; p%cofgen(2,:)=0.45_real64",
        "    p%z=zv; p%dz=dzv",
        "    p%elasticity_active=.false.; p%prepared_default_mvg_available=.true.",
        "  end subroutine init_base",
        "  logical function same_relevant(x,y) result(ok)",
        "    type(fmr_b110_physical_parameters_t),intent(in)::x,y",
        "    integer::i,j; integer(int64)::a,b",
        "    ok=.false.",
        "    if(x%active_nodes/=y%active_nodes)return",
        "    if(x%elasticity_active.neqv.y%elasticity_active)return",
        "    if(x%prepared_default_mvg_available.neqv.y%prepared_default_mvg_available)return",
        "    if(allocated(x%cofgen).neqv.allocated(y%cofgen))return",
        "    if(allocated(x%z).neqv.allocated(y%z))return",
        "    if(allocated(x%dz).neqv.allocated(y%dz))return",
        "    if(.not.allocated(x%cofgen))return",
        "    if(any(shape(x%cofgen)/=shape(y%cofgen)))return",
        "    if(size(x%z)/=size(y%z).or.size(x%dz)/=size(y%dz))return",
        "    do j=1,size(x%cofgen,2); do i=1,size(x%cofgen,1)",
        "      a=transfer(x%cofgen(i,j),a); b=transfer(y%cofgen(i,j),b); if(a/=b)return",
        "    end do; end do",
        "    do i=1,size(x%z)",
        "      a=transfer(x%z(i),a); b=transfer(y%z(i),b); if(a/=b)return",
        "      a=transfer(x%dz(i),a); b=transfer(y%dz(i),b); if(a/=b)return",
        "    end do",
        "    ok=.true.",
        "  end function same_relevant",
        "  subroutine req(cond,msg)",
        "    logical,intent(in)::cond; character(len=*),intent(in)::msg",
        "    if(.not.cond)then; write(*,'(A,1X,A)')'F_PE_ELASTIC44_FAIL',trim(msg); error stop 1; end if",
        "  end subroutine req",
        "end program test_fpe_elastic44_application_host",
    ]
    Path(a.fixture).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("F_PE_ELASTIC44_PREP=" + json.dumps({
        "profile_id": pid,
        "x_rd_m": X_RD,
        "y_rd_m": Y_RD,
        "source_hash": e36.SOURCE_ARTIFACT_SHA256,
    }, sort_keys=True, separators=(",", ":")))

if __name__ == "__main__":
    main()
