"""Read-only diagnostic replay of an actual rejected historical water day."""
import argparse,hashlib,json,math,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--bundle',type=Path,required=True)
 ap.add_argument('--checkpoint-dir',type=Path,required=True);ap.add_argument('--day',type=int,required=True)
 ap.add_argument('--output',type=Path,required=True)
 ap.add_argument('--retain-water-proposal',action='store_true');ap.add_argument('--max-iterations',type=int)
 ap.add_argument('--temporal-components',action='store_true')
 ap.add_argument('--picard-conductivity',action='store_true')
 ap.add_argument('--production-picard',action='store_true')
 ap.add_argument('--trace-chemical',action='store_true')
 ap.add_argument('--historical-zero-solute-exfiltration',action='store_true')
 ap.add_argument('--temporal-tolerance',type=float)
 ap.add_argument('--expect',choices=['success','reject','diagnostic'],default='reject');a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 source=(ROOT/'app/solute_project/main.f90').read_text()
 if a.production_picard:
  assert not a.picard_conductivity and a.max_iterations is None
  source=source.replace('p%picard_conductivity_iteration=picard_conductivity_iteration', 'p%picard_conductivity_iteration=.true.;p%max_iterations=64')
 if a.retain_water_proposal:
  source=source.replace('numerical%retain_accepted_step_proposal=retain_accepted_step_proposal',
   'numerical%retain_accepted_step_proposal=.true.')
 if a.max_iterations is not None:
  assert a.max_iterations>=8
  source=source.replace('p%max_iterations=8','p%max_iterations='+str(a.max_iterations))
 anchor="      write(*,*)'joint status/water/chemical: ',result%status,result%water%status,result%chemical%status"
 assert source.count(anchor)==1
 source=source.replace(anchor,anchor+"""
      write(*,*)'water progress:',result%water%requested_t0,result%water%requested_t1,result%water%completed_t
      write(*,*)'accepted/attempts/retries:',result%diagnostics%accepted_substeps, &
        result%diagnostics%attempts,result%diagnostics%retries
      write(*,*)'solver/temporal/mass rejects:',result%diagnostics%solver_rejections, &
        result%diagnostics%temporal_rejections,result%diagnostics%mass_rejections
      write(*,*)'min/max accepted dt:',result%diagnostics%min_accepted_substep_duration, &
        result%diagnostics%max_accepted_substep_duration
      write(*,*)'max temporal/mass:',result%diagnostics%max_temporal_indicator, &
        result%diagnostics%max_abs_step_mass_residual
""")
 bundle=json.loads((a.bundle/'bundle.json').read_text())
 build=json.loads((Path(bundle['exe']).parent/'build-complete.json').read_text())
 assert all(sha((ROOT/p).read_bytes())==h for p,h in build['input_sha256'].items())
 identities=build['reused_artifact_sha256'];assert all(sha(Path(p).read_bytes())==h for p,h in identities.items())
 objects=[p for p in identities if p.endswith('.o')];archive=[p for p in identities if p.endswith('.a')];assert len(objects)==193
 (out/'driver.f90').write_text(source);exe=out/'diagnostic'
 events=[]
 def run(cmd):
  start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,input=b'',timeout=180);i=len(events)
  for stream in ['stdout','stderr']:(out/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
  events.append(dict(command=list(map(str,cmd)),seconds=time.perf_counter()-start,returncode=r.returncode));return r
 flags=[f for f in build['flags']if not f.startswith('-J')]+['-J'+str(out)]
 diagnostic_provider_sha256=None
 if a.temporal_components:
  provider_path='src/process/mod_pond_water_temporal_difference.f90'
  provider=(ROOT/provider_path).read_text()
  provider=provider.replace('contains', '''  integer,save::trace_count=0
  real(real64),save::trace_values(13,32)=0d0
  public::dump_temporal_components
contains''',1)
  anchor='    if(any(abs(hf)>1.e6_real64).or.any(abs(hh)>1.e6_real64))return'
  assert provider.count(anchor)==1
  provider=provider.replace(anchor,'''    trace_count=trace_count+1
    trace_values(:,1+mod(trace_count-1,32))=[maxval(abs(hf-hh)),abs(pf-ph),abs(gf-gh), &
      gf,gh,pf,ph,minval(hf),maxval(hf),minval(hh),maxval(hh),hf(1),hh(1)]
'''+anchor)
  provider=provider.replace('end module','''  subroutine dump_temporal_components()
    integer::i,k
    print *, 'TEMPORAL_COMPONENT_CALLS',trace_count
    print *, 'TEMPORAL_COMPONENT_COLUMNS head pond gwl gf gh pf ph hminf hmaxf hminh hmaxh hf1 hh1'
    do i=max(1,trace_count-31),trace_count
      k=1+mod(i-1,32)
      print *, 'TEMPORAL_COMPONENT',i,trace_values(:,k)
    end do
  end subroutine
end module''')
  (out/'temporal.f90').write_text(provider);diagnostic_provider_sha256=sha(provider.encode())
  source=source.replace('  implicit none','  use mod_pond_water_temporal_difference,only:dump_temporal_components\n  implicit none',1)
  source=source.replace("      write(*,*)'water progress:'","      call dump_temporal_components()\n      write(*,*)'water progress:'",1)
  (out/'driver.f90').write_text(source)
  old_object=[e['command'][-1]for e in build['source_build']['events']if e['category']=='compile'and e['command'][-3]==str(ROOT/provider_path)]
  assert len(old_object)==1
  objects=[p for p in objects if p!=old_object[0]];assert len(objects)==192
  flags=['-I'+str(out),*flags]
  assert run(build['compiler_command']+flags+['-c',out/'temporal.f90','-o',out/'temporal.o']).returncode==0
  objects+=[str(out/'temporal.o')]
 picard_provider_sha256=None
 chemical_provider_sha256=None
 historical_exfiltration_provider_sha256=None
 if a.historical_zero_solute_exfiltration:
  path='src/process/mod_b111_persistent_pond.f90';provider=(ROOT/path).read_text()
  needle='s%qtop>s%soil_evaporation_rate.or.s%qtop< -1d6'
  assert provider.count(needle)==1
  # Diagnostic only: historical solute.f90:347-355 sets cfluxt=0 for
  # qtop>=-1e-6. Keep that existing chemical operator, and permit upward
  # water in this copied carrier. No production guard or source is changed.
  provider=provider.replace(needle,'s%qtop>1d6.or.s%qtop< -1d6')
  historical_exfiltration_provider_sha256=sha(provider.encode());(out/'historical_exfiltration.f90').write_text(provider)
  old_object=[e['command'][-1]for e in build['source_build']['events']if e['category']=='compile'and e['command'][-3]==str(ROOT/path)]
  assert len(old_object)==1
  objects=[p for p in objects if p!=old_object[0]]
  assert run(build['compiler_command']+flags+['-c',out/'historical_exfiltration.f90','-o',out/'historical_exfiltration.o']).returncode==0
  objects+=[str(out/'historical_exfiltration.o')]
 if a.trace_chemical:
  path='src/runtime/mod_fmr_b111_pond_solute_route.f90';provider=(ROOT/path).read_text()
  lines=[]
  for i,line in enumerate(provider.splitlines(),1):
   if line.rstrip().endswith('return'):
    lines+=[line.rstrip()[:-6]+'then'," print *, 'CHEM_CARRIER_RETURN',"+str(i)]
    if 'pond_receipt%status' in line:
     lines+=[" print *, 'POND_RECEIPT',pond_receipt%status,k,dt,t%pond_start_cm,t%pond_end_cm,t%top_flux", 
      " print *, 'POND_EVAP',pond_step%pond_evaporation_rate,pond_step%soil_evaporation_rate,pond_step%rain_rate", 
      " print *, 'POND_BALANCE',pond_receipt%water_residual"]
    lines+=[' return',' end if']
   else:lines.append(line)
  provider='\n'.join(lines)+'\n';chemical_provider_sha256=sha(provider.encode())
  (out/'chemical.f90').write_text(provider)
  old_object=[e['command'][-1]for e in build['source_build']['events']if e['category']=='compile'and e['command'][-3]==str(ROOT/path)]
  assert len(old_object)==1
  objects=[p for p in objects if p!=old_object[0]]
  assert run(build['compiler_command']+flags+['-c',out/'chemical.f90','-o',out/'chemical.o']).returncode==0
  objects+=[str(out/'chemical.o')]
 if a.picard_conductivity:
  path='src/legacy/b1_10_port/headcalc.f90';provider=(ROOT/path).read_text()
  # Research only: keep the exact physical providers/root-source contract and
  # iterate conductivity with pressure (modified Picard), instead of freezing
  # it for the whole step. SwKimpl1's unbound legacy calls are never entered.
  needle='if (SwKimpl == 0 .and. swbotb /= 7 .and. swbotb /= -2) then'
  assert provider.count(needle)==1
  provider=provider.replace(needle,'if (.false.) then',1)
  needle='else if (SwKimpl == 0 .and. (swbotb == 7 .or. swbotb == -2) .and. &'
  assert provider.count(needle)==1
  provider=provider.replace(needle,'else if (.false. .and. &',1)
  anchor='!        update gradient in state%h'
  assert provider.count(anchor)==1
  provider=provider.replace(anchor,'''         if (SwKimpl == 0 .and. provider_constitutive_active) then
            state%k(1:numnod)=fsi_ws%provider_k(1:numnod)
            do i=1,numnod
               if (scale_matrix_area) state%k(i)=matrix_fraction(i)*state%k(i)
               if (i>1)state%kmean(i)=hcomean(swkmean,state%k(i-1),state%k(i),grid_dz(i-1),grid_dz(i), &
                    i,state%h(i-1),state%h(i))
            end do
            state%kmean(numnod+1)=state%k(numnod)
            do i=2,numnod
               fsi_ws%dfdh_upper(i)=-state%kmean(i)/grid_disnod(i)
               fsi_ws%dfdh_lower(i-1)=fsi_ws%dfdh_upper(i)
            end do
         end if
'''+anchor)
  (out/'picard.f90').write_text(provider);picard_provider_sha256=sha(provider.encode())
  old_object=[e['command'][-1]for e in build['source_build']['events']if e['category']=='compile'and e['command'][-3]==str(ROOT/path)]
  assert len(old_object)==1
  objects=[p for p in objects if p!=old_object[0]]
  assert run(build['compiler_command']+flags+['-c',out/'picard.f90','-o',out/'picard.o']).returncode==0
  objects+=[str(out/'picard.o')]
 assert run(build['compiler_command']+flags+[out/'driver.f90',*objects,*archive,'-o',exe]).returncode==0
 for src,dst in [('input.nml','input.nml'),('input.swp','input.swp'),('diagnostic-rejected.bin','before.bin')]:
  (out/dst).write_bytes((a.checkpoint_dir/src).read_bytes())
 if a.temporal_tolerance is not None:
  assert math.isfinite(a.temporal_tolerance)and a.temporal_tolerance>0
  text=(out/'input.nml').read_text()
  text,count=re.subn(r'(?m)^ temporal_tolerance=.*$',f' temporal_tolerance={a.temporal_tolerance:.17e}',text)
  assert count==1;(out/'input.nml').write_text(text)
 r=run([exe,'input.nml','before.bin',str(a.day),'input.swp'])
 rejection_kind=None
 if r.returncode!=0:
  if b'water progress:'in r.stdout:
   rejection_kind='JOINT_TRANSACTION'
   assert (out/'before.bin').read_bytes()==(out/'diagnostic-rejected.bin').read_bytes()
  else:
   assert a.expect=='diagnostic'and b'invalid temporal tolerance'in r.stdout
   rejection_kind='INPUT_DOMAIN'
   assert not(out/'diagnostic-rejected.bin').exists()
  assert not(out/'endpoint.csv').exists()
 else:
  import csv
  rows=[{k:float(v)for k,v in x.items()}for x in csv.DictReader((out/'budget.csv').open())]
  assert len(rows)==1
  assert abs(rows[0]['water_residual_cm'])<1e-10 and abs(rows[0]['solute_residual_mg_cm2'])<1e-10
 report=dict(status='ACTUAL_WATER_DAY_PASS'if r.returncode==0 else'ACTUAL_WATER_REJECTION_DIAGNOSTIC_REPLAY_OWNERS_EXACT',day=a.day,events=events,
  inputs={p:sha((ROOT/p).read_bytes())for p in ['app/solute_project/main.f90','tests/nut-sol/qualify_project_water_rejection.py']},
  build=build,driver_sha256=sha(source.encode()),before_sha256=sha((out/'before.bin').read_bytes()),
  retain_water_proposal=a.retain_water_proposal,max_iterations=a.max_iterations,expected=a.expect,
  diagnostic_provider_sha256=diagnostic_provider_sha256,picard_provider_sha256=picard_provider_sha256,
  production_picard=a.production_picard,chemical_provider_sha256=chemical_provider_sha256,
  temporal_tolerance=a.temporal_tolerance,rejection_kind=rejection_kind,
  historical_exfiltration_provider_sha256=historical_exfiltration_provider_sha256)
 (out/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(r.stdout.decode())
 if a.expect!='diagnostic':assert(r.returncode==0)==(a.expect=='success')
if __name__=='__main__':main()
