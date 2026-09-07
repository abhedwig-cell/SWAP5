#!/usr/bin/env python3
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
P=ROOT/'src/solver/mod_b110_constitutive_provider.f90'
s=P.read_text()
old='theta = max(1.0000001_real64*p%wcr(i), p%wcr(i) + p%wcs_min_wcr(i)*expterm)'
new='theta = max(1.0000001*p%wcr(i), p%wcr(i) + p%wcs_min_wcr(i)*expterm)'
if s.count(old)!=1:
    raise SystemExit(f'F-SI09 model-2 literal repair expected once, found {s.count(old)}')
P.write_text(s.replace(old,new,1))
print('F-SI09_MODEL2_LITERAL_KIND_REPAIRED')
