#!/usr/bin/env python3
import hashlib
import itertools
import json
import math
import os
from pathlib import Path
import random
import subprocess
import tempfile

BASE = "3e21bffdf8e8c354c336d0b4898fdf77db320bf1"
C2A = "5417799834775293fd459cd3f7ba5be3d3e5723e"
C2B = "4f1ff62ce6bf0b391760acb3b4677e475931c4e8"
C2C = "e92807165e674b48600e8ec2ae132d1dfc85a798"
DRAINAGE_SHA256 = "48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc"
CUTOFF = 1.0e-10
EXPECTED_BLOBS = {
    (C2A, "src/process/mod_drainage_hooghoudt_ipos1_response.f90"): "89f26e2d2b77bef5bdd0c5fdb2ce9ca1f03206fa",
    (C2B, "src/process/mod_drainage_hooghoudt_equivalent_depth.f90"): "6b7b2bb1fd259879d3f26c46abfc071ea2b2f108",
    (C2B, "src/process/mod_drainage_hooghoudt_ipos23_response.f90"): "5637ddb4d33141f00b4ebf737d1c7f7fe1824164",
    (C2C, "src/process/mod_drainage_ernst_ipos45_preparation.f90"): "fa1d5d400bb32be42e78889c0ff2a3bcab335142",
    (C2C, "src/process/mod_drainage_ernst_ipos45_response.f90"): "b00ef0ae1f10182af2d0a8ea636d10b196e93379",
}

# Input layout shared with the probe:
# L, shape, z_drain, z_base, wetper, Kh_top, Kh_bottom, Kv_top, Kv_bottom,
# z_interface, geometry_factor, entry_resistance, groundwater_level


def run(*args, input_text=None):
    return subprocess.run(args, input=input_text, text=True, check=True, capture_output=True).stdout


def git_blob(commit, path):
    return run("git", "rev-parse", f"{commit}:{path}").strip()


def git_show(commit, path):
    return run("git", "show", f"{commit}:{path}")


def eqdepth_oracle(L, zd, base, wetper):
    effective_base = max(base, zd - 0.25 * L)
    dbot = zd - effective_base
    x = 2.0 * math.pi * dbot / L
    if x > 0.5:
        branch = 3
        fx = 0.0
        for i in (1, 3, 5):
            e = math.exp(-2.0 * i * x)
            fx += 4.0 * e / (i * (1.0 - e))
        den = math.log(L / wetper) + fx
        raw = math.pi * L / (8.0 * den)
    elif x < 1.0e-6:
        branch = 1
        raw = dbot
    else:
        branch = 2
        fx = math.pi * math.pi / (4.0 * x) + math.log(x / (2.0 * math.pi))
        den = math.log(L / wetper) + fx
        raw = math.pi * L / (8.0 * den)
    return min(raw, dbot), branch, x


def oracle(ipos, x):
    L, shape, zd, base, wet, kht, khb, kvt, kvb, zint, geofac, ent, gwl = x
    d = (gwl - zd) / shape
    if d < CUTOFF:
        return {"q": 0.0, "derivative_expected": True, "dq": 0.0, "aux1": 0.0, "branch": 0}
    if ipos == 1:
        rhor = L * L / (4.0 * kht * abs(d))
        total = rhor + ent
        q = d / total
        aux1 = rhor
        branch = 0
    elif ipos in (2, 3):
        eqd, branch, _ = eqdepth_oracle(L, zd, base, wet)
        keq = kht if ipos == 2 else khb
        den = 8.0 * keq * eqd + 4.0 * kht * abs(d)
        rhor = L * L / den
        total = rhor + ent
        q = d / total
        aux1 = eqd
    elif ipos == 4:
        effective_base = max(base, zd - 0.25 * L)
        dbot = zd - effective_base
        rhor = L * L / (8.0 * khb * dbot)
        rrad = L / (math.pi * math.sqrt(khb * kvb)) * math.log(dbot / wet)
        if gwl > zint:
            rver = (gwl - zint) / kvt + (zint - zd) / kvb
        else:
            rver = (gwl - zd) / kvb
        total = rver + rhor + rrad + ent
        q = d / total
        aux1 = rrad
        branch = 1 if gwl <= zint else 2
    elif ipos == 5:
        effective_base = max(base, zd - 0.25 * L)
        hden = 8.0 * kht * (zd - zint) + 8.0 * khb * (zint - effective_base)
        rhor = L * L / hden
        logarg = geofac * (zd - zint) / wet
        rrad = L / (math.pi * math.sqrt(kht * kvt)) * math.log(logarg)
        rver = (gwl - zd) / kvt
        total = rver + rhor + rrad + ent
        q = d / total
        aux1 = rrad
        branch = 0
    else:
        raise AssertionError(ipos)
    if not math.isfinite(q) or not math.isfinite(total) or total <= 0.0:
        raise ValueError("oracle case outside positive-total-resistance domain")
    exact_cutoff = d == CUTOFF
    interface_kink = ipos == 4 and gwl == zint and kvt != kvb
    derivative_expected = not exact_cutoff and not interface_kink
    return {"q": q, "derivative_expected": derivative_expected, "aux1": aux1, "branch": branch}


