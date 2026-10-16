"""Checksum-correct provider, state, configuration and source native rejection witnesses."""
from pathlib import Path
import struct,zlib,hashlib

def execute(session,exe,fixture,phase,build,opt,name,sensor=False,interval_days=None):
 checkpoint=Path(str(exe)+'.checkpoint')if sensor else Path(str(exe)+'.'+('morning'if phase=='neutral'else'dayend')+'.checkpoint')
 original=checkpoint.read_bytes();source=(fixture/'weather.999').read_bytes();first=original.index(source);next_record=first+len(source)
 present,day,n=struct.unpack_from('<iii',original,next_record);assert present in(0,1)and n in(0,len(source));payload=next_record+12+n
 counter=struct.unpack_from('<i',original,payload+40)[0]
 if interval_days is None:assert counter==366
 else:assert 0<=counter<=interval_days or counter==366
 def fixed(raw):return raw[:-4]+struct.pack('<I',zlib.crc32(raw[:-4]))
 cases={'bad_crc':original[:-1]+bytes([original[-1]^1]),'truncated':original[:-13],'wrong_tag':fixed(b'S5WI0009'+original[8:]),'trailing':fixed(original[:-4]+b'x'+original[-4:])}
 raw=bytearray(original);raw[first+20]^=1;cases['different_source']=fixed(bytes(raw))
 for label,offset,fmt,value in [
  ('irrigation_schema',4,'i',2),('future_day',8,'i',9999999),('nan_clock',12,'d',float('nan')),('infinite_clock',12,'d',float('inf')),('wrong_clock',12,'d',999.),('nan_delivery',20,'d',float('nan')),('negative_delivery',20,'d',-1.),('week7',40,'i',7 if interval_days is None else interval_days+1),('overflow_week',40,'i',2147483647),
  ('provider_source',88,'q',0),('provider_revision',96,'q',-1),('provider_window',112,'d',-1.),('provider_fraction',120,'d',1.1),('nan_provider_fraction',120,'d',float('nan'))]:
  raw=bytearray(original);struct.pack_into('<'+fmt,raw,payload+offset,value);cases[label]=fixed(bytes(raw))
 rows=[]
 for label,raw in cases.items():
  target=build/f'{name}-{phase}-{label}.bad';target.write_bytes(raw)
  stdout,e=session.command([str(exe),*[str(fixture/p)for p in ['weather.999','altered.999','bad.999','backup.999']],'native-reject',phase,str(target)],build,'decoder-'+name+'-'+label)
  assert (b'AVAIL_NATIVE_INVALID_ATOMIC=PASS'if sensor else b'TCS6_NATIVE_INVALID_NO_PARTIAL_PUBLICATION=PASS')in stdout
  rows.append(dict(opt=opt,driver=name,phase=phase,case=label,returncode=e['returncode'],stdout_sha256=hashlib.sha256(stdout).hexdigest(),input_sha256=hashlib.sha256(raw).hexdigest(),input=target.name))
 stdout,e=session.command([str(exe),*[str(fixture/p)for p in ['weather.999','altered.999','bad.999','backup.999']],'native-reject-config',phase,str(checkpoint)],build,'decoder-'+name+'-different-config')
 assert (b'AVAIL_NATIVE_INVALID_ATOMIC=PASS'if sensor else b'TCS6_NATIVE_INVALID_NO_PARTIAL_PUBLICATION=PASS')in stdout
 rows.append(dict(opt=opt,driver=name,phase=phase,case='different_config',returncode=e['returncode'],stdout_sha256=hashlib.sha256(stdout).hexdigest(),input_sha256=hashlib.sha256(original).hexdigest(),input=checkpoint.name))
 return rows
