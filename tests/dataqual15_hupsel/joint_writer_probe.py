"""Reversible native public-writer probe and actual publication fault/kill matrix."""
import os,json
from pathlib import Path
import joint_production as g
import pond_thermal_writer as publication

def driver(source,name):
 text=g.normal(source).decode();chem='solute'if name=='age'else'nitrogen';seed='restart_path'if name=='age'else'path'
 read=f'call read_{name}_joint_restart_file(trim({seed}),column,cfg%tiles(1)%template,670001_int64,9001_int64,p,water,{chem},status)'
 write=f'call write_{name}_joint_restart_file(trim(OUTPUT),column,cfg%tiles(1)%template,670001_int64,water,{chem},status)'
 branch=f'''  if(trim(mode)=='probe-writer')then
    block
      character(512)::target,recovery
      character(16)::layout
      call get_command_argument(3,target)
      call get_command_argument(4,recovery)
      call get_command_argument(5,layout)
      if(trim(layout)=='plain')cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
      {read}
      call require(status==0.and.water%ready().and.{chem}%ready(),'proper writer origin')
      {write.replace('trim(OUTPUT)','trim(target)')}
      print '(A,I0)','WRITE_STATUS=',status
      {write.replace('trim(OUTPUT)','trim(recovery)')}
      call require(status==0,'writer preserves live owners')
    end block
    stop
  end if
'''
 anchor=next(s for s in text.splitlines(True)if "if(trim(mode)=='reject')then"in s)
 result=text.replace(anchor,branch+anchor,1);assert result.replace(branch,'',1)==text
 return result.encode()

def measure(out,exes,events):
 rows=[];crashes=[]
 for name in g.NAMES:
  for layout in (('history','plain')if name=='age'else('history',)):
   seed=out/name/('restart.bin.base'if layout=='plain'else'restart.bin');good=seed.read_bytes()
   # A distinct *valid* old generation is required, not an arbitrary sentinel.
   old_path=out/name/('restart.bin'if layout=='plain'else'full.bin')
   old=old_path.read_bytes();assert old!=good
   home=out/('publication-'+name+'-'+layout);home.mkdir()
   def command(target,recovery):return [exes[name],'probe-writer',seed,target,recovery,layout]
   for stage in (0,2,3,4,5,6):
    case=home/str(stage);case.mkdir();target=case/'authority';target.write_bytes(old);recovery=case/'recovered'
    env={'MTPUB_TARGET':str(target)}
    if stage:env['MTPUB_FAIL']=str(stage)
    event=publication.execute(command(target,recovery),case,'writer',env);success=stage==0 or(stage==6 and os.name=='nt');published=stage in(0,6)
    assert (b'WRITE_STATUS=0'in(case/event['stdout']).read_bytes())==success
    assert (b'WRITE_STATUS=1'in(case/event['stdout']).read_bytes())== (not success)
    assert target.read_bytes()==(good if published else old)and recovery.read_bytes()==good
    pending=Path(str(target)+'.pending');assert pending.exists()==(stage in(2,3,4,5))
    if pending.exists():
     assert pending.read_bytes()==good
     retry=publication.execute(command(target,case/'retry-recovered'),case,'retry')
     assert b'WRITE_STATUS=1'in(case/retry['stdout']).read_bytes()and pending.read_bytes()==good and target.read_bytes()==old and(case/'retry-recovered').read_bytes()==good
     event['retry']=retry
    rows.append(dict(codec=name,layout=layout,stage=stage,event=event))
   for phase in ('before','after'):
    case=home/phase;case.mkdir();target=case/'authority';target.write_bytes(old)
    event=publication.terminate(command(target,case/'never'),case,phase,target)
    assert target.read_bytes()==(old if phase=='before'else good)
    pending=Path(str(target)+'.pending');assert pending.exists()==(phase=='before')
    if pending.exists():assert pending.read_bytes()==good
    # Read the surviving authority through the complete original public reader.
    fresh=publication.execute([exes[name],'probe-writer',target,case/'fresh',case/'fresh-again',layout],case,'fresh')
    assert(case/'fresh').read_bytes()==target.read_bytes()==(case/'fresh-again').read_bytes()
    crashes.append(dict(codec=name,layout=layout,phase=phase,event=event,fresh=fresh))
 assert len(rows)==24 and len(crashes)==8
 return dict(cases=rows,terminations=crashes)
