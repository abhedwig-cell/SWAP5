"""Real S5HR0003 checkpoint decoder controls; never alters historical input.

The valid nonadvancing application control must reach the post-read 'no
requested windows remain' assertion. Mutations must reject before that point,
with no budget/checkpoint publication. This is decoder proof, not a model run
or restart suffix equivalence. Native stream offsets are same-platform ABI,
derived from the incumbent S5HR3/S5HG2/S5PT4 writers and checked against tags,
lengths, CRCs and decoded source state before any mutation.
"""
import argparse, hashlib, json, os, re, shutil, struct, subprocess, time, zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def crc(raw,start,end):return zlib.crc32(raw[start:end-4])==struct.unpack_from('=I',raw,end-4)[0]
def seal(raw,start,end):struct.pack_into('=I',raw,end-4,zlib.crc32(raw[start:end-4]))
def locations(raw):
 assert raw[:8]==b'S5HR0003' and crc(raw,0,len(raw))
 clock,nodes=struct.unpack_from('=di',raw,8);assert nodes==34 and clock==int(clock)
 off=20;inputs=[]
 for name in ['swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra']:
  n=struct.unpack_from('=i',raw,off)[0];assert 0<n<16777216;inputs.append((name,off+4,n));off+=4+n
 n=struct.unpack_from('=i',raw,off)[0];maize=off+4;maize_end=maize+n
 assert raw[maize:maize+8]==b'S5HG0002' and crc(raw,maize,maize_end)
 assert struct.unpack_from('=d',raw,maize+12)[0]==clock
 n=struct.unpack_from('=i',raw,maize+84)[0];physical=maize+88;physical_end=physical+n
 assert physical_end+4==maize_end and raw[physical:physical+8]==b'S5PT0004' and crc(raw,physical,physical_end)
 # fmr_template_t has 8 integer64 fields plus its integer backend identity.
 header=struct.unpack_from('=8siqii11qi2qdiiiqi',raw,physical)
 n,count=header[-4],header[-1];assert n==34 and 0<count<100000 and header[-6]==clock
 black=physical+168+8*count+3*8*n+16
 micro=black+8;rutter=black+20
 assert struct.unpack_from('=i',raw,micro)[0] in (0,1)
 assert struct.unpack_from('=i',raw,rutter)[0]==2
 assert struct.unpack_from('=d',raw,rutter+48)[0]==clock
 # Last crop is grass. Its fixed management extension precedes the 68-byte
 # irrigation continuation and outer CRC. No owner/biomass size is guessed.
 flag=len(raw)-120;management=flag+4;irrigation=len(raw)-72
 assert struct.unpack_from('=i',raw,flag)[0]==1
 state=struct.unpack_from('=7i2d',raw,management)
 assert state[0]>=1 and state[1]>=1 and min(state[2:7])>=0
 assert struct.unpack_from('=d',raw,irrigation+4)[0]==clock
 return dict(clock=clock,inputs=inputs,maize=maize,maize_end=maize_end,physical=physical,
             physical_end=physical_end,black=black,micro=micro,rutter=rutter,
             grass_flag=flag,grass=management,irrigation=irrigation,grass_state=state)
