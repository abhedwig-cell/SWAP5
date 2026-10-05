import hashlib,json,pathlib,subprocess,tempfile,os
root=pathlib.Path(__file__).resolve().parents[2]
correction=root/'reference/swap-4.3.1/frost-corrections/FROST-GEOMETRY-01'
original=root/'reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90'
base=root/'reference/swap-4.3.1/frost-corrections/FROST-DRAIN-01/frozencond.f90'
record={'work_unit':'PPA-WU05B7-REF','original_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),'runs':{}}
with tempfile.TemporaryDirectory(prefix='frost-geometry-reference-') as folder:
 folder=pathlib.Path(folder);patched=folder/'patched.f90'
 subprocess.run(['python3',str(correction/'apply.py'),str(base),str(patched)],check=True)
 assert patched.read_bytes()==(correction/'frozencond.f90').read_bytes()
 patched.write_bytes(patched.read_bytes().replace(b'module MOD_frost\r\n',b'module MOD_frost_guarded\r\n'))
 outputs=[]
 for opt in [0,2]:
  out=folder/f'o{opt}';out.mkdir();exe=out/'test'
  subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(out),'-I',str(out),str(root/'tests/frost/test_ppa_wu05b5_corrected_drain_globals.f90'),str(original),str(patched),str(root/'tests/frost/test_ppa_wu05b7_geometry_reference.f90'),'-o',str(exe)],check=True)
  runs={}
  for mode in ['valid','original_uniform','guarded_uniform','original_epsilon','guarded_epsilon','guarded_nan','guarded_grid','guarded_limits','guarded_distance','original_drain_index','guarded_drain_index','guarded_stale_geometry']:
   r=subprocess.run([str(exe),mode],capture_output=True,text=True)
   runs[mode]={'returncode':r.returncode,'stdout':r.stdout,'stderr':r.stderr}
   if mode=='valid':
    assert r.returncode==0 and 'IDENTITY_CASES=48' in r.stdout,(r.stdout,r.stderr)
   elif mode in ['original_uniform','original_drain_index']:assert r.returncode!=0
   elif mode=='original_epsilon':assert r.returncode==0 and float(r.stdout.split('=')[1])>1000.0
   elif mode=='guarded_drain_index':assert r.returncode!=0 and 'FROST_DRAIN_GEOMETRY_INVALID' in r.stderr
   elif mode=='guarded_stale_geometry':assert r.returncode!=0 and 'FROST_GEOMETRY_UNAVAILABLE' in r.stderr
   else:assert r.returncode==0 and 'GUARDED_INVALID_GEOMETRY_STATUS=PASS' in r.stdout
  outputs.append(runs['valid']['stdout']);record['runs'][f'O{opt}']=runs
  print(runs['valid']['stdout'],end='')
 assert outputs[0]==outputs[1]
 before=base.read_bytes();occupied=folder/'occupied';occupied.write_bytes(b'occupied')
 for src,dst in [(original,folder/'bad'),(base,base),(base,occupied)]:
  r=subprocess.run(['python3',str(correction/'apply.py'),str(src),str(dst)],capture_output=True)
  assert r.returncode!=0
 assert before==base.read_bytes() and occupied.read_bytes()==b'occupied'
 assert not (folder/'bad').exists()
record['status']='LOCAL_BOUNDED_REFERENCE_COMPONENT_PASS_NOT_ADMITTED'
record['O0_O2_valid_stdout']='IDENTICAL'
result=pathlib.Path(os.environ.get('B7_REF_RESULT',str(pathlib.Path(tempfile.gettempdir())/'ppa-wu05b7-reference-result.json')))
result.write_text(json.dumps(record,indent=2)+'\n')
print('FROST_GEOMETRY_01_ORIGINAL_DEFECTS_AND_FAIL_CLOSED_GUARDS=PASS')
print('FROST_GEOMETRY_01_EXACT_BASE_AND_OVERWRITE_GUARDS=PASS')
