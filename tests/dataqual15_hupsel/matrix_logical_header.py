"""Corrected typed native header controls using exact qualified matrix objects."""
import argparse,io,json,lzma,os,re,struct,subprocess,tarfile,zipfile,zlib
from pathlib import Path,PurePosixPath,PureWindowsPath
import matrix_logical_evidence as evidence
import matrix_logical_runtime as g
from native_n_crc_runtime import run

def projection(raw):
 source=raw.decode().replace('\r\n','\n')
 marker="  if(trim(mode)=='reject')then\n"
 entry="""  if(trim(mode)=='header-base'.or.trim(mode)=='header-temporal')then
    call observe_header()
    if(trim(mode)=='header-base') &
      cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p, &
         water,solute,status)
    if(status==JOINT_OK)then
      call require(water%ready().and.solute%ready(),'canonical header restored both owners')
      print '(A)','MATRIX_LOGICAL_NATIVE_READ=ACCEPTED'
    else
      call require(.not.water%ready().and..not.solute%ready(),'malformed header leaves both owners empty')
      print '(A)','MATRIX_LOGICAL_NATIVE_READ=REFUSED_EMPTY'
    end if
    stop
  end if
"""
 observer="""  subroutine observe_header()
    use iso_fortran_env,only:int8
    use mod_fmr_committed_restart,only:fmr_committed_restart_record_t,fmr_committed_restart_bundle_t
    type(fmr_committed_restart_record_t)::r
    type(fmr_committed_restart_bundle_t)::b
    character(8)::tag
    integer::u,io,stream_mode,n,bpos,mpos,npos,hpos
    integer(int8)::raw_logical(storage_size(.true.)/8)
    open(newunit=u,file=trim(restart_path),access='stream',form='unformatted',status='old',iostat=io)
    call require(io==0,'native header file opened')
    read(u,iostat=io)tag,b%schema_version,b%parameter_set_identity, &
         r%schema_version,r%kernel_schema_version,r%column_id,r%parameter_ref,r%forcing_handle, &
         r%template_identity,r%lineage_id,r%revision,r%committed_time
    call require(io==0.and.tag=='S5MJ0001','original typed S5MJ0001 header prefix')
    inquire(unit=u,pos=bpos)
    read(u)raw_logical
    inquire(unit=u,pos=mpos)
    read(u)stream_mode
    inquire(unit=u,pos=npos)
    read(u)n
    inquire(unit=u,pos=hpos)
    read(u)raw_logical
    close(u)
    call require(n==numnod,'native header node count')
    call require(stream_mode==merge(0,1,trim(mode)=='header-base'),'matching original native physical mode')
    print '(A,4(I0,1X))','MATRIX_LOGICAL_FIELD_OFFSETS=',bpos-1,mpos-1,npos-1,hpos-1
  end subroutine
"""
 assert source.count(marker)==1 and source.count('\ncontains\n')==1
 new=source.replace(marker,entry+marker).replace('\ncontains\n','\ncontains\n'+observer)
 assert new.replace(entry,'').replace(observer,'')==source
 return new.encode()

def source_files(stem):
 evidence.verify(stem);raw=stem.with_suffix('.tar.xz').read_bytes()
 with tarfile.open(fileobj=io.BytesIO(lzma.decompress(raw)),mode='r:')as t:files={p.name:t.extractfile(p).read()for p in t.getmembers()}
 return files,g.sha(raw)

