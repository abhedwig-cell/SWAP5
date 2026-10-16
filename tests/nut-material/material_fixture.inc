 subroutine parameters(p)
   type(reactive_parameters_t),intent(out)::p
   p%mineral%dz_cm=[5d0,5d0,10d0,10d0];p%mineral%inventory%depth_m=.3d0
   p%mineral%inventory%nfrac_fom=[.015d0,.025d0]
   p%mineral%inventory%nfrac_biomass=.04d0;p%mineral%inventory%nfrac_humus=.02d0
   p%mineral%drybd=1300d0;p%mineral%sorption=.0002d0
   p%mineral%c_bottom=[.1d0,.2d0];p%mineral%c_lateral=[.3d0,.4d0]
   p%organic_reference%ratecon_fom=[.04d0,.015d0]
   p%organic_reference%asfa_fom_bio=[.2d0,.25d0];p%organic_reference%asfa_fom_hum=[.15d0,.1d0]
   p%organic_reference%ratecon_bio=.008d0;p%organic_reference%ratecon_hum=.0008d0
   p%organic_reference%asfa_bio=.3d0;p%organic_reference%asfa_hum=.2d0
   p%cfrac_fom=[.45d0,.45d0];p%cfrac_biomass=.45d0;p%cfrac_humus=.45d0;p%wfpscrit=.6d0
   p%environment%temperature_c=20d0;p%environment%temperature_reference_c=20d0
   p%environment%wfrac_sat=.423d0;p%environment%wfpscrit2=.5d0
   p%environment%cdissi_half_kg_m2=.1d0
   p%environment%nitrification_ref_per_day=.02d0;p%environment%denitrification_ref_per_day=.03d0
   p%mineral%inventory%nfrac_fom=[.06d0,.002d0,.06d0,.002d0,.06d0,.002d0,.06d0,.002d0]
   p%mineral%inventory%nfrac_biomass=.58d0/10d0;p%mineral%inventory%nfrac_humus=.58d0/14d0
   p%organic_reference%ratecon_fom=[3d0,3d0,3d0,3d0,.3d0,.3d0,.3d0,.3d0]/365.2425d0
   p%organic_reference%asfa_fom_bio=[.04d0,.04d0,.28d0,.28d0,.04d0,.04d0,.28d0,.28d0]*.46d0
   p%organic_reference%asfa_fom_hum=[.04d0,.04d0,.28d0,.28d0,.04d0,.04d0,.28d0,.28d0]*.54d0
   p%organic_reference%ratecon_bio=.66d0/365.2425d0;p%organic_reference%ratecon_hum=.02d0/365.2425d0
   p%organic_reference%asfa_bio=.46d0*.2d0;p%organic_reference%asfa_hum=.54d0*.2d0
   p%cfrac_fom=spread(.45d0,1,8);p%cfrac_biomass=.58d0;p%cfrac_humus=.58d0
 end subroutine
 subroutine materials(items,split)
 type(soil_n_material_input_t),intent(out)::items(2)
 type(b111_soil_n_split_parameters_t),intent(out)::split
 split%nfrac_fom_min=.002d0;split%nfrac_fom_max=.06d0;split%nfrac_humus=.58d0/14d0
 split%asfa_min=.04d0;split%asfa_max=.28d0
 items(1)%kind=MATERIAL_AMENDMENT;items(1)%material%application_kg_m2=.04d0
 items(1)%material%application_age=3.16d0;items(1)%material%organic_matter_fraction=.5d0
 items(1)%material%organic_n_fraction=.025d0;items(1)%material%ammonium_n_fraction=.02d0
 items(1)%material%nitrate_n_fraction=.01d0;items(1)%material%volatilization_fraction=.25d0
 items(2)=items(1);items(2)%kind=MATERIAL_RESIDUE;items(2)%material%application_age=.99d0
 items(2)%material%volatilization_fraction=0d0;items(2)%material%application_kg_m2=.01d0
 end subroutine
