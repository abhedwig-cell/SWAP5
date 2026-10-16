#!/usr/bin/env python3
"""Qualify only isolated DIVDRA Paragraph12 normalization, before production."""
import argparse,hashlib,importlib.util,json,math,shutil,struct,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('modular',ROOT/'tests/modularity/run_modular_tests.py');M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M)
DRIVER='tests/fmig431/test_swap431_dislayer_reference.f90'
REF='reference/swap-4.3.1/frost-corrections/'
SOURCE={'original03':REF+'FROST-DIVDRA-03/divdra.f90','corrected04':REF+'FROST-DIVDRA-04/divdra.f90'}
RECORD=struct.Struct('<10i78d')
def parse(raw):
 assert len(raw)%RECORD.size==0
 return list(RECORD.iter_unpack(raw))
def row(v,start,i):return [v[start+i+3*n]for n in range(8)]
def validate(original,corrected):
 assert len(original)==len(corrected)==25920
 affected=unchanged=zero=small=0;maximum=0.
 for a,b in zip(original,corrected):
  assert a[:10]==b[:10]and a[10:40]==b[10:40] # same q, top, base
  grid,lev,pattern,g,inf,mode,t,mag,*_=a[:10]
  dz=[.25,.75,1.5,.5,2.,.25,1.25,1.5]if grid==2 else[1.]*8
  bottoms=[-math.fsum(dz[:i+1])for i in range(8)]
  for i in range(lev):
   q=b[10+i];base=row(b,16,i);out=row(b,40,i);old=row(a,40,i)
   expected=base[:];retained=None;legacy_retained=None
   if mode and i!=1:
    top=b[13+i];node=next(n for n,z in enumerate(bottoms)if top>=z)
    expected[:node]=[0.]*node;expected[node]*=(top-bottoms[node])/dz[node]
    retained=math.fsum(expected)
    legacy_retained=expected[node]
    for value in base[node+1:]:legacy_retained+=value
    if retained:
     expected=[v/retained*q for v in expected];small+=abs(retained)<1e-8
    else:expected=[q if n==node else 0. for n in range(8)];zero+=1
   error=max(abs(x-y)for x,y in zip(out,expected));maximum=max(maximum,error)
   assert error<=1e-14 and abs(math.fsum(out)-q)<=1e-14,('corrected source',a[:10],i,out,expected)
   changed_domain=legacy_retained is not None and abs(legacy_retained)<1e-8
   if not changed_domain:assert old==out;unchanged+=1
   else:affected+=1
 assert affected and zero and small and unchanged
 return dict(cases=25920,affected_rows=affected,unchanged_rows=unchanged,zero_support=zero,small_nonzero_support=small,max_nodal_error=maximum)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);a=ap.parse_args()
 def plan(case,broad=False):return ['tests/frost/test_ppa_wu05b20_multilevel_globals.f90',SOURCE[case],DRIVER]
 M.plan=plan
 for case in SOURCE:M.CASES[case]={'driver':DRIVER,'marker':'DISLAYER_COMPLETE_SOURCE_NATIVE_MATRIX=PASS','flags':M.COMMON}
 s=M.Session(a.output);s.share_modules=False;results=[];payloads={}
 try:
  for case in SOURCE:
   for opt in(0,2):
    r=s.execute(case,opt);source=Path(s.events[-1]['command'][0]).parent/'partition.bin';dest=s.out/(case+'-O'+str(opt)+'.bin');shutil.copyfile(source,dest)
    raw=dest.read_bytes();r['binary_path']=dest.name;r['binary_sha256']=hashlib.sha256(raw).hexdigest();payloads[case,opt]=raw;results.append(r)
  start=time.perf_counter();science=[validate(parse(payloads['original03',o]),parse(payloads['corrected04',o]))for o in(0,2)]
  for case in SOURCE:assert payloads[case,0]==payloads[case,2],case+' O0/O2 raw node drift'
  assert science[0]==science[1]
  M.write(s.out/'result.json',{'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'results':results,'events':s.events,'science':science,'binary_validation_seconds':time.perf_counter()-start,'status':'REFERENCE_COMPONENT_QUALIFIED_NOT_ADMITTED','production_qualified':False})
  print(json.dumps(science[0]));print('DISLAYER_CORRECTED04_REFERENCE_BEFORE_PRODUCTION=PASS')
 finally:M.write(s.out/'events.json',s.events)
if __name__=='__main__':main()
