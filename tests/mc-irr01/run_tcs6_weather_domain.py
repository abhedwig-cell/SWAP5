"""O0/O2 original-domain preservation and source-unit correction witness."""
from pathlib import Path
import sys,importlib.util,json,time,hashlib,subprocess,argparse,base64,gzip,io,tarfile
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('feedback',ROOT/'tests/modularity/run_modular_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args();out=Path(a.output).resolve();session=m.Session(out);start=time.perf_counter()
seed='tests/fmig431/test_crop_file_weather_production.f90';original=(ROOT/seed).read_text();helpers=original[original.index('  subroutine make_bundle(bundle)'):original.index('  subroutine copy_input_file(')]
driver='tests/mc-irr01/test_tcs6_weather_domain.f90';generated=out/'driver.f90';generated.write_text((ROOT/driver).read_text().replace('! INSERT_EXISTING_HELPERS',helpers))
weather='tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-andelst_meteo.999.gz';fixture=out/'weather.999';fixture.write_bytes(gzip.decompress((ROOT/weather).read_bytes()))
authority='integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/authority).read_bytes())))as ar:meteo=ar.extractfile('SWAP/MOD_meteo.f90').read()
assert hashlib.sha256(meteo).hexdigest()=='99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f'
assert b'radmax = 5.d6'in meteo and b'arad = 1000.d0 * arad'in meteo
(out/'SOURCE_DOMAIN.txt').write_text('Authenticated MOD_meteo read bound radmax=5.d6 kJ/m2/day then arad=1000.d0*arad J/m2/day; current crop bound5.d6 is applied after conversion. The existing5e6J bound is corrected to the source5e9J bound; original-domain values must remain exact.\n')
sources,_=m.DEP.strict_closure(ROOT,[driver]);inputs={str(s.relative_to(ROOT)):m.sha(s)for s in sources}
for q in [seed,weather,authority,'tests/mc-irr01/run_tcs6_weather_domain.py']:inputs[q]=m.sha(ROOT/q)
old=out/'original_assimilation.f90';old.write_bytes(subprocess.check_output(['git','show','d27c6abe023eecd4f2e63ae42ad2fb330ad2ef15:src/crop/mod_wofost_prepare_assimilation.f90'],cwd=ROOT))
results=[];original_bits={}
for opt in (0,2):
 build=out/f'o{opt}';build.mkdir();objects=[]
 for i,source in enumerate([*sources[:-1],generated]):
  obj=build/f'{i}.o';session.command([session.compiler,*m.COMMON,f'-O{opt}','-J',str(build),'-I',str(build),'-c',str(source),'-o',str(obj)],build,'compile');objects.append(obj)
 for profile in ('original','corrected'):
  local=list(objects)
  if profile=='original':
   obj=build/'original-assim.o';session.command([session.compiler,*m.COMMON,f'-O{opt}','-J',str(build),'-I',str(build),'-c',str(old),'-o',str(obj)],build,'original-compile')
   index=[str(p.relative_to(ROOT))for p in sources].index('src/crop/mod_wofost_prepare_assimilation.f90');local[index]=obj
  exe=build/('reproducer-'+profile);session.command([session.compiler,*m.COMMON,f'-O{opt}',*map(str,local),'-o',str(exe)],build,'link')
  raw,e=session.command([str(exe),str(fixture),profile],build,'native');assert b'TCS6_SHARED_CROP_SOURCE_UNIT_DOMAIN=PASS'in raw
  bits=[line for line in raw.splitlines()if line.startswith(b'ORIGINAL_DOMAIN_BITS=')]
  original_bits[opt,profile]=bits
  results.append({'opt':opt,'profile':profile,'status':'PASS_SOURCE_DOMAIN_AND_PRESERVATION','returncode':e['returncode'],'stdout_sha256':hashlib.sha256(raw).hexdigest()})

assert all(v==original_bits[0,'original']for v in original_bits.values())and len(original_bits)==4
assert all(m.sha(ROOT/p)==h for p,h in inputs.items())
r={'status':'PASS_SOURCE_UNIT_DOMAIN_CORRECTION_AND_ORIGINAL_DOMAIN_EXACT','inputs':inputs,'results':results,'compiler':session.identity,'flags':m.COMMON,'events':session.events,'providers':len(sources)-1,'generated_sha256':m.sha(generated),'wall_seconds':time.perf_counter()-start};(out/'RESULTS.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
