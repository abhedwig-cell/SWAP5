! B1.11 MOD_meteo::astro, explicit immutable day/latitude/radiation inputs.
! WOFOST assimilation consumes this view; it owns no weather or crop state.
module mod_crop_solar_geometry
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 integer,parameter,public::CROP_SOLAR_OK=0,CROP_SOLAR_INVALID=1
 real(real64),parameter::pi=3.141592653589793238462643383279502884197d0,radial=pi/180d0
 type,public::crop_solar_geometry_t
  real(real64)::atmospheric_transmission=0d0,daylength_hours=0d0,photoperiod_hours=0d0
  real(real64)::sine_offset=0d0,sine_amplitude=0d0,diffuse_perpendicular=0d0,effective_solar_height=0d0
 end type
 public::evaluate_crop_solar_geometry
contains
 pure subroutine evaluate_crop_solar_geometry(iday,lat,rad,result,status)
  integer,intent(in)::iday
  real(real64),intent(in)::lat,rad
  type(crop_solar_geometry_t),intent(out)::result
  integer,intent(out)::status
  real(real64)::dec,sc,aob,aob_corr,angot,dsinb,frdif
  real(real64)::atmtr_,dayl_,daylp_,sinld_,cosld_,difpp_,dsinbe_
  real(real64),parameter::angle=-4d0
  result=crop_solar_geometry_t();status=CROP_SOLAR_INVALID
  if(iday<1.or.iday>366)return
  if(.not.ieee_is_finite(lat).or..not.ieee_is_finite(rad))return
  if(abs(lat)>90d0.or.rad<0d0)return
      ! declination and solar constant for this day
      dec = -asin(dsin(23.45d0 * radial) * dcos(2.d0 * pi * dble(iday + 10.d0) / 365.d0))
      sc = 1370.d0*(1.d0 + 0.033d0 * dcos(2.d0 * pi * dble(iday) / 365.d0))

      ! calculation of daylength from intermediate variables (sinld, cosld, aob)
      sinld_ = dsin(radial * lat) * dsin(dec)
      cosld_ = dcos(radial * lat) * dcos(dec)
      aob = sinld_ / cosld_

      ! For very high latitudes and days in summer and winter a limit is
      ! inserted to avoid math errors when daylength reaches 24 hours in
      ! summer or 0 hours in winter.

      ! calculate solution for base=0 degrees
      if (dabs(aob) <= 1.d0) then

         dayl_  = 12.d0 * (1.d0 + 2.d0 * asin(aob) / pi)

         ! integrals of sine of solar height
         dsinb  = 3600.d0 * (dayl_ * sinld_ + 24.d0 * cosld_ * dsqrt(1.d0 - aob**2) / pi)
         dsinbe_ = 3600.d0 * (dayl_ * (sinld_ + 0.4d0 * (sinld_**2 + cosld_**2 * 0.5d0)) + &
                  12.d0 * cosld_ * (2.d0 + 3.d0 * 0.4d0 * sinld_) * dsqrt(1.d0 - aob**2) / pi)
      else

         if (aob > 1.d0)  dayl_ = 24.d0
         if (aob < -1.d0) dayl_ = 0.d0

         ! integrals of sine of solar height
         dsinb = 3600.d0 * (dayl_ * sinld_)
         dsinbe_ = 3600.d0 * (dayl_ * (sinld_ + 0.4d0 * (sinld_**2 + cosld_**2 * 0.5d0)))
      end if

      ! calculate solution for base=-4 (ANGLE) degrees
      aob_corr = (-dsin(angle * radial) + sinld_) / cosld_
      if (dabs(aob_corr) <= 1.0d0) then
         daylp_ = 12.d0 * (1.d0 + 2.d0 * asin(aob_corr) / pi)
      else
         if (aob_corr > 1.0d0)  daylp_ = 24.d0
         if (aob_corr < -1.0d0) daylp_ = 0.d0
      end if

      ! extraterrestrial radiation and atmospheric transmission
      angot = sc * dsinb

      ! check for DAYL=0 as in that case the angot radiation is 0 as well
      if (dayl_ > 0.d0) then
         atmtr_ = rad / angot
      else
         atmtr_ = 0.d0
      end if

      ! estimate fraction diffuse irradiation
      if (atmtr_ > 0.75d0) frdif = 0.23d0
      if (atmtr_ <= 0.75d0 .AND. atmtr_ > 0.35d0) frdif = 1.33d0 - 1.46d0 * atmtr_
      if (atmtr_ <= 0.35d0 .AND. atmtr_ > 0.07d0) frdif = 1.d0 - 2.3d0 * (atmtr_ - 0.07d0)**2
      if (atmtr_ <= 0.07d0) frdif = 1.d0

      difpp_ = frdif * atmtr_ * 0.5d0 * sc

  if(.not.all(ieee_is_finite([atmtr_,dayl_,daylp_,sinld_,cosld_,difpp_,dsinbe_])))return
  result=crop_solar_geometry_t(atmtr_,dayl_,daylp_,sinld_,cosld_,difpp_,dsinbe_)
  status=CROP_SOLAR_OK
 end subroutine
end module
