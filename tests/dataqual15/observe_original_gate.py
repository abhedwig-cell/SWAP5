"""Locate the remaining sharp gate after original numerical input was restored.

Read-only failure observer, not a contact repair or restart qualification.
"""
import argparse,hashlib,json,os,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
HEAD='src/legacy/b1_10_port/headcalc.f90'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
HOOK='''
      if(provider_macropore_active.and.dt<=1d-8.and.state%numbit>=MaxIt)then
        block
          real(8)::oh(numnod),ot(numnod),okc(numnod),oc(numnod),odk(numnod),oq(numnod),qm(numnod),qp(numnod),entry
          real(8)::inc0(numnod),incm(numnod),incp(numnod),rm,rp,vertical
          integer::ou,onode
          logical::oactive
          open(newunit=ou,file='original-gate.csv',status='replace')
          write(ou,*)'ITERATION',dt,state%numbit,MaxIt,maxval(abs(fsi_ws%residual(:NN)))
          call evaluation_context%macropore%evaluate_rate(state%h,state%theta,oq,oactive)
          call evaluation_context%constitutive%evaluate_water_content_increment(state%h,state%hm1,state%theta,state%thetm1,inc0)
          select type(mp=>evaluation_context%macropore)
          type is(ppa_wu05a16_inner_macropore_provider_t)
            do onode=1,numnod
              entry=mp%rate_template%unsaturated%entry_head(onode)
              write(ou,*)'STATE',onode,state%hm1(onode),state%h(onode),entry,state%theta(onode),oq(onode),fsi_ws%residual(onode)
              write(ou,*)'SOURCE_CACHE',onode,provider_macropore_exchange(onode),oq(onode)
              if(abs(state%h(onode)-entry)>1d-2.and.abs(state%h(onode))>1d-2)cycle
              oh=state%h;oh(onode)=oh(onode)-1d-7
              if(abs(state%h(onode)-entry)<1d-2)oh(onode)=entry-1d-8-1d-10
              call evaluation_context%constitutive%evaluate(oh,ot,okc,oc,odk)
              call evaluation_context%constitutive%evaluate_water_content_increment(oh,state%hm1,ot,state%thetm1,incm)
              call evaluation_context%macropore%evaluate_rate(oh,ot,qm,oactive)
              if(.not.oactive)cycle
              rm=oh(onode)-state%h(onode)
              oh=state%h;oh(onode)=oh(onode)+1d-7
              if(abs(state%h(onode)-entry)<1d-2)oh(onode)=entry-1d-8+1d-10
              call evaluation_context%constitutive%evaluate(oh,ot,okc,oc,odk)
              call evaluation_context%constitutive%evaluate_water_content_increment(oh,state%hm1,ot,state%thetm1,incp)
              call evaluation_context%macropore%evaluate_rate(oh,ot,qp,oactive)
              if(.not.oactive)cycle
              write(ou,*)'GATE_BRACKET',onode,state%h(onode),entry,maxval(abs(qp-qm)),sum(qm),sum(qp),qm(onode),qp(onode)
              if(onode>1.and.onode<numnod)then
                vertical=state%kmean(onode)/grid_disnod(onode)+state%kmean(onode+1)/grid_disnod(onode+1)
                rp=fsi_ws%residual(onode)+(incp(onode)-inc0(onode))*matrix_fraction(onode)*grid_dz(onode)/dt+ &
                   oq(onode)-qp(onode)+vertical*(oh(onode)-state%h(onode))
                rm=fsi_ws%residual(onode)+(incm(onode)-inc0(onode))*matrix_fraction(onode)*grid_dz(onode)/dt+ &
                   oq(onode)-qm(onode)+vertical*rm
                write(ou,*)'FROZEN_NEIGHBOUR_RESIDUAL_BRACKET',onode,rm,rp,storage_rank
              end if
            end do
          end select
          close(ou)
          error stop 'ORIGINAL_GATE_OBSERVATION_STOP'
        end block
      end if
'''

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for n in ('bundle','origin','output'):p.add_argument('--'+n,type=Path,required=True)
 a=p.parse_args();bundle=a.bundle.resolve();origin=a.origin.resolve();origin_pin=sha(origin);out=a.output.resolve();out.mkdir()
 meta=json.loads((bundle/'BUILD.json').read_text());assert all(sha(Path(n))==h for n,h in meta['source_sha256'].items())
 assert all(sha(Path(n))==h for n,h in meta['object_sha256'].items())
 sources=list(meta['source_sha256']);objects=list(meta['object_sha256']);at=sources.index(str(ROOT/HEAD))
 body=(ROOT/HEAD).read_text();anchor='   use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t'
 assert body.count(anchor)==1;body=body.replace(anchor,anchor+'\n   use mod_ppa_wu05a16_inner_macropore_provider,only:ppa_wu05a16_inner_macropore_provider_t')
 anchor='!     in the rare case that TRIDAG fails, use alternative solution';assert body.count(anchor)==1;body=body.replace(anchor,HOOK+anchor)
 source=out/'headcalc_observed.f90';source.write_text(body,newline='\n')
 fc=meta['recovery']['failed_link_retained'];failed=Path(fc);old=json.loads((failed/'EVENTS.json').read_text())
 command=next(e['command']for e in old if e['label']=='compile'and e['command'][-3]==str(ROOT/HEAD));compiler=command[0]
 flags=[f for f in command[1:-4]if not f.startswith(('-I','-J'))]+['-I'+str(bundle),'-I'+str(out),'-J'+str(out)]
 events=[]
 def run(cmd,cwd,timeout=120):
  begin=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=timeout)
  i=len(events);(out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr)
  events.append(dict(command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-begin));return r
 obj=out/'headcalc.o';assert run([compiler,*flags,'-c',source,'-o',obj],out).returncode==0
 objects[at]=str(obj);exe=out/'observe.exe'
 assert run([compiler,'-fopenmp','-Wl,--stack,16777216',*objects,meta['publication_provider']['object'],meta['ttutil_archive'],'-o',exe],out).returncode==0
 case=out/'case';case.mkdir();launch=json.loads((origin.parent/'LAUNCH.json').read_text())
 for n in launch['original_input_sha256']:shutil.copyfile(origin.parent/n,case/n)
 command=launch['command'].copy();command[0]=str(exe);command[2]=str(origin)
 if len(command)==14:command.append('quiet-macro-stages')
 os.environ['OMP_NUM_THREADS']='1';r=run(command,case,180)
 report=dict(scope='READ_ONLY_FAILURE_OBSERVER_NO_RESTART_OR_EXECUTION_QUALIFICATION',events=events,
  baseline_build_sha256=sha(bundle/'BUILD.json'),origin_sha256=sha(origin),source_sha256=meta['source_sha256'],
  observed_source_sha256=sha(source),executable_sha256=sha(exe),state_stream_unchanged=sha(origin)==origin_pin,
  observation_stop=b'ORIGINAL_GATE_OBSERVATION_STOP'in r.stderr)
 assert report['state_stream_unchanged']and report['observation_stop']and(case/'original-gate.csv').exists(),r.stderr[-2000:]
 (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print((case/'original-gate.csv').read_text()[:1200])

if __name__=='__main__':main()
