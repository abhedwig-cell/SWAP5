"""Recognize a separate perched zone by the original critical air-volume rule.

Keep strict main GWL and the literal no-macro/no-main-GWL branch unchanged.
"""
from donor_sources import replace

def render(source):
    source=source.replace('\r\n','\n')
    source=replace(source,'only: disnod,numnod,z','only: disnod,numnod,z,dz')
    source=replace(source,'gwlconv\n','gwlconv,Theta,ThetaS\n')
    source=replace(source,'      integer              :: i, node, nodheq1','      integer              :: i, node, nodheq1\n      real(8) :: perched_gap_air')
    old='''      do i = min(nodgwl,numnod), 1, -1
         if (h(i) >= 0.0d0) exit
      end do
      if (i == 1 .AND. h(1) < 0.0d0) i = 0'''
    new='''      if(swmacro==1.and.gwl<990d0)then
         i=min(nodgwl,numnod)
         ! A saturated centre belonging to MAIN groundwater is not a perched bottom.
         do while(i>0)
            if(h(i)<0d0)exit
            i=i-1
         end do
         perched_gap_air=0d0
         do while(i>0)
            if(h(i)>=0d0)then
               ! Same whole-cell air measure and threshold comparison as WATERTABLE.
               if(perched_gap_air>CritUndSatVol-1d-8)exit
               ! No independent perched zone across a subcritical air gap.
               ! Skip this attached saturated block; look above the next gap.
               do while(i>0)
                  if(h(i)<0d0)exit
                  i=i-1
               end do
               perched_gap_air=0d0
            else
               perched_gap_air=perched_gap_air+max(0d0,ThetaS(i)-Theta(i))*dz(i)
               i=i-1
            end if
         end do
      else
'''+old+'''
      end if'''
    return replace(source,old,new)
