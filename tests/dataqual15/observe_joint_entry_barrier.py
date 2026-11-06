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
body=Path(sources[index]).read_text();hook=HOOK
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
fc='C:/msys64/ucrt64/bin/gfortran.exe';flags=[f for f in meta['flags']if not f.startswith(('-I','-J'))]+['-I'+str(bundle),'-I'+str(out),'-J'+str(out)]
events=[]
def run(command,folder,timeout):
 start=time.monotonic();r=subprocess.run(list(map(str,command)),cwd=folder,capture_output=True,timeout=timeout,env=dict(os.environ,OMP_NUM_THREADS='1'))
 i=len(events);(out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr);events.append(dict(command=list(map(str,command)),returncode=r.returncode,seconds=time.monotonic()-start));return r
obj=out/'headcalc.o';r=run([fc,*flags,'-c',source,'-o',obj],out,300);assert r.returncode==0,r.stderr.decode()
objects[index]=str(obj);exe=out/'observe.exe';r=run([fc,'-fopenmp','-Wl,--stack,16777216',*objects,meta['publication_provider']['object'],meta['ttutil_archive'],'-o',exe],out,120);assert r.returncode==0,r.stderr.decode()
case=out/'case';case.mkdir();launch=json.loads((origin.parent/'LAUNCH.json').read_text());before=origin.read_bytes()
for n in launch['original_input_sha256']:shutil.copyfile(origin.parent/n,case/n)
command=launch['command'].copy();command[0]=str(exe);command[2]=str(origin)
r=run(command,case,120)
report=dict(scope='READ_ONLY_NEXT_BARRIER_STOP_NOT_RESTART_OR_TRAJECTORY_QUALIFICATION',events=events,origin_sha256=sha(origin),origin_unchanged=origin.read_bytes()==before,compiled_graph_source_sha256=meta['source_sha256'],observed_source_sha256=sha(source),executable_sha256=sha(exe),observation_stop=b'ORIGINAL_GATE_OBSERVATION_STOP'in r.stderr)
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');assert report['origin_unchanged']and report['observation_stop'],r.stderr[-2000:]
print((case/'original-gate.csv').read_text()[:600])
