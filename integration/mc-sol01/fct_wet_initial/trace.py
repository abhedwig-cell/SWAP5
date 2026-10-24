"""Private source-generated logging only, original native reference execution."""
import hashlib,json,os,re,stat,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
def main():
 scratch=ROOT.parent;old=scratch/'wet-reference-recovered-o2';out=scratch/os.environ.get('SWAP_TRACE_OUTPUT','wet-water-trace');out.mkdir(exist_ok=False);b=json.loads((old/'build.json').read_text())
 cmd=b['events'][-1]['command'];cmd=[x.replace(str(old),str(out)) for x in cmd]
 for p in old.iterdir():
  if p.is_file() and (p.suffix=='.f90' or p.name=='libttutil.a'):(out/p.name).write_bytes(p.read_bytes())
 changes={}
 for name,anchor,extra in [
 ('src/runtime/mod_canonical_interval_runtime.f90','      call accumulate_transaction(result, tx)',"      write(*,*)'TRACE_INTERVAL',cursor,transaction_t1,tx%status,tx%accepted_t1,tx%accepted_dt,tx%attempts,tx%temporal_error\n"),
 ('src/transaction/mod_transaction_reference.f90','    result%rollbacks = result%rollbacks + 1',"    write(*,*)'TRACE_RETRY',retry_index,attempt_dt,result%solver_rejections,result%temporal_rejections,result%temporal_error\n"),
 ('src/runtime/mod_fmr_serialized_reference_backend.f90','    if (solve_result%status /= SW_SOLVE_CONVERGED) return',"    select type(trace_state=>state)\n    class is(fmr_b110_physical_state_t)\n      write(*,*)'TRACE_WATER',t0,t1,trace_state%ponding_depth,minval(trace_state%pressure_head),maxval(trace_state%pressure_head),solve_result%status\n    end select\n")]:
  src=ROOT/name;text=src.read_text();assert text.count(anchor)==1;text=text.replace(anchor,extra+anchor);target=out/src.name;target.write_text(text);changes[name]=hashlib.sha256(target.read_bytes()).hexdigest();cmd=[str(target) if x==str(src) else x for x in cmd]
 src=ROOT/'src/legacy/b1_10_port/headcalc.f90';lines=src.read_text().splitlines(keepends=True);text=''
 for i,line in enumerate(lines,1):
  if re.search(r'(?i)state%fldecdt\s*=\s*\.true\.',line):text+=f"      write(*,*)'TRACE_HEADCALC_REDUCTION',{i}\n"
  text+=line
 anchor='!     in case of macropores\n      if (swmacro == 1) then\n         if (IcTopMp == 1) then';assert text.count(anchor)==1
 text=text.replace(anchor,"      write(*,*)'TRACE_CRITERIA',maxval(abs(fsi_ws%residual(1:NN))),CritDevBalCp, &\n       maxval(abs(state%h(1:NN)-fsi_ws%old_head(1:NN))),CritDevh1Cp,CritDevh2Cp,flnonconv,flnonconv3\n      write(*,*)'TRACE_TOTAL',sum1,CritDevBalTot,dt,sum1*dt\n"+anchor)
 if os.environ.get('SWAP_TRACE_CONSERVATIVE')=='1':
  anchor='         sum1 = sum(fsi_ws%residual(1:NN))';assert text.count(anchor)==1
  text=text.replace(anchor,anchor+'''
         if(provider_constitutive_active.and.swmacro==0.and.NN==numnod.and.swbotb/=1.and. &
           .not.provider_macropore_rate_active)then
           block
             real(16)::total_depth
             integer::total_node
             total_depth=0.0_16
             do total_node=1,NN
               total_depth=total_depth+real(fsi_ws%provider_water_content_increment(total_node),16)* &
                 real(matrix_fraction(total_node),16)*real(grid_dz(total_node),16)+real(dt,16)* &
                 (real(fsi_ws%sink(total_node),16)-real(fsi_ws%source(total_node),16)+real(root_sink_term(total_node),16))
             end do
             if(state%ftoph)then
               total_depth=total_depth-real(dt,16)*real(state%kmean(1),16)*real(fsi_ws%head_gradient(1),16)
             else
               total_depth=total_depth+real(dt,16)*real(state%qtop,16)
             end if
             total_depth=total_depth-real(dt,16)*real(state%qbot,16)
             sum1=real(total_depth/real(dt,16),8)
           end block
         end if''')
 target=out/'headcalc.f90';target.write_text(text);changes[str(src.relative_to(ROOT))]=hashlib.sha256(target.read_bytes()).hexdigest();cmd=[str(target) if x==str(src) else x for x in cmd]
 cmd=['-O0' if x=='-O2' else x for x in cmd];t=time.monotonic();cp=subprocess.run(cmd,cwd=out,capture_output=True,timeout=180)
 (out/'compile.stdout').write_bytes(cp.stdout);(out/'compile.stderr').write_bytes(cp.stderr);(out/'trace-build.json').write_text(json.dumps(dict(command=cmd,returncode=cp.returncode,seconds=time.monotonic()-t,generated_logging=changes,reader_optimization='O2 immutable archive reused for diagnostic only'),indent=2));assert cp.returncode==0,cp.stderr[-1000:]
 exe=out/'native_fct';exe.chmod(exe.stat().st_mode|stat.S_IXUSR);case=scratch/'wet-initial-diagnostic/o2-uniform-frozen';run=[str(exe),str(case/'input.nml'),'-','4',str(case/'project.swp')];t=time.monotonic();cp=subprocess.run(run,cwd=out,capture_output=True,timeout=180)
 (out/'stdout').write_bytes(cp.stdout);(out/'stderr').write_bytes(cp.stderr);(out/'event.json').write_text(json.dumps(dict(command=run,returncode=cp.returncode,seconds=time.monotonic()-t)));print(cp.stdout.decode())
if __name__=='__main__':main()
