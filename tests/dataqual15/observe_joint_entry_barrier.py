"""Read-only stop inside the exact graph implementation at its next unresolved barrier."""
import argparse,hashlib,json,os,shutil,subprocess,time
from pathlib import Path
from observe_original_gate import HOOK
ROOT=Path(__file__).resolve().parents[2];sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
p=argparse.ArgumentParser()
for n in ('bundle','origin','output'):p.add_argument('--'+n,type=Path,required=True)
a=p.parse_args();bundle=a.bundle.resolve();origin=a.origin.resolve();out=a.output.resolve();out.mkdir();meta=json.loads((bundle/'BUILD.json').read_text())
assert meta['contact_model']=='ANDELST_SHARP_ENTRY_GRAPH_V1'
assert all(sha(n)==h for n,h in meta['source_sha256'].items())and all(sha(n)==h for n,h in meta['object_sha256'].items())
sources=list(meta['source_sha256']);objects=list(meta['object_sha256']);index=next(i for i,n in enumerate(sources)if n.replace('\\','/').endswith('/src/legacy/b1_10_port/headcalc.f90'))
body=Path(sources[index]).read_text();hook=HOOK.replace('dt<=1d-8','obs_source_start>=2.7799d0')
body=body.replace('   use mod_reference_bordered_solver,only:reference_bordered_solve','   use mod_reference_bordered_solver,only:reference_bordered_solve\n   use mod_entry_observation_clock')
hook=hook.replace('entry\n','entry,plane,w\n')
needle="              write(ou,*)'SOURCE_CACHE',onode,provider_macropore_exchange(onode),oq(onode)"
hook=hook.replace(needle,needle+"""
              if(onode<numnod)then
                if(state%h(onode)<0d0.and.state%h(onode+1)>0d0)then
                  w=1d0-grid_dz(onode)/(2d0*grid_disnod(onode+1))
                  plane=-(1d0-w)*state%h(onode+1)/w
                  oh=state%h;oh(onode)=plane-1d-8
                  call evaluation_context%constitutive%evaluate(oh,ot,okc,oc,odk)
                  call evaluation_context%macropore%evaluate_rate(oh,ot,qm,oactive)
                  oh(onode)=plane+1d-8
                  call evaluation_context%constitutive%evaluate(oh,ot,okc,oc,odk)
                  call evaluation_context%macropore%evaluate_rate(oh,ot,qp,oactive)
                  write(ou,*)'TOPOLOGY_BRACKET',onode,state%h(onode),state%h(onode+1),plane, &
                    w*state%h(onode)+(1d0-w)*state%h(onode+1),maxval(abs(qp-qm)),qm(onode),qp(onode)
                end if
              end if
""")
anchor='!     in the rare case that TRIDAG fails, use alternative solution';assert body.count(anchor)==1
body=body.replace(anchor,hook+anchor);source=out/'headcalc_observed.f90';source.write_text(body,newline='\n')
fc='C:/msys64/ucrt64/bin/gfortran.exe';flags=[f for f in meta['flags']if not f.startswith(('-I','-J'))]+['-I'+str(out),'-I'+str(bundle),'-J'+str(out)]
events=[]
def run(command,folder,timeout):
 start=time.monotonic();censored=False
 try:r=subprocess.run(list(map(str,command)),cwd=folder,capture_output=True,timeout=timeout,env=dict(os.environ,OMP_NUM_THREADS='1'))
 except subprocess.TimeoutExpired as e:
  censored=True;r=subprocess.CompletedProcess(command,-999,e.stdout or b'',e.stderr or b'')
 i=len(events);(out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr);events.append(dict(command=list(map(str,command)),returncode=r.returncode,seconds=time.monotonic()-start,censored=censored));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');return r
