"""Generate the experimental HeadCalc with a refreshed acceptance residual."""

import sys
from pathlib import Path
p = Path(sys.argv[1])
s = p.read_text(encoding='cp1252')
def patch(old,new):
    global s
    if s.count(old) != 1:
        raise ValueError(f'Expected one source anchor: {old}')
    s = s.replace(old, new)
patch('logical                          :: flboth, flok','logical                          :: flboth, flok, checked_exchange')
patch('   iBackTr        = 0', '   checked_exchange = .FALSE.\n   iBackTr        = 0')
patch('if (dt <  0.01d0 .AND. swmacro == 1 .AND. .NOT.flnonconv3) then','if (dt < 0.01d0 .AND. swmacro == 1 .AND. .NOT.flnonconv3 .AND. .NOT.checked_exchange) then')
patch('!     save sump voor next iteration', '''!     Verify the refreshed physical residual before accepting a frozen-exchange solve.
      if (.not.flnonconv .and. swmacro == 1 .and. flunsatok(3)) then
         flunsatok = .false.
         checked_exchange = .true.
         call vector_F(2, hgrad)
         sump = 0.5d0 * dot_product(F(1:NN), F(1:NN))
         flnonconv = maxval(abs(F(1:NN))) > CritDevBalCp .or. &
                     abs(sum(F(1:NN))) > CritDevBalTot .or. fldecMPmbf
         if (ftoph) qtop = -kmean(1)*hgrad(1)
         if (IcTopMp == 1) then
            deviat = pond - pondm1 + epd*dt + reva*dt - (nraidt+nird+Melt)*dt - runon*dt + &
                     runots - qtop*dt + ArMpSs*(nraidt+nird+Melt)*dt + QMpLatSs
            flnonconv = flnonconv .or. abs(deviat) > CritDevPondDt
         else if (ftoph) then
            deviat = pond - pondm1 + epd*dt + reva*dt - (nraidt+nird+Melt)*dt - runon*dt + runots - qtop*dt
            flnonconv = flnonconv .or. abs(deviat) > CritDevPondDt
         end if
      end if

!     save sump voor next iteration''')
patch('!     continue without convergence !!!', '''!     A failed refreshed check cannot fall through to a committed step.
      if (checked_exchange) error stop 'Unresolved refreshed macropore residual'

!     continue without convergence !!!''')
Path(sys.argv[2]).write_text(s, encoding='cp1252')
