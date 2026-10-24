"""Original numeric heat source initialization and real importer on checked providers."""
import argparse,base64,gzip,hashlib,io,json,os,re,subprocess,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];p=argparse.ArgumentParser();p.add_argument('--build',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();build=a.build.resolve();out=a.output.resolve();out.mkdir();sha=lambda b:hashlib.sha256(b).hexdigest();events=[];inputs={}
b=json.loads((build/'build-complete.json').read_text());assert b['status']=='BUILT'
for path,h in b['input_sha256'].items():
 if path!='app/solute_column/main.f90':assert sha((ROOT/path).read_bytes())==h,path
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())))as t:
 raw=t.extractfile('SWAP/temperature.f90').read();source=raw.decode('latin1');s=source[source.index('         do lay = 1, numlay'):];s=s[:s.index('         end do')+len('         end do')]
 literal='module literal_texture_oracle\nimplicit none\ncontains\nsubroutine literal_texture(numlay,thetsl,psand,psilt,pclay,orgmat,fquartz,fclay,forg)\ninteger,intent(in)::numlay\nreal(8),intent(in)::thetsl(:),psand(:),psilt(:),pclay(:),orgmat(:)\nreal(8),intent(out)::fquartz(:),fclay(:),forg(:)\ninteger::lay\nreal(8)::dummy,gmineral\n'+s+'\nend subroutine\nend module\n'
(out/'literal.f90').write_text(literal);(out/'original-temperature.f90').write_bytes(raw)
flags=[x for x in b['flags']if not x.startswith('-J')];link=next(e['command']for e in b['events']if e['category']=='link');objects=[x for x in link if x.endswith('.o')][:-1];archives=[x for x in link if x.endswith('.a')];fc=b['compiler_command'];bindings={str(x):sha(Path(x).read_bytes())for x in objects+archives+[str(p)for p in build.glob('*.mod')]}
def run(cmd,label,expected=0):
 start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,input=b'',timeout=60);(out/(label+'.stdout')).write_bytes(r.stdout);(out/(label+'.stderr')).write_bytes(r.stderr);events.append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-start));(out/'events.json').write_text(json.dumps(events,indent=2));assert (r.returncode==0)==(expected==0),(label,r.stdout.decode()[-1000:],r.stderr.decode()[-2000:]);return r
exe=out/'driver';driver=ROOT/'tests/nut-sol/test_swp_heat_bootstrap.f90';r=run(fc+flags+['-J'+str(out),out/'literal.f90',driver,*objects,*archives,'-o',exe],'link')
original=gzip.decompress((ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-swap.swp.gz').read_bytes()).decode('latin1')
cases={'original':original,'nonuniform':original.replace('  TSOILTB =\n   -0.0 10.0\n -320.0 10.0','  TSOILTB =\n 0.0 5.0\n -100.0 15.0\n -320.0 3.0')}
assert cases['nonuniform']!=original
results={}
for name,text in cases.items():
 path=out/(name+'.swp');path.write_text(text);r=run([exe,path.name],name);assert b'NATIVE_HEAT_SOURCE_AND_NEGATIVE_CONTROLS_PASS'in r.stdout;results[name]=[l.decode()for l in r.stdout.splitlines()if l.startswith(b'NODE ')]
negatives={
 'disabled':original.replace('SWHEA = 1','SWHEA = 0'),
 'analytic':original.replace('SWCALT = 2','SWCALT = 1'),
 'external_top':original.replace('SWTOPBHEA = 1','SWTOPBHEA = 2'),
 'external_bottom':original.replace('SWBOTBHEA = 1','SWBOTBHEA = 2'),
 'organic_one':original.replace('0.194 0.529 0.277  0.021','0.194 0.529 0.277  1.000'),
 'solid_volume_invalid':original.replace('0.194 0.529 0.277  0.021','1.000 1.000 1.000  0.021'),
 'reverse_table':original.replace('   -0.0 10.0\n -320.0 10.0',' -320.0 10.0\n   -0.0 10.0'),
 'temperature_high':original.replace('   -0.0 10.0','   -0.0 51.0')}
for name,text in negatives.items():
 assert text!=original,name;path=out/(name+'.swp');path.write_text(text);run([exe,path.name],name,expected=1)
for mode in ['bad-width','bad-center','bad-porosity']:run([exe,'original.swp',mode],mode,expected=1)
for path,h in bindings.items():assert sha(Path(path).read_bytes())==h,path
for path in [str(driver.relative_to(ROOT)),str(Path(__file__).relative_to(ROOT)),'tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-swap.swp.gz','integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64']:inputs[path]=sha((ROOT/path).read_bytes())
inputs.update({p:h for p,h in b['input_sha256'].items()if p!='app/solute_column/main.f90'});result=dict(status='ORIGINAL_NATIVE_NUMERIC_HEAT_BOOTSTRAP_AND_NEGATIVES_PASS',results=results,negative_processes=len(negatives)+3,constructor_controls=14,original_temperature_sha256=sha(raw),literal_sha256=sha((out/'literal.f90').read_bytes()),events=events,input_sha256=inputs,provider_bindings=bindings,excluded_unlinked_program='app/solute_column/main.f90',qualified=False,canonically_admitted=False);(out/'RESULT.json').write_text(json.dumps(result,indent=2));print(json.dumps({'status':result['status'],'nodes':len(results['original']),'negative_processes':result['negative_processes']}))
