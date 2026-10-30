program original_hupsel_germination_oracle
 use iso_fortran_env,only:real64
 use MOD_cropdevelopment,only:germination,sw_germ,fl_germ,tsumgerm,tsumemeopt,tbasem,teffmx,hdrygerm,hwetgerm,agerm,zgerm
 use plant_interface,only:unit_crp,crpfilnam,fl_start_croprotation
 use atmosphere_interface,only:tav
 use MOD_grid,only:numnod,dz
 use variables,only:h
 use mod_crop_germination_preflight
 implicit none
 type(crop_germination_candidate_t)::candidate
 real(real64)::time,head,temperature,expected,base,maximum
 integer::u,io,code,count
 logical::completed
 unit_crp=74;crpfilnam='maize.crp';call germination(1)
 fl_start_croprotation=.true.;call germination(2);fl_start_croprotation=.false.
 numnod=1;dz(1)=10d0;count=0;maximum=0d0;base=0d0
 open(newunit=u,file='samples.txt',status='old')
 do
  read(u,*,iostat=io)time,head,temperature,expected,completed
  if(io/=0)exit
  h(1)=head;tav=temperature
  call germination(3)
  call propose_crop_germination(2,base,tsumemeopt,tbasem,teffmx,temperature,head, &
   hdrygerm,hwetgerm,agerm,candidate,code)
  if(code/=0.or..not.candidate%valid)error stop 'production germination rejected'
  maximum=max(maximum,abs(tsumgerm-candidate%next_temperature_sum))
  if(abs(tsumgerm-candidate%next_temperature_sum)>1d-12)error stop 'compiled original mismatch'
  if(abs(candidate%next_temperature_sum-expected)>1d-12)error stop 'native original application mismatch'
  if(fl_germ.neqv.candidate%complete)error stop 'original completion mismatch'
  if(completed.neqv.candidate%complete)error stop 'native completion mismatch'
  base=candidate%next_temperature_sum;count=count+1
 end do
 close(u)
 if(count/=19)error stop 'missing original germination days'
 print *,'ORIGINAL_HUPSEL_GERMINATION_PASS',count,maximum
end program
