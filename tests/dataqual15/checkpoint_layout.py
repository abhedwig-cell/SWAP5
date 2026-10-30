"""Inspect the actual native Grassgrowth v3 stream; no model implementation."""
import struct,zlib

def layout(raw):
 assert raw[:8]==b'S5GRS003';assert zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0]
 pos=8
 for _ in range(6):
  n=struct.unpack_from('=i',raw,pos)[0];assert 0<n<=2097152;pos+=4+n
 header=pos;nodes,clock=struct.unpack_from('=id',raw,pos);assert nodes==113
 pos+=48+16*nodes
 physical=pos;pos+=24*nodes+32
 def crop(pos):
  start=pos;_,leaves=struct.unpack_from('=di',raw,pos);assert 1<=leaves<=4096
  return pos+164+24*leaves,dict(start=start,leaves=leaves)
 pos,actual=crop(pos);pos,potential=crop(pos);roots=pos;pos+=16;management=pos;pos+=28
 compat=[]
 for _ in range(2):
  flag=struct.unpack_from('=i',raw,pos)[0];assert flag in [0,1];compat.append(pos);pos+=4+8*flag
 assert pos==len(raw)-4,(pos,len(raw))
 return dict(header=header,nodes=nodes,clock=clock,physical=physical,actual=actual,potential=potential,roots=roots,management=management,compatibility=compat)

def payload(raw):
 return raw[layout(raw)['header']:-4]
