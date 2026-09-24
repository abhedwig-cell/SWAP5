#!/usr/bin/env python3
from pathlib import Path
import argparse, re, shutil

def set_scalar(text, name, value):
    p = rf'(?mi)^(\s*{re.escape(name)}\s*=\s*)([^!\r\n]*)(.*)$'
    text, n = re.subn(p, lambda m: m.group(1)+str(value)+' '+m.group(3), text, count=1)
    if n != 1:
        raise RuntimeError(name)
    return text

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('src',type=Path)
    ap.add_argument('dst',type=Path)
    ap.add_argument('--swvapor',type=int,default=1)
    a=ap.parse_args()
    if a.dst.exists():
        shutil.rmtree(a.dst)
    shutil.copytree(a.src,a.dst)
    src=a.dst/'swap_linux.swp.template'
    dst=a.dst/'swap.swp'
    shutil.copy2(src,dst)
    t=dst.read_text()
    for k,v in [
        ('PROJECT',"'pdi_vt04_fullrun'"),('TSTART','1980-01-01'),('TEND','1980-01-02'),
        ('DATEFIX','02 01'),('SWCSV','0'),('SWETR','1'),('SWDIVIDE','0'),
        ('SWCROP','0'),('SWINCO','1'),('SWDRA','0'),('SWBBCFILE','0'),('SWHEA','0'),
        ('SWAFO','2')]:
        t=set_scalar(t,k,v)
    if not re.search(r'(?mi)^\s*SWDISCRVERT\s*=',t):
        m=re.search(r'(?mi)^\s*SWSOPHY\s*=.*$',t)
        if not m: raise RuntimeError('swsophy')
        t=t[:m.end()]+'\n  SWDISCRVERT = 0'+t[m.end():]
    t,n=re.subn(r'(?mi)^\s*GWLI\s*=.*$','  ZI = -0.5 -600.0\n  H = -1.0E5 -1.0E5',t,count=1)
    if n!=1: raise RuntimeError('initial')
    pat=r'(?ms)^\s*ORES\s+OSAT\s+ALFA\s+NPAR.*?^\* End of table'
    rows=f""" IHWCKMODEL ORES OSAT ALFA NPAR KSATFIT LEXP H_ENPR KSATEXM BDENS H0 HA APAR OMEGA_K SWVAPOR
 8 0.02 0.433878 0.021645 1.34877 83.24164 7.202077 0.0 83.24164 1300.0 -10000000.0 -10000.0 -1.5 0.01 {a.swvapor}
 8 0.02 0.433878 0.021645 1.34877 83.24164 7.202077 0.0 83.24164 1300.0 -10000000.0 -10000.0 -1.5 0.01 {a.swvapor}
 8 0.02 0.433878 0.021645 1.34877 83.24164 7.202077 0.0 83.24164 1300.0 -10000000.0 -10000.0 -1.5 0.01 {a.swvapor}
 8 0.01 0.364074 0.013642 1.48844 25.81471 2.179397 0.0 25.81471 1300.0 -10000000.0 -10000.0 -1.5 0.01 {a.swvapor}
 8 0.01 0.364074 0.013642 1.48844 25.81471 2.179397 0.0 25.81471 1300.0 -10000000.0 -10000.0 -1.5 0.01 {a.swvapor}
* End of table"""
    t,n=re.subn(pat,rows,t,count=1)
    if n!=1: raise RuntimeError('hydraulics')
    if re.search(r'(?mi)^\s*SWBOTB\s*=',t):
        t=set_scalar(t,'SWBOTB','6')
    else:
        m=re.search(r'(?mi)^\s*BBCFIL\s*=.*$',t)
        if not m: raise RuntimeError('bb')
        t=t[:m.end()]+'\n  SWBOTB = 6'+t[m.end():]
    dst.write_text(t)
    (a.dst/'pdi.met').write_text(
        "Station,DD,MM,YYYY,Rad,Tmin,Tmax,Hum,Wind,Rain,ETref,Wet\n"
        "'999',01,01,1980,18000.0,15.0,28.0,1.0,2.0,0.0,5.0,0.0\n"
        "'999',02,01,1980,18000.0,15.0,28.0,1.0,2.0,0.0,5.0,0.0\n")
if __name__=='__main__': main()
