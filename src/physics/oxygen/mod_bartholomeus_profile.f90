module mod_bartholomeus_profile
   use iso_fortran_env, only : real64
   use mod_bartholomeus_response, only : BartholomeusResponseInput, bartholomeus_respiration_factor, &
                                         bartholomeus_rwu_factor
   use mod_bartholomeus_macro, only : bartholomeus_macro_concentration
   implicit none
   private

   integer, parameter, public :: BARTHOLOMEUS_PROFILE_OK = 0
   integer, parameter, public :: BARTHOLOMEUS_PROFILE_INVALID_INPUT = 1
   integer, parameter, public :: BARTHOLOMEUS_PROFILE_NODE_FAILURE = 2

   type, public :: BartholomeusProfileResult
      integer :: status = BARTHOLOMEUS_PROFILE_INVALID_INPUT
      real(real64), allocatable :: respiration_factor(:)
      real(real64), allocatable :: rwu_factor(:)
      real(real64), allocatable :: ctop(:)
      real(real64), allocatable :: c_macro(:)
   end type BartholomeusProfileResult

   public :: evaluate_bartholomeus_profile

contains

   subroutine evaluate_bartholomeus_profile(nodes, atmospheric_ctop, result)
      type(BartholomeusResponseInput), intent(in) :: nodes(:)
      real(real64), intent(in) :: atmospheric_ctop
      type(BartholomeusProfileResult), intent(out) :: result

      type(BartholomeusResponseInput) :: p
      real(real64) :: ctop, resp, cmacro
      logical :: ok
      integer :: i, n

      result = BartholomeusProfileResult()
      n = size(nodes)
      if (n <= 0 .or. atmospheric_ctop < 0.0_real64) return

      allocate(result%respiration_factor(n), result%rwu_factor(n), result%ctop(n), result%c_macro(n))
      result%respiration_factor = 0.0_real64
      result%rwu_factor = 0.0_real64
      result%ctop = 0.0_real64
      result%c_macro = 0.0_real64

      ctop = atmospheric_ctop
      do i = 1, n
         p = nodes(i)
         p%macro%ctop = ctop
         result%ctop(i) = ctop

         call bartholomeus_respiration_factor(p, resp, ok)
         if (.not. ok) then
            result%status = BARTHOLOMEUS_PROFILE_NODE_FAILURE
            return
         end if

         cmacro = bartholomeus_macro_concentration(p%macro, resp, ok)
         if (.not. ok) then
            result%status = BARTHOLOMEUS_PROFILE_NODE_FAILURE
            return
         end if

         result%respiration_factor(i) = resp
         result%rwu_factor(i) = bartholomeus_rwu_factor(resp, p%max_resp_factor)
         result%c_macro(i) = cmacro

         ! Exact legacy within-profile ownership:
         ! C_top(node+1) = C_macro(node).
         ctop = cmacro
      end do

      result%status = BARTHOLOMEUS_PROFILE_OK
   end subroutine evaluate_bartholomeus_profile

end module mod_bartholomeus_profile
