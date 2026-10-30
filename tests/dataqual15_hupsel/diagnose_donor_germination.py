from pathlib import Path
import json,subprocess,hashlib,time,shutil
import argparse
ap=argparse.ArgumentParser(description='Read-only original donor germination diagnostic; original full physical project unchanged')
ap.add_argument('--provider-build',type=Path,required=True)
ap.add_argument('--project',type=Path,required=True)
ap.add_argument('--compiler',type=Path,required=True)
ap.add_argument('--output',type=Path,required=True)
a=ap.parse_args();build=a.provider_build.resolve();project=a.project.resolve();out=a.output.resolve();out.mkdir(exist_ok=True)
src=build/'providers/selected/MOD_cropdevelopment.f90'
s=src.read_text();start=s.index('   subroutine germination (task)');end=s.index('   end subroutine germination',start)
piece=s[start:end]
piece=piece.replace('      use atmosphere_interface,only: tav','      use variables, only: tcum, date\n      use atmosphere_interface,only: tav',1)
piece=piece.replace('      integer, intent(in) :: task','      integer, intent(in) :: task\n      integer :: diag_unit',1)
needle='         ! delay growth until tsumgerm is reached'
insert='''         ! Read-only historical diagnostic: no assignment to model state.
         open(newunit=diag_unit,file='germination_donor.csv',status='unknown',position='append')
         write(diag_unit,'(a,",",a,",",6(es26.17e3,","),3(l1,","))') &
              trim(date),trim(crpfilnam),tcum,h_avg,tsumemesub,tav,tsumgerm,tsumemeopt,fl_prep,fl_sow,fl_germ
         close(diag_unit)

'''
piece=piece.replace(needle,insert+needle,1)
s=s[:start]+piece+s[end:];mod=out/'MOD_cropdevelopment.f90';mod.write_text(s)
record=json.loads((build/'BUILD.json').read_text());compiler=str(a.compiler.resolve())
command=[compiler,'-O2','-finit-local-zero','-fallow-argument-mismatch','-ffree-line-length-none','-I',str(build/'providers/swobj'),'-I',str(build/'providers/ttobj'),'-J',str(out),'-c',str(mod),'-o',str(out/'MOD_cropdevelopment.o')]
commands=[command];t=time.monotonic();r=subprocess.run(command,capture_output=True,text=True);(out/'compile.stdout').write_text(r.stdout);(out/'compile.stderr').write_text(r.stderr);assert r.returncode==0,r.stderr
command=record['commands'][-1].copy();command[0]=compiler;command=[str(out/'MOD_cropdevelopment.o') if x.endswith('/swobj/MOD_cropdevelopment.o') else x for x in command];command[-1]=str(out/'swap431_germdiag');commands.append(command);r=subprocess.run(command,capture_output=True,text=True);(out/'link.stdout').write_text(r.stdout);(out/'link.stderr').write_text(r.stderr);assert r.returncode==0,r.stderr
for f in project.iterdir():
 if f.suffix in ['.swp','.crp','.met','.dra','.inp']:shutil.copy2(f,out/f.name)
(out/'germination_donor.csv').unlink(missing_ok=True)
r=subprocess.run([str(out/'swap431_germdiag')],cwd=out,capture_output=True,text=True,timeout=60);(out/'run.stdout').write_text(r.stdout);(out/'run.stderr').write_text(r.stderr)
manifest={'commands':commands,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'instrumented_source_sha256':hashlib.sha256(mod.read_bytes()).hexdigest(),'elapsed_seconds':time.monotonic()-t,'exit_code':r.returncode,'swap_ok':(out/'swap.ok').exists(),'model_state_assignments_added':False,'original1096':True,'reference_output_bytes_equal':{f.name:(out/f.name).read_bytes()==f.read_bytes() for f in project.glob('result*') if (out/f.name).is_file()},'reference_csv_numeric_lines_equal':(out/'result_output.csv').read_text().splitlines()[6:]==(project/'result_output.csv').read_text().splitlines()[6:]}
(out/'DIAGNOSTIC_BUILD.json').write_text(json.dumps(manifest,indent=2)+'\n')
assert manifest['exit_code']==100 and manifest['swap_ok']
assert manifest['reference_csv_numeric_lines_equal'], 'Diagnostic must preserve all original numeric output rows'
print(json.dumps({k:v for k,v in manifest.items() if k!='commands'},indent=2))
