#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()

src=Path(args.source).read_text()
changes=0

decls=[
("real(real64) :: tr,ts,alpha,nvg,ksat,lambda,dt,ledger,maxledger",
 "real(real64) :: tr,ts,alpha,nvg,ksat,lambda,dt,ledger,maxledger,topflux"),
("real(real64) :: tr,ts,alpha,nvg,ksat,lambda,dt",
 "real(real64) :: tr,ts,alpha,nvg,ksat,lambda,dt,topflux"),
]
for old,new in decls:
    if old in src:
        src=src.replace(old,new,1); changes+=1; break

old="call read_real(6,ksat); call read_real(7,lambda); call read_int(8,initial_tail)"
new="call read_real(6,ksat); call read_real(7,lambda); call read_int(8,initial_tail); call read_real(9,topflux)"
if old in src:
    src=src.replace(old,new,1); changes+=1
else:
    old="call read_real(6,ksat); call read_real(7,lambda)\n  call read_int(8,initial_tail)"
    new="call read_real(6,ksat); call read_real(7,lambda)\n  call read_int(8,initial_tail); call read_real(9,topflux)"
    if old in src:
        src=src.replace(old,new,1); changes+=1

old="req%boundary%top_flux=-0.01_real64"
if old in src:
    src=src.replace(old,"req%boundary%top_flux=topflux",1); changes+=1

if changes != 3:
    raise SystemExit(f"MIQUAL03 forcing materializer expected 3 changes, got {changes}")

Path(args.output).write_text(src)
print("F_PE_MIQUAL03_FORCING_MATERIALIZER=PASS")
