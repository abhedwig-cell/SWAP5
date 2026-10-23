program test_nondepleting_exchange
 use iso_fortran_env,only:real64,iostat_end
 use mod_b111_soil_n_daily_exchange
 implicit none
 type(b111_soil_n_exchange_forcing_t)::f
 type(b111_soil_n_exchange_result_t)::r
 real(real64)::x(24)
 integer::ios,mode
 do
  read(*,*,iostat=ios)x,mode
  if(ios==iostat_end)exit
  if(ios/=0)error stop 1
  f=b111_soil_n_exchange_forcing_t()
  f%depth_m=x(1);f%dt_day=x(2);f%wfrac_t0=x(3);f%wfrac_t=x(4)
  f%wflux_out=x(5);f%wflux_transp=x(6);f%wflux_inbot=x(7);f%wflux_intop=x(8);f%wflux_inlat=x(9)
  f%tcsf_n=x(10);f%root_depth_cm=x(11);f%crop_n_demand_kg_m2=x(12)
  f%dvs=x(13);f%lai=x(14);f%lai_crit_nupt=x(15);f%crop_calendar_active=.true.
  f%drybd=x(16);f%sorpcoef=x(17);f%ratecon_nitrif=x(18);f%ratecon_denitr=x(19);f%nminer_kg_m3=x(20)
  f%cnh4_top=x(21);f%cno3_top=x(22)
  f%nondepleting_top=mode==1.or.mode==2
  f%finite_donor_top=mode==2.or.mode==3
  call evaluate_b111_soil_n_daily_exchange(f,x(23),x(24),r)
  write(*,'(I3,16(1X,ES26.17E3))')r%status,r%cnh4_end,r%cnh4_average,r%cno3_end,r%cno3_average, &
   r%nh4_crop_uptake_kg_m2,r%no3_crop_uptake_kg_m2,r%nh4_nitrified_kg_m2,r%no3_denitrified_kg_m2, &
   r%top_actual,r%top_unmet,r%external_input_kg_m2,r%external_output_kg_m2, &
   r%nh4_outflow_kg_m2,r%no3_outflow_kg_m2
 end do
end program
