#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, sqlite3, sys
from pathlib import Path

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"F_PE_ELASTIC42_FAIL cannot load {path}")
    mod=importlib.util.module_from_spec(spec)
    sys.modules[spec.name]=mod
    spec.loader.exec_module(mod)
    return mod

def f64(x):
    return format(float(x),".17g")+"_real64"

def fstr(s):
    return str(s).replace("'","''")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--work-dir",required=True)
    ap.add_argument("--fixture",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root)
    tools=root/"tools"
    if str(tools) not in sys.path:
        sys.path.insert(0,str(tools))
    e24=load("fpe_elastic24_profile_retrieval",tools/"fpe_elastic24_profile_retrieval.py")
    e33=load("fpe_elastic33_profile_row_interchange",tools/"fpe_elastic33_profile_row_interchange.py")
    e34=load("fpe_elastic34_rd_point_maparea",tools/"fpe_elastic34_rd_point_maparea.py")
    e36=load("fpe_elastic36_rd_point_profile_interchange",tools/"fpe_elastic36_rd_point_profile_interchange.py")

    hits=list(Path(a.artifact_dir).rglob("*.gpkg"))
    if len(hits)!=1:
        raise SystemExit(f"F_PE_ELASTIC42_FAIL gpkg hits={len(hits)}")
    gpkg=hits[0]
    if e36.SOURCE_ARTIFACT_SHA256!="f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6":
        raise SystemExit("F_PE_ELASTIC42_FAIL source hash")
    print("F_PE_ELASTIC42_A1_SOURCE_AUTHORITY=PASS")

    work=Path(a.work_dir)
    work.mkdir(parents=True,exist_ok=True)
    polygons=e34.load_polygons(gpkg)
    seen=set()
    candidates=[]
    con=sqlite3.connect(f"file:{gpkg.resolve()}?mode=ro",uri=True)
    try:
        for poly in polygons:
            probe=e34.strict_probe(poly)
            if probe is None:
                continue
            rel=con.execute(
                "select normalsoilprofile_id from soilarea_normalsoilprofile where maparea_id=?",
                (poly.maparea_id,)
            ).fetchall()
            if len(rel)!=1:
                continue
            pid=int(rel[0][0])
            if pid in seen:
                continue
            seen.add(pid)
            profile=e24.retrieve_profile(gpkg,pid)
            if not all(
                h["organic_matter_pct"] is not None
                and float(h["organic_matter_pct"])<=15.0
                and h["peat_type"] is None
                for h in profile["horizons"]
            ):
                continue
            provenance,interchange=e36.compose(gpkg,probe[0],probe[1],polygons=polygons)
            direct=e33.materialize_interchange(profile)
            if interchange!=direct:
                raise SystemExit(f"F_PE_ELASTIC42_FAIL interchange identity profile={pid}")
            row_path=work/f"profile-{pid}.rows"
            row_path.write_text(interchange,encoding="utf-8")
            z=[]; dz=[]
            for h in profile["horizons"]:
                top=float(h["top_depth_m"])
                bottom=float(h["bottom_depth_m"])
                z.append(-0.5*(top+bottom)*100.0)
                dz.append((bottom-top)*100.0)
            candidates.append({
                "pid":pid,"maparea_id":poly.maparea_id,"x":float(probe[0]),"y":float(probe[1]),
                "path":row_path,"z":z,"dz":dz,"provenance":provenance
            })
    finally:
        con.close()

    if not candidates:
        raise SystemExit("F_PE_ELASTIC42_FAIL no mineral candidates")
    print(f"F_PE_ELASTIC42_A2_MINERAL_CANDIDATES={len(candidates)}")
    print("F_PE_ELASTIC42_A3_INTERCHANGE_IDENTITY=PASS")

    cfg=work/"request.cfg"
    cfg.write_text("ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR\n",encoding="utf-8")

    lines=[
"program test_fpe_elastic42_rd_end_to_end",
"  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite",
"  use, intrinsic :: iso_fortran_env, only: int64, real64",
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t",
"  use mod_fmr_elastic_storage_application_config, only: fmr_elastic_storage_application_request_t",
"  use mod_fmr_elastic_storage_application_request_discovery, only: &",
"       fmr_elastic_storage_request_discovery_diagnostics_t, fmr_discover_elastic_storage_application_request, &",
"       FMR_ELAS_DISCOVERY_OK, FMR_ELAS_DISCOVERY_INACTIVE",
"  use mod_fmr_elastic_storage_row_application_binding, only: &",
"       fmr_elastic_storage_row_application_diagnostics_t, fmr_bind_elastic_storage_from_row_interchange, &",
"       FMR_ELAS_ROW_APP_OK, FMR_ELAS_ROW_APP_INACTIVE, FMR_ELAS_ROW_APP_ASSEMBLY_REJECTED",
"  implicit none",
"  type(fmr_elastic_storage_application_request_t) :: request",
"  type(fmr_elastic_storage_request_discovery_diagnostics_t) :: ddiag",
"  type(fmr_elastic_storage_row_application_diagnostics_t) :: bdiag",
"  type(fmr_b110_physical_parameters_t) :: base,bound,selected_base,conflict",
"  logical :: found",
"  character(len=512) :: selected_path",
"  integer :: selected_pid",
"  found=.false.; selected_path=''; selected_pid=0",
"  call init_base(base,1,[-25.0_real64],[50.0_real64])",
"  call fmr_discover_elastic_storage_application_request('',request,ddiag)",
"  call req(ddiag%status==FMR_ELAS_DISCOVERY_INACTIVE.and..not.request%generated_prior_requested,'A7 discovery off')",
"  call fmr_bind_elastic_storage_from_row_interchange('does-not-exist.rows',request%generated_prior_requested,base,bound,bdiag)",
"  call req(bdiag%status==FMR_ELAS_ROW_APP_INACTIVE,'A7 binding off')",
"  call req(same_relevant(base,bound),'A7 identity')",
"  write(*,'(A)')'F_PE_ELASTIC42_A7_DEFAULT_OFF=PASS'",
f"  call fmr_discover_elastic_storage_application_request('{fstr(cfg.as_posix())}',request,ddiag)",
"  call req(ddiag%status==FMR_ELAS_DISCOVERY_OK.and.request%generated_prior_requested,'A4 request')",
"  write(*,'(A)')'F_PE_ELASTIC42_A4_EXPLICIT_REQUEST=PASS'",
]
    for c in candidates:
        zarr="["+",".join(f64(v) for v in c["z"])+"]"
        dzarr="["+",".join(f64(v) for v in c["dz"])+"]"
        lines += [
"  if(.not.found)then",
f"    call init_base(base,{len(c['z'])},{zarr},{dzarr})",
f"    call fmr_bind_elastic_storage_from_row_interchange('{fstr(c['path'].as_posix())}',request%generated_prior_requested,base,bound,bdiag)",
"    if(bdiag%status==FMR_ELAS_ROW_APP_OK)then",
"      found=.true.; selected_base=base",
f"      selected_path='{fstr(c['path'].as_posix())}'; selected_pid={c['pid']}",
f"      write(*,'(A,I0,A,A,A,ES24.16,A,ES24.16)')'F_PE_ELASTIC42_SELECTED_PROFILE=',{c['pid']},',MAPAREA=','{fstr(c['maparea_id'])}',',X=',{f64(c['x'])},',Y=',{f64(c['y'])}",
"      call req(bound%elasticity_active.and.bdiag%generated_prior_applied,'A5 active')",
"      call req(all(ieee_is_finite(bound%cofgen(24,1:bound%active_nodes))),'A6 finite')",
"      call req(all(bound%cofgen(24,1:bound%active_nodes)>0.0_real64),'A6 positive')",
"    end if",
"  end if",
]
    lines += [
"  call req(found,'A5 no eligible bound real profile')",
"  write(*,'(A)')'F_PE_ELASTIC42_A5_REAL_PROFILE_BINDING=PASS'",
"  write(*,'(A)')'F_PE_ELASTIC42_A6_FINITE_POSITIVE_PRIORS=PASS'",
"  conflict=selected_base",
"  conflict%elasticity_active=.true.",
"  conflict%cofgen(24,1:conflict%active_nodes)=1.0e-6_real64",
"  call fmr_bind_elastic_storage_from_row_interchange(trim(selected_path),.true.,conflict,bound,bdiag)",
"  call req(bdiag%status==FMR_ELAS_ROW_APP_ASSEMBLY_REJECTED,'A8 conflict status')",
"  call req(same_relevant(conflict,bound),'A8 preserve')",
"  write(*,'(A)')'F_PE_ELASTIC42_A8_EXPLICIT_OWNER_PRESERVED=PASS'",
"  write(*,'(A)')'F_PE_ELASTIC42=PASS'",
"contains",
"  subroutine init_base(p,n,zv,dzv)",
"    type(fmr_b110_physical_parameters_t),intent(out)::p",
"    integer,intent(in)::n",
"    real(real64),intent(in)::zv(n),dzv(n)",
"    if(allocated(p%cofgen))deallocate(p%cofgen)",
"    if(allocated(p%z))deallocate(p%z)",
"    if(allocated(p%dz))deallocate(p%dz)",
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
"    if(.not.cond)then; write(*,'(A,1X,A)')'F_PE_ELASTIC42_FAIL',trim(msg); error stop 1; end if",
"  end subroutine req",
"end program test_fpe_elastic42_rd_end_to_end",
]
    Path(a.fixture).write_text("\n".join(lines)+"\n",encoding="utf-8")
    print("F_PE_ELASTIC42_PREP="+json.dumps({
        "candidate_count":len(candidates),
        "source_hash":e36.SOURCE_ARTIFACT_SHA256
    },sort_keys=True,separators=(",",":")))

if __name__=="__main__":
    main()
