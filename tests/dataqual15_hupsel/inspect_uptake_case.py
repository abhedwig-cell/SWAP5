"""Additional same-input observations; keep the first failed paired producer sealed."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
def detailed_source(include_nodes=True):
 base=(ROOT/'tests/dataqual15_hupsel/paired_uptake.f90').read_bytes()
 assert sha(base)=='ad9b239d4638b7887e528860a7b17e057948dcc7e65494ae568932c140cd9605',sha(base)
 source=base.decode();anchor='  deallocate(tables,factors)';assert source.count(anchor)==1
 if include_nodes:
  source=source.replace(' use O2_pars,only:c_top',' use O2_pars,only:c_top,waterfilm_thickness')
  source=source.replace('use mod_bartholomeus_waterfilm_provider,only:BARTHOLOMEUS_WATERFILM_REFERENCE','use mod_bartholomeus_waterfilm_provider,only:BARTHOLOMEUS_WATERFILM_REFERENCE,evaluate_bartholomeus_waterfilm')
  source=source.replace(' character(4096)::filename',' real(real64)::original_film(34)\n real(real64),allocatable::current_film(:)\n character(4096)::filename')
  source=source.replace('   call OxygenStress(node,original_oxygen(node))','   call OxygenStress(node,original_oxygen(node))\n   original_film(node)=waterfilm_thickness')
 detail="""
  block
   real(real64)::legacy_factor(34),chain_sink(34),a,b,c,d
   logical::chain_check(3)
   legacy_factor=oxygen;legacy_factor(:rooted)=original_oxygen(:rooted)
   call RWU_micro(2,1,rooted,dz(:34),h(:34),lrv,legacy_factor*salinity,.false.,demand,b,chain_sink,a,c,d,chain_check)
   print '(a,i0,6(a,es25.17e3),a,i0)','CHAIN,',record,',',t0,',',t1, &
     ',',maxval(abs(original_oxygen(:rooted)-factors)),',',maxval(abs(factors-oxygen(:rooted))), &
     ',',sum(chain_sink(:rooted)),',',maxval(abs(chain_sink(:rooted)-observed(:rooted))),',',count(chain_check)
   do node=1,rooted
    print '(a,i0,a,i0,9(a,es25.17e3))','NODE,',record,',',node,',',h(node),',',theta(node),',',tsoil(node), &
     ',',original_oxygen(node),',',factors(node),',',oxygen(node),',',lrv(node), &
     ',',wroot_node_top(node),',',chain_sink(node)
   end do
  end block
"""
 if include_nodes:
  detail=detail.replace('   do node=1,rooted',"   call evaluate_bartholomeus_waterfilm(view,data,BARTHOLOMEUS_WATERFILM_REFERENCE,current_film,status)\n   if(status/=0)error stop 'film observation rejected'\n   do node=1,rooted")
  detail=detail.replace('9(a,es25.17e3)','11(a,es25.17e3)').replace('chain_sink(node)\n','chain_sink(node),\',\',original_film(node),\',\',current_film(node)\n')
  detail=detail.replace('   end do','   end do\n   deallocate(current_film)')
 else:
  start=detail.index('   do node=1,rooted');end=detail.index('   end do',start)+len('   end do');detail=detail[:start]+detail[end:]
 return source.replace(anchor,detail+anchor)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--components',type=Path,required=True);p.add_argument('--cases',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);old=a.components.resolve();m=json.loads((old/'RESULT.json').read_text());fc=a.compiler.resolve();assert subprocess.check_output([fc,'--version'],text=True).splitlines()[0]==m['compiler'];report=dict(status='IN_PROGRESS',events=[],source_base_sha256={},native_execution=True)
 for name,pin in m['source_sha256'].items():
  assert sha((ROOT/name).read_bytes())==pin,name
  report['source_base_sha256'][name]=pin
 source=out/'detailed.f90';source.write_text(detailed_source(),newline='\n');report.update(generated_sha256=sha(source.read_bytes()),input_sha256=sha(a.cases.read_bytes()))
 for opt in ['O0','O2']:
  folder=old/opt;exe=folder/'paired.exe';assert sha(exe.read_bytes())==m['paired'][opt]['binary_sha256'];target=out/('detailed-'+opt+'.exe')
  text=(folder/'link.args').read_text();before=str(ROOT/'tests/dataqual15_hupsel/paired_uptake.f90').replace('\\','/');assert text.count(before)==1
  text=text.replace(before,str(source).replace('\\','/'));before=str(exe).replace('\\','/');assert text.count(before)==1;text=text.replace(before,str(target).replace('\\','/'));args=out/(opt+'.args');args.write_text(text,newline='\n')
  for label,cmd in [('compile-'+opt,[fc,'@'+str(args)]),('native-'+opt,[target,a.cases.resolve()])]:
   start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=120);(out/(label+'.stdout')).write_bytes(r.stdout);(out/(label+'.stderr')).write_bytes(r.stderr);report['events'].append(dict(label=label,command=list(map(str,cmd)),seconds=time.monotonic()-start,returncode=r.returncode));assert r.returncode==0,(label,r.stderr.decode(errors='replace'),r.stdout.decode(errors='replace'))
 report['status']='DETAILED_REAL_OWNER_CASES_MEASURED';(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
if __name__=='__main__':main()