def execute(stem,out,fc):
 os.environ['OMP_NUM_THREADS']='1';files,sha=source_files(stem);r=json.loads(files['RESULT.json']);opt=r['optimization'];platform='WINDOWS'if os.name=='nt'else'POSIX';assert r['platform']==platform
 assert subprocess.check_output([fc,'--version'],text=True).splitlines()[0]==r['compiler'];out.mkdir(parents=True);providers=out/'providers';events=[];rows=[];builds={}
 for name,raw in files.items():
  p=PurePosixPath(name);assert not p.is_absolute()and '..'not in p.parts
  if name.startswith('fixture/')or p.suffix in ('.o','.mod','.smod'):
   path=providers/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
 q=PureWindowsPath if os.name=='nt'else PurePosixPath
 for role in ('incumbent','candidate'):
  build=json.loads(files[role+'/BUILD.json']);root=q(build['bindings'][0]['object']).parent.parent;paths=[q(x['object']).relative_to(root).as_posix()for x in build['bindings']]+[role+'/publisher.o']
  work=out/role;work.mkdir();src=work/'header.f90';src.write_bytes(projection(files[role+'/'+build['drivers']['joint']['source']]))
  flags=[f for f in build['flags']if not f.startswith(('-I','-J'))]+['-I'+str(providers/role),'-I'+str(providers/'fixture'),'-I'+str(providers/'incumbent'),'-J'+str(work)]
  obj=work/'header.o';exe=work/('header.exe'if os.name=='nt'else'header-driver');run([fc,*flags,'-c',src,'-o',obj],out,events,role+'-compile')
  args=flags+(['-Wl,--stack,16777216']if os.name=='nt'else[])+[str(obj),*map(str,(providers/p for p in paths)),'-o',str(exe)];rsp=work/'header.args';rsp.write_text('\n'.join('"'+a.replace('\\','/')+'"'for a in args)+'\n');run([fc,'@'+str(rsp)],out,events,role+'-link')
  builds[role]=dict(objects={p:g.sha((providers/p).read_bytes())for p in paths},source_sha256=g.sha(src.read_bytes()),executable=exe.relative_to(out).as_posix(),executable_sha256=g.sha(exe.read_bytes()))
  for exponent in g.original.EXPONENTS:
   for kind,file in (('base','restart.bin.base'),('temporal','restart.bin')):
    name=role+'/n'+exponent+'/'+file;raw=files[name];assert raw[:8]==b'S5MJ0001'and zlib.crc32(raw[:-4])==struct.unpack('<I',raw[-4:])[0]
    path=out/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
    def observe(test,field,value):
     p=run([exe,'header-'+kind,test,'unused',exponent],out,events,role+'-header');m=re.search(rb'MATRIX_LOGICAL_FIELD_OFFSETS=([\d ]+)',p.stdout);assert m
     offsets=tuple(map(int,m.group(1).split()));assert offsets==(144,148,152,156),offsets
     accepted=b'MATRIX_LOGICAL_NATIVE_READ=ACCEPTED'in p.stdout;refused=b'MATRIX_LOGICAL_NATIVE_READ=REFUSED_EMPTY'in p.stdout;assert accepted!=refused
     rows.append(dict(role=role,exponent=exponent,kind=kind,canonical=name,input=test.relative_to(out).as_posix(),field=field,value=value,offsets=offsets,accepted=accepted,event=len(events)-1))
     return accepted,offsets
    accepted,offsets=observe(path,'canonical',None);assert accepted
    for field,offset in zip(('time_bound','has_history'),(offsets[0],offsets[3])):
     assert struct.unpack_from('<i',raw,offset)[0]in(0,1)
     for value in (2,-1,256):
      modified=bytearray(raw[:-4]);struct.pack_into('<i',modified,offset,value);modified+=struct.pack('<I',zlib.crc32(modified));bad=path.with_name(path.name+'-'+field+'-'+str(value));bad.write_bytes(modified)
      accepted,_=observe(bad,field,value)
      if role=='candidate':assert not accepted
 report=dict(status='CORRECTED_TYPED_MATRIX_HEADER_CONTROLS_PASS',platform=platform,optimization=opt,archive_sha256=sha,original_producer=r['head'],rows=rows,builds=builds,production_admission=False,qualified_tags=['S5MJ0001']);(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');return report

def audit(native,files,archive_sha):
 r=json.loads(files['RESULT.json']);assert r['archive_sha256']==archive_sha and r['production_admission']is False and r['qualified_tags']==['S5MJ0001'];old=json.loads(native['RESULT.json']);assert (r['platform'],r['optimization'],r['original_producer'])==(old['platform'],old['optimization'],old['head'])
 events=json.loads(files['EVENTS.json']);assert len(events)==172 and all(e['returncode']==0 for e in events);seen=set();counts={}
 for role in ('incumbent','candidate'):
  b=json.loads(native[role+'/BUILD.json']);m=r['builds'][role];assert g.sha(files[m['executable']])==m['executable_sha256'];source=files[role+'/header.f90'];assert source==projection(native[role+'/'+b['drivers']['joint']['source']])and g.sha(source)==m['source_sha256'];assert len(m['objects'])==284 and all(g.sha(native[p])==h for p,h in m['objects'].items());counts[role]=dict(canonical=0,accepted_malformed=0,refused_malformed=0)
 q=PureWindowsPath if r['platform']=='WINDOWS'else PurePosixPath
 for role in ('incumbent','candidate'):
  build=json.loads(native[role+'/BUILD.json']);oldroot=q(build['bindings'][0]['object']).parent.parent
  paths=[q(x['object']).relative_to(oldroot).as_posix()for x in build['bindings']]+[role+'/publisher.o'];assert list(r['builds'][role]['objects'])==paths
  compile_event=next(e for e in events if e['label']==role+'-compile');link_event=next(e for e in events if e['label']==role+'-link')
  fc=compile_event['command'][0];root=q(compile_event['command'][-1]).parent.parent;work=root/role;providers=root/'providers';obj=work/'header.o'
  flags=[f for f in build['flags']if not f.startswith(('-I','-J'))]+['-I'+str(providers/role),'-I'+str(providers/'fixture'),'-I'+str(providers/'incumbent'),'-J'+str(work)]
  assert compile_event['command']==[fc,*flags,'-c',str(work/'header.f90'),'-o',str(obj)]
  args=flags+(['-Wl,--stack,16777216']if r['platform']=='WINDOWS'else[])+[str(obj),*map(str,(providers/p for p in paths)),'-o',str(root/r['builds'][role]['executable'])]
  response='\n'.join('"'+x.replace('\\','/')+'"'for x in args)+'\n';assert files[role+'/header.args'].replace(b'\r\n',b'\n')==response.encode();assert link_event['command']==[fc,'@'+str(work/'header.args')]
 for row in r['rows']:
  key=(row['role'],row['exponent'],row['kind'],row['field'],row['value']);assert key not in seen;seen.add(key)
  role,exponent,kind,field,value=key;assert role in counts and exponent in g.original.EXPONENTS and kind in ('base','temporal')
  expected_name=role+'/n'+exponent+'/restart.bin'+('.base'if kind=='base'else'');assert row['canonical']==expected_name and files[expected_name]==native[expected_name]
  original=native[expected_name];data=files[row['input']];event=events[row['event']];assert event['label']==role+'-header'and Path(event['command'][2].replace('\\','/')).name==Path(row['input']).name
  stdout=files[event['stdout']];assert re.search(rb'MATRIX_LOGICAL_FIELD_OFFSETS=144 +148 +152 +156',stdout);assert row['offsets']==[144,148,152,156]
  accepted=b'MATRIX_LOGICAL_NATIVE_READ=ACCEPTED'in stdout;refused=b'MATRIX_LOGICAL_NATIVE_READ=REFUSED_EMPTY'in stdout;assert accepted==row['accepted']and accepted!=refused
  if field=='canonical':assert data==original and accepted and value is None;counts[role]['canonical']+=1
  else:
   assert field in ('time_bound','has_history')and value in(2,-1,256);expected=bytearray(original[:-4]);struct.pack_into('<i',expected,144 if field=='time_bound'else 156,value);expected+=struct.pack('<I',zlib.crc32(expected));assert data==expected
   counts[role]['accepted_malformed'if accepted else'refused_malformed']+=1
 assert len(seen)==168 and counts['incumbent']['canonical']==counts['candidate']['canonical']==12 and counts['candidate']['refused_malformed']==72
 return counts

def pack(stem,out,dest):
 native,sha=source_files(stem);files={p.relative_to(out).as_posix():p.read_bytes()for p in out.rglob('*')if p.is_file()and not p.is_relative_to(out/'providers')};counts=audit(native,files,sha)
 with zipfile.ZipFile(dest.with_suffix('.zip'),'w',zipfile.ZIP_DEFLATED)as z:
  for p,b in files.items():z.writestr(p,b)
 dest.with_suffix('.json').write_text(json.dumps(dict(sha256=g.sha(dest.with_suffix('.zip').read_bytes()),members={p:g.sha(b)for p,b in files.items()},measurement=counts),indent=2)+'\n');print(json.dumps(counts))
def verify(stem,dest):
 native,sha=source_files(stem);m=json.loads(dest.with_suffix('.json').read_text());raw=dest.with_suffix('.zip').read_bytes();assert g.sha(raw)==m['sha256']
 with zipfile.ZipFile(io.BytesIO(raw))as z:
  assert len(z.namelist())==len(set(z.namelist()));files={p:z.read(p)for p in z.namelist()}
 assert {p:g.sha(b)for p,b in files.items()}==m['members'];counts=audit(native,files,sha);assert counts==m['measurement'];print(json.dumps(counts))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--native',type=Path,required=True);p.add_argument('--stem',type=Path,required=True);p.add_argument('--output',type=Path);p.add_argument('--compiler');a=p.parse_args()
 if a.output:execute(a.native.resolve(),a.output.resolve(),str(Path(a.compiler).resolve()));pack(a.native.resolve(),a.output.resolve(),a.stem.resolve())
 else:verify(a.native.resolve(),a.stem.resolve())
