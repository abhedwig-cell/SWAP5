"""Source-exact MACROINIT producer and real existing production initialization."""
import argparse,base64,hashlib,io,json,re,subprocess,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--fc',required=True);p.add_argument('--input-build',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();events=[];inputs={};results={};descriptors=[]
S=ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006'
import gzip
for name in ['swap.swp','swap.bbc','swap.dra']:
 path=S/('b111-'+name+'.gz');(out/name).write_bytes(gzip.decompress(path.read_bytes()));inputs[str(path.relative_to(ROOT))]=sha(path.read_bytes())
def run(cmd,cwd,label,success=True):
 start=time.monotonic();cp=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=90)
 for k in ['stdout','stderr']:(out/(label+'.'+k)).write_bytes(getattr(cp,k))
 events.append(dict(label=label,command=list(map(str,cmd)),returncode=cp.returncode,expected_success=success,seconds=time.monotonic()-start));(out/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert(cp.returncode==0)==success,(label,cp.stdout.decode()[-2000:],cp.stderr.decode()[-3000:]);return cp
paths=['src/runtime/mod_macropore_continuation_state.f90',*['src/process/macropore/'+s for s in ['mod_ppa_wu05a5_top_partition.f90','mod_ppa_wu05a5_multi_domain_process.f90','mod_macropore_dynamic_shrinkage.f90','mod_macropore_standard_storage.f90','mod_ppa_wu05a6_sorptivity_rate.f90']],'app/solute_column/read_swp_macro_geometry.f90','app/solute_column/read_swp_macro_initial.f90','tests/nut-sol/test_native_macro_initial.f90']
for opt in ['O0','O2']:
 b=out/opt;run(['python','-B',ROOT/'tools/solute/build_macro_geometry_reader.py','--initial-state','--fc',a.fc,'--input-build',a.input_build,'--optimization',opt,'--output',b],out,opt+'-build');meta=json.loads((b/'build-complete.json').read_bytes());inputs.update(meta['input_sha256']);exe=b/'swap5_read_macro_initial';nml=out/(opt+'.nml')
 run([exe,out/'swap.swp',out/'swap.bbc',nml,out/'swap.dra'],out,opt+'-source');descriptors.append(nml.read_bytes());text=nml.read_text();v={k:[float(y)for y in x.split(',')if y.strip()]for k,x in re.findall(r'^ (\w+)=(.*)$',text,re.M)}
 assert v['nodes']==[112]and v['domains']==[5]and v['layers']==[8]and v['cutoff']==[57]
 assert v['groundwater']==[-80.9]and sum(v['domain_water'])>1.6 and max(v['sorptivity_max'])>15
 c=out/(opt+'-consumer');c.mkdir();ce=c/'consumer';flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(c),'-I'+str(c)]
 run([a.fc,*flags,*[ROOT/p for p in paths],'-o',ce],c,opt+'-consumer-link');cp=run([ce,nml],c,opt+'-consumer');results[opt]=dict(descriptor_sha256=sha(nml.read_bytes()),consumer_stdout_sha256=sha(cp.stdout),values=[float(x)for x in cp.stdout.decode().split('ORIGINAL_MACRO_INITIAL_VALUES=')[1].split()])
 original=(out/'swap.swp').read_bytes()
 for label,raw in [('frost',original.replace(b'SWFROST = 0',b'SWFROST = 1')),('macro-off',original.replace(b'SWMACRO = 1',b'SWMACRO = 0')),('solute-on',original.replace(b'SWSOLU = 0',b'SWSOLU = 1')),('empirical',re.sub(rb'(?m)^(\s*)1(\s+0\.33)',rb'\g<1>2\2',original)),('bad-shrink',re.sub(rb'(?m)^(\s*)1(\s+2\s+0\.385)',rb'\g<1>2\2',original))]:
  assert raw!=original,label;swp=out/(opt.lower()+'-'+label+'.swp');swp.write_bytes(raw);target=out/(opt+'-'+label+'.nml');run([exe,swp,out/'swap.bbc',target,out/'swap.dra'],out,opt+'-'+label,False);assert not target.exists();assert b'SWP_MACRO_GEOMETRY_REJECTED:'in(out/(opt+'-'+label+'.stdout')).read_bytes()
 old_source=subprocess.check_output(['git','show','9118712678cd305e9bbe96bc0a1ad8e6a51ada15:src/process/macropore/mod_macropore_standard_storage.f90'],cwd=ROOT)
 oldpath=out/(opt+'-predecessor-storage.f90');oldpath.write_bytes(old_source);counter=out/(opt+'-counter');counter.mkdir();cx=counter/'consumer'
 counter_sources=[oldpath if p=='src/process/macropore/mod_macropore_standard_storage.f90'else ROOT/p for p in paths]
 counter_flags=[f.replace(str(c),str(counter))for f in flags]
 run([a.fc,*counter_flags,*counter_sources,'-o',cx],counter,opt+'-predecessor-link')
 cp=run([cx,nml],counter,opt+'-predecessor',False);assert b'SWP_MACRO_INITIAL_REJECTED: canonical initial storage'in cp.stdout
 for label,key,value in [('open-drain',b'SWDTYP1 = 1',b'SWDTYP1 = 2'),('drain-model',b'DRAMET = 3',b'DRAMET = 1')]:
  raw=(out/'swap.dra').read_bytes();modified=raw.replace(key,value);assert raw!=modified
  path=out/(opt.lower()+'-'+label+'.dra');path.write_bytes(modified);target=out/(opt+'-'+label+'.nml')
  cp=run([exe,out/'swap.swp',out/'swap.bbc',target,path],out,opt+'-'+label,False)
  assert not target.exists()and b'SWP_MACRO_GEOMETRY_REJECTED:'in cp.stdout
 # Under SWSORP1 raw empirical coefficients are dummies. Alter every row,
 # leaving hydraulic coefficients and Parlange factors untouched.
 raw=re.sub(rb'(?m)^(\s*1\s+(?:0\.33|0\.5)\s+)\S+(\s+)\S+',rb'\g<1>99.0\g<2>4.0',original);assert raw!=original
 swp=out/(opt.lower()+'-dummy.swp');swp.write_bytes(raw);target=out/(opt+'-dummy.nml');run([exe,swp,out/'swap.bbc',target,out/'swap.dra'],out,opt+'-dummy');assert target.read_bytes()==nml.read_bytes()
 for label,raw in [('missing',re.sub(r'^ sorptivity_max=.*\n','',text,flags=re.M)),('negative',re.sub(r'(sorptivity_max=)\s*[-+\d.E]+',r'\g<1>-1.',text,count=1)),('stock',re.sub(r'(domain_water=)\s*[-+\d.E]+',r'\g<1>9.',text,count=1)),('cutoff',text.replace(' cutoff=57',' cutoff=113')),('dynamic',re.sub(r'(dynamic_volume=)\s*[-+\d.E]+',r'\g<1>9.',text,count=1))]:
  assert raw!=text;path=out/(opt+'-bad-'+label+'.nml');path.write_text(raw);run([ce,path],c,opt+'-bad-'+label,False)
assert descriptors[0]==descriptors[1]and results['O0']==results['O2']
for path in paths+['integration/mc-sol01/drainage/qualify_native_macro_initial.py']:inputs[path]=sha((ROOT/path).read_bytes())
r=dict(status='ORIGINAL_MACROINIT112_FIVE_DOMAIN_TYPED_O0_O2_PASS',source_input_unmodified=True,source_dummy_invariance=True,results=results,events=events,input_sha256=inputs,source_per_layer_hydraulics=8,source_initialization=True,full_water_dispatch=False,file_restart=False,qualified=False,canonically_admitted=False);(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
