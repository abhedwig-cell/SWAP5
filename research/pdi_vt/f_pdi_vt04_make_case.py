#!/usr/bin/env python3
from pathlib import Path
import argparse,re,shutil,hashlib

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def scalar(text,name,val):
    pat=rf'(?mi)^(\s*{re.escape(name)}\s*=\s*)([^!\r\n]*)(.*)$'
    text,n=re.subn(pat,lambda m:m.group(1)+str(val)+' '+m.group(3),text,count=1)
    if n!=1: raise RuntimeError(f'{name}: expected one match, got {n}')
    return text

def main():
    ap=argparse.ArgumentParser();ap.add_argument('src',type=Path);ap.add_argument('dst',type=Path);ap.add_argument('--swvapor',type=int,default=1);a=ap.parse_args()
    if a.dst.exists(): shutil.rmtree(a.dst)
    shutil.copytree(a.src,a.dst)
    template=a.dst/'swap_linux.swp.template'
    if not template.exists(): raise SystemExit('missing swap_linux.swp.template')
    p=a.dst/'swap.swp';shutil.copy2(template,p);text=p.read_text()
    for n,v in [
      ('PROJECT',"'pdi_vt04_fullrun'"),('TSTART','1980-01-01'),('TEND','1980-01-02'),('DATEFIX','02 01'),
      ('SWHEADER','0'),('SWBAL','1'),('SWBLC','1'),('SWCSV','0'),('METFIL',"'pdi.met'"),('SWETR','1'),
      ('SWDIVIDE','0'),('SWCROP','0'),('SWINCO','1'),('SWDRA','0'),('SWBBCFILE','0'),('SWHEA','0')]:
        text=scalar(text,n,v)
    # Ensure BFO output for state/flux comparison and strict mass criterion.
    text=scalar(text,'SWAFO','2')
    if 'CRITDEVMASBAL' in text:
        text=scalar(text,'CRITDEVMASBAL','1.0E-6')
    else:
        marker=next(ln for ln in text.splitlines() if ln.lstrip().startswith('SWHEADER ='))
        text=text.replace(marker,marker+'\n  CRITDEVMASBAL = 1.0E-6',1)
    # Uniform very dry initial pressure head through HTB table.
    text,n=re.subn(r'(?mi)^\s*GWLI\s*=.*$',"  HTB =\n    -0.5 -100000.0\n  -600.0 -100000.0\n* End of table",text,count=1)
    if n!=1:
        # Newer templates may already use HTB. Replace its table block.
        pat=r'(?ms)^\s*HTB\s*=\s*\n.*?^\* End of table'
        text,n=re.subn(pat,"  HTB =\n    -0.5 -100000.0\n  -600.0 -100000.0\n* End of table",text,count=1)
    if n!=1: raise RuntimeError('initial head table replacement failed')
    # Replace the hydraulic parameter table by a five-layer model-8 PDI vapor-on setup.
    pat=r'(?ms)^\s*(?:IHWCKMODEL\s+)?ORES\s+OSAT\s+ALFA\s+NPAR.*?^\* End of table'
    rows=f''' IHWCKMODEL ORES OSAT ALFA NPAR LEXP H_ENPR KSATFIT KSATEXM BDENS H0 HA APAR OMEGA_K SWVAPOR
 8 0.02 0.433878 0.021645 1.34877 7.202077 0.0 83.24164 83.24164 1300.0 -10000000.0 -10000.0 -1.5 0.01 {a.swvapor}
 8 0.02 0.433878 0.021645 1.34877 7.202077 0.0 83.24164 83.24164 1300.0 -10000000.0 -10000.0 -1.5 0.01 {a.swvapor}
 8 0.02 0.433878 0.021645 1.34877 7.202077 0.0 83.24164 83.24164 1300.0 -10000000.0 -10000.0 -1.5 0.01 {a.swvapor}
 8 0.01 0.364074 0.013642 1.48844 2.179397 0.0 25.81471 25.81471 1300.0 -10000000.0 -10000.0 -1.5 0.01 {a.swvapor}
 8 0.01 0.364074 0.013642 1.48844 2.179397 0.0 25.81471 25.81471 1300.0 -10000000.0 -10000.0 -1.5 0.01 {a.swvapor}
* End of table'''
    text,n=re.subn(pat,rows,text,count=1)
    if n!=1: raise RuntimeError('hydraulic table replacement failed')
    # Force zero bottom flux. Insert SWBOTB=6 next to BBCFIL if needed.
    if re.search(r'(?mi)^\s*SWBOTB\s*=',text):
        text=scalar(text,'SWBOTB','6')
    else:
        m=re.search(r'(?mi)^\s*BBCFIL\s*=.*$',text)
        if not m: raise RuntimeError('BBCFIL not found')
        text=text[:m.end()]+'\n\n  SWBOTB = 6'+text[m.end():]
    p.write_text(text)
    (a.dst/'pdi.met').write_text(
      "Station,DD,MM,YYYY,Rad,Tmin,Tmax,Hum,Wind,Rain,ETref,Wet\n"
      "'999',01,01,1980,18000.0,15.0,28.0,1.0,2.0,0.0,5.0,0.0\n"
      "'999',02,01,1980,18000.0,15.0,28.0,1.0,2.0,0.0,5.0,0.0\n"
    )
    print('swap.swp',sha(p));print('pdi.met',sha(a.dst/'pdi.met'))
if __name__=='__main__': main()