clock=out/'clock.f90';clock.write_text('module mod_entry_observation_clock\nreal(8)::obs_source_start=0d0,obs_last_t0=0d0,obs_last_t1=0d0\ninteger::obs_samples=0\nend module\n')
r=run([fc,*flags,'-c',clock,'-o',out/'clock.o'],out,60);assert r.returncode==0,r.stderr.decode()
backend_index=next(i for i,n in enumerate(sources)if n.replace('\\','/').endswith('/src/runtime/mod_fmr_serialized_reference_backend.f90'))
backend=Path(sources[backend_index]).read_text();backend=backend.replace('  implicit none','  use mod_entry_observation_clock\n  implicit none',1)
start=backend.index('  subroutine fmr_serialized_advance(');pos=backend.index('    outcome = trial_outcome_t()',start)
backend=backend[:pos]+'    obs_last_t0=t0;obs_last_t1=t1\n'+backend[pos:]
start=backend.index('  real(real64) function fmr_macropore_physical_temporal_error(')
pos=backend.index('        ! ICpBtDm is discrete topology',start)
probe="""        if(obs_source_start>=2.7799d0)then
          block
            integer::ou,onode,odomain
            obs_samples=obs_samples+1
            open(newunit=ou,file='next-temporal.csv',status='unknown',position='append')
            write(ou,*)'ASSESSMENT',obs_samples,obs_source_start,obs_last_t0,obs_last_t1,self%temporal_tolerance_cm, &
              maxval(abs(full%pressure_head-half%pressure_head)),maxloc(abs(full%pressure_head-half%pressure_head)), &
              maxval(abs(full%macropore%water_domain_cp-half%macropore%water_domain_cp)), &
              maxval(abs(full%macropore%volume_domain_cp-half%macropore%volume_domain_cp))
            do odomain=1,full%macropore%num_domains
              write(ou,*)'TOPOLOGY',odomain,full%macropore%icp_bottom_domain(odomain),half%macropore%icp_bottom_domain(odomain)
              do onode=1,n
                write(ou,*)'STATE',odomain,onode,full%pressure_head(onode),half%pressure_head(onode), &
                 full%water_content(onode),half%water_content(onode), &
                 full%macropore%water_domain_cp(odomain,onode),half%macropore%water_domain_cp(odomain,onode), &
                 full%macropore%absorption_time(odomain,onode),half%macropore%absorption_time(odomain,onode)
              end do
            end do
            close(ou)
            if(obs_samples>=25)error stop 'NEXT_TEMPORAL_OBSERVATION_STOP'
          end block
        end if
"""
backend=backend[:pos]+probe+backend[pos:];backend_source=out/'backend_observed.f90';backend_source.write_text(backend,newline='\n')
r=run([fc,*flags,'-c',backend_source,'-o',out/'backend.o'],out,300);assert r.returncode==0,r.stderr.decode();objects[backend_index]=str(out/'backend.o')
main=Path(sources[-1]).read_text();main=main.replace('  implicit none','  use mod_entry_observation_clock\n  implicit none',1)
marker='      call backend%run_trial(column_id,template,p,water,forcing,numerical,cursor,endpoint,checkpoint, &'
assert main.count(marker)==1;main=main.replace(marker,'      obs_source_start=cursor\n'+marker)
main_source=out/'main_observed.f90';main_source.write_text(main,newline='\n')
r=run([fc,*flags,'-c',main_source,'-o',out/'main.o'],out,300);assert r.returncode==0,r.stderr.decode();objects[-1]=str(out/'main.o')
objects.insert(0,str(out/'clock.o'));index=index+1
obj=out/'headcalc.o';r=run([fc,*flags,'-c',source,'-o',obj],out,300);assert r.returncode==0,r.stderr.decode()
objects[index]=str(obj);exe=out/'observe.exe';r=run([fc,'-fopenmp','-Wl,--stack,16777216',*objects,meta['publication_provider']['object'],meta['ttutil_archive'],'-o',exe],out,120);assert r.returncode==0,r.stderr.decode()
case=out/'case';case.mkdir();launch=json.loads((origin.parent/'LAUNCH.json').read_text());before=origin.read_bytes()
for n in launch['original_input_sha256']:shutil.copyfile(origin.parent/n,case/n)
command=launch['command'].copy();command[0]=str(exe);command[2]=str(origin)
r=run(command,case,300)
report=dict(scope='READ_ONLY_NEXT_BARRIER_STOP_NOT_RESTART_OR_TRAJECTORY_QUALIFICATION',events=events,origin_sha256=sha(origin),origin_unchanged=origin.read_bytes()==before,compiled_graph_source_sha256=meta['source_sha256'],observed_source_sha256=sha(source),executable_sha256=sha(exe),observation_stop=b'ORIGINAL_GATE_OBSERVATION_STOP'in r.stderr or b'NEXT_TEMPORAL_OBSERVATION_STOP'in r.stderr)
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');assert report['origin_unchanged']and report['observation_stop'],r.stderr[-2000:]
observed=case/('original-gate.csv'if(case/'original-gate.csv').exists()else'next-temporal.csv');print(observed.read_text()[:700])
