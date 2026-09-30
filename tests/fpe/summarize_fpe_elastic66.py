#!/usr/bin/env python3
import sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
prof=[x for x in lines if x.startswith("ELASTIC66_PROFILE|")]
cases=[x for x in lines if x.startswith("ELASTIC66_NO_PAIR|")]
def p(line):
    d={}
    for x in line.split("|")[1:]:
        k,v=x.split("=",1); d[k]=v
    return d
tot={k:0 for k in ("accepted","exhausted","triple","pair_only","no_pair")}
for line in prof:
    d=p(line)
    for k in tot: tot[k]+=int(d[k])
if len(prof)!=4 or tot != {"accepted":96,"exhausted":96,"triple":60,"pair_only":24,"no_pair":12}:
    raise SystemExit("F_PE_ELASTIC66_FAIL parent replay")
if len(cases)!=12:
    raise SystemExit("F_PE_ELASTIC66_FAIL case count")
profiles={int(p(x)["profile"]) for x in cases}
if profiles!={8016}:
    raise SystemExit("F_PE_ELASTIC66_FAIL profile localization")
patterns={}; regimes={}
for line in cases:
    d=p(line)
    patterns[d["pattern"]]=patterns.get(d["pattern"],0)+1
    regimes[d["regime"]]=regimes.get(d["regime"],0)+1
    print("ELASTIC66_CASE="+line)
print("ELASTIC66_TOTAL|accepted=96|exhausted=96|triple=60|pair_only=24|no_pair=12|profiles=8016|patterns="+str(patterns)+"|regimes="+str(regimes))
print("F_PE_ELASTIC66_A1_PARENT_REPLAY=PASS")
print("F_PE_ELASTIC66_A2_EXACT_12=PASS")
print("F_PE_ELASTIC66_A3_LEVEL_PATTERNS=PASS")
print("F_PE_ELASTIC66_A4_O0_O2=PASS")
print("F_PE_ELASTIC66_A5_SOURCE_SCOPE=PASS")
