#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, sys
from pathlib import Path

X_RD = 179362.75550490862
Y_RD = 418659.84937244334
PROFILE_ID = 90116260

def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"F_PE_ELASTIC45_FAIL cannot load {path}")
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

    root = Path(a.repo_root).resolve()
    tools = root / "tools"
    if str(tools) not in sys.path:
        sys.path.insert(0, str(tools))
    e24 = load("fpe_elastic24_profile_retrieval", tools / "fpe_elastic24_profile_retrieval.py")

    hits = list(Path(a.artifact_dir).rglob("*.gpkg"))
    if len(hits) != 1:
        raise SystemExit(f"F_PE_ELASTIC45_FAIL gpkg hits={len(hits)}")
    gpkg = hits[0].resolve()
    profile = e24.retrieve_profile(gpkg, PROFILE_ID)

    work = Path(a.work_dir).resolve()
    work.mkdir(parents=True, exist_ok=True)
    cfg = work / "request.cfg"
    cfg.write_text("ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR\n", encoding="utf-8")
    row = work / "host.rows"
    prov = work / "host.provenance.json"
    row_copy = work / "host.rows.first"
    prov_copy = work / "host.provenance.first"

    z=[]; dz=[]
    for h in profile["horizons"]:
        top=float(h["top_depth_m"]); bottom=float(h["bottom_depth_m"])
        z.append(-0.5*(top+bottom)*100.0)
        dz.append((bottom-top)*100.0)
    n=len(z)
    zarr="["+",".join(f64(v) for v in z)+"]"
    dzarr="["+",".join(f64(v) for v in dz)+"]"

    script=(tools / "fpe_elastic41_rd_application_handoff.py").resolve()

    lines=[
"program test_fpe_elastic45_rd_host",
"  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite",
"  use, intrinsic :: iso_fortran_env, only: int64, real64",
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t",
"  use mod_fmr_elastic_storage_rd_application_host, only: &",
"       fmr_elastic_storage_rd_application_host_diagnostics_t, fmr_prepare_rd_application_with_elastic_storage, &",
"       FMR_ELAS_RD_HOST_OK, FMR_ELAS_RD_HOST_INACTIVE, FMR_ELAS_RD_HOST_DISCOVERY_REJECTED, &",
"       FMR_ELAS_RD_HOST_PREPROCESS_REJECTED, FMR_ELAS_RD_HOST_BINDING_REJECTED",
"  implicit none",
"  type(fmr_b110_physical_parameters_t) :: base,prepared,again,conflict",
"  type(fmr_elastic_storage_rd_application_host_diagnostics_t) :: diag",
"  character(len=32) :: mode",
"  integer :: stat",
"  mode='normal'",
"  if(command_argument_count()>0) call get_command_argument(1,mode)",
f"  call init_base(base,{n},{zarr},{dzarr})",
"  if(trim(mode)=='conflict')then",
f"    call fmr_prepare_rd_application_with_elastic_storage('{fstr(cfg)}','{fstr(gpkg)}',{f64(X_RD)},{f64(Y_RD)}, &",
f"         '{fstr(row)}','{fstr(prov)}',base,prepared,real_preprocess,diag)",
"    call req(diag%status==FMR_ELAS_RD_HOST_DISCOVERY_REJECTED,'source conflict status')",
"    call req(diag%preprocess_invocations==0,'source conflict callback count')",
"    call req(same_relevant(base,prepared),'source conflict preserve')",
"    write(*,'(A)')'F_PE_ELASTIC45_A5_SOURCE_CONFLICT=PASS'",
"    stop",
"  end if",
f"  call fmr_prepare_rd_application_with_elastic_storage('','{fstr(work / 'missing.gpkg')}',0.0_real64,0.0_real64, &",
f"       '{fstr(row)}','{fstr(prov)}',base,prepared,real_preprocess,diag)",
"  call req(diag%status==FMR_ELAS_RD_HOST_INACTIVE,'inactive status')",
"  call req(diag%preprocess_invocations==0,'inactive callback count')",
"  call req(same_relevant(base,prepared),'inactive identity')",
"  write(*,'(A)')'F_PE_ELASTIC45_A1_INACTIVE_NO_PREPROCESS=PASS'",
f"  call fmr_prepare_rd_application_with_elastic_storage('{fstr(cfg)}','{fstr(work / 'missing.gpkg')}',{f64(X_RD)},{f64(Y_RD)}, &",
f"       '{fstr(row)}','{fstr(prov)}',base,prepared,failing_preprocess,diag)",
"  call req(diag%status==FMR_ELAS_RD_HOST_PREPROCESS_REJECTED,'preprocess rejection')",
"  call req(diag%preprocess_invocations==1,'preprocess failure callback count')",
"  call req(same_relevant(base,prepared),'preprocess rejection preserve')",
"  write(*,'(A)')'F_PE_ELASTIC45_A6_PREPROCESS_FAIL_CLOSED=PASS'",
f"  call fmr_prepare_rd_application_with_elastic_storage('{fstr(cfg)}','{fstr(gpkg)}',{f64(X_RD)},{f64(Y_RD)}, &",
f"       '{fstr(row)}','{fstr(prov)}',base,prepared,missing_row_preprocess,diag)",
"  call req(diag%status==FMR_ELAS_RD_HOST_BINDING_REJECTED,'binding rejection')",
"  call req(diag%preprocess_invocations==1,'binding failure callback count')",
"  call req(same_relevant(base,prepared),'binding rejection preserve')",
"  write(*,'(A)')'F_PE_ELASTIC45_A7_BINDING_FAIL_CLOSED=PASS'",
f"  call fmr_prepare_rd_application_with_elastic_storage('{fstr(cfg)}','{fstr(gpkg)}',{f64(X_RD)},{f64(Y_RD)}, &",
f"       '{fstr(row)}','{fstr(prov)}',base,prepared,real_preprocess,diag)",
"  call req(diag%status==FMR_ELAS_RD_HOST_OK,'active host status')",
"  call req(diag%preprocess_invocations==1.and.diag%preprocess_status==0,'active callback')",
"  call req(diag%generated_prior_applied.and.prepared%elasticity_active,'active prior')",
"  call req(all(ieee_is_finite(prepared%cofgen(24,1:prepared%active_nodes))),'finite priors')",
"  call req(all(prepared%cofgen(24,1:prepared%active_nodes)>0.0_real64),'positive priors')",
"  write(*,'(A)')'F_PE_ELASTIC45_A2_EXACT_CALLBACK_ARGUMENTS=PASS'",
"  write(*,'(A)')'F_PE_ELASTIC45_A3_REAL_ELASTIC41=PASS'",
"  write(*,'(A)')'F_PE_ELASTIC45_A4_REAL_ELASTIC44_BINDING=PASS'",
f"  call execute_command_line('cp {fstr(row)} {fstr(row_copy)}',exitstat=stat)",
"  call req(stat==0,'copy row')",
f"  call execute_command_line('cp {fstr(prov)} {fstr(prov_copy)}',exitstat=stat)",
"  call req(stat==0,'copy provenance')",
f"  call fmr_prepare_rd_application_with_elastic_storage('{fstr(cfg)}','{fstr(gpkg)}',{f64(X_RD)},{f64(Y_RD)}, &",
f"       '{fstr(row)}','{fstr(prov)}',base,again,real_preprocess,diag)",
"  call req(diag%status==FMR_ELAS_RD_HOST_OK.and.same_relevant(prepared,again),'repeat postimage')",
f"  call execute_command_line('cmp -s {fstr(row)} {fstr(row_copy)}',exitstat=stat)",
"  call req(stat==0,'repeat row bytes')",
f"  call execute_command_line('cmp -s {fstr(prov)} {fstr(prov_copy)}',exitstat=stat)",
"  call req(stat==0,'repeat provenance bytes')",
"  write(*,'(A)')'F_PE_ELASTIC45_A9_REPEAT_DETERMINISM=PASS'",
"  conflict=base",
"  conflict%elasticity_active=.true.",
"  conflict%cofgen(24,1:conflict%active_nodes)=1.0e-6_real64",
f"  call fmr_prepare_rd_application_with_elastic_storage('{fstr(cfg)}','{fstr(gpkg)}',{f64(X_RD)},{f64(Y_RD)}, &",
f"       '{fstr(row)}','{fstr(prov)}',conflict,prepared,real_preprocess,diag)",
"  call req(diag%status==FMR_ELAS_RD_HOST_BINDING_REJECTED,'owner binding status')",
"  call req(same_relevant(conflict,prepared),'owner preserve')",
"  write(*,'(A)')'F_PE_ELASTIC45_A8_EXPLICIT_OWNER_PRESERVED=PASS'",
f"  write(*,'(A,I0)')'F_PE_ELASTIC45_SELECTED_PROFILE=',{PROFILE_ID}",
"  write(*,'(A)')'F_PE_ELASTIC45=PASS'",
"contains",
"  subroutine real_preprocess(source_path,x,y,row_path,prov_path,status)",
"    character(len=*),intent(in)::source_path,row_path,prov_path",
"    real(real64),intent(in)::x,y",
"    integer,intent(out)::status",
"    character(len=4096)::cmd",
f"    call req(trim(source_path)=='{fstr(gpkg)}','callback source identity')",
f"    call req(transfer(x,0_int64)==transfer({f64(X_RD)},0_int64),'callback x identity')",
f"    call req(transfer(y,0_int64)==transfer({f64(Y_RD)},0_int64),'callback y identity')",
f"    call req(trim(row_path)=='{fstr(row)}','callback row path identity')",
f"    call req(trim(prov_path)=='{fstr(prov)}','callback provenance path identity')",
f"    write(cmd,'(A)') 'python3 {fstr(script)} --generated-prior-requested=true --gpkg '//trim(source_path)// &",
"         ' --x '//trim(real_text(x))//' --y '//trim(real_text(y))//' --row-output '//trim(row_path)// &",
"         ' --provenance-output '//trim(prov_path)//' > /dev/null 2>&1'",
"    call execute_command_line(trim(cmd),exitstat=status)",
"  end subroutine real_preprocess",
"  subroutine failing_preprocess(source_path,x,y,row_path,prov_path,status)",
"    character(len=*),intent(in)::source_path,row_path,prov_path",
"    real(real64),intent(in)::x,y",
"    integer,intent(out)::status",
"    status=17",
"  end subroutine failing_preprocess",
"  subroutine missing_row_preprocess(source_path,x,y,row_path,prov_path,status)",
"    character(len=*),intent(in)::source_path,row_path,prov_path",
"    real(real64),intent(in)::x,y",
"    integer,intent(out)::status",
"    call execute_command_line('rm -f "'//trim(row_path)//'" "'//trim(prov_path)//'"')",
"    status=0",
"  end subroutine missing_row_preprocess",
"  function real_text(x) result(text)",
"    real(real64),intent(in)::x",
"    character(len=64)::text",
"    write(text,'(ES24.16E3)')x",
"    text=adjustl(text)",
"  end function real_text",
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
"    if(.not.cond)then; write(*,'(A,1X,A)')'F_PE_ELASTIC45_FAIL',trim(msg); error stop 1; end if",
"  end subroutine req",
"end program test_fpe_elastic45_rd_host",
]
    Path(a.fixture).write_text("\n".join(lines)+"\n",encoding="utf-8")
    print("F_PE_ELASTIC45_PREP=PASS")

if __name__=="__main__":
    main()
