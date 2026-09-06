#!/usr/bin/env python3
"""Prepare a GNU-build copy of exact B1.6 without changing the canonical tree.

Intel !DEC$ conditional blocks are resolved for the standalone Linux reference
configuration: multiswap/with_sss/with_animo disabled, linux Windows-only blocks
disabled. This is a compiler-portability adapter only.
"""
from pathlib import Path
import argparse, shutil

def cond_value(text:str)->bool:
    t=text.strip().lower().replace(' ','')
    if 'defined(multiswap)' in t: return False
    if 'defined(with_sss)' in t: return False
    if 'defined(with_animo)' in t: return False
    if '(linux==0)' in t or 'linux==0' in t: return False
    raise RuntimeError(f'unknown DEC condition: {text}')

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--source',type=Path,required=True); ap.add_argument('--output',type=Path,required=True); ap.add_argument('--ttutil-prefs',type=Path,required=True)
    a=ap.parse_args()
    if a.output.exists(): shutil.rmtree(a.output)
    shutil.copytree(a.source,a.output)
    shutil.copy2(a.ttutil_prefs,a.output/'ttutilprefs.f90')
    for p in a.output.glob('*.f90'):
        lines=p.read_text(encoding='latin1').splitlines(keepends=True); out=[]; stack=[]; active=True
        for line in lines:
            s=line.strip(); u=s.upper()
            if u.startswith('!DEC$ IF'):
                c=cond_value(s); stack.append((active,c)); active=active and c; continue
            if u.startswith('!DEC$ ELSE'):
                parent,c=stack[-1]; active=parent and not c; continue
            if u.startswith('!DEC$ END IF'):
                parent,_=stack.pop(); active=parent; continue
            if active: out.append(line)
        if stack: raise RuntimeError(f'unclosed DEC block in {p}')
        p.write_text(''.join(out),encoding='latin1')
    print(a.output)
if __name__=='__main__': main()
