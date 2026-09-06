#!/usr/bin/env python3
"""Generate the SWAP-009 full-production PDI qualification case.

Input must be the supplied B0 official `cases/2.grassgrowth` directory.
The output case deliberately uses a normal-Ksat PDI model with vapor enabled,
uniform h=-1e5 cm, a zero-flux bottom boundary and 5 mm/d reference ET for
1980-01-01 through 1980-01-02.
"""
from pathlib import Path
import argparse, re, shutil, hashlib

EXPECTED_SWP_SHA256 = "5de82558c539cbab0fe110c88d3509b25f689a781158c7b511a3f5086c549c7c"
EXPECTED_MET_SHA256 = "48c269785405464476ca49dd315e12ae67e782fb0e6d3cd0322155d0ab8fb3bc"

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main() -> None:
    ap=argparse.ArgumentParser()
    ap.add_argument('official_case',type=Path)
    ap.add_argument('output',type=Path)
    a=ap.parse_args()
    if a.output.exists(): shutil.rmtree(a.output)
    shutil.copytree(a.official_case,a.output)
    p=a.output/'swap.swp'; text=p.read_text()
    def scalar(name,val):
        nonlocal text
        pat=rf'(?mi)^(\s*{re.escape(name)}\s*=\s*)([^!\r\n]*)(.*)$'
        text,n=re.subn(pat,lambda m:m.group(1)+str(val)+' '+m.group(3),text,count=1)
        if n!=1: raise RuntimeError(f'{name}: expected one match, got {n}')
    scalar('PROJECT',"'pdi_swap009_fullrun'")
    scalar('TSTART','1980-01-01'); scalar('TEND','1980-01-02'); scalar('DATEFIX','02 01')
    scalar('SWHEADER','0'); scalar('SWBAL','1'); scalar('SWBLC','1'); scalar('SWCSV','0')
    text=re.sub(r'(?mi)^\s*SWHEADER\s*=.*$', '  SWHEADER = 0', text, count=1)
    text=re.sub(r'(?mi)^\s*SWCSV\s*=.*$', '  SWCSV = 0', text, count=1)
    marker=next((ln for ln in text.splitlines() if ln.lstrip().startswith('SWHEADER =')),None)
    if not marker: raise RuntimeError('SWHEADER line not found')
    text=text.replace(marker, marker+'\n  SWAFO = 2\n  CRITDEVMASBAL = 1.0E-6               ! Print header at the start of each balance period [Y=1, N=0]',1)
    scalar('METFIL',"'pdi.met'"); scalar('SWETR','1'); scalar('SWDIVIDE','0'); scalar('SWCROP','0'); scalar('SWINCO','1')
    text,n=re.subn(r'(?mi)^\s*GWLI\s*=.*$',"  HTB =\n    -0.5 -100000.0\n  -600.0 -100000.0\n* End of table",text,count=1)
    if n!=1: raise RuntimeError('GWLI replacement failed')
    pat=r'(?ms)^\s*ORES\s+OSAT\s+ALFA\s+NPAR\s+LEXP\s+H_ENPR\s+KSATFIT\s+KSATEXM\s+BDENS\s*\n.*?^\* End of table'
    rows=''' IHWCKMODEL ORES OSAT ALFA NPAR LEXP H_ENPR KSATFIT KSATEXM BDENS H0 HA APAR OMEGA_K SWVAPOR
 8 0.02 0.433878 0.021645 1.34877 7.202077 0.0 83.24164 83.24164 1300.0 -10000000.0 -10000.0 -1.5 0.01 1
 8 0.02 0.433878 0.021645 1.34877 7.202077 0.0 83.24164 83.24164 1300.0 -10000000.0 -10000.0 -1.5 0.01 1
 8 0.02 0.433878 0.021645 1.34877 7.202077 0.0 83.24164 83.24164 1300.0 -10000000.0 -10000.0 -1.5 0.01 1
 8 0.01 0.364074 0.013642 1.48844 2.179397 0.0 25.81471 25.81471 1300.0 -10000000.0 -10000.0 -1.5 0.01 1
 8 0.01 0.364074 0.013642 1.48844 2.179397 0.0 25.81471 25.81471 1300.0 -10000000.0 -10000.0 -1.5 0.01 1
* End of table'''
    text,n=re.subn(pat,rows,text,count=1)
    if n!=1: raise RuntimeError(f'hydraulic table: expected one match, got {n}')
    scalar('SWDRA','0'); scalar('SWBBCFILE','0')
    m=re.search(r'(?mi)^\s*BBCFIL\s*=.*$',text)
    if not m: raise RuntimeError('BBCFIL not found')
    text=text[:m.end()]+'\n\n  SWBOTB = 6                ! qualification case: zero bottom flux'+text[m.end():]
    scalar('SWHEA','0')
    p.write_text(text)
    (a.output/'pdi.met').write_text(
        "Station,DD,MM,YYYY,Rad,Tmin,Tmax,Hum,Wind,Rain,ETref,Wet\n"
        "'999',01,01,1980,18000.0,15.0,28.0,1.0,2.0,0.0,5.0,0.0\n"
        "'999',02,01,1980,18000.0,15.0,28.0,1.0,2.0,0.0,5.0,0.0\n"
    )
    print('swap.swp',sha(p)); print('pdi.met',sha(a.output/'pdi.met'))
    if sha(p)!=EXPECTED_SWP_SHA256 or sha(a.output/'pdi.met')!=EXPECTED_MET_SHA256:
        raise SystemExit('generated case identity does not match qualified case')
if __name__=='__main__': main()
