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
 end subroutine
