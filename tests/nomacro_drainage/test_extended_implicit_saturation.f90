! Real original constitutive provider, including original watcon/moiscap.
program original_implicit_saturation_probe
use MOD_MvG,only:cofgen,swsophy,iHWCKmodel,sw_use_elas,fl_use_tables,fl_use_kh_power, &
 set_cofgen_pointers,calc_cofgen_extra,watcon,moiscap,hconduc,dhconduc
use MOD_grid,only:numnod,layer
use MOD_swap_base,only:swmacro,swfrost,swhyst
use variables,only:indeks,fhyst,fluseksatexm
implicit none
integer::i,soil
real(8)::head,theta,se,k,derivative,plus,minus,epsilon,again,other,saved(42)
real(8),parameter::heads(*)=[-100d0,-10d0,-1d0,-.1d0,-.02d0,-.015d0,-.0145215456084479243d0, &
 -.0145115456084479243d0,-.0145015456084479243d0,-.012d0,-.01001d0,-.00999d0,-.005d0,-.001d0,0d0,1d0]
numnod=1;layer(1)=1;swsophy=0;swmacro=0;swfrost=0;swhyst=0;sw_use_elas=0
fl_use_tables=.false.;fl_use_kh_power=.false.;iHWCKmodel(1)=1;indeks(1)=-1;fhyst(1)=1d0;fluseksatexm(1)=.false.
call set_cofgen_pointers()
do soil=1,2
 cofgen=0d0
 if(soil==1)then
  cofgen(1:10,1)=[.02d0,.433878d0,83.24164d0,.021645d0,7.202077d0,1.34877d0, &
     1d0-1d0/1.34877d0,.04329d0,0d0,0d0]
 else
  cofgen(1:10,1)=[.02d0,.387064d0,22.76176d0,.016083d0,2.439662d0,1.524418d0, &
     1d0-1d0/1.524418d0,.032166d0,0d0,0d0]
 end if
 call calc_cofgen_extra(1)
 do i=1,size(heads)
  head=heads(i);theta=watcon(1,head);se=(theta-cofgen(1,1))/cofgen(25,1)
  saved=cofgen(1:42,1);k=hconduc(1,head,theta,1d0)
  derivative=dhconduc(1,head,theta,moiscap(1,head),1d0)
  other=hconduc(1,-10d0,watcon(1,-10d0),1d0);again=hconduc(1,head,theta,1d0)
  if(again/=k.or.any(saved/=cofgen(1:42,1)))error stop 'Actual Mualem provider mutated physical parameters or A/B/A'
  epsilon=1d-6
  plus=hconduc(1,head+epsilon,watcon(1,head+epsilon),1d0)
  minus=hconduc(1,head-epsilon,watcon(1,head-epsilon),1d0)
  write(*,'(a,2(1x,i0),10(1x,es25.17e3))')'ACTUAL_ORIGINAL_SATURATION',soil,i, &
    head,theta,se,k,derivative,plus,minus,cofgen(3,1),cofgen(5,1),cofgen(7,1)
 end do
end do
write(*,'(a)')'ACTUAL_ORIGINAL_SATURATION_COMPONENT_COMPLETE 32'
end program
