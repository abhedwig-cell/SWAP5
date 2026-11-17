import pathlib,subprocess,json,hashlib,zipfile,sys
root=pathlib.Path.cwd();e=pathlib.Path('C:/Users/Veldh012/swap5-coverage-evidence');sha=lambda b:hashlib.sha256(b).hexdigest();reports={};configs=[];out=pathlib.Path('C:/Users/Veldh012/swap5-complete01-evidence/preservation');out.mkdir(parents=True,exist_ok=False)
for key in ('water-surface-combined','chemical-surface-combined','registered-grass','prescribed-head5'):
 prior=e/('N_preserve_'+key+'_build');meta=json.loads((prior/'BUILD.json').read_text());model='HYBRID_GRASSGROWTH_WATER' if key=='registered-grass' else None
 inputs=None if model else pathlib.Path(meta['project']['input_directory']) if 'input_directory' in meta.get('project',{}) else None
 if not inputs and not model:
  inputs=e/'M_preserved_L_head5_inputs' if key=='prescribed-head5' else next((e/'run43867490337').glob('*-'+key+'-*'))/('input-'+key)
 configs.append((key,prior,inputs,'O2' if model else 'O0',model))
for key in ('water-file-subsurface-interval','chemical-file-sprinkler'):
 configs.append((key,e/('N_'+key+'_O0_build'),e/('N_'+key+'_input'),'O0',None))
# Current local fixtures are byte-identical to immutable original mixture input deck.
for key in ('water-plate-history','chemical-plate-history'):
 configs.append((key,None,e/'O_water_local'/key,'O0',None))
for mode in ('water','chemical'):
 configs.append((mode+'-surface-history',e/('O_'+mode+'_local/O0-build'),e/'O_water_local'/(mode+'-surface-history'),'O0',None))
for key,prior,inputs,opt,model in configs:
 if inputs and not inputs.exists():
  # N short fixture names are owned by the existing six-case generator.
  sys.path.insert(0,str(root/'tools/solute'));from fixed_irrigation_cases import create
  inputs=out/(key+'_input')
  if not inputs.exists():create(inputs,key)
 bundle=out/(key+'_build')
 cmd=['python','-B','tools/solute/run_water.py','--model',model or 'HYBRID_NOMACRO_WATER','--reference-work',str(e/'J_windows_provider'),'--build-only','--kernel-opt',opt,'--output',str(bundle)]
 cmd+=['--no-macro-release'] if model else ['--experimental-project',str(inputs),'--donor-opt',opt]
 if not (bundle/'BUILD.json').exists():
  r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(out/(key+'.stdout')).write_text(r.stdout);(out/(key+'.stderr')).write_text(r.stderr);assert r.returncode==0,(key,r.stderr)
 a=json.loads((bundle/'BUILD.json').read_text());fields={}
 if prior:
  b=json.loads((prior/'BUILD.json').read_text());assert a['inputs']==b['inputs'];oldfiles={file:(prior/file).read_bytes() for file in b['identity']['donor_generated']}
 else:
  with zipfile.ZipFile(root/'integration/nomacro-mixtures01/RAW_PLATE.zip') as z:
   b=json.loads(z.read(key+'-O0-build/BUILD.json'));oldfiles={file:z.read(key+'-O0-build/'+file) for file in b['identity']['donor_generated']}
  assert a['inputs']==b['inputs'],key
 assert set(a['identity']['donor_generated'])==set(oldfiles),key
 for file,before in oldfiles.items():
  now=(bundle/file).read_bytes();assert sha(before)==b['identity']['donor_generated'][file] and sha(now)==a['identity']['donor_generated'][file]
  assert before.replace(b'\r\n',b'\n')==now.replace(b'\r\n',b'\n'),(key,file)
  fields[file]=dict(prior_actual_sha256=sha(before),current_actual_sha256=sha(now),normalized_LF_sha256=sha(now.replace(b'\r\n',b'\n')))
 kernel={}
 for file,digest in b['identity']['kernel_sources']:
  now=(root/file).read_bytes();old=subprocess.check_output(['git','show','8dcda0fb247ae7823d720817d6340114d5227728:'+file]);assert now.replace(b'\r\n',b'\n')==old
  assert digest in (sha(now),sha(old));kernel[file]=sha(now)
 for field in ('floating_point_profile','soil_table_policy','solute_step_policy','time_step_policy'):assert a['identity'].get(field)==b['identity'].get(field),(key,field)
 assert a['identity'].get('scheduled_pond_history')==b['identity'].get('scheduled_pond_history');assert a['identity'].get('frost_reference') is None
 reports[key]=dict(status='ACTUAL_PRIOR_GENERATED_SOURCES_INPUTS_POLICIES_EXACT',generated=fields,kernel_sources=kernel,inputs=a['inputs'],scope='Fresh actual generated sources; original immutable source/native capsules not rebound; distinct build identities retained')
 q=dict(status='SCHEDULED_SSDI_PRIOR_O_J_PLATE_N_M_L5_AND_NAMED_SOURCE_PRESERVATION_PASS',runtime_source=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),profiles=reports,science='NOT_QUALIFIED')
 (out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(key,'SOURCE_PRESERVATION_PASS',flush=True)
