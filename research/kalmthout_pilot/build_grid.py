#!/usr/bin/env python3
import csv, json, sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
cfg=json.loads((HERE/"domain.json").read_text())
bbox=cfg["minimal_extent"]
grid=cfg["pilot_grid"]
dx=float(grid["cell_size_m"])
ncols=int(grid["ncols"]); nrows=int(grid["nrows"])

assert abs((bbox["xmax"]-bbox["xmin"])/dx-ncols)<1e-12
assert abs((bbox["ymax"]-bbox["ymin"])/dx-nrows)<1e-12
assert ncols*nrows==int(grid["cell_count"])

writer=csv.writer(sys.stdout)
writer.writerow(["cell_id","col","row","xmin","ymin","xmax","ymax","easting","northing"])
for row in range(1,nrows+1):
    ymin=bbox["ymin"]+(row-1)*dx
    ymax=ymin+dx
    for col in range(1,ncols+1):
        xmin=bbox["xmin"]+(col-1)*dx
        xmax=xmin+dx
        cell_no=(row-1)*ncols+col
        writer.writerow([f"KAL_{cell_no:04d}",col,row,
                         f"{xmin:.1f}",f"{ymin:.1f}",f"{xmax:.1f}",f"{ymax:.1f}",
                         f"{xmin+dx/2:.1f}",f"{ymin+dx/2:.1f}"])
