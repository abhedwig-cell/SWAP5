"""Build isolated source-exact macropore input/geometry preparation, no water kernel."""
import argparse,hashlib,json,re,subprocess,time
from pathlib import Path
from legacy_reader_sources import materialize_macro_geometry
ROOT=Path(__file__).resolve().parents[2];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--fc',required=True);p.add_argument('--input-build',type=Path,required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();base=a.input_build.resolve();meta=json.loads((base/'build-complete.json').read_text());assert meta['status']=='BUILT'
for p,h in meta['generated_input_sha256'].items():assert sha(base/p)==h,p
original,identity=materialize_macro_geometry(ROOT,out);archive=base/'libttutil.a';original_utility=base/'legacy_swp_original.f90';text=original_utility.read_text();bodies=[]
for name in ['afgen_2','rdadortb']:
 m=re.search(r'^\s*subroutine '+name+r'\b.*?^\s*end subroutine '+name+r'\b',text,re.M|re.I|re.S);assert m,name;bodies.append(m.group())
utility=out/'original_water_utilities.f90';utility.write_text('\n'.join(bodies)+'\n');sources=[original,ROOT/'app/solute_column/read_swp_water.f90',utility,ROOT/'app/solute_crop/read_swp_macro_geometry.f90'];flags=['-'+a.optimization,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(out),'-I'+str(out)];exe=out/'swap5_read_macro_geometry';events=[]
def run(cmd,label):
 start=time.monotonic();cp=subprocess.run(cmd,cwd=out,capture_output=True)
 for name in ['stdout','stderr']:(out/(label+'.'+name)).write_bytes(getattr(cp,name))
 events.append(dict(command=cmd,returncode=cp.returncode,seconds=time.monotonic()-start));(out/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert cp.returncode==0,cp.stderr.decode()[-4000:]
objects=[]
for i,src in enumerate(sources):
 obj=out/(str(i)+'.o');selected=[x if x!='-std=f2008'else'-std=legacy'for x in flags]if src==utility else flags
 run([a.fc,*selected,'-c',str(src),'-o',str(obj)],'compile-'+str(i));objects.append(str(obj))
run([a.fc,*flags,*objects,str(archive),'-o',str(exe)],'link')
inputs={str(p.relative_to(ROOT)):sha(p)for p in [ROOT/'tools/solute/build_macro_geometry_reader.py',ROOT/'tools/solute/legacy_reader_sources.py',ROOT/'app/solute_crop/read_swp_macro_geometry.f90',ROOT/'app/solute_column/read_swp_water.f90',ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64']}
r=dict(status='BUILT',optimization=a.optimization,compiler_command=[a.fc],compiler=subprocess.check_output([a.fc,'--version'],text=True).splitlines()[0],flags=flags,events=events,input_sha256=inputs,original_source_identity=identity,generated_source_sha256=sha(original),original_utility_sha256=sha(utility),ttutil_archive_sha256=sha(archive),executable_sha256=sha(exe),independent_application_source_files=4,full_water_kernel_linked=False)
(out/'build-complete.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(dict(status='BUILT',source_files=4,seconds=events[0]['seconds'])))
