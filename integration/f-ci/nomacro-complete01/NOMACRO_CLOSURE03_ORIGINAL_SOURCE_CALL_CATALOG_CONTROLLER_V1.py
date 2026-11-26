"""Catalog original reader/guard/call sites; source observation, no validity inference."""
from pathlib import Path
import io,zipfile,json,subprocess,hashlib,re
R=Path('C:/Users/Veldh012/swap5-nomacro-scheduled-chemical01');E=Path(__file__).resolve().parent;M='22520105f5a3ccac2bd2ae1b726f27b7b0d67b1e';P='reference/swap-4.3.1/source-archives/SWAP.ZIP';sha=lambda b:hashlib.sha256(b).hexdigest();raw=subprocess.check_output(['git','show',M+':'+P],cwd=R);assert sha(raw)=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
def uncomment(line):
 out=[];quote=None;i=0
 while i<len(line):
  c=line[i]
  if quote:
   out.append(c)
   if c==quote:
    if i+1<len(line) and line[i+1]==quote:out.append(line[i+1]);i+=1
    else:quote=None
  elif c in "'\"":quote=c;out.append(c)
  elif c=='!':break
  else:out.append(c)
  i+=1
 return ''.join(out)
def args(text,start):
 depth=1;quote=None;values=[];out=[];i=start
 while i<len(text):
  c=text[i]
  if quote:
   out.append(c)
   if c==quote:
    if i+1<len(text) and text[i+1]==quote:out.append(text[i+1]);i+=1
    else:quote=None
  elif c in "'\"":quote=c;out.append(c)
  elif c=='(':depth+=1;out.append(c)
  elif c==')':
   depth-=1
   if depth==0:values.append(''.join(out).strip());return values,i+1
   out.append(c)
  elif c==',' and depth==1:values.append(''.join(out).strip());out=[]
  else:out.append(c)
  i+=1
 raise AssertionError('Unterminated source call '+text[start-60:start+80])
readers=[];guards=[];edges=[];members={};definitions=[]
with zipfile.ZipFile(io.BytesIO(raw)) as z:
 for name in z.namelist():
  if not name.lower().endswith(('.f90','.f','.for')):continue
  value=z.read(name);lines=value.decode('cp1252').splitlines();joined=[];spans=[];pending='';first=0
  for number,line in enumerate(lines,1):
   code=uncomment(line).strip()
   if not code:continue
   if not pending:first=number
   continuation=code.endswith('&');pending+=' '+code.removeprefix('&').removesuffix('&')
   if not continuation:spans.append((len(''.join(joined)),first,number));joined.append(pending+'\n');pending=''
  assert not pending,(name,'Incomplete continuation')
  text=''.join(joined);members[name]=dict(bytes=len(value),sha256=sha(value));starts=[(m.start(),m.group(1).lower()) for m in re.finditer(r'(?mi)^\s*(?:(?:recursive|pure|elemental|real(?:\([^)]*\))?|integer|logical|character(?:\([^)]*\))?)\s+)*(?:subroutine|function)\s+([a-z][a-z0-9_]*)\s*\(',text)]
  definitions.extend(dict(unit=name,routine=called) for _,called in starts)
  def context(position):
   span=next(s for s in reversed(spans) if s[0]<=position);routine=next((r for p,r in reversed(starts) if p<=position),None)
   return dict(unit=name,source_raw_sha256=members[name]['sha256'],first_line=span[1],last_line=span[2],containing_routine=routine)
  calls=list(re.finditer(r'(?i)\bcall\s+([a-z][a-z0-9_]*)\s*\(',text))
  for match in calls:
   name_call=match.group(1).lower();values,end=args(text,match.end());item=dict(**context(match.start()),callee=name_call,arguments=values,original_logical_statement=text[match.start():end])
   edges.append(dict(**context(match.start()),callee=name_call))
   if name_call.startswith(('rds','rdf')):
    keyword=re.fullmatch(r"'([^']*)'|\"([^\"]*)\"",values[0]) if values else None
    item['input_keyword']=next(x for x in keyword.groups() if x is not None) if keyword else None;item['dynamic_first_argument']=not bool(keyword);readers.append(item)
   if name_call in ('swap_error','swap_warning'):
    item['kind']='FATAL_EXECUTION_GUARD' if name_call=='swap_error' else 'WARNING_ONLY_NOT_PROOF_OF_UNSUPPORTED_SCOPE';item['physical_source_context']=lines[max(0,item['first_line']-4):min(len(lines),item['last_line']+3)];guards.append(item)
  for match in re.finditer(r'(?i)\b(rdinqr|rdinar)\s*\(',text):
   values,end=args(text,match.end());readers.append(dict(**context(match.start()),callee=match.group(1).lower(),arguments=values,original_logical_statement=text[match.start():end],kind='INPUT_PRESENCE_OR_SHAPE_QUERY'))
q=dict(status='ORIGINAL_FORTRAN_READER_GUARD_AND_DIRECT_CALL_SITE_CATALOG_NOT_A_FULL_VALID_CONFIGURATION_PROOF',actual_canonical=M,original_source_path=P,original_archive_sha256=sha(raw),source_members=members,reader_sites=readers,guard_sites=guards,direct_call_edges=edges,original_routine_definitions=definitions,limitations=['Lexical catalog, not a Fortran semantic/control-flow proof','Direct callees are not automatically resolved across modules, interface dispatch or procedural arguments','Warning-only sites must not be classified as unsupported functions','Macro source is cataloged for explicit scope exclusion, not developed or counted as a migration gap','Dynamic reader keywords and valid table/noninteger/logical domains require source-dependency review'],global_historical_valid_configuration_inventory_complete=False,compiler_executions=0,model_executions=0)
with (E/'NOMACRO_CLOSURE03_ORIGINAL_SOURCE_CALL_CATALOG_V1.json').open('x') as f:json.dump(q,f,indent=2);f.write('\n')
print(q['status'],len(members),'source units',len(readers),'reader sites',len(guards),'guard sites',len(edges),'direct calls',flush=True)
