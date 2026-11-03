"""Source-bound full-column contact experiment; original acceptance stays authoritative."""
import argparse,hashlib,json,os,subprocess,sys,tarfile,time,zlib,struct,shutil
from pathlib import Path
import qualify_nonlinear_native_contact as native
from research_native_build_cache import verified_objects
ROOT=native.ROOT

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--prior-build',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir(exist_ok=False);build=out/'build';build.mkdir()
 prior=a.prior_build.resolve();old=json.loads((prior/'RESULT.json').read_text(encoding='utf-8'))
 report=dict(baseline=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),optimization=a.optimization,events=[],scope='FULL_COLUMN_NONLINEAR_RESEARCH_NOT_COMMITTED',full_energy_balance_complete=False)
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 def run(cmd,cwd,label,env=None,check=True):
  start=time.monotonic();cp=subprocess.run(list(map(str,cmd)),cwd=cwd,env=env,capture_output=True,timeout=180)
  (out/(label+'.stdout')).write_bytes(cp.stdout);(out/(label+'.stderr')).write_bytes(cp.stderr)
  report['events'].append(dict(label=label,command=list(map(str,cmd)),returncode=cp.returncode,seconds=time.monotonic()-start));save()
  if check:assert cp.returncode==0,(label,cp.stderr.decode(errors='replace')[-3000:])
  return cp
 shadow=native.overlays(out/'overlay')
 head=shadow[native.HEAD];s=head.read_text(encoding='utf-8');s=s.replace((ROOT/(native.RESEARCH+'contact_headcalc_methods.inc')).read_text(encoding='utf-8'),(ROOT/(native.RESEARCH+'coupled_headcalc_methods.inc')).read_text(encoding='utf-8').replace('research_coupled_contact()','research_nonlinear_contact()'));head.write_text(s,encoding='utf-8')
 driver=shadow[native.DRIVER];s=driver.read_text(encoding='utf-8');s=s.replace('integer::heat_unit,heat_node','integer::heat_unit,heat_node,domain_id,transport_unit')
 marker="            close(heat_unit)"
 export="""            open(newunit=transport_unit,file='actual-transport.csv',status='unknown',position='append')
            do heat_node=1,numnod
              write(transport_unit,'(a,2(a,es25.17e3),a,i0,8(a,es25.17e3))')'MATRIX',',',s%t0,',',s%t1,',',heat_node, &
               ',',s%matrix_area_fraction(heat_node),',',s%top_flux,',',s%bottom_flux,',',s%net_node_source(heat_node), &
               ',',s%root_sink(heat_node),',',s%drainage_sink(heat_node),',',s%subsurface_source(heat_node),',',s%macropore_matrix_exchange(heat_node)
              do domain_id=1,size(s%macropore_water_start,1)
                write(transport_unit,'(a,2(a,es25.17e3),2(a,i0),6(a,es25.17e3))')'MACRO',',',s%t0,',',s%t1,',',domain_id,',',heat_node, &
                  ',',s%macropore_water_start(domain_id,heat_node),',',s%macropore_water_end(domain_id,heat_node), &
                  ',',s%macropore_vertical_face_rate(domain_id,heat_node),',',s%macropore_vertical_face_rate(domain_id,heat_node+1), &
                  ',',s%macropore_matrix_exchange_domain(domain_id,heat_node),',',s%macropore_external_outflow_rate(domain_id,heat_node)
              end do
            end do
            close(transport_unit)
"""
 assert s.count(marker)==1;s=s.replace(marker,marker+'\n'+export);driver.write_text(s,encoding='utf-8')
 original,tt=native.materialize(ROOT,build)
 old_order=[Path(e['command'][-3]) for e in old['events'] if e['label'].startswith('compile-') and e['label'][8:].isdigit()]
 assert len(old_order)==202
 ordered=[]
 for source in old_order:
  selected=None
  for key in shadow:
   if source.as_posix().endswith('/'+key):selected=shadow[key];break
  if selected is None:
   if source.name=='legacy_swp_original.f90':selected=original
   else:selected=source
  ordered.append(selected)
 compiler=subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0];report['compiler']=compiler
 # Existing helper verifies every original compile input, object and TTUTIL authority.
 old_shadow={key:prior/'overlay'/key for key in shadow}
 verified_objects(prior,ROOT,old_order,old_shadow,a.optimization,compiler)
 utilities=prior/'original'
 sources=[x.relative_to(ROOT).as_posix() for x in ordered if x.is_relative_to(ROOT)]
 sources += list(shadow)+['tests/dataqual15/qualify_coupled_contact.py',native.SELF,native.RESEARCH+'coupled_headcalc_methods.inc',native.RESEARCH+'contact_headcalc_methods.inc',native.RESEARCH+'contact_provider_methods.inc']
 assert not subprocess.check_output(['git','diff','HEAD','--',*sources]),'persist first'
 report['source_git_blob']={x:subprocess.check_output(['git','rev-parse','HEAD:'+x],text=True).strip() for x in set(sources)}
 report['rendered_sha256']={x:sha(y) for x,y in shadow.items()};report['generated_reader_sha256']=sha(original);save()
 flags=['-'+a.optimization,'-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build),'-I'+str(utilities/'ttobj')]
 objects=[]
 for i,source in enumerate(ordered):
  obj=build/(str(i)+'.o');run(['gfortran',*flags,'-c',source,'-o',obj],build,'compile-'+str(i));objects.append(obj)
 for name,source in [('publish','app/support/restart_publish.c'),('platform',native.RESEARCH+'native_contact_platform.c')]:
  obj=build/(name+'.o');run(['gcc','-O2','-c',ROOT/source,'-o',obj],build,'compile-'+name);objects.append(obj)
 exe=build/'native.exe';run(['gfortran','-fopenmp',*objects,utilities/'ttobj/libttutil.a','-o',exe],build,'link');report['executable_sha256']=sha(exe);save()
 def case(name):
  folder=out/name;folder.mkdir()
  with tarfile.open(ROOT/'integration/dataqual15/ANDELST_CONTACT_DIAGNOSTIC.tar.xz') as t:
   for n in ('input.nml','input.swp','input.bbc','input.dra','macro.nml','origin.bin'):(folder/n).write_bytes(t.extractfile('run/'+n).read())
  binding=hashlib.sha256((folder/'input.nml').read_bytes()+(folder/'input.swp').read_bytes()+(folder/'macro.nml').read_bytes()+report['executable_sha256'].encode()).hexdigest()
  raw=(folder/'origin.bin').read_bytes();assert zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0]
  raw=raw[:8]+binding.encode()+raw[72:-4];raw+=struct.pack('=I',zlib.crc32(raw));(folder/'origin.bin').write_bytes(raw)
  return folder,binding
 for enabled in (0,1):
  folder,binding=case('contact-'+str(enabled));cp=run([exe,'input.nml','origin.bin','5','input.swp','macro.nml',binding,'5.0','anchored-cauchy','0.0001','experimental','source-surface-demand','perched-jacobian','conservative-macro-storage'],folder,'contact-'+str(enabled),env=dict(os.environ,OMP_NUM_THREADS='1',SWAP5_RESEARCH_CONTACT=str(enabled)),check=False)
  assert cp.returncode!=0,'inspect unexpected full continuation'
 assert (out/'contact-0/origin.bin').read_bytes()==(out/'contact-0/diagnostic-rejected.bin').read_bytes()==(out/'contact-1/diagnostic-rejected.bin').read_bytes()
 report['contact_rows']=(out/'contact-1/coupled-contact.csv').read_text(encoding='utf-8').splitlines();report['native_rollback_exact']=True;save()
 folder,binding=case('actual-prefix');run([exe,'input.nml','-','1','input.swp','macro.nml',binding,'1.0','anchored-cauchy','0.0001','experimental','source-surface-demand','perched-jacobian','conservative-macro-storage'],folder,'actual-prefix',env=dict(os.environ,OMP_NUM_THREADS='1',SWAP5_RESEARCH_CONTACT='0'))
 report['status']='EXECUTED_FULL_COLUMN_CONTACT_AND_TRANSPORT_OBSERVATIONS';save();print(report['status']);print('\n'.join(x for x in report['contact_rows'] if x.startswith('COUPLED')))
if __name__=='__main__':main()
