"""Actual existing native decoder negatives, including checksum-correct records."""
from pathlib import Path
import struct,zlib,hashlib

def execute(session,exe,fixture,phase,build,opt,name):
 tag='morning'if phase=='neutral'else'dayend'
 checkpoint=Path(str(exe)+'.'+tag+'.checkpoint');original=checkpoint.read_bytes()
 source=(fixture/'weather.999').read_bytes();first=original.index(source);second=original.index(source,first+len(source));payload=second+len(source)
 assert struct.unpack_from('<i',original,payload+40)[0]==6,'counter6 before actual week boundary'
 def fixed(raw):return raw[:-4]+struct.pack('<I',zlib.crc32(raw[:-4]))
 cases={}
 cases['bad_crc']=original[:-1]+bytes([original[-1]^1]);cases['truncated']=original[:-13]
 cases['wrong_tag']=fixed(b'S5WI0009'+original[8:])
 cases['trailing']=fixed(original[:-4]+b'x'+original[-4:])
 raw=bytearray(original);raw[first+20]^=1;cases['different_source']=fixed(bytes(raw))
 for label,offset,fmt,value in [
  ('irrigation_schema',4,'i',2),('future_day',8,'i',9999999),
  ('nan_clock',12,'d',float('nan')),('infinite_clock',12,'d',float('inf')),('wrong_clock',12,'d',999.),
  ('nan_delivery',20,'d',float('nan')),('negative_delivery',20,'d',-1.),
  ('week7',40,'i',7),('negative_week',40,'i',-1),('overflow_week',40,'i',2147483647),
  ('provider_fraction',120,'d',1.1),('nan_provider_fraction',120,'d',float('nan'))]:
  raw=bytearray(original);struct.pack_into('<'+fmt,raw,payload+offset,value);cases[label]=fixed(bytes(raw))
 if struct.unpack_from('<i',original,payload+80)[0]==0:
  # No frozen provider exists in the nontrigger case; inactive allocation
  # fields are not reclassified as committed authority by a decoder test.
  cases.pop('provider_fraction');cases.pop('nan_provider_fraction')
 rows=[]
 for label,raw in cases.items():
  target=build/f'{name}-{tag}-{label}.bad';target.write_bytes(raw)
  args=[str(exe),*[str(fixture/p)for p in ['weather.999','altered.999','bad.999','backup.999']],'native-reject',phase,str(target)]
  stdout,e=session.command(args,build,f'decoder-{name}-{tag}-{label}')
  assert b'TCS6_NATIVE_INVALID_NO_PARTIAL_PUBLICATION=PASS'in stdout,label
  rows.append(dict(opt=opt,driver=name,phase=phase,case=label,returncode=e['returncode'],stdout_sha256=hashlib.sha256(stdout).hexdigest(),input_sha256=hashlib.sha256(raw).hexdigest()))
 args=[str(exe),*[str(fixture/p)for p in ['weather.999','altered.999','bad.999','backup.999']],'native-reject-config',phase,str(checkpoint)]
 stdout,e=session.command(args,build,f'decoder-{name}-{tag}-different_config');assert b'TCS6_NATIVE_INVALID_NO_PARTIAL_PUBLICATION=PASS'in stdout
 rows.append(dict(opt=opt,driver=name,phase=phase,case='different_config',returncode=e['returncode'],stdout_sha256=hashlib.sha256(stdout).hexdigest(),input_sha256=hashlib.sha256(original).hexdigest()))
 return rows
