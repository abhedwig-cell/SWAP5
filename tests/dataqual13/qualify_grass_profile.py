"""Original Grassgrowth profile through the actual SWP/MvG production adapters."""
import hashlib,json,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];out=ROOT.parent/'dq13-grass-profile-source';out.mkdir(exist_ok=False)
ref=ROOT.parent/'dq13-reference431/providers';archive=ref/'ttobj/libttutil.a';functions=(ref/'selected/functions.f90').read_text();helpers=''
for name in ['rdadortb','afgen_2']:
 match=re.search(r'^\s*subroutine '+name+r'\b.*?^\s*end subroutine '+name+r'\b',functions,re.M|re.S|re.I);assert match;helpers+=match.group()+'\n'
match=re.search(r'^\s*real\(8\) function afgen\b.*?^\s*end function afgen\b',functions,re.M|re.S|re.I);assert match;helpers+=match.group()+'\n'
# Only the historical input helper's error reporting endpoint, no calculation.
helpers+='''subroutine swap_error(caller,message)
character(*)::caller,message
print *,caller,message
error stop 1
end subroutine
'''
(out/'original_input_helpers.f90').write_text(helpers)
sources=[ROOT/p for p in ['src/solver/mod_soil_water_accepted_step_direction_contract.f90','src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_b110_default_mvg_provider.f90','app/solute_column/read_swp_water.f90','tests/dataqual13/grass_profile_input_driver.f90']];events=[]
for opt in ['O0','O2']:
 f=out/opt;f.mkdir();cmd=['/usr/bin/x86_64-linux-gnu-gfortran-13','-'+opt,'-ffree-line-length-none','-fcheck=all','-I'+str(f),'-J'+str(f),*map(str,sources),str(out/'original_input_helpers.f90'),str(archive),'-o',str(f/'test')];t=time.perf_counter();r=subprocess.run(cmd,capture_output=True);(f/'compile.stderr').write_bytes(r.stderr);assert r.returncode==0,r.stderr.decode();swp=ROOT/'reference/swap-4.3.1/projects/2.grassgrowth/swap.swp';(f/'input.swp').write_bytes(swp.read_bytes());(f/'swap.bbc').write_bytes((swp.parent/'swap.bbc').read_bytes());r=subprocess.run([str(f/'test'),'input.swp','groundwater'],cwd=f,capture_output=True);(f/'stdout').write_bytes(r.stdout);(f/'stderr').write_bytes(r.stderr);print(opt,r.returncode,r.stdout.decode(),flush=True);assert r.returncode==0,r.stderr.decode()
 r=subprocess.run([str(f/'test'),'input.swp'],cwd=f,capture_output=True);(f/'default-reject.stdout').write_bytes(r.stdout);(f/'default-reject.stderr').write_bytes(r.stderr);assert r.returncode!=0
 events.append(dict(optimization=opt,seconds=time.perf_counter()-t,default_rejected=True))
(out/'RESULT.json').write_text(json.dumps(dict(status='ORIGINAL_GRASS_PROFILE_IMPORT_PASS_NOT_MODEL_RUN',events=events,source_sha256={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()for p in sources},original_swp_sha256=hashlib.sha256(swp.read_bytes()).hexdigest(),original_functions_normalized_sha256=hashlib.sha256(functions.encode()).hexdigest(),archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest()),indent=2))
