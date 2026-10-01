#!/usr/bin/env python3
import base64
import gzip
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
src=ROOT/"tests/fpm/fixtures/PPA_WU05A18_ANDELST_PERCHED_SNAPSHOT.txt.gz.b64"
outdir=ROOT/"tests/fpm/.a18_generated"
outdir.mkdir(exist_ok=True)
text=gzip.decompress(base64.b64decode(src.read_text().strip())).decode()
rows={}
cofs={}
for line in text.splitlines():
    key,body=line.split(" ",1)
    if key.startswith("COF") and key!="COF_RUNS":
        cofs[int(key[3:])]=[float(x) for x in body.split()]
    elif key=="META":
        rows[key]=[float(x) for x in body.split()]
    elif key=="COF_RUNS":
        rows[key]=[int(x) for x in body.split()]
    else:
        rows[key]=[float(x) for x in body.split()]

n=len(rows["H"])
assert n==112
assert len(rows["Z"])==n and len(rows["DZ"])==n
assert len(rows["THETA"])==n and len(rows["QROT"])==n and len(rows["QDRA_SUM"])==n
assert len(rows["COF_RUNS"])==n
assert len(cofs)==8 and all(len(v)==42 for v in cofs.values())

def farr(vals):
    return ", &\n       ".join(f"{v:.17e}_real64" for v in vals)

def darr(vals):
    return ", &\n       ".join(f"{v:.17e}d0" for v in vals)

grid=f"""module MOD_grid
  implicit none
  integer, parameter :: numnod={n}
  real(8), parameter :: z(numnod)=[ &\n       {darr(rows['Z'])} ]
  real(8), parameter :: dz(numnod)=[ &\n       {darr(rows['DZ'])} ]
  real(8), parameter :: disnod(numnod+1)=[0.5d0*(dz(1)), &\n       {( ', &\n       '.join(f'0.5d0*({rows["DZ"][i-1]:.17e}d0+{rows["DZ"][i]:.17e}d0)' for i in range(1,n)) )}, &\n       0.5d0*dz(numnod)]
  real(8), parameter :: zbotcp(numnod)=z-0.5d0*dz
  real(8), parameter :: zbotcp0(numnod)=zbotcp
  real(8), parameter :: zbotcp_mtx(numnod)=zbotcp
end module MOD_grid

module MOD_swap_base
  implicit none
  integer :: swmacro=0, i_instance=1
end module MOD_swap_base

module variables
  use MOD_grid, only:numnod
  implicit none
  integer :: swbotb=2, swkimpl=0, swkmean=1, swbotb3impl=0
  logical :: fldaystart=.false., fldtmin=.false.
  real(8) :: runon=0d0,epd=0d0,reva=0d0,pondm1=0d0,dt=0d0,runots=0d0,t1900=0d0
  real(8) :: swbotb3resvert=0d0,deepgw=0d0,rimlay=0d0,sw4=0d0,hplate=0d0
  real(8) :: dtmin=1d-7,critdevh2cp=1d-2,critdevh1cp=1d-3,critdevponddt=1d-4
  real(8) :: CritDevBalCp=1d-6,CritDevBalTot=1d-5
  integer :: maxit=80,maxbacktr=8,nodgwl=numnod+1
  real(8) :: gwlm1=999d0,gwlinp=0d0,pond=0d0,dtold=0d0,qtop=0d0,qbot=0d0,hbot=0d0,gwl=999d0
  integer :: itnumb=0
  logical :: fllowgwl=.false.,fldecdt=.false.
  real(8) :: qbotab(2*numnod)=0d0
  real(8) :: h(numnod)=0d0,theta(numnod)=0d0,kmean(numnod+1)=0d0,k(numnod)=0d0,dimoca(numnod)=0d0
  real(8) :: thetm1(numnod)=0d0,qrot(numnod)=0d0,hm1(numnod)=0d0
end module variables

module MOD_top
  implicit none
  real(8) :: q0=0d0,hsurf=0d0
  logical :: flrunoff=.false.,ftoph=.false.
contains
  subroutine boundtop(mode); integer,intent(in)::mode; end subroutine
  subroutine pondrunoff(); end subroutine
end module MOD_top

module MOD_meteo
  implicit none
  real(8) :: nraidt=0d0
end module MOD_meteo

module MOD_rootextraction
contains
  subroutine RootExtraction(mode); integer,intent(in)::mode; end subroutine
end module MOD_rootextraction

module MOD_snow
  implicit none
  real(8) :: melt=0d0
end module MOD_snow

module MOD_frost
  use MOD_grid, only:numnod
  implicit none
  real(8) :: rfcp(numnod)=1d0
end module MOD_frost

module MOD_drain
  use MOD_grid, only:numnod
  implicit none
  integer, parameter :: nrlevs=1
  real(8) :: qdra(nrlevs,numnod)=0d0
end module MOD_drain

module MOD_irrigation
  use MOD_grid, only:numnod
  implicit none
  real(8) :: qssdi(numnod)=0d0,nird=0d0
end module MOD_irrigation

module MOD_swap_mp
  use MOD_grid, only:numnod
  implicit none
  real(8) :: armpss=0d0
  real(8) :: frarmtrx(numnod)=1d0,qexcmpmtx(numnod)=0d0,dfdhmp(numnod)=0d0
  integer :: ictopmp=numnod
  real(8) :: qmplatss=0d0
  integer :: idecmprat=0
  logical :: fldecmprat=.false.,fldecMPmbf=.false.
end module MOD_swap_mp
"""
(outdir/"a18_grid_stubs.f90").write_text(grid)

meta=rows["META"]
cofcols=[]
for node,idx in enumerate(rows["COF_RUNS"],1):
    cofcols.append(cofs[idx])
flat=[]
for node in range(n):
    flat.extend(cofcols[node])

fixture=f"""module ppa_wu05a18_snapshot
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  integer, parameter :: n={n}
  real(real64), parameter :: snapshot_dt={meta[0]:.17e}_real64
  real(real64), parameter :: snapshot_qtop={meta[1]:.17e}_real64
  real(real64), parameter :: snapshot_qbot={meta[2]:.17e}_real64
  real(real64), parameter :: snapshot_gwl={meta[3]:.17e}_real64
  integer, parameter :: snapshot_nodgwl={int(meta[4])}
  real(real64), parameter :: snapshot_pegwl={meta[5]:.17e}_real64
  integer, parameter :: snapshot_npegwl={int(meta[6])}
  real(real64), parameter :: snapshot_pegwl_bot={meta[7]:.17e}_real64
  integer, parameter :: snapshot_bpegwl={int(meta[8])}
  real(real64), parameter :: snapshot_h(n)=[ &\n       {farr(rows['H'])} ]
  real(real64), parameter :: snapshot_theta(n)=[ &\n       {farr(rows['THETA'])} ]
  real(real64), parameter :: snapshot_frarmtrx(n)=[ &\n       {farr(rows['FRARMTRX'])} ]
  real(real64), parameter :: snapshot_qrot(n)=[ &\n       {farr(rows['QROT'])} ]
  real(real64), parameter :: snapshot_qdra(n)=[ &\n       {farr(rows['QDRA_SUM'])} ]
  real(real64), parameter :: snapshot_cofgen(42,n)=reshape([ &\n       {farr(flat)} ],[42,n])
end module ppa_wu05a18_snapshot
"""
(outdir/"a18_snapshot_module.f90").write_text(fixture)
print(outdir)
