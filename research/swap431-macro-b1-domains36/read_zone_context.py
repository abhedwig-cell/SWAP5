from pathlib import Path
import re,math,struct,json,gzip
R=Path('research/swap431-macro-b1-domains36');s=(R/'macrorate_node.f90').read_text();sizes={'macp':5000,'madm':20}
compiled=gzip.decompress(Path('C:/Users/Veldh012/swap431-domains36-work/native/O2/obj/mod_arrays.mod').read_bytes()).decode()
for name,value in dict(macp=5000,madm=20,maho=25).items():
 match=re.search(r"'"+name+r"'.*?CONSTANT.*? 0 '(\d+)'",compiled,re.S);assert match and int(match[1])==value
def dims_size(txt):
 out=1
 for x in txt.lower().split(','):out*=sizes[x.strip()] if x.strip() in sizes else int(x.strip())
 return out
def section_length(src,entry):
 decl={}
 for raw in src.splitlines():
  line=raw.split('!')[0].strip().lower()
  if '::' not in line:continue
  before,after=line.split('::',1)
  b=8 if before.startswith('real(8)') else (4 if before.startswith(('integer','logical')) else None)
  if b is None:continue
  dm=re.search(r'dimension\(([^)]*)\)',before);n=dims_size(dm[1]) if dm else 1
  for part in re.split(r',\s*(?![^()]*\))',after):
   part=part.split('=')[0].strip();m=re.fullmatch(r'(\w+)(?:\(([^)]*)\))?',part)
   if m:decl[m[1]]=b*(dims_size(m[2]) if m[2] else n)
 code=src[src.index(entry):];code=code[:code.index('      else')]
 names=[]
 for line in code.splitlines():
  m=re.search(r'write\(snap23_unit\)\s*(.*)',line,re.I)
  if m:names.extend(v.strip().lower() for v in m[1].split(','))
 missing=set(names)-set(decl);assert not missing,missing
 return sum(decl[v] for v in names),names
rate=s[:s.index('end subroutine MacroRate')];sat=s[s.index('subroutine SATFLOW'):s.index('subroutine ABSORPTION')];ab=s[s.index('subroutine ABSORPTION'):]
lr,nr=section_length(rate,'entry sense23_rate_io');ls,ns=section_length(sat,'entry sense23_sat_io');la,na=section_length(ab,'entry sense23_abs_io');lg=3*4+4+200+19+19+10
print('suffix lengths',lr,ls,la,lg)
out=[]
for opt in ['O0','O2']:
 p=R/'data'/opt/'TRIAL_PROBE/probe35_base.bin';buf=p.read_bytes();end=len(buf)-lr-ls-la-lg
 bp,np,pe,pbot,gm1=struct.unpack_from('<ii3d',buf,end-68)
 conv,pond,dt,t,seq=struct.unpack_from('<4di',buf,end-36)
 assert t==35797.370324351359 and dt==.0006875745394909628 and seq==121
 assert bp==np==51 and pe==-66.56028506140325 and -320<pbot<0
 print(opt,'perched',np,bp,pe,pbot,'mainend',end,'clock',t,dt,seq)
 shr=struct.unpack_from('<25i',buf,5*4+25*4)
 assert shr[:8]==(1,)*8
 out.append(dict(optimization=opt,soil_shrinkage_options=list(shr),snapshot_main_body_bytes=end,perched_top_compartment=np,perched_bottom_compartment=bp,perched_GWL_cm=pe,perched_bottom_level_cm=pbot,previous_GWL_cm=gm1,clock=t,dt=dt,macro_sequence=seq))
(R/'NATIVE_ZONE_CONTEXT.json').write_text(json.dumps(dict(method='Offline read of retained SENSE23 snapshot footer; offsets derived from exact rate/sat/abs/GWL WRITE lists and compiled MaCp5000/MaDm20; clock/dt/sequence crosschecked',suffix_bytes=dict(rate=lr,sat=ls,abs=la,gwl=lg),contexts=out),indent=2)+'\n')
