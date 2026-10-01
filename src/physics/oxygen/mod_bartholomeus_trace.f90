module mod_bartholomeus_trace
   use iso_fortran_env, only : real64
   implicit none
   private
   public :: BartholomeusTrace
   public :: bartholomeus_trace_close

   type :: BartholomeusTrace
      real(real64) :: waterfilm_thickness_m = 0.0_real64
      real(real64) :: d_soil = 0.0_real64
      real(real64) :: r_microbial_z0 = 0.0_real64
      real(real64) :: ctopnode = 0.0_real64
      real(real64) :: c_macro = 0.0_real64
      real(real64) :: c_min_micro = 0.0_real64
      real(real64) :: resp_factor = 0.0_real64
      real(real64) :: rwu_factor = 0.0_real64
   end type BartholomeusTrace

contains

   pure logical function bartholomeus_trace_close(a,b,rtol,atol)
      type(BartholomeusTrace), intent(in) :: a,b
      real(real64), intent(in) :: rtol,atol
      bartholomeus_trace_close = close1(a%waterfilm_thickness_m,b%waterfilm_thickness_m,rtol,atol) .and. &
                                 close1(a%d_soil,b%d_soil,rtol,atol) .and. &
                                 close1(a%r_microbial_z0,b%r_microbial_z0,rtol,atol) .and. &
                                 close1(a%ctopnode,b%ctopnode,rtol,atol) .and. &
                                 close1(a%c_macro,b%c_macro,rtol,atol) .and. &
                                 close1(a%c_min_micro,b%c_min_micro,rtol,atol) .and. &
                                 close1(a%resp_factor,b%resp_factor,rtol,atol) .and. &
                                 close1(a%rwu_factor,b%rwu_factor,rtol,atol)
   end function

   pure logical function close1(x,y,rtol,atol)
      real(real64), intent(in) :: x,y,rtol,atol
      close1 = abs(x-y) <= atol + rtol*max(abs(x),abs(y))
   end function

end module mod_bartholomeus_trace
