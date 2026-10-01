module mod_bartholomeus_response
   use iso_fortran_env, only : real64
   use mod_bartholomeus_micro, only : BartholomeusMicroInput, bartholomeus_micro_concentration
   use mod_bartholomeus_macro, only : BartholomeusMacroInput, bartholomeus_macro_concentration
   use mod_oxygen_scalar_bracket, only : oxygen_bisect_monotone, OXYGEN_INVALID_BRACKET
   implicit none
   private

   public :: BartholomeusResponseInput
   public :: bartholomeus_respiration_factor
   public :: bartholomeus_rwu_factor

   type :: BartholomeusResponseInput
      type(BartholomeusMicroInput) :: micro
      type(BartholomeusMacroInput) :: macro
      real(real64) :: max_resp_factor
   end type BartholomeusResponseInput

contains

   subroutine bartholomeus_respiration_factor(p, resp_factor, ok)
      type(BartholomeusResponseInput), intent(in) :: p
      real(real64), intent(out) :: resp_factor
      logical, intent(out) :: ok
      integer :: status

      ok = .false.
      if (p%max_resp_factor < 0.0_real64) then
         resp_factor = 0.0_real64
         return
      end if

      call oxygen_bisect_monotone(residual, p%max_resp_factor, resp_factor, status, xtol=1.0e-8_real64)
      if (status == OXYGEN_INVALID_BRACKET) return
      ok = .true.

   contains
      function residual(x) result(f)
         real(real64), intent(in) :: x
         real(real64) :: f, c_macro, c_micro
         logical :: macro_ok

         c_micro = bartholomeus_micro_concentration(p%micro,x)
         c_macro = bartholomeus_macro_concentration(p%macro,x,macro_ok)
         if (.not. macro_ok) then
            ! Invalid physical input is surfaced through a deliberately negative
            ! residual; caller validation must prevent this path in production.
            f = -huge(1.0_real64)
         else
            f = c_macro-c_micro
         end if
      end function residual
   end subroutine bartholomeus_respiration_factor

   pure function bartholomeus_rwu_factor(resp_factor,max_resp_factor) result(rwu_factor)
      real(real64), intent(in) :: resp_factor,max_resp_factor
      real(real64) :: rwu_factor

      if (max_resp_factor > 1.0_real64) then
         rwu_factor = (resp_factor-1.0_real64)/(max_resp_factor-1.0_real64)
      else
         if (resp_factor < 1.0_real64) then
            rwu_factor = 0.0_real64
         else
            rwu_factor = 1.0_real64
         end if
      end if
      rwu_factor = min(1.0_real64,max(0.0_real64,rwu_factor))
   end function bartholomeus_rwu_factor

end module mod_bartholomeus_response
