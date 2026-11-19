"""Cancellation-safe read-only soil delta for the selected complete receipt.

Keep original exported daily double totals and the public1e-10 checks. Only
the internal trial projection evaluates the equivalent soil change directly
from actual original nodal theta, avoiding subtraction of large rounded sums.
"""

def render(text):
    old='  implicit none\n  private'
    assert text.count(old)==1
    text=text.replace(old,'''  implicit none
  real(8),save::soil_origin_clock=-huge(0d0)
  real(8),allocatable,save::soil_origin_theta(:)
  private''',1)
    old='    use variables,only:tcum,dt'
    assert text.count(old)==1
    text=text.replace(old,'''    use variables,only:tcum,dt,t1900,theta,thetm1
    use MOD_grid,only:numnod,dz
    use MOD_drain,only:swman,nmper''',1)
    old='    real(8) :: terms(28)'
    assert text.count(old)==1
    text=text.replace(old,old+'\n    real(8)::day_clock\n    real(real128)::soil_change',1)
    old='    residual=real(sum(real(terms,real128)),8)'
    assert text.count(old)==1
    text=text.replace(old,'''    if(any(swman(1:nmper)==2))then
    day_clock=anint(t1900-tcum)
    if(day_clock/=soil_origin_clock)then
      if(allocated(soil_origin_theta))deallocate(soil_origin_theta)
      allocate(soil_origin_theta(numnod))
      soil_origin_theta=thetm1(1:numnod)
      soil_origin_clock=day_clock
    end if
    soil_change=sum((real(theta(1:numnod),real128)-real(soil_origin_theta,real128))*real(dz(1:numnod),real128))
    residual=real(sum(real(terms(1:16),real128))+sum(real(terms(18:22),real128)) &
                 +sum(real(terms(24:28),real128))-soil_change,8)
    else
      residual=real(sum(real(terms,real128)),8)
    end if''',1)
    # The original daily double witness remains literal, separately checked
    # against the unchanged public water criterion after every actual day.
    old="'EXTENDED_DRAIN_TERMINAL_WATER',residual,terms"
    assert text.count(old)==1
    text=text.replace(old,"'EXTENDED_DRAIN_TERMINAL_WATER',real(sum(real(terms,real128)),8),terms",1)
    return text
