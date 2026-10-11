#!/usr/bin/env python3
"""F-PE-ELASTIC38 research-only CRS capability audit."""
from __future__ import annotations
import json, math, os, shutil, subprocess, sys
from pathlib import Path

POINTS=[
    (5.6631,51.9851,"wageningen"),
    (4.8952,52.3702,"amsterdam"),
    (5.1214,52.0907,"utrecht"),
    (6.5665,53.2194,"groningen"),
    (3.6100,51.4400,"zeeland"),
]

def fail(msg):
    raise SystemExit("F_PE_ELASTIC38_FAIL "+msg)

def run_optional(cmd):
    exe=shutil.which(cmd[0])
    if not exe:
        return {"available":False}
    env=dict(os.environ)
    env["PROJ_NETWORK"]="OFF"
    p=subprocess.run([exe,*cmd[1:]],text=True,capture_output=True,env=env)
    return {"available":True,"returncode":p.returncode,"stdout":p.stdout,"stderr":p.stderr}

def main():
    os.environ["PROJ_NETWORK"]="OFF"
    try:
        import pyproj
        from pyproj import CRS, Transformer, datadir, network
    except Exception as exc:
        fail("pyproj unavailable: "+repr(exc))

    network.set_network_enabled(False)
    if network.is_network_enabled():
        fail("PROJ network remained enabled")

    src=CRS.from_epsg(4326)
    dst=CRS.from_epsg(28992)
    if src.to_epsg()!=4326 or dst.to_epsg()!=28992:
        fail("EPSG resolution mismatch")
    print("F_PE_ELASTIC38_A1_PYPROJ_AVAILABLE=PASS")
    print("F_PE_ELASTIC38_A2_VERSION="+json.dumps({
        "pyproj":pyproj.__version__,
        "proj":pyproj.proj_version_str,
        "data_dir":datadir.get_data_dir(),
    },sort_keys=True,separators=(",",":")))
    print("F_PE_ELASTIC38_A3_OFFLINE_EPSG=PASS")

    fwd1=Transformer.from_crs(src,dst,always_xy=True)
    fwd2=Transformer.from_crs(src,dst,always_xy=True)
    inv=Transformer.from_crs(dst,src,always_xy=True)

    if fwd1.description != fwd2.description:
        fail("transformer description drift")
    if fwd1.definition != fwd2.definition:
        fail("transformer definition drift")
    print("F_PE_ELASTIC38_A4_TRANSFORMER_DETERMINISM=PASS")

    axis_probe=fwd1.transform(5.6631,51.9851)
    reversed_probe=fwd1.transform(51.9851,5.6631)
    if axis_probe == reversed_probe:
        fail("axis probe did not discriminate")
    print("F_PE_ELASTIC38_A5_AXIS_ORDER_EXPLICIT=PASS")

    results=[]
    max_lon_err=max_lat_err=0.0
    for lon,lat,name in POINTS:
        x,y=fwd1.transform(lon,lat)
        if not (math.isfinite(x) and math.isfinite(y)):
            fail(f"nonfinite forward {name}")
        if not (0.0 <= x <= 300000.0 and 250000.0 <= y <= 650000.0):
            fail(f"implausible RD range {name}: {x},{y}")
        lon2,lat2=inv.transform(x,y)
        if not (math.isfinite(lon2) and math.isfinite(lat2)):
            fail(f"nonfinite inverse {name}")
        lon_err=abs(lon2-lon); lat_err=abs(lat2-lat)
        max_lon_err=max(max_lon_err,lon_err); max_lat_err=max(max_lat_err,lat_err)
        if lon_err>1e-8 or lat_err>1e-8:
            fail(f"geographic roundtrip {name}: {lon_err},{lat_err}")
        x2,y2=fwd1.transform(lon2,lat2)
        rd_err=math.hypot(x2-x,y2-y)
        if rd_err>1e-3:
            fail(f"RD roundtrip {name}: {rd_err}")
        results.append({"name":name,"lon":lon,"lat":lat,"x":x,"y":y,
                        "lon_error_deg":lon_err,"lat_error_deg":lat_err,"rd_error_m":rd_err})
    print("F_PE_ELASTIC38_A6_FINITE_TRANSFORM=PASS")
    print("F_PE_ELASTIC38_A7_ROUNDTRIP=PASS")
    print("F_PE_ELASTIC38_A8_RD_RANGE=PASS")
    print("F_PE_ELASTIC38_POINTS="+json.dumps(results,sort_keys=True,separators=(",",":")))

    projinfo=run_optional(["projinfo","EPSG:28992"])
    cs2cs=run_optional(["cs2cs","EPSG:4326","EPSG:28992"])
    if projinfo.get("available") and projinfo.get("returncode")!=0:
        fail("projinfo present but EPSG:28992 lookup failed")
    if cs2cs.get("available") and cs2cs.get("returncode")!=0:
        fail("cs2cs present but CRS pair setup failed")
    print("F_PE_ELASTIC38_A9_PROJ_CLI_CHARACTERIZED="+json.dumps({
        "projinfo_available":projinfo.get("available",False),
        "cs2cs_available":cs2cs.get("available",False),
    },sort_keys=True,separators=(",",":")))

    print("F_PE_ELASTIC38=PASS")

if __name__=="__main__":
    main()
