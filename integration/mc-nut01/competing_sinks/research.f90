! Research only: alternative partitions of the real production donor receipt.
program competing_sinks
 use iso_fortran_env,only:real64
 use mod_b111_soil_n_transport
 implicit none
 type(b111_soil_n_transport_result_t)::r
 real(real64)::c0,loading,top,crop,h,tau,after,pt,pc,tt,tc,ct,cc,book
 integer::ios
 do
  read(*,*,iostat=ios)c0,loading,top,crop,h
  if(ios/=0)exit
  call evaluate_b111_soil_n_negative_boundary(.3d0,1d0,.3d0+h,.3d0,.002d0, &
   .001d0,-.01d0,0d0,.04d0,loading/.3d0,0d0,0d0,0d0, &
   (top+crop)/.01d0,0d0,c0,r)
  if(r%status/=B111_NTRANS_OK)error stop 1
  tau=r%depletion_time;after=1d0-tau
  pt=top*tau+loading*after*top/(top+crop)
  pc=crop*tau+loading*after*crop/(top+crop)
  tt=top*tau+min(top,loading)*after
  tc=crop*tau+max(0d0,loading-top)*after
  cc=crop*tau+min(crop,loading)*after
  ct=top*tau+max(0d0,loading-crop)*after
  book=.3d0*.3d0*c0+loading-.3d0*(.3d0+h)*r%concentration_end &
   -(.002d0+.04d0*.3d0*(.3d0+.5d0*h))*r%concentration_average &
   +r%top_actual_rate
  print '(11(es25.16e3,1x))',r%concentration_end,r%concentration_average,tau, &
   -r%top_actual_rate,pt,pc,tt,tc,ct,cc,book
 end do
end program
