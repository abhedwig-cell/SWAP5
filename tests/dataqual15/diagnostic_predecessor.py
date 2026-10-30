"""Explicit diagnostic-only predecessor replay; never a restart qualification.

Replace only embedded application binding and CRC. All physical bytes and five
original inputs must remain identical. Final qualification must rerun day1 and
compare this replay with its same-build checkpoint.
"""
import argparse,hashlib,json,struct,zlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--checkpoint',type=Path,required=True);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();data=a.checkpoint.read_bytes();assert zlib.crc32(data[:-4])==struct.unpack('=I',data[-4:])[0]
pos=8
for name in ['input.swp','grass.crp','input.met','swap.bbc','swap.dra']:
 n=struct.unpack_from('=i',data,pos)[0];assert data[pos+4:pos+4+n]==(a.bundle/'original-interval'/name).read_bytes();pos+=4+n
n=struct.unpack_from('=i',data,pos)[0];binding=(a.bundle/'original-interval/application.binding').read_bytes();result=data[:pos]+struct.pack('=i',len(binding))+binding+data[pos+4+n:-4];result+=struct.pack('=I',zlib.crc32(result));a.output.write_bytes(result)
sha=lambda b:hashlib.sha256(b).hexdigest();a.output.with_suffix('.json').write_text(json.dumps(dict(scope='DIAGNOSTIC_ONLY_NOT_RESTART_QUALIFICATION',predecessor=str(a.checkpoint.resolve()),predecessor_sha256=sha(data),successor_sha256=sha(result),original_physical_payload_sha256=sha(data[pos+4+n:-4]),successor_binding_sha256=sha(binding),changed='Only source binding field length/bytes and trailing CRC',required_followup='Same-source full day1 rerun and physical checkpoint equality'),indent=2)+'\n')
