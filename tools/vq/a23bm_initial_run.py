#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
from zipfile import ZipFile
from datetime import date
import argparse, csv, hashlib, os, re, shutil, subprocess
PREFIX='SWAP_4.3.1/cases/1.hupselbrook/'
IRRIGATION_DATE=date(2002,1,5)

def sha256(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def sub1(s,pat,repl):
    s2,n=re.subn(pat,repl,s,count=1,flags=re.M)
    if n!=1: raise RuntimeError((pat,n))
    return s2

def extract_case(archive,dst):
    if dst.exists(): shutil.rmtree(dst)
    dst.mkdir(parents=True)
    with ZipFile(archive) as z:
        for n in z.namelist():
            if n.startswith(PREFIX) and not n.endswith('/'):
                rel=n[len(PREFIX):]; p=dst/rel; p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes(z.read(n))

def parse_csv(path):
    lines=[ln for ln in path.read_text().splitlines() if ln and not ln.startswith('*')]
    rows=list(csv.DictReader(lines))
    def f(row,key):
        v=row.get(key)
        if v is None or v.strip()=='' or v.strip()=='-': return 0.0
        return float(v)
    data=rows[1:]; initial=f(rows[0],'WTOT'); final=f(rows[-1],'WTOT')
    balance=sum(f(r,'BALDEV') for r in data); inputs=outputs=0.0
    for r in data:
        inputs += f(r,'RAIN')+f(r,'IRRIG')+f(r,'RUNON')+f(r,'SSDI')
        bot=f(r,'BOT')
        if bot>=0: inputs+=bot
        else: outputs += -bot
        outputs += f(r,'RUNOFF')+f(r,'EIC')+f(r,'EACT')+f(r,'TACT')+f(r,'ESUBLIM')+f(r,'DRN')
    return initial,final,balance,inputs,outputs,len(data)

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--archive',type=Path,required=True); ap.add_argument('--exe',type=Path,required=True)
    ap.add_argument('--start',required=True); ap.add_argument('--end',required=True); ap.add_argument('--workdir',type=Path,required=True); ap.add_argument('--meta',type=Path,required=True)
    a=ap.parse_args(); start=date.fromisoformat(a.start); end=date.fromisoformat(a.end)
    extract_case(a.archive,a.workdir)
    p=a.workdir/'swap.swp'; s=p.read_text(encoding='latin1')
    s=sub1(s,r'^\s*TSTART\s*=.*$',f'  TSTART = {a.start}        ! A23BM')
    s=sub1(s,r'^\s*TEND\s*=.*$',f'  TEND = {a.end}          ! A23BM')
    s=sub1(s,r'^\s*OUTFIL\s*=.*$',"  OUTFIL = 'result'          ! A23BM")
    s=sub1(s,r'^\s*SWMONTH\s*=.*$','  SWMONTH = 0                ! A23BM')
    s=sub1(s,r'^\s*PERIOD\s*=.*$','  PERIOD = 1                 ! A23BM')
    s=sub1(s,r'^\s*SWEND\s*=.*$','  SWEND = 1                  ! A23BM')
    s=sub1(s,r'^\s*SWENDTYPE\s*=.*$','  SWENDTYPE = 2              ! A23BM exact binary restart')
    s=sub1(s,r'^\s*INLIST_CSV\s*=.*$',"  INLIST_CSV = 'WATBAL,ETTERMS,SOLBAL,GWL' ! A23BM")
    s=sub1(s,r'^\s*SWINCO\s*=.*$','  SWINCO = 2                 ! A23BM canonical initial state')
    if not (start<=IRRIGATION_DATE<=end): s=sub1(s,r'^\s*SWIRFIX\s*=.*$','  SWIRFIX = 0                ! A23BM forcing slice')
    p.write_text(s,encoding='latin1')
    env=os.environ.copy(); env['TERM']='xterm'
    cp=subprocess.run([str(a.exe),'./swap.swp'],cwd=a.workdir,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,env=env)
    (a.workdir/'run.log').write_text(cp.stdout)
    ok=(a.workdir/'swap.ok').exists() and 'normal completion' in cp.stdout.lower() and (a.workdir/'result.end').exists()
    with a.meta.open('w') as h:
        h.write(f'solver_ok={1 if ok else 0}\n')
        if ok:
            initial,final,balance,fin,fout,days=parse_csv(a.workdir/'result_output.csv')
            h.write(f'restart_file={(a.workdir/"result.end").resolve()}\nrestart_sha256={sha256(a.workdir/"result.end")}\n')
            h.write(f'storage_initial_cm={initial:.17g}\nstorage_final_cm={final:.17g}\nlegacy_balance_residual_cm={balance:.17g}\n')
            h.write(f'physical_flux_in_cm={fin:.17g}\nphysical_flux_out_cm={fout:.17g}\ndays={days}\n')
    return 0 if ok else 2
if __name__=='__main__': raise SystemExit(main())
