"""Independent original/corrected Mualem values, derivatives and source audit."""
from decimal import Decimal,localcontext
import json,math
from pathlib import Path
from extended_evidence import digest
from extended_forensics import require

def audit(root):
 root=Path(root);q=json.loads((root/'RESULT.json').read_text());data={}
 for mode in ('original','corrected'):
  meta=q['modes'][mode];require(meta['returncode']==0 and not (root/(mode+'.stderr')).read_bytes(),'Actual original Mualem component failed')
  for name,key in [('MOD_MvG_functions.f90','source_sha256'),('probe.exe','executable_sha256')]:require(digest((root/(mode+'-'+name)).read_bytes())==meta[key],'Actual original Mualem source/executable changed')
  logs=json.loads((root/(mode+'-compile.json')).read_text());require(len(logs)==2 and all(v['returncode']==0 and '-'+q['optimization'] in v['command'] and '-ffp-contract=off' in v['command'] for v in logs),'Actual real Mualem compiler arithmetic differs')
  rows={}
  for line in (root/(mode+'.stdout')).read_text().splitlines():
   if not line.startswith('ACTUAL_ORIGINAL_SATURATION '):continue
   words=line.split();key=tuple(map(int,words[1:3]));require(key not in rows,'Duplicate actual original constitutive case');rows[key]=words[3:]
  require(set(rows)=={(s,i) for s in (1,2) for i in range(1,17)} and 'ACTUAL_ORIGINAL_SATURATION_COMPONENT_COMPLETE 32' in (root/(mode+'.stdout')).read_text(),'Actual original constitutive denominator or A/B/A completion changed');data[mode]=rows
 original=(root/'original-MOD_MvG_functions.f90').read_bytes().replace(b'\r\n',b'\n');current=(root/'corrected-MOD_MvG_functions.f90').read_bytes().replace(b'\r\n',b'\n')
 old=b'                  else if (relsat > (1.0d0-1.0d-6)) then';require(original.count(old)==1,'Actual original default analytic cutoff ambiguous')
 expected=original.replace(old,b'                  else if (relsat >= 1.0d0) then',1).replace(b'h_enpr(node)>h_crit.and.relsat>1d0-1d-6',b'h_enpr(node)>h_crit.and.relsat>=1d0',1)
 require(expected==current,'Actual correction changed other physical or numerical source')
 max_value=max_derivative=0.;unchanged=0
 for key,fields in data['corrected'].items():
  v=list(map(float,fields));h,t,se,k,der,plus,minus,ks,l,m=v;require(all(math.isfinite(x) for x in v) and 0<=k<=ks and der>=0,'Invalid actual corrected constitutive result')
  with localcontext() as ctx:
   ctx.prec=70;s=Decimal(fields[2]);a=Decimal(fields[8]);mm=Decimal(fields[9]);sat=Decimal(fields[7]);reference=sat*s**a*(1-(1-s**(1/mm))**mm)**2 if s<1 else sat
  error=abs(k-float(reference));max_value=max(max_value,error);require(error<=1e-8,'Actual corrected Mualem differs from independent70digit equation')
  if h!=0:
   fd=(plus-minus)/2e-6;error=abs(fd-der)/max(1.,abs(der));max_derivative=max(max_derivative,error);require(abs(fd-der)<=2e-8+2e-6*max(1.,abs(der)),'Actual corrected derivative differs from central difference away from physical boundary')
  if se<=1-1e-6 or se>=1:
   require(fields[:5]+fields[7:]==data['original'][key][:5]+data['original'][key][7:],'Actual unselected dry/saturated constitutive point result changed');unchanged+=1
 for soil in (1,2):require(all(float(data['corrected'][soil,i][3])<=float(data['corrected'][soil,i+1][3]) for i in range(1,16)),'Actual corrected K lost monotonicity')
 before=float(data['original'][2,9][3])-float(data['original'][2,7][3]);after=float(data['corrected'][2,9][3])-float(data['corrected'][2,7][3]);require(before>.5 and 0<after<.001,'Actual original discontinuity/corrected continuous neighbourhood not witnessed')
 return dict(status='INDEPENDENT_REAL_ORIGINAL_CUTOFF_DEFECT_AND_CORRECTED_MUALEM_COMPONENT_PASS',actual_cases=32,optimization=q['optimization'],independent_decimal_digits=70,maximum_K_equation_error_cm_day=max_value,maximum_derivative_relative_scaled_error=max_derivative,exact_unchanged_dry_and_saturated_cases=unchanged,actual_original_jump_cm_day=before,actual_corrected_neighbour_difference_cm_day=after,derivative_at_exact_saturation='ONE_SIDED_CONSTANT_BRANCH; central difference not selected across physical boundary',mass_guards_changed=False,full_model_qualified=False)

if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=audit(a.directory)
 with a.output.open('x') as stream:json.dump(q,stream,indent=2)
 print(q['status'],q['optimization'])
