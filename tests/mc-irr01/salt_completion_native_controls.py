"""Salt-specific CRC-correct invalid state/config cases in the existing codec."""
from pathlib import Path
import struct,zlib,hashlib
from availability_native_controls import execute as inherited

def execute(session,exe,fixture,phase,build,opt,name,sensor=False,interval_days=None,activation=False):
 rows=inherited(session,exe,fixture,phase,build,opt,name,sensor,interval_days,activation)
 checkpoint=Path(str(exe)+'.'+('morning'if phase=='neutral'else'dayend')+'.checkpoint');original=checkpoint.read_bytes()
 source=(fixture/'weather.999').read_bytes();a=original.index(source)+len(source);present,day,n=struct.unpack_from('<iii',original,a);payload=a+12+n
 soil=payload+240;n,history,thermal=struct.unpack_from('<iii',original,soil+36)
 assert n==4 and history==0 and thermal==1,(n,history,thermal)
 salt=soil+68+32*n+16+8*n
 masses=struct.unpack_from('<'+str(n)+'d',original,salt);assert all(x>=0 for x in masses)and sum(masses)>0
 sourceid,revision=struct.unpack_from('<qq',original,salt+8*n);assert sourceid==1 and revision>=0
 cases={}
 for label,offset,fmt,value in [('negative_salt',0,'d',-1.),('nan_salt',0,'d',float('nan')),('inf_salt',0,'d',float('inf')),('salt_source',8*n,'q',2),('salt_revision',8*n+8,'q',-2)]:
  raw=bytearray(original);struct.pack_into('<'+fmt,raw,salt+offset,value);raw=bytes(raw);raw=raw[:-4]+struct.pack('<I',zlib.crc32(raw[:-4]));cases[label]=raw
 for label,raw in cases.items():
  target=build/f'{name}-{phase}-{label}.bad';target.write_bytes(raw)
  stdout,e=session.command([str(exe),*[str(fixture/p)for p in ['weather.999','altered.999','bad.999','backup.999']],'native-reject',phase,str(target)],build,'decoder-'+name+'-'+label)
  assert b'TCS6_NATIVE_INVALID_NO_PARTIAL_PUBLICATION=PASS'in stdout
  rows.append(dict(opt=opt,driver=name,phase=phase,case=label,returncode=e['returncode'],stdout_sha256=hashlib.sha256(stdout).hexdigest(),input_sha256=hashlib.sha256(raw).hexdigest(),input=target.name))
 for label in ['salt-policy','salt-boundary','salt-threshold','salt-tscf']:
  stdout,e=session.command([str(exe),*[str(fixture/p)for p in ['weather.999','altered.999','bad.999','backup.999']],'native-reject-'+label,phase,str(checkpoint)],build,'decoder-'+name+'-'+label)
  assert b'TCS6_NATIVE_INVALID_NO_PARTIAL_PUBLICATION=PASS'in stdout
  rows.append(dict(opt=opt,driver=name,phase=phase,case=label,returncode=e['returncode'],stdout_sha256=hashlib.sha256(stdout).hexdigest(),input_sha256=hashlib.sha256(original).hexdigest(),input=checkpoint.name))
 assert len(rows)==31
 return rows
