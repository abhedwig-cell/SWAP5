"""Read the unchanged original interval schema, not a synthetic daily state."""
import hashlib,math,re,struct

WRITER_SHA='7406171723a1e8af82035a609a201d33f5cc8750be0a4dbce6c3980da81f3068'


def split_fields(value):
 depth=0;start=0;fields=[]
 for index,char in enumerate(value):
  if char in '([':depth+=1
  if char in ')]':depth-=1
  if char==',' and depth==0:fields.append(value[start:index]);start=index+1
 fields.append(value[start:]);assert depth==0;return fields


def decode(raw,source,nodes):
 writer=re.findall(r'allocate\(values\(nreal\)\);values=\[(.*)\]\n',source)
 assert len(writer)==1 and hashlib.sha256(writer[0].encode()).hexdigest()==WRITER_SHA
 candidates=[];prefix=struct.pack('<2i',1,nodes)
 for at in range(len(raw)-160):
  if raw[at:at+8]!=prefix:continue
  header=struct.unpack_from('<20i',raw,at);nreal=header[3]
  if 0<header[2]<100 and 100<nreal<100000 and at+160+16*nreal<=len(raw) and raw[at:at+80]==raw[at+80:at+160] and raw[at+160:at+160+8*nreal]==raw[at+160+8*nreal:at+160+16*nreal]:candidates.append((at,header))
 assert len(candidates)==1
 at,header=candidates[0];sizes=dict(numnod=nodes,nrlevs=header[2]);fields=[]
 for token in split_fields(writer[0]):
  if token.startswith('reshape('):
   name=re.match(r'reshape\((\w+)\(',token)[1];assert name in ('inqdra','inqdra_in','inqdra_out');size=nodes*header[2]
  elif '(' in token:
   match=re.fullmatch(r'(\w+)\(1:([^()]+)\)',token);assert match;name,expr=match.groups()
   assert expr in ('numnod','numnod+1','nrlevs','maout')
   size=None if expr=='maout' else eval(expr,{'__builtins__':{}},sizes)
  else:assert re.fullmatch(r'\w+',token);name=token;size=1
  fields.append((name,size))
 unknown=sum(size is None for name,size in fields);assert unknown==2
 remainder=header[3]-sum(size or 0 for name,size in fields);assert remainder>0 and remainder%unknown==0
 maout=remainder//unknown;values=struct.unpack_from('<'+str(header[3])+'d',raw,at+160);assert all(math.isfinite(v) for v in values)
 position=0;result={}
 for name,size in fields:
  count=size or maout;result[name]=values[position] if count==1 else values[position:position+count];position+=count
 assert position==header[3];return result,header


def terminal_terms(state,stock_end):
 names=['igrai',None,None,'igird','irunon','iqssdi','iqbup','iintc','iruno','iqrot','iepd','ievap',None,'iqdra',None,'iqbdo','ivolbeg','ipondbeg',None,'isicbeg',None,None]
 return [(state[name] if name else 0.)*(-1 if 7<=index<16 else 1) for index,name in enumerate(names)]+[-v for v in stock_end]
