#!/usr/bin/env python3
"""F-PE-ELASTIC34: deterministic offline RD point -> BRO maparea selection."""
from __future__ import annotations
import argparse, json, math, sqlite3, struct
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

FEATURE_TABLE="soilarea"
GEOMETRY_COLUMN="geom"
SRS_ID=28992

class SpatialError(RuntimeError):
    pass

@dataclass(frozen=True)
class Polygon:
    maparea_id: object
    rings: tuple[tuple[tuple[float,float],...],...]
    bbox: tuple[float,float,float,float]

def find_one_gpkg(root:Path)->Path:
    hits=list(root.rglob("*.gpkg"))
    if len(hits)!=1:
        raise SpatialError(f"expected one GeoPackage, found {len(hits)}")
    return hits[0]

def _u32(data:bytes, off:int, endian:str):
    if off+4>len(data): raise SpatialError("truncated uint32")
    return struct.unpack_from(endian+"I",data,off)[0],off+4

def _f64(data:bytes, off:int, endian:str):
    if off+8>len(data): raise SpatialError("truncated float64")
    return struct.unpack_from(endian+"d",data,off)[0],off+8

def decode_gpkg_polygon(blob:bytes)->tuple[tuple[tuple[float,float],...],...]:
    if blob is None or len(blob)<8 or blob[:2]!=b"GP":
        raise SpatialError("invalid GeoPackage geometry header")
    flags=blob[3]
    endian="<" if (flags & 1) else ">"
    envelope_code=(flags >> 1) & 0x07
    envelope_bytes={0:0,1:32,2:48,3:48,4:64}.get(envelope_code)
    if envelope_bytes is None:
        raise SpatialError(f"unsupported envelope code {envelope_code}")
    srs_id=struct.unpack_from(endian+"i",blob,4)[0]
    if srs_id!=SRS_ID:
        raise SpatialError(f"unexpected geometry SRS {srs_id}")
    off=8+envelope_bytes
    if off+5>len(blob):
        raise SpatialError("missing WKB payload")
    byte_order=blob[off]
    wend="<" if byte_order==1 else ">" if byte_order==0 else None
    if wend is None:
        raise SpatialError("invalid WKB byte order")
    off+=1
    geom_type,off=_u32(blob,off,wend)
    base_type=geom_type & 0x000000FF
    if base_type!=3:
        if geom_type in (1003,2003,3003):
            dims=2 + (geom_type//1000 in (1,3)) + (geom_type//1000 in (2,3))
        else:
            raise SpatialError(f"unsupported WKB geometry type {geom_type}")
    else:
        dims=2
    nrings,off=_u32(blob,off,wend)
    if nrings<1:
        raise SpatialError("polygon has no rings")
    rings=[]
    for _ in range(nrings):
        npts,off=_u32(blob,off,wend)
        if npts<4:
            raise SpatialError("ring has fewer than 4 points")
        pts=[]
        for _ in range(npts):
            coords=[]
            for _ in range(dims):
                v,off=_f64(blob,off,wend); coords.append(v)
            x,y=coords[0],coords[1]
            if not math.isfinite(x) or not math.isfinite(y):
                raise SpatialError("non-finite coordinate")
            pts.append((x,y))
        if pts[0]!=pts[-1]:
            raise SpatialError("ring is not closed")
        rings.append(tuple(pts))
    return tuple(rings)

def bbox_of(rings):
    xs=[p[0] for r in rings for p in r]
    ys=[p[1] for r in rings for p in r]
    return min(xs),min(ys),max(xs),max(ys)

def point_on_segment(x,y,a,b):
    ax,ay=a; bx,by=b
    cross=(x-ax)*(by-ay)-(y-ay)*(bx-ax)
    if cross!=0.0:
        return False
    return min(ax,bx)<=x<=max(ax,bx) and min(ay,by)<=y<=max(ay,by)

def ring_relation(x,y,ring):
    inside=False
    for a,b in zip(ring[:-1],ring[1:]):
        if point_on_segment(x,y,a,b):
            return "boundary"
        x1,y1=a; x2,y2=b
        if (y1>y)!=(y2>y):
            xin=(x2-x1)*(y-y1)/(y2-y1)+x1
            if xin==x:
                return "boundary"
            if xin>x:
                inside=not inside
    return "inside" if inside else "outside"

def polygon_relation(x,y,polygon:Polygon):
    minx,miny,maxx,maxy=polygon.bbox
    if x<minx or x>maxx or y<miny or y>maxy:
        return "outside"
    outer=ring_relation(x,y,polygon.rings[0])
    if outer!="inside":
        return outer
    for hole in polygon.rings[1:]:
        rel=ring_relation(x,y,hole)
        if rel=="boundary": return "boundary"
        if rel=="inside": return "outside"
    return "inside"

def load_polygons(gpkg:Path)->list[Polygon]:
    con=sqlite3.connect(f"file:{gpkg.resolve()}?mode=ro",uri=True)
    try:
        meta=con.execute(
            "select geometry_type_name,srs_id from gpkg_geometry_columns "
            "where table_name=? and column_name=?",(FEATURE_TABLE,GEOMETRY_COLUMN)
        ).fetchall()
        if meta!=[("POLYGON",SRS_ID)]:
            raise SpatialError(f"unexpected geometry metadata {meta!r}")
        rows=con.execute(
            f'select maparea_id,"{GEOMETRY_COLUMN}" from "{FEATURE_TABLE}" '
            'where maparea_id is not null and "geom" is not null order by maparea_id'
        ).fetchall()
    finally:
        con.close()
    polygons=[]
    for maparea_id,blob in rows:
        rings=decode_gpkg_polygon(blob)
        polygons.append(Polygon(maparea_id,rings,bbox_of(rings)))
    return polygons

def select_maparea(polygons:Iterable[Polygon],x:float,y:float):
    if not math.isfinite(x) or not math.isfinite(y):
        raise SpatialError("point coordinates must be finite")
    inside=[]
    boundary=[]
    for p in polygons:
        rel=polygon_relation(x,y,p)
        if rel=="inside": inside.append(p.maparea_id)
        elif rel=="boundary": boundary.append(p.maparea_id)
    if boundary:
        return {"status":"BOUNDARY","maparea_id":None,"boundary_ids":boundary,"inside_ids":inside}
    if len(inside)==0:
        return {"status":"NOT_FOUND","maparea_id":None,"boundary_ids":[],"inside_ids":[]}
    if len(inside)>1:
        return {"status":"AMBIGUOUS","maparea_id":None,"boundary_ids":[],"inside_ids":inside}
    return {"status":"OK","maparea_id":inside[0],"boundary_ids":[],"inside_ids":inside}

def ring_centroid(ring):
    area2=0.0; cx=0.0; cy=0.0
    for (x1,y1),(x2,y2) in zip(ring[:-1],ring[1:]):
        cross=x1*y2-x2*y1
        area2+=cross
        cx+=(x1+x2)*cross
        cy+=(y1+y2)*cross
    if area2==0.0:
        return None
    return cx/(3.0*area2),cy/(3.0*area2)

def strict_probe(p:Polygon):
    c=ring_centroid(p.rings[0])
    if c is not None and polygon_relation(c[0],c[1],p)=="inside":
        return c
    ring=p.rings[0]
    a=ring[0]
    for i in range(1,len(ring)-2):
        b=ring[i]; c=ring[i+1]
        probe=((a[0]+b[0]+c[0])/3.0,(a[1]+b[1]+c[1])/3.0)
        if polygon_relation(probe[0],probe[1],p)=="inside":
            return probe
    return None

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--gpkg",required=True)
    ap.add_argument("--x",type=float)
    ap.add_argument("--y",type=float)
    ap.add_argument("--output")
    a=ap.parse_args()
    gpkg=Path(a.gpkg)
    polygons=load_polygons(gpkg)
    if len(polygons)!=48025:
        raise SpatialError(f"expected 48025 polygons, got {len(polygons)}")
    result={"schema":"swap5.elastic34.rd-maparea.v1","srs_id":SRS_ID,"polygon_count":len(polygons)}
    if a.x is not None or a.y is not None:
        if a.x is None or a.y is None:
            raise SpatialError("both x and y are required")
        result["selection"]=select_maparea(polygons,a.x,a.y)
    if a.output:
        Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    else:
        print(json.dumps(result,sort_keys=True))

if __name__=="__main__":
    main()
