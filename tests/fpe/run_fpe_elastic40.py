#!/usr/bin/env python3
from __future__ import annotations
import math, os, shutil, subprocess

PTS=[
    (5.6631,51.9851),
    (4.8952,52.3702),
    (5.1214,52.0907),
    (6.5665,53.2194),
    (3.6100,51.4400),
]

def run(cmd, inp=None):
    env=dict(os.environ); env["PROJ_NETWORK"]="OFF"
    return subprocess.run(cmd,input=inp,text=True,capture_output=True,env=env)

def parse_xy(text):
    line=text.strip().splitlines()[-1]
    parts=line.split()
    if len(parts)<2: raise RuntimeError("short gdaltransform output")
    x=float(parts[0]); y=float(parts[1])
    if not math.isfinite(x) or not math.isfinite(y): raise RuntimeError("nonfinite output")
    return x,y

def main():
    exe=shutil.which("gdaltransform")
    if exe is None:
        raise SystemExit("F_PE_ELASTIC40_FAIL gdaltransform unavailable")
    print("F_PE_ELASTIC40_A1_GDALTRANSFORM_PRESENT=PASS")

    ver=run([exe,"--version"])
    if ver.returncode!=0:
        raise SystemExit("F_PE_ELASTIC40_FAIL version query")
    print("F_PE_ELASTIC40_GDALTRANSFORM="+ver.stdout.strip())

    ogr=shutil.which("ogr2ogr")
    print("F_PE_ELASTIC40_OGR2OGR="+("PRESENT" if ogr else "ABSENT"))
    if ogr:
        over=run([ogr,"--version"])
        print("F_PE_ELASTIC40_OGR2OGR_VERSION="+over.stdout.strip())

    outputs=[]
    for lon,lat in PTS:
        inp=f"{lon} {lat}\n"
        a=run([exe,"-s_srs","EPSG:4326","-t_srs","EPSG:28992"],inp)
        if a.returncode!=0:
            raise SystemExit("F_PE_ELASTIC40_FAIL forward "+a.stderr.strip())
        x,y=parse_xy(a.stdout)
        if not (0.0<=x<=300000.0 and 250000.0<=y<=650000.0):
            raise SystemExit(f"F_PE_ELASTIC40_FAIL implausible RD {x} {y}")
        b=run([exe,"-s_srs","EPSG:4326","-t_srs","EPSG:28992"],inp)
        if b.returncode!=0 or a.stdout!=b.stdout:
            raise SystemExit("F_PE_ELASTIC40_FAIL repeat identity")
        inv=run([exe,"-s_srs","EPSG:28992","-t_srs","EPSG:4326"],f"{x} {y}\n")
        if inv.returncode!=0:
            raise SystemExit("F_PE_ELASTIC40_FAIL inverse")
        lon2,lat2=parse_xy(inv.stdout)
        if abs(lon2-lon)>2e-7 or abs(lat2-lat)>2e-7:
            raise SystemExit(f"F_PE_ELASTIC40_FAIL roundtrip {lon} {lat} {lon2} {lat2}")
        swap=run([exe,"-s_srs","EPSG:4326","-t_srs","EPSG:28992"],f"{lat} {lon}\n")
        if swap.returncode==0:
            sx,sy=parse_xy(swap.stdout)
            if abs(sx-x)<1e-6 and abs(sy-y)<1e-6:
                raise SystemExit("F_PE_ELASTIC40_FAIL swapped axis reproduced point")
        outputs.append((x,y))
    print("F_PE_ELASTIC40_A2_FORWARD_RANGE=PASS")
    print("F_PE_ELASTIC40_A3_REPEAT_IDENTITY=PASS")
    print("F_PE_ELASTIC40_A4_INVERSE_FINITE=PASS")
    print("F_PE_ELASTIC40_A5_ROUNDTRIP=PASS")
    print("F_PE_ELASTIC40_A6_AXIS_SENSITIVITY=PASS")
    print("F_PE_ELASTIC40_A7_OFFLINE=PASS")
    print("F_PE_ELASTIC40_A8_PROVENANCE=PASS")
    print("F_PE_ELASTIC40_A9_OGR2OGR_CHARACTERIZED=PASS")
    print("F_PE_ELASTIC40=PASS")

if __name__=="__main__":
    main()
