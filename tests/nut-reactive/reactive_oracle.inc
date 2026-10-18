 ! This setup/receipt wrapper calls complete literal historical routines.
 ! The explicit one-line Nminer reference repair is made before compilation.
 subroutine literal_day(p,before,w0,w1,qout,qbot,qlat,root,after,nit,denit,carbon,surface_water)
   use wofost_soil_declarations
   use MOD_texture_orgmat,only:bdens
   type(reactive_parameters_t),intent(in)::p
   type(soil_n_pool_state_t),intent(in)::before
   real(real64),intent(in)::w0,w1,qout,qbot,qlat,root
   type(soil_n_pool_state_t),intent(out)::after
   real(real64),intent(out)::nit,denit,carbon
   real(real64),optional,intent(in)::surface_water
   real(real64)::top_water
   real(real64)::nh4c,no3c,nh4end,no3end,nh4avg,no3avg,pa,prod
   top_water=0d0;if(present(surface_water))top_water=max(0d0,surface_water)
   nf=size(before%fom_kg_m3);dt_WSN=1d0;dz_WSN=p%mineral%inventory%depth_m
   WFrac_t0=w0;WFrac_t=w1;WFrac_sat=p%environment%wfrac_sat
   Temp=p%environment%temperature_c;Temp_ref=p%environment%temperature_reference_c
   WFPScrit=p%wfpscrit;WFPScrit2=p%environment%wfpscrit2;CdissiHalf=p%environment%cdissi_half_kg_m2
   RateconFOM_ref(1:nf)=p%organic_reference%ratecon_fom
   RateconBio_ref=p%organic_reference%ratecon_bio;RateconHum_ref=p%organic_reference%ratecon_hum
   RateconHum_exp=0d0;t1900Soil=0d0;tstartHumexp=0d0
   RateConNitrif_ref=p%environment%nitrification_ref_per_day;RateConDenitr_ref=p%environment%denitrification_ref_per_day
   AsfaFOM_Bio(1:nf)=p%organic_reference%asfa_fom_bio;AsfaFOM_Hum(1:nf)=p%organic_reference%asfa_fom_hum
   AsfaBio=p%organic_reference%asfa_bio;AsfaHum=p%organic_reference%asfa_hum
   CFracFOM(1:nf)=p%cfrac_fom;CFracBio=p%cfrac_biomass;CFracHum=p%cfrac_humus
   NFracFOM(1:nf)=p%mineral%inventory%nfrac_fom
   NFracBio=p%mineral%inventory%nfrac_biomass;NFracHum=p%mineral%inventory%nfrac_humus
   FOM_t0(1:nf)=before%fom_kg_m3;Bio_t0=before%biomass_kg_m3;Hum_t0=before%humus_kg_m3
   FOM2Bio=0d0;NFOM2Bio=0d0;FOM2Hum=0d0;NFOM2Hum=0d0;FOM_dis=0d0;NFOM_min=0d0
   Bio2Bio=0d0;NBio2Bio=0d0;Bio2Hum=0d0;NBio2Hum=0d0;Bio_dis=0d0;NBio_min=0d0
   Hum2Bio=0d0;NHum2Bio=0d0;Hum2Hum=0d0;NHum2Hum=0d0;Hum_dis=0d0;NHum_min=0d0
   call wofost_soilrateconstants(1)
   call wofost_soilorgmatn()
   call wofost_soilrateconstants(2)
   carbon=Cdissi;bdens(1)=p%mineral%drybd
   nh4c=before%ammonium_n_kg_m2/(dz_WSN*(w0+bdens(1)*p%mineral%sorption))
   no3c=before%nitrate_n_kg_m2/(dz_WSN*w0)
   call Wofost_SoilWaterN(dz_WSN,1d0,w1,w0,qout,root,qbot,top_water,qlat,0d0,RateConNitrif,Nminer,pa, &
       p%mineral%sorption,p%mineral%c_bottom(1),p%mineral%c_top(1),p%mineral%c_lateral(1),nh4c,nh4end,nh4avg)
   prod=.5d0*(w0+w1)*RateConNitrif*nh4avg
   call Wofost_SoilWaterN(dz_WSN,1d0,w1,w0,qout,root,qbot,top_water,qlat,0d0,RateConDenitr,prod,pa, &
       0d0,p%mineral%c_bottom(2),p%mineral%c_top(2),p%mineral%c_lateral(2),no3c,no3end,no3avg)
   after%fom_kg_m3=FOM_t(1:nf);after%biomass_kg_m3=Bio_t;after%humus_kg_m3=Hum_t
   after%ammonium_n_kg_m2=nh4end*dz_WSN*(w1+bdens(1)*p%mineral%sorption)
   after%nitrate_n_kg_m2=no3end*dz_WSN*w1
   nit=prod*dz_WSN;denit=.5d0*(w0+w1)*RateConDenitr*no3avg*dz_WSN
 end subroutine