def main():
 p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--case',type=Path,required=True);p.add_argument('--checkpoint',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 bundle=a.bundle.resolve();base=a.case.resolve();out=a.output.resolve();out.mkdir();build=json.loads((bundle/'BUILD.json').read_text());exe=bundle/'swap5_hupsel_germination';assert sha(exe)==build['executable_sha256']
 # A live worktree may have advanced since this exact executable was built.
 # Verify all Git-owned provider bytes against its recorded commit instead.
 verified={}
 for source,digest in build['source_sha256'].items():
  path=Path(source);relative=None
  for segment in ['/src/','/app/','/tools/','/tests/']:
   if segment in source:relative=segment[1:]+source.split(segment,1)[1];break
  record=subprocess.run(['git','show',build['candidate']+':'+relative],cwd=ROOT,capture_output=True) if relative else None
  if record and record.returncode==0:assert hashlib.sha256(record.stdout).hexdigest()==digest,source;verified[source]='git:'+build['candidate']+':'+relative
  else:assert path.exists()and sha(path)==digest,source;verified[source]='unchanged external/generated provider'
 if not os.access(exe,os.X_OK):exe.chmod(exe.stat().st_mode|0o100)
 raw=a.checkpoint.resolve().read_bytes();loc=locations(raw);(out/'valid-original.bin').write_bytes(raw);shutil.copyfile(bundle/'BUILD.json',out/'BUILD.json')
 for name,off,n in loc['inputs']:assert (base/name).read_bytes()==raw[off:off+n],name
 nml=(base/'input.nml').read_text();ends=[float(v)for v in re.search('^ends_day=(.*)$',nml,re.M)[1].split(',')if v.strip()];stop=next(i+1 for i,v in enumerate(ends)if v==loc['clock'])
 changes={
  'outer_crc':('outer',20,'xor',1),'outer_schema':('outer',0,'8s',b'S5HR9999'),
  'outer_nodes':('outer',16,'i',35),'outer_clock_nan':('outer',8,'d',float('nan')),
  'outer_clock_fractional':('outer',8,'d',loc['clock']+.5),
  'bound_original_input':('outer',loc['inputs'][3][1],'xor',1),
  'grass_cut_zero':('outer',loc['grass'],'i',0),'grass_cut_exceeds_source_sequence':('outer',loc['grass'],'i',22),
  'grass_potential_cut_zero':('outer',loc['grass']+4,'i',0),'grass_potential_cut_exceeds_source_sequence':('outer',loc['grass']+4,'i',22),
  'grass_actual_cut_age_negative':('outer',loc['grass']+8,'i',-1),'grass_potential_cut_age_negative':('outer',loc['grass']+12,'i',-1),
  'grass_warm_days_negative':('outer',loc['grass']+16,'i',-1),'grass_delay_negative':('outer',loc['grass']+20,'i',-1),
  'grass_potential_delay_negative':('outer',loc['grass']+24,'i',-1),'grass_harvest_negative':('outer',loc['grass']+28,'d',-1.),
  'grass_harvest_nan':('outer',loc['grass']+28,'d',float('nan')),'grass_potential_harvest_negative':('outer',loc['grass']+36,'d',-1.),
  'grass_potential_harvest_nan':('outer',loc['grass']+36,'d',float('nan')),
  'micro_presence_mismatch':('physical',loc['micro'],'i',1-struct.unpack_from('=i',raw,loc['micro'])[0]),
  'micro_carry_negative':('physical',loc['micro']+4,'d',-.1),'micro_carry_above_one':('physical',loc['micro']+4,'d',1.1),
  'micro_carry_nan':('physical',loc['micro']+4,'d',float('nan')),
  'black_age_negative':('physical',loc['black'],'d',-1.),'black_age_nan':('physical',loc['black'],'d',float('nan')),
  'rutter_schema_unsupported':('physical',loc['rutter'],'i',99),'rutter_schema_zero_nonzero_progress':('physical',loc['rutter'],'i',0),
  'rutter_canopy_negative':('physical',loc['rutter']+4,'d',-1.),'rutter_canopy_nan':('physical',loc['rutter']+4,'d',float('nan')),
  'rutter_progress_clock_mismatch':('physical',loc['rutter']+48,'d',loc['clock']+1.),
  'rutter_progress_clock_nan':('physical',loc['rutter']+48,'d',float('nan')),
  'irrigation_clock_mismatch':('outer',loc['irrigation']+4,'d',loc['clock']+1.)}
 changes['grass_presence_payload_retained']=('outer',loc['grass_flag'],'i',0)
 events=[]
 for kind in ['valid_nonadvancing',*changes,'grass_management_silent_loss','truncated','extra_payload']:
  case=out/kind;case.mkdir()
  for name,_,_ in loc['inputs']:shutil.copyfile(base/name,case/name)
  shutil.copyfile(base/'input.nml',case/'input.nml');data=bytearray(raw)
  if kind in changes:
   level,off,fmt,value=changes[kind]
   if fmt=='xor':data[off]^=value
   else:struct.pack_into('='+fmt,data,off,value)
   if level=='physical':seal(data,loc['physical'],loc['physical_end']);seal(data,loc['maize'],loc['maize_end'])
  elif kind=='grass_management_silent_loss':
   struct.pack_into('=i',data,loc['grass_flag'],0);del data[loc['grass']:loc['grass']+44]
  elif kind=='truncated':data=data[:-11]
  elif kind=='extra_payload':data=data[:-4]+b'UNSUPPORTED'+data[-4:]
  if kind not in ['outer_crc','truncated']:seal(data,0,len(data))
  restart=case/'restart-input.bin';restart.write_bytes(data)
  cmd=[str(exe),'input.nml',str(restart),str(stop),'swap.swp','maize.crp'];t=time.monotonic();r=subprocess.run(cmd,cwd=case,capture_output=True,timeout=30)
  (case/'stdout').write_bytes(r.stdout);(case/'stderr').write_bytes(r.stderr)
  reached=b'no requested windows remain'in r.stdout+r.stderr
  decoder_rejected=any(marker in r.stdout for marker in [b'source rotation envelope rejected before publication',b'restart rejected'])
  passed=(r.returncode==1 and (reached if kind=='valid_nonadvancing' else decoder_rejected) and reached==(kind=='valid_nonadvancing') and not any((case/n).exists()for n in ['budget.csv','checkpoint.bin','restart.bin','crop.csv','germination.csv']))
  event=dict(case=kind,status='PASS'if passed else'FAIL',returncode=r.returncode,seconds=time.monotonic()-t,command=cmd,reached_post_read_boundary=reached,checkpoint_sha256=sha(restart),stdout=r.stdout.decode(errors='replace'),stderr=r.stderr.decode(errors='replace'))
  events.append(event);(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');print(kind,event['status'],flush=True)
  assert passed,kind
 result=dict(status='REAL_ROTATION_CODEC_CONTROLS_PASS_NOT_MODEL_OR_SUFFIX_EXECUTION',code_commit=build['candidate'],compiler=build['compiler'],executable_sha256=sha(exe),checkpoint_source=str(a.checkpoint.resolve()),checkpoint_sha256=hashlib.sha256(raw).hexdigest(),clock=loc['clock'],grass_management=loc['grass_state'],abi_locations=loc,provider_verification=verified,original_inputs_sha256={n:sha(base/n)for n,_,_ in loc['inputs']},events=events)
 (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 assert a.checkpoint.resolve().read_bytes()==raw or a.checkpoint.name=='checkpoint.bin','immutable input checkpoint changed'
if __name__=='__main__':main()
