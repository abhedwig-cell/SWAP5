from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from b0_source_runner import select_dec_branches
p=Path('reference-run/selected/macrorate.f90')
s=select_dec_branches(Path('reference-run/source/macrorate.f90').read_bytes().decode('cp1252'))
s=s.replace('use MOD_macropore,','use MOD_macropore,',1)
s=s.replace('flendsrpevt, frreduq, idecmprat,','migmac01_rate_trace, flendsrpevt, frreduq, idecmprat,',1)
s=s.replace('      if (ITask == 1) return','      call migmac01_rate_trace(ITask)\n      if (ITask == 1) return',1)
p.write_bytes(s.encode('cp1252'))
p=Path('reference-run/selected/macropore.f90');s=p.read_text(encoding='cp1252')
hook='''
      subroutine migmac01_rate_trace(task)
      use MOD_grid, only:numnod,z,dz
      use variables, only:h,theta,t1900,dt,npegwl,bpegwl,pegwl,nodgwl
      implicit none
      integer,intent(in)::task
      integer::u,ic
      open(newunit=u,file='migmac01_last_rate.csv',status='replace')
      write(u,'(*(g0,:,","))') 'RATE_META',t1900,dt,task,nodgwl,nodgwlflcpzo,gwlflcpzo, &
         npegwl,bpegwl,pegwl,ICpTpSatZon,ICpTpPerZon,ICpBtPerZon,CritUndSatVol
      do ic=1,numnod
        write(u,'(*(g0,:,","))') 'RATE_NODE',ic,h(ic),theta(ic),QExcMpMtx(ic)
      end do
      close(u)
      end subroutine migmac01_rate_trace
'''
s=s.replace('end module MOD_macropore',hook+'\nend module MOD_macropore')
p.write_bytes(s.encode('cp1252'))
