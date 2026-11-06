"""Private full native writer postimages; production and frozen guards unchanged."""
from pathlib import Path
import joint_production as g
BASE='3620ae01e9be7bb0ea8e6348ba50c0474307a586'
DIRECTORY=g.ROOT/'tests/dataqual15_hupsel/joint_writer_candidates'

def candidate(name):
 text=g.raw(BASE,g.SOURCES[name]).decode()
 def replace(before,after):
  nonlocal text
  assert text.count(before)==1,(name,before)
  text=text.replace(before,after,1)
 replace('  use ieee_arithmetic', '  use iso_c_binding,only:c_int,c_char,c_null_char\n  use ieee_arithmetic')
 replace('contains\n','''  interface
    integer(c_int) function publish_restart(a,b)bind(C,name='swap5_restart_publish')
      import c_int,c_char
      character(c_char),intent(in)::a(*),b(*)
    end function
  end interface
contains
''')
 replace('    integer::u,io,mode,n\n','    character(:),allocatable::pending\n    integer::close_status\n    integer::u,io,mode,n\n')
 replace("    open(newunit=u,file=path,access='stream',form='unformatted',status='replace',iostat=io)","    pending=path//'.pending'\n    open(newunit=u,file=pending,access='stream',form='unformatted',status='new',iostat=io)")
 replace('''    close(u)
    if(io/=0)return
    call append_crc(path,io)
    if(io==0)status=JOINT_OK''','''    if(io==0)flush(u,iostat=io)
    close(u,iostat=close_status)
    if(io/=0.or.close_status/=0)return
    call append_crc(pending,io)
    if(io/=0)return
    ! Existing publisher preserves post-replacement POSIX directory-sync refusal.
    ! Failed pending generations stay retained; retries never overwrite them.
    io=publish_restart(pending//c_null_char,path//c_null_char)
    if(io==0)status=JOINT_OK''')
 # The append unit must also report delayed buffered I/O and close failures.
 start=text.index('  subroutine append_crc(');end=text.index('  end subroutine',start)
 block=text[start:end]
 assert block.count('    integer::u,n,io')==1 and block.count('    close(u)')==1
 block=block.replace('    integer::u,n,io','    integer::u,n,io,close_status').replace('    close(u)','    if(io==0)flush(u,iostat=io)\n    close(u,iostat=close_status)\n    if(close_status/=0)return')
 text=text[:start]+block+text[end:]
 return text.encode()

def guard():
 trees=g.source_guard()
 for n in g.NAMES:
  assert g.raw('HEAD',g.SOURCES[n])==g.raw(BASE,g.SOURCES[n])
  path=DIRECTORY/Path(g.SOURCES[n]).name
  assert g.normal(path.read_bytes())==candidate(n)==g.raw('HEAD',path.relative_to(g.ROOT).as_posix())
 return trees

if __name__=='__main__':
 DIRECTORY.mkdir(exist_ok=True)
 for n in g.NAMES:(DIRECTORY/Path(g.SOURCES[n]).name).write_bytes(candidate(n))

