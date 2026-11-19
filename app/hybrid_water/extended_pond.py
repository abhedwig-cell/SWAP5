"""Selected numerical solve of the literal original extended runoff function."""

def render(source):
    old='      runots = runoff()\n      if (dabs(runots)'
    assert source.count(old)==1
    source=source.replace(old,'''      ! The original inundation root may exceed its no-exchange h0max.
      ! Evaluate the unchanged original runoff() with a complete bracket.
      if(swdra==2.and.swmacro==0.and..not.(wls<=pondmx.and.rsroexp==1d0.and.rsro>=1d-3))then
         call extended_pond_root()
         return
      end if
'''+old,1)
    old='      contains\n! ----------------------------------------------------------------------\n      function runoff ()'
    assert source.count(old)==1
    source=source.replace(old,'''      contains
      subroutine extended_pond_root()
        real(8)::lower,upper,middle,left_value,right_value,value,constant,coefficient
        integer::iteration
        coefficient=1d0+k1max/disnod(1)*dt
        constant=pondm1+q0hlp*dt-k1max*dt+k1max/disnod(1)*dt*h(1)
        lower=0d0;upper=max(h0max,wls)
        pond=lower;runots=runoff();left_value=coefficient*pond+runots-constant
        pond=upper;runots=runoff();right_value=coefficient*pond+runots-constant
        if(left_value>0d0.or.right_value<0d0)error stop 'Original extended pond root not bracketed'
        do iteration=1,128
           middle=lower+(upper-lower)*.5d0
           if(middle==lower.or.middle==upper)exit
           pond=middle;runots=runoff();value=coefficient*pond+runots-constant
           if(value==0d0)then
              hsurf=pond
              return
           else if(value<0d0)then
              lower=middle;left_value=value
           else
              upper=middle;right_value=value
           end if
        end do
        pond=lower
        if(abs(right_value)<abs(left_value))pond=upper
        runots=runoff();hsurf=pond
      end subroutine
! ----------------------------------------------------------------------
      function runoff ()''',1)
    old='public :: pondrunoff, q0, FlRunoff, ftoph, hsurf'
    assert source.count(old)==1
    source=source.replace(old,old+', extended_pond_top_jacobian',1)
    old='end module MOD_top';assert source.count(old)==1
    source=source.replace(old,'''real(8) function extended_pond_top_jacobian(conductance,step) result(tangent)
  use MOD_drain,only:wls,swst,sttab
  use variables,only:pond,pondmx,rsro,rsroexp
  real(8),intent(in)::conductance,step
  real(8)::slope,available,level_limit,swstlev
  integer::i
  slope=0d0
  if(pond>pondmx.and.pond>wls)then
     slope=step/rsro*rsroexp*(pond-max(pondmx,wls))**(rsroexp-1d0)
  else if(pond>pondmx.and.pond<wls)then
     available=swst-swstlev(pond);level_limit=wls-max(pond,pondmx)
     if(available<level_limit)then
        i=1
        do while(.not.(pond>=sttab(i+1,1).and.pond<=sttab(i,1)))
           i=i+1
           if(i>=22)error stop 'Original extended pond derivative outside table'
        end do
        slope=(sttab(i,2)-sttab(i+1,2))/(sttab(i,1)-sttab(i+1,1))
     else
        slope=1d0
     end if
  end if
  tangent=conductance*(1d0+slope)/(1d0+step*conductance+slope)
end function
end module MOD_top''',1)
    return source
