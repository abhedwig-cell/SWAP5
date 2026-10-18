from pathlib import Path
import re, subprocess, sys, json, hashlib
root=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parent
out=root/'gnu'; out.mkdir(exist_ok=True)
src=out/'source';src.mkdir(exist_ok=True)
files=[]
for d in [root/'ttutil/TTUTIL',root/'source/SWAP']:
 for p in sorted(d.iterdir()):
  if p.suffix.lower() not in ['.f90','.for']:continue
  s=p.read_text(errors='replace')
  s=re.sub(r'^!DEC\$ IF DEFINED \((\w+)\)',r'#ifdef \1',s,flags=re.M)
  s=re.sub(r'^!DEC\$ IF \(linux==0\)',r'#if linux==0',s,flags=re.M)
  s=re.sub(r'^!DEC\$ ELSE',r'#else',s,flags=re.M)
  s=re.sub(r'^!DEC\$ END IF',r'#endif',s,flags=re.M)
  q=src/p.name;q.write_text(s);files.append(q)
providers={}
texts={}
for p in files:
 s=subprocess.check_output(['gfortran','-cpp','-E','-Dlinux=1',str(p)],text=True)
 texts[p]=s
 for m in re.findall(r'^\s*module\s+(?!procedure\b)(\w+)',s,re.I|re.M):providers[m.lower()]=p
ordered=[];vis=set()
def add(p):
 if p in vis:return
 vis.add(p)
 for m in re.findall(r'^\s*use\s+(\w+)',texts[p],re.I|re.M):
  if m.lower() in providers and providers[m.lower()]!=p:add(providers[m.lower()])
 ordered.append(p)
for p in files:add(p)
objects=[]
for p in ordered:
 obj=out/(p.stem+'.o');objects.append(str(obj))
 if obj.exists() and obj.stat().st_mtime>p.stat().st_mtime:continue
 cmd=['gfortran','-cpp','-Dlinux=1','-O2','-fallow-argument-mismatch','-ffree-line-length-none','-ffixed-line-length-none','-I',str(root/'ttutil/TTUTIL'),'-I',str(src),'-J',str(out),'-I',str(out),'-c',str(p),'-o',str(obj)]
 subprocess.run(cmd,check=True)
 print('COMPILED',p.name,flush=True)
subprocess.run(['gfortran',*objects,'-o',str(out/'swap_gnu')],check=True)
print('GNU_LEGACY_BUILD_PASS',len(objects))
