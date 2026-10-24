program organic_constraint
 use iso_fortran_env,only:real64
 use mod_soil_n_pool_state
 use mod_b111_soil_organic_turnover
 use mod_b111_soil_organic_dissimilation
 use mod_b111_soil_n_organic_turnover_transfer
 use mod_b111_soil_n_daily_candidate
 use mod_b111_soil_n_daily_exchange
 implicit none
 type(soil_n_inventory_parameters_t)::p
 type(soil_n_pool_state_t)::s,c
 type(soil_n_transfer_t)::x
 type(soil_n_receipt_t)::receipt
 type(b111_organic_turnover_parameters_t)::k
 type(b111_organic_n_turnover_receipt_t)::o
 type(b111_organic_dissimilation_result_t)::d
 type(b111_soil_n_daily_candidate_result_t)::r
 type(b111_soil_n_exchange_forcing_t)::f
 type(b111_soil_n_rate_environment_t)::e
 real(real64)::a,lo,hi,mid,gain,roots(2)
 integer::i,j,mode,stock,code
 p%depth_m=1d0;p%nfrac_fom=[.001d0];p%nfrac_biomass=.08d0;p%nfrac_humus=.02d0
 k%ratecon_fom=[10d0];k%asfa_fom_bio=[.5d0];k%asfa_fom_hum=[0d0]
 k%ratecon_bio=5d0;k%ratecon_hum=0d0;k%asfa_bio=0d0;k%asfa_hum=0d0
 call initialize_soil_n_pool_state(p,[1d0],0d0,0d0,.005d0,0d0,s,code)
 call require(code==0,'initial state')
 do i=0,2000
  a=real(i,real64)/2000d0
  call organic(a)
  print '(A,1X,I0,6(1X,ES25.17E3))','SWEEP',i,a,o%organic%fom_kg_m3(1), &
    o%organic%biomass_kg_m3,o%organic%humus_kg_m3,-o%nitrogen%mineralized_n_kg_m2, &
    d%carbon_dissimilation_kg_m2
 end do
 do j=1,2
  if(j==1)then;lo=0d0;hi=.13d0;else;lo=.14d0;hi=1d0;end if
  do i=1,65
   mid=(lo+hi)/2d0;call organic(mid);gain=-o%nitrogen%mineralized_n_kg_m2
   if((gain<.005d0).eqv.(j==1))then;lo=mid;else;hi=mid;end if
  end do
  roots(j)=(lo+hi)/2d0;call organic(roots(j))
  ! Remove precisely the organic N gain. Roundoff at an equality root must
  ! not turn a zero NH4 endpoint negative; initial stock includes1e-14 slack.
  s%ammonium_n_kg_m2=.005d0+1d-14
  call apply_soil_n_transfer(p,s,x,c,receipt)
  call require(receipt%status==0,'conservative root transfer')
  print '(A,1X,I0,5(1X,ES25.17E3))','ROOT',j,roots(j),c%fom_kg_m3(1), &
    c%biomass_kg_m3,d%carbon_dissimilation_kg_m2,receipt%balance_residual_kg_m2
 end do
 call organic(.13d0)
 x%ammonium_n_delta_kg_m2=-.005d0
 s%ammonium_n_kg_m2=.005d0
 call apply_soil_n_transfer(p,s,x,c,receipt)
 call require(receipt%status==SOIL_N_BALANCE,'clipped immobilisation rejected by owner')
 call same(s,c)
 print '(A,1X,I0,1X,ES25.17E3)','CLIPPED',receipt%status,receipt%balance_residual_kg_m2
 ! Slow one-day turnover has an unambiguous negative net mineralisation.
 k%ratecon_fom=[.1d0];k%ratecon_bio=0d0
 e%temperature_c=20d0;e%temperature_reference_c=20d0;e%wfrac_sat=.45d0
 e%wfpscrit2=.5d0;e%cdissi_half_kg_m2=.1d0
 do mode=0,2
  do stock=0,1
   f=b111_soil_n_exchange_forcing_t();f%wfrac_t=.3d0;f%wfrac_t0=.3d0
   f%drybd=1300d0;f%sorpcoef=.0002d0
   if(mode>0)then;f%nondepleting_top=.true.;f%wflux_intop=-.001d0;end if
   if(mode==2)then
    f%proportional_constant_sinks=.true.;f%crop_calendar_active=.true.
    f%lai_crit_nupt=1d0;f%root_depth_cm=30d0
   end if
   s%ammonium_n_kg_m2=merge(.02d0,.00001d0,stock==1)
   call evaluate_b111_soil_n_daily_candidate(p,s,k,[.45d0],.45d0,.45d0,e,f,c,r)
   call require(r%organic%nitrogen%mineralized_n_kg_m2<0d0,'negative organic production')
   if(stock==1.and.mode<2)then
    call require(r%status==0,'sufficient immobilisation accepted')
    call require(abs(c%nitrogen_total(p)-s%nitrogen_total(p))<1d-12,'whole N conservation')
   else
    call require(r%status/=0,'unsupported or insufficient immobilisation rejected')
    call same(s,c)
   end if
   print '(A,4(1X,I0),3(1X,ES25.17E3))','CANDIDATE',mode,stock,r%status,r%exchange%status, &
    r%organic%nitrogen%mineralized_n_kg_m2,c%ammonium_n_kg_m2,c%nitrogen_total(p)-s%nitrogen_total(p)
  end do
 end do
contains
 subroutine organic(activity)
  real(real64),intent(in)::activity
  k%ratecon_fom=[10d0*activity];k%ratecon_bio=5d0*activity
  call build_b111_organic_n_turnover_transfer(p,s,1d0,k,x,o)
  call require(o%status==0,'production organic turnover')
  call evaluate_b111_organic_dissimilation(s%fom_kg_m3,s%biomass_kg_m3,s%humus_kg_m3, &
   1d0,1d0,k,o%organic,[.45d0],.45d0,.45d0,d)
  call require(d%status==0,'production carbon dissimilation')
 end subroutine
 subroutine same(left,right)
  type(soil_n_pool_state_t),intent(in)::left,right
  call require(all(left%fom_kg_m3==right%fom_kg_m3).and.left%biomass_kg_m3==right%biomass_kg_m3.and. &
   left%humus_kg_m3==right%humus_kg_m3.and.left%ammonium_n_kg_m2==right%ammonium_n_kg_m2.and. &
   left%nitrate_n_kg_m2==right%nitrate_n_kg_m2,'rejected candidate exact rollback')
 end subroutine
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print *,label;error stop 1;end if
 end subroutine
end program
