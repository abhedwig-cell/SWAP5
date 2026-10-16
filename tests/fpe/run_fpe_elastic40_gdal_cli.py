#!/usr/bin/env python3
"""F-PE-ELASTIC40 research-only GDAL CLI capability audit."""
from __future__ import annotations
import json, math, os, shutil, subprocess

POINTS=[
    (5.6631,51.9851,"wageningen"),
    (4.8952,52.3702,"amsterdam"),
    (5.1214,52.0907,"utrecht"),
    (6.5665,53.2194,"groningen"),
    (3.6100,51.4400,"zeeland"),
]

ENV=dict(os.environ)
ENV["PROJ_NETWORK"]="OFF"

def fail(msg):
    raise SystemExit("F_PE_ELASTIC40_FAIL "+msg)

def run(cmd, stdin=None):
    p=subprocess.run(cmd,input=stdin,text=True,capture_output=True,env=ENV)
    if p.returncode!=0:
        fail(f"command failed {cmd}: {p.stderr.strip()}")
    return p.stdout.strip()

def parse_pair(text):
    parts=text.splitlines()[0].strip().replace("\t"," ").split()
    if len(parts)<2:
        fail("cannot parse coordinate output: "+repr(text))
    try:
        a=float(parts[0]); b=float(parts[1])
    except ValueError:
        fail("non-numeric coordinate output: "+repr(text))
    if not (math.isfinite(a) and math.isfinite(b)):
        fail("non-finite coordinate output")
    return a,b

def forward(exe, lon, lat):
    out=run([exe,"-s_srs","EPSG:4326","-t_srs","EPSG:28992"],f"{lon:.10f} {lat:.10f}\n")
    return parse_pair(out),out

def inverse(exe, x, y):
    out=run([exe,"-s_srs","EPSG:28992","-t_srs","EPSG:4326"],f"{x:.8f} {y:.8f}\n")
    return parse_pair(out),out

def main():
    exe=shutil.which("gdaltransform")
    if not exe:
        fail("gdaltransform unavailable")
    print("F_PE_ELASTIC40_A1_GDALTRANSFORM_AVAILABLE=PASS")

    version=""
    p=subprocess.run([exe,"--version"],text=True,capture_output=True,env=ENV)
    version=(p.stdout+"\n"+p.stderr).strip().splitlines()[0] if (p.stdout or p.stderr) else ""

    results=[]
    for lon,lat,name in POINTS:
        (x,y),txt1=forward(exe,lon,lat)
        (x2,y2),txt2=forward(exe,lon,lat)
        if txt1!=txt2:
            fail(f"non-deterministic forward text {name}")
        if not (0.0<=x<=300000.0 and 250000.0<=y<=650000.0):
            fail(f"implausible RD range {name}: {x},{y}")
        (lon2,lat2),inv_txt=inverse(exe,x,y)
        lon_err=abs(lon2-lon); lat_err=abs(lat2-lat)
        if lon_err>2e-7 or lat_err>2e-7:
            fail(f"roundtrip {name}: {lon_err},{lat_err}")
        results.append({
            "name":name,"lon":lon,"lat":lat,"x":x,"y":y,
            "lon2":lon2,"lat2":lat2,"lon_error_deg":lon_err,
            "lat_error_deg":lat_err,"forward_text":txt1,"inverse_text":inv_txt
        })
    print("F_PE_ELASTIC40_A2_RD_RANGE=PASS")
    print("F_PE_ELASTIC40_A3_TEXT_DETERMINISM=PASS")
    print("F_PE_ELASTIC40_A4_INVERSE_FINITE=PASS")
    print("F_PE_ELASTIC40_A5_ROUNDTRIP=PASS")

    (goodx,goody),_=forward(exe,5.6631,51.9851)
    (swapx,swapy),_=forward(exe,51.9851,5.6631)
    if math.hypot(goodx-swapx,goody-swapy)<1.0:
        fail("axis-order probe did not discriminate")
    print("F_PE_ELASTIC40_A6_AXIS_ORDER_DISCRIMINATED=PASS")

    if ENV.get("PROJ_NETWORK")!="OFF":
        fail("PROJ_NETWORK not OFF")
    print("F_PE_ELASTIC40_A7_OFFLINE_NETWORK_POLICY=PASS")

    ogr2ogr=shutil.which("ogr2ogr")
    print("F_PE_ELASTIC40_A8_PROVENANCE="+json.dumps({
        "gdaltransform_path":exe,"gdaltransform_version":version,
        "proj_network":"OFF","points":results
    },sort_keys=True,separators=(",",":")))
    print("F_PE_ELASTIC40_A9_OGR2OGR_CHARACTERIZED="+json.dumps({
        "available":bool(ogr2ogr),"path":ogr2ogr
    },sort_keys=True,separators=(",",":")))
    print("F_PE_ELASTIC40=PASS")

if __name__=="__main__":
    main()