def oracle_fd(ipos, x):
    gwl = x[12]
    scale = max(1.0, abs(gwl))
    eps = 2.0e-6 * scale
    xp = list(x); xm = list(x)
    xp[12] += eps; xm[12] -= eps
    qp = oracle(ipos, xp)["q"]
    qm = oracle(ipos, xm)["q"]
    return (qp - qm) / (2.0 * eps)


def case(ipos, *vals, tag="stable"):
    assert len(vals) == 13
    return {"ipos": ipos, "x": tuple(float(v) for v in vals), "tag": tag}


def build_cases():
    cases = []
    rng = random.Random(38002)

    # IPOS1 broad valid-domain response sample.
    for i in range(24):
        L = [35.0, 80.0, 160.0, 260.0][i % 4]
        shape = [0.6, 1.0, 1.7, 2.8][(i // 2) % 4]
        zd = [-15.0, 0.0, 18.0][i % 3]
        kht = [0.4, 2.5, 12.0, 35.0][(i // 3) % 4]
        ent = [0.0, 0.3, 4.0][(i // 4) % 3]
        d = [0.05, 0.5, 5.0, 30.0][(i // 5) % 4]
        gwl = zd + shape * d
        cases.append(case(1,L,shape,zd,zd-10.0,1.0,kht,0,0,0,0,1,ent,gwl))

    # Equivalent-depth branch coverage for IPOS2 and IPOS3.
    x_targets = [5e-7, 2e-6, 0.05, 0.25, 0.4999, 0.5001, 0.8, 1.2]
    for ipos in (2,3):
        for j, xt in enumerate(x_targets):
            for rep in range(2):
                L = 60.0 + 35.0 * rep + 3.0 * j
                zd = (-5.0 if rep == 0 else 12.0)
                depth = xt * L / (2.0 * math.pi)
                base = zd - depth
                wet = max(1.0e-5, min(0.02 * L, 0.4 * depth))
                shape = 0.8 + 0.35 * rep
                kht = 1.5 + 0.7 * j
                khb = 0.0 if (ipos == 3 and j == 2 and rep == 0) else 0.8 + 0.5 * j
                ent = 0.2 * (j % 3)
                d = 0.3 + 1.7 * (j + 1)
                gwl = zd + shape * d
                cases.append(case(ipos,L,shape,zd,base,wet,kht,khb,0,0,0,1,ent,gwl,tag="eqdepth"))

    # IPOS4 stable branches across interface and varied geometry.
    for i in range(24):
        L = 50.0 + 8.0 * i
        shape = [0.7,1.0,1.8][i % 3]
        zd = [-10.0,0.0,14.0][i % 3]
        depth = min(0.20 * L, 8.0 + (i % 5) * 3.0)
        base = zd - depth
        zint = zd + 4.0 + (i % 4) * 2.0
        khb = 1.0 + (i % 6) * 1.7
        kvt = 0.8 + (i % 5) * 1.1
        kvb = 1.2 + (i % 7) * 0.9
        wet = max(0.5, 0.3 * depth)
        ent = 0.5 + (i % 3)
        gwl = (zd + 0.45 * (zint-zd)) if i % 2 == 0 else (zint + 3.0 + i % 4)
        cases.append(case(4,L,shape,zd,base,wet,0,khb,kvt,kvb,zint,1,ent,gwl))

    # IPOS5 broad layered sample.
    for i in range(24):
        L = 70.0 + 6.0 * i
        shape = [0.7,1.0,2.2][i % 3]
        zd = [5.0,15.0,30.0][i % 3]
        zint = zd - (3.0 + i % 5)
        base = zint - (4.0 + i % 6)
        kht = 1.0 + (i % 7) * 1.6
        khb = 0.2 + (i % 5) * 0.9
        kvt = 0.7 + (i % 6) * 1.2
        wet = 0.5 + (i % 4) * 0.5
        geofac = 0.8 + (i % 5) * 0.4
        ent = 0.5 + (i % 4) * 0.4
        gwl = zd + shape * (0.4 + (i % 6) * 1.8)
        cases.append(case(5,L,shape,zd,base,wet,kht,khb,kvt,0,zint,geofac,ent,gwl))

    # Deliberate negative radial-resistance cases that still have positive total resistance.
    cases.append(case(4,100,1,0,-20,25,0,10,4,8,10,1,2,15,tag="negative_rrad"))
    cases.append(case(5,100,1,10,-20,10,10,5,4,0,0,0.5,3,20,tag="negative_rrad"))

    # Exact IPOS4 interface: unequal Kv is nondifferentiable, equal Kv is differentiable.
    cases.append(case(4,100,1,0,-20,2,0,10,4,8,10,1,1,10,tag="interface_kink"))
    cases.append(case(4,100,1,0,-20,2,0,10,6,6,10,1,1,10,tag="interface_equal"))

    # Compatibility cutoff on every response family using z_drain=0, shape=1.
    for ipos in (1,2,3,4,5):
        if ipos == 1:
            base,wet,kht,khb,kvt,kvb,zint,geo,ent = -20,1,5,1,1,1,5,1,1
        elif ipos in (2,3):
            base,wet,kht,khb,kvt,kvb,zint,geo,ent = -10,1,5,3,1,1,5,1,1
        elif ipos == 4:
            base,wet,kht,khb,kvt,kvb,zint,geo,ent = -20,2,1,10,4,8,10,1,2
        else:
            # IPOS5 requires drain bottom > interface.
            base,wet,kht,khb,kvt,kvb,zint,geo,ent = -20,1,10,5,4,1,-10,1.5,2
        for mult,tag in ((0.5,"below_cutoff"),(1.0,"exact_cutoff"),(2.0,"above_cutoff")):
            cases.append(case(ipos,100,1,0,base,wet,kht,khb,kvt,kvb,zint,geo,ent,mult*CUTOFF,tag=tag))

    # Deterministic extra perturbations for broad coverage without authoring fixtures.
    for ipos in range(1,6):
        for _ in range(5):
            L=rng.uniform(45,220); shape=rng.uniform(0.6,2.5); zd=rng.uniform(-20,20)
            if ipos <= 3:
                depth=rng.uniform(0.01,0.22)*L; base=zd-depth; wet=max(1e-4,min(depth*0.5,L*0.02))
                kht=rng.uniform(0.5,20); khb=rng.uniform(0.1,15); kvt=kvb=1; zint=zd+5; geo=1; ent=rng.uniform(0,3)
                gwl=zd+shape*rng.uniform(0.05,15)
            elif ipos == 4:
                depth=rng.uniform(0.05,0.2)*L; base=zd-depth; wet=max(0.2,depth*rng.uniform(0.15,0.7))
                kht=1; khb=rng.uniform(0.8,15); kvt=rng.uniform(0.8,10); kvb=rng.uniform(0.8,10); zint=zd+rng.uniform(2,12); geo=1; ent=rng.uniform(0.5,4)
                gwl=zd+rng.uniform(0.5,zint-zd+10)
                if abs(gwl-zint)<0.3: gwl += 1.0
            else:
                zint=zd-rng.uniform(2,10); base=zint-rng.uniform(2,10); wet=rng.uniform(0.3,2.0)
                kht=rng.uniform(1,20); khb=rng.uniform(0.1,12); kvt=rng.uniform(0.8,10); kvb=1; geo=rng.uniform(0.8,2.5); ent=rng.uniform(0.5,4)
                gwl=zd+shape*rng.uniform(0.1,12)
            c=case(ipos,L,shape,zd,base,wet,kht,khb,kvt,kvb,zint,geo,ent,gwl)
            try:
                oracle(ipos,c["x"])
            except (ValueError,ZeroDivisionError,OverflowError):
                continue
            cases.append(c)
    return cases


PROBE = r'''program fvq38_probe
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_hooghoudt_ipos1_response, only: drainage_hooghoudt_ipos1_parameters_t, &
       drainage_hooghoudt_ipos1_result_t, drainage_hooghoudt_ipos1_diagnostics_t, evaluate_drainage_hooghoudt_ipos1_response
  use mod_drainage_hooghoudt_equivalent_depth, only: hooghoudt_equivalent_depth_geometry_t, &
       hooghoudt_equivalent_depth_prepared_t, hooghoudt_equivalent_depth_diagnostics_t, prepare_hooghoudt_equivalent_depth
  use mod_drainage_hooghoudt_ipos23_response, only: drainage_hooghoudt_ipos2_parameters_t, drainage_hooghoudt_ipos3_parameters_t, &
       drainage_hooghoudt_ipos23_result_t, drainage_hooghoudt_ipos23_diagnostics_t, &
       evaluate_drainage_hooghoudt_ipos2_response, evaluate_drainage_hooghoudt_ipos3_response
  use mod_drainage_ernst_ipos45_preparation, only: ernst_ipos4_geometry_t, ernst_ipos5_geometry_t, &
       ernst_ipos4_prepared_t, ernst_ipos5_prepared_t, ernst_preparation_diagnostics_t, prepare_ernst_ipos4, prepare_ernst_ipos5
  use mod_drainage_ernst_ipos45_response, only: drainage_ernst_response_t, drainage_ernst_diagnostics_t, &
       evaluate_drainage_ernst_ipos4_response, evaluate_drainage_ernst_ipos5_response
  implicit none
  integer :: ipos, ios, status, evaluated, ddef, branch
  real(real64) :: x(13), q, dq, aux1, aux2
  type(process_hydraulic_view_t) :: v
  type(drainage_hooghoudt_ipos1_parameters_t) :: p1
  type(drainage_hooghoudt_ipos1_result_t) :: r1
  type(drainage_hooghoudt_ipos1_diagnostics_t) :: d1
  type(hooghoudt_equivalent_depth_geometry_t) :: ge
  type(hooghoudt_equivalent_depth_prepared_t) :: pe
  type(hooghoudt_equivalent_depth_diagnostics_t) :: de
  type(drainage_hooghoudt_ipos2_parameters_t) :: p2
  type(drainage_hooghoudt_ipos3_parameters_t) :: p3
  type(drainage_hooghoudt_ipos23_result_t) :: r23
  type(drainage_hooghoudt_ipos23_diagnostics_t) :: d23
  type(ernst_ipos4_geometry_t) :: g4
  type(ernst_ipos5_geometry_t) :: g5
  type(ernst_ipos4_prepared_t) :: pr4
  type(ernst_ipos5_prepared_t) :: pr5
  type(ernst_preparation_diagnostics_t) :: dp
  type(drainage_ernst_response_t) :: re
  type(drainage_ernst_diagnostics_t) :: dd

  do
    read(*,*,iostat=ios) ipos, x
    if (ios < 0) exit
    if (ios > 0) error stop 2
    v%groundwater_level=x(13); status=0; evaluated=0; ddef=0; branch=0; q=0; dq=0; aux1=0; aux2=0
    select case(ipos)
    case(1)
      p1%drain_spacing=x(1); p1%shape_factor=x(2); p1%drain_bottom_level=x(3); p1%horizontal_conductivity_top=x(6); p1%entry_resistance=x(12)
      call evaluate_drainage_hooghoudt_ipos1_response(p1,v,r1,d1)
      status=d1%status; if(d1%evaluated)evaluated=1; q=r1%signed_soil_to_drain_rate; if(r1%derivative_defined)ddef=1; dq=r1%dq_dgroundwater_level
      aux1=d1%horizontal_resistance; aux2=d1%total_resistance
    case(2,3)
      ge%drain_spacing=x(1); ge%drain_bottom_level=x(3); ge%impermeable_base_level=x(4); ge%wetted_perimeter=x(5)
      call prepare_hooghoudt_equivalent_depth(ge,pe,de)
      if(.not.de%prepared) then; status=100+de%status; else
        if(ipos==2) then
          p2%shape_factor=x(2); p2%horizontal_conductivity_top=x(6); p2%entry_resistance=x(12)
          call evaluate_drainage_hooghoudt_ipos2_response(p2,pe,v,r23,d23)
        else
          p3%shape_factor=x(2); p3%horizontal_conductivity_top=x(6); p3%horizontal_conductivity_bottom=x(7); p3%entry_resistance=x(12)
          call evaluate_drainage_hooghoudt_ipos3_response(p3,pe,v,r23,d23)
        end if
        status=d23%status; if(d23%evaluated)evaluated=1; q=r23%signed_soil_to_drain_rate; if(r23%derivative_defined)ddef=1; dq=r23%dq_dgroundwater_level
        aux1=pe%equivalent_depth; aux2=d23%total_resistance; branch=pe%branch
      end if
    case(4)
      g4%drain_spacing=x(1); g4%shape_factor=x(2); g4%drain_bottom_level=x(3); g4%impermeable_base_level=x(4); g4%wetted_perimeter=x(5)
      g4%horizontal_conductivity_bottom=x(7); g4%vertical_conductivity_top=x(8); g4%vertical_conductivity_bottom=x(9); g4%interface_level=x(10); g4%entry_resistance=x(12)
      call prepare_ernst_ipos4(g4,pr4,dp)
      if(.not.dp%prepared) then; status=100+dp%status; else
        call evaluate_drainage_ernst_ipos4_response(pr4,v,re,dd)
        status=dd%status; if(dd%evaluated)evaluated=1; q=re%signed_soil_to_drain_rate; if(re%derivative_defined)ddef=1; dq=re%dq_dgroundwater_level
        aux1=pr4%radial_resistance; aux2=dd%total_resistance
      end if
    case(5)
      g5%drain_spacing=x(1); g5%shape_factor=x(2); g5%drain_bottom_level=x(3); g5%impermeable_base_level=x(4); g5%wetted_perimeter=x(5)
      g5%horizontal_conductivity_top=x(6); g5%horizontal_conductivity_bottom=x(7); g5%vertical_conductivity_top=x(8); g5%interface_level=x(10)
      g5%geometry_factor=x(11); g5%entry_resistance=x(12)
      call prepare_ernst_ipos5(g5,pr5,dp)
      if(.not.dp%prepared) then; status=100+dp%status; else
        call evaluate_drainage_ernst_ipos5_response(pr5,v,re,dd)
        status=dd%status; if(dd%evaluated)evaluated=1; q=re%signed_soil_to_drain_rate; if(re%derivative_defined)ddef=1; dq=re%dq_dgroundwater_level
        aux1=pr5%radial_resistance; aux2=dd%total_resistance
      end if
    end select
    write(*,'(i0,1x,i0,1x,es24.16,1x,i0,1x,es24.16,1x,es24.16,1x,es24.16,1x,i0)') status,evaluated,q,ddef,dq,aux1,aux2,branch
  end do
end program fvq38_probe
'''


def compile_probe(root, tmp, opt):
    srcs = []
    for (commit,path), expected in EXPECTED_BLOBS.items():
        actual = git_blob(commit,path)
        if actual != expected:
            raise AssertionError(f"candidate blob drift {commit}:{path} expected {expected} got {actual}")
        out = tmp / (path.split('/')[-1])
        out.write_text(git_show(commit,path))
        srcs.append(out)
    probe = tmp / "fvq38_probe.f90"
    probe.write_text(PROBE)
    build = tmp / f"o{opt}"; build.mkdir()
    common = ["-std=f2008","-ffree-line-length-none",f"-O{opt}","-fcheck=all","-ffpe-trap=invalid,zero,overflow","-J",str(build),"-I",str(build)]
    objs=[]
    ordered = [
        root/"src/solver/mod_soil_water_solver_contract.f90",
        root/"src/solver/mod_process_hydraulic_view.f90",
        tmp/"mod_drainage_hooghoudt_ipos1_response.f90",
        tmp/"mod_drainage_hooghoudt_equivalent_depth.f90",
        tmp/"mod_drainage_hooghoudt_ipos23_response.f90",
        tmp/"mod_drainage_ernst_ipos45_preparation.f90",
        tmp/"mod_drainage_ernst_ipos45_response.f90",
        probe,
    ]
    for i,s in enumerate(ordered):
        o=build/f"{i}.o"; subprocess.run(["gfortran",*common,"-c",str(s),"-o",str(o)],check=True); objs.append(o)
    exe=build/"fvq38_probe"
    subprocess.run(["gfortran",f"-O{opt}",*[str(o) for o in objs],"-o",str(exe)],check=True)
    return exe


def serialize_cases(cases):
    return "".join(str(c["ipos"])+" "+" ".join(format(v,".17g") for v in c["x"])+"\n" for c in cases)


def parse_outputs(text):
    out=[]
    for line in text.splitlines():
        p=line.split()
        if len(p)!=8: raise AssertionError(f"unexpected probe output: {line}")
        out.append({"status":int(p[0]),"evaluated":int(p[1]),"q":float(p[2]),"ddef":int(p[3]),"dq":float(p[4]),"aux1":float(p[5]),"aux2":float(p[6]),"branch":int(p[7])})
    return out


def close(a,b,rtol=3e-12,atol=3e-13):
    return abs(a-b) <= atol + rtol*max(abs(a),abs(b))


def main():
    root=Path(__file__).resolve().parents[2]
    manifest=(root/"reference/swap-4.3.1/b0/file-manifest.sha256").read_text()
    required=f"{DRAINAGE_SHA256}     18321  SWAP/drainage.f90"
    if required not in manifest:
        raise AssertionError("frozen drainage source hash absent from B0 manifest")
    print("FVQ38_FROZEN_DRAINAGE_SOURCE_IDENTITY=PASS")
    for key,expected in EXPECTED_BLOBS.items():
        actual=git_blob(*key)
        if actual!=expected: raise AssertionError((key,expected,actual))
    print("FVQ38_CANDIDATE_CLOSEOUT_BLOB_IDENTITY=PASS")

    cases=build_cases()
    payload=serialize_cases(cases)
    with tempfile.TemporaryDirectory(prefix="fvq38-") as td:
        tmp=Path(td)
        exe0=compile_probe(root,tmp,0)
        out0=run(str(exe0),input_text=payload)
        exe2=compile_probe(root,tmp,2)
        out2=run(str(exe2),input_text=payload)
    if out0 != out2:
        raise AssertionError("O0/O2 candidate probe output differs")
    print("FVQ38_CANDIDATE_O0_O2_OUTPUT_IDENTITY=PASS")
    observed=parse_outputs(out0)
    if len(observed)!=len(cases): raise AssertionError("case/output count mismatch")

    max_q_abs=0.0; max_q_rel=0.0; max_dq_rel=0.0
    eq_branches=set(); tags={}; counts={i:0 for i in range(1,6)}; derivative_checks=0
    for c,o in zip(cases,observed):
        ipos=c["ipos"]; x=c["x"]; tag=c["tag"]; counts[ipos]+=1; tags[tag]=tags.get(tag,0)+1
        expected=oracle(ipos,x)
        if o["status"]!=0 or o["evaluated"]!=1:
            raise AssertionError(f"candidate rejected qualified case ipos={ipos} tag={tag} status={o['status']}")
        qerr=abs(o["q"]-expected["q"]); qrel=qerr/max(1e-15,abs(expected["q"]))
        max_q_abs=max(max_q_abs,qerr); max_q_rel=max(max_q_rel,qrel)
        if not close(o["q"],expected["q"]):
            raise AssertionError(f"flux mismatch ipos={ipos} tag={tag}: {o['q']} vs {expected['q']}")
        d=(x[12]-x[2])/x[1]
        exact_cutoff=(d==CUTOFF)
        expected_ddef=expected["derivative_expected"]
        if bool(o["ddef"]) != bool(expected_ddef):
            raise AssertionError(f"derivative availability mismatch ipos={ipos} tag={tag}")
        if expected_ddef and d > CUTOFF and tag not in ("above_cutoff",):
            fd=oracle_fd(ipos,x); derr=abs(o["dq"]-fd); drel=derr/max(1e-12,abs(fd)); max_dq_rel=max(max_dq_rel,drel)
            if not close(o["dq"],fd,rtol=3e-6,atol=2e-9):
                raise AssertionError(f"derivative mismatch ipos={ipos} tag={tag}: {o['dq']} vs FD {fd}")
            derivative_checks += 1
        if ipos in (2,3) and tag=="eqdepth":
            eqd,branch,_=eqdepth_oracle(x[0],x[2],x[3],x[4]); eq_branches.add(o["branch"])
            if o["branch"]!=branch or not close(o["aux1"],eqd,rtol=5e-12,atol=2e-13):
                raise AssertionError(f"equivalent-depth mismatch ipos={ipos}: branch {o['branch']}/{branch}, {o['aux1']}/{eqd}")
        if tag=="negative_rrad" and not (o["aux1"] < 0.0 and o["aux2"] > 0.0):
            raise AssertionError(f"negative radial resistance case not preserved ipos={ipos}")
        if tag=="below_cutoff" and not (o["q"]==0.0 and o["ddef"]==1 and o["dq"]==0.0):
            raise AssertionError(f"below cutoff semantics mismatch ipos={ipos}")
        if tag=="exact_cutoff" and o["ddef"]!=0:
            raise AssertionError(f"exact cutoff tangent should be unavailable ipos={ipos}")
        if tag=="interface_kink" and o["ddef"]!=0:
            raise AssertionError("IPOS4 unequal-Kv interface tangent exposed")
        if tag=="interface_equal" and o["ddef"]!=1:
            raise AssertionError("IPOS4 equal-Kv interface tangent unavailable")

    if eq_branches != {1,2,3}: raise AssertionError(f"equivalent-depth branch coverage incomplete: {eq_branches}")
    if min(counts.values()) < 20: raise AssertionError(f"insufficient per-IPOS coverage: {counts}")
    print("FVQ38_IPOS1_TO_5_INDEPENDENT_FLUX_ORACLE=PASS")
    print("FVQ38_EQDEPTH_ALL_THREE_BRANCHES=PASS")
    print("FVQ38_IPOS4_INTERFACE_DERIVATIVE_SEMANTICS=PASS")
    print("FVQ38_NEGATIVE_RADIAL_RESISTANCE_PARITY=PASS")
    print("FVQ38_B110_CUTOFF_SIDEDNESS_ALL_IPOS=PASS")
    print("FVQ38_RESPONSE_TANGENTS_VS_INDEPENDENT_ORACLE_FD=PASS")
    summary={
        "cases_total":len(cases),"cases_by_ipos":counts,"tags":tags,"derivative_fd_checks":derivative_checks,
        "equivalent_depth_branches":sorted(eq_branches),"max_flux_abs_error":max_q_abs,"max_flux_rel_error":max_q_rel,
        "max_derivative_rel_error":max_dq_rel,"candidate_heads":{"C2A":C2A,"C2B":C2B,"C2C":C2C}
    }
    encoded=json.dumps(summary,sort_keys=True,separators=(",",":")).encode()
    print("FVQ38_SUMMARY="+json.dumps(summary,sort_keys=True))
    print("FVQ38_SUMMARY_SHA256="+hashlib.sha256(encoded).hexdigest())
    print("FVQ38_DRAMET2_SCIENTIFIC_EQUIVALENCE PASS")

if __name__=="__main__":
    main()
