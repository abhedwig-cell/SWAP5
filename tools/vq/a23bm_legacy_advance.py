#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
from zipfile import ZipFile
from datetime import date, timedelta
import argparse, csv, hashlib, os, re, shutil, subprocess

PREFIX='SWAP_4.3.1/cases/1.hupselbrook/'
ORIGIN=date(2002,1,3)  # checkpoint is end of this day; t=0 starts 2002-01-04
IRRIGATION_DATE=date(2002,1,5)

def sha256(p:Path)->str:
    return hashlib.sha256(p.read_bytes()).hexdigest()

def sub1(s, pat, repl):
    s2,n=re.subn(pat,repl,s,count=1,flags=re.M)
    if n!=1: raise RuntimeError(f'pattern count {n}: {pat}')
    return s2

def extract_case(archive:Path,dst:Path):
    if dst.exists(): shutil.rmtree(dst)
    dst.mkdir(parents=True)
    with ZipFile(archive) as z:
        for n in z.namelist():
            if n.startswith(PREFIX) and not n.endswith('/'):
                rel=n[len(PREFIX):]; p=dst/rel; p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes(z.read(n))

def configure(case:Path,start:date,end:date,restart:Path):
    shutil.copy2(restart,case/'input.end')
    p=case/'swap.swp'; s=p.read_text(encoding='latin1')
    s=sub1(s,r'^\s*TSTART\s*=.*$',f'  TSTART = {start.isoformat()}        ! A23BM')
    s=sub1(s,r'^\s*TEND\s*=.*$',f'  TEND = {end.isoformat()}          ! A23BM')
    s=sub1(s,r'^\s*OUTFIL\s*=.*$',"  OUTFIL = 'result'          ! A23BM")
    s=sub1(s,r'^\s*SWMONTH\s*=.*$','  SWMONTH = 0                ! A23BM')
    s=sub1(s,r'^\s*PERIOD\s*=.*$','  PERIOD = 1                 ! A23BM')
    s=sub1(s,r'^\s*SWEND\s*=.*$','  SWEND = 1                  ! A23BM')
    s=sub1(s,r'^\s*SWENDTYPE\s*=.*$','  SWENDTYPE = 2              ! A23BM exact binary restart')
    s=sub1(s,r'^\s*INLIST_CSV\s*=.*$',"  INLIST_CSV = 'WATBAL,ETTERMS,SOLBAL,GWL' ! A23BM")
    s=sub1(s,r'^\s*SWINCO\s*=.*$','  SWINCO = 3                 ! A23BM restart')
    s=sub1(s,r'^\s*INIFIL\s*=.*$',"  INIFIL = 'input.end'       ! A23BM restart\n  SWINITYPE = 2               ! A23BM binary restart")
    if not (start <= IRRIGATION_DATE <= end):
        s=sub1(s,r'^\s*SWIRFIX\s*=.*$','  SWIRFIX = 0                ! A23BM forcing slice')
    p.write_text(s,encoding='latin1')

def parse_csv(path:Path):
    lines=[ln for ln in path.read_text().splitlines() if ln and not ln.startswith('*')]
    rows=list(csv.DictReader(lines))
    if len(rows)<2: raise RuntimeError('expected initial and final CSV rows')
    def f(row,key):
        v=row.get(key)
        if v is None or v.strip()=='' or v.strip()=='-': return 0.0
        return float(v)
    initial=f(rows[0],'WTOT'); final=f(rows[-1],'WTOT')
    data=rows[1:]
    balance=sum(f(r,'BALDEV') for r in data)
    inputs=0.0; outputs=0.0
    for r in data:
        inputs += f(r,'RAIN') + f(r,'IRRIG') + f(r,'RUNON') + f(r,'SSDI')
        bot=f(r,'BOT')
        if bot>=0: inputs += bot
        else: outputs += -bot
        outputs += f(r,'RUNOFF') + f(r,'EIC') + f(r,'EACT') + f(r,'TACT') + f(r,'ESUBLIM') + f(r,'DRN')
    return initial, final, balance, inputs, outputs, len(data)

def write_meta(path:Path, **kw):
    with path.open('w') as h:
        for k,v in kw.items(): h.write(f'{k}={v}\n')

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--archive',type=Path,required=True); ap.add_argument('--exe',type=Path,required=True)
    ap.add_argument('--restart',type=Path,required=True); ap.add_argument('--t0',type=float,required=True); ap.add_argument('--t1',type=float,required=True)
    ap.add_argument('--workdir',type=Path,required=True); ap.add_argument('--meta',type=Path,required=True)
    a=ap.parse_args()
    for x in (a.t0,a.t1):
        if abs(x-round(x))>1e-12: raise SystemExit('A23BM legacy adapter supports integer-day VQ windows only')
    i0=int(round(a.t0)); i1=int(round(a.t1))
    if i1<=i0: raise SystemExit('invalid interval')
    start=ORIGIN + timedelta(days=i0+1); end=ORIGIN + timedelta(days=i1)
    extract_case(a.archive,a.workdir); configure(a.workdir,start,end,a.restart)
    env=os.environ.copy(); env['TERM']='xterm'
    cp=subprocess.run([str(a.exe),'./swap.swp'],cwd=a.workdir,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,env=env)
    (a.workdir/'run.log').write_text(cp.stdout)
    ok=(a.workdir/'swap.ok').exists() and 'normal completion' in cp.stdout.lower() and (a.workdir/'result.end').exists()
    if not ok:
        write_meta(a.meta,solver_ok=0,returncode=cp.returncode)
        return 0
    initial,final,balance,flux_in,flux_out,days=parse_csv(a.workdir/'result_output.csv')
    write_meta(a.meta,solver_ok=1,returncode=cp.returncode,restart_file=(a.workdir/'result.end').resolve(),restart_sha256=sha256(a.workdir/'result.end'),
               storage_initial_cm=f'{initial:.17g}',storage_final_cm=f'{final:.17g}',legacy_balance_residual_cm=f'{balance:.17g}',
               physical_flux_in_cm=f'{flux_in:.17g}',physical_flux_out_cm=f'{flux_out:.17g}',days=days)
    return 0
if __name__=='__main__': raise SystemExit(main())
