module mod_rfm_endpoint_release
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  type, public :: rfm_endpoint_release_request_t
    real(real64) :: step_duration_day = 0.0_real64
    real(real64), allocatable :: accepted_storage_cm(:), contact_thickness_cm(:), exchange_length_cm(:)
    real(real64), allocatable :: chi_wall(:), wall_sorptivity_cm_sqrt_day(:)
    real(real64), allocatable :: matrix_conductivity_cm_per_day(:), macro_to_matrix_head_difference_cm(:)
    real(real64), allocatable :: accepted_wall_age_day(:)
  contains
    procedure, public :: valid => request_valid
  end type

  type, public :: rfm_endpoint_release_result_t
    logical :: valid = .false.
    real(real64), allocatable :: philip_potential_cm(:), darcy_potential_cm(:), release_to_matrix_cm(:)
    real(real64), allocatable :: candidate_storage_cm(:), candidate_wall_age_day(:)
    real(real64), allocatable :: candidate_wall_sorptivity_cm_sqrt_day(:)
    real(real64) :: storage_start_cm=0.0_real64, release_total_cm=0.0_real64
    real(real64) :: storage_end_cm=0.0_real64, mass_residual_cm=0.0_real64
  end type

  public :: evaluate_rfm_endpoint_release

contains

  pure logical function request_valid(self) result(ok)
    class(rfm_endpoint_release_request_t), intent(in) :: self
    integer :: n
    ok=ieee_is_finite(self%step_duration_day).and.self%step_duration_day>0.0_real64 .and. &
       allocated(self%accepted_storage_cm).and.allocated(self%contact_thickness_cm).and. &
       allocated(self%exchange_length_cm).and.allocated(self%chi_wall).and. &
       allocated(self%wall_sorptivity_cm_sqrt_day).and.allocated(self%matrix_conductivity_cm_per_day).and. &
       allocated(self%macro_to_matrix_head_difference_cm).and.allocated(self%accepted_wall_age_day)
    if(.not.ok)return
    n=size(self%accepted_storage_cm)
    ok=n>0.and.size(self%contact_thickness_cm)==n.and.size(self%exchange_length_cm)==n.and. &
       size(self%chi_wall)==n.and.size(self%wall_sorptivity_cm_sqrt_day)==n.and. &
       size(self%matrix_conductivity_cm_per_day)==n.and.size(self%macro_to_matrix_head_difference_cm)==n.and. &
       size(self%accepted_wall_age_day)==n
    if(.not.ok)return
    ok=all(ieee_is_finite(self%accepted_storage_cm)).and.all(self%accepted_storage_cm>=0.0_real64).and. &
       all(ieee_is_finite(self%contact_thickness_cm)).and.all(self%contact_thickness_cm>0.0_real64).and. &
       all(ieee_is_finite(self%exchange_length_cm)).and.all(self%exchange_length_cm>0.0_real64).and. &
       all(ieee_is_finite(self%chi_wall)).and.all(self%chi_wall>=0.0_real64).and. &
       all(ieee_is_finite(self%wall_sorptivity_cm_sqrt_day)).and.all(self%wall_sorptivity_cm_sqrt_day>=0.0_real64).and. &
       all(ieee_is_finite(self%matrix_conductivity_cm_per_day)).and.all(self%matrix_conductivity_cm_per_day>=0.0_real64).and. &
       all(ieee_is_finite(self%macro_to_matrix_head_difference_cm)).and. &
       all(self%macro_to_matrix_head_difference_cm>=0.0_real64).and. &
       all(ieee_is_finite(self%accepted_wall_age_day)).and.all(self%accepted_wall_age_day>=0.0_real64)
  end function

  pure subroutine evaluate_rfm_endpoint_release(request,tolerance,result)
    type(rfm_endpoint_release_request_t),intent(in)::request
    real(real64),intent(in)::tolerance
    type(rfm_endpoint_release_result_t),intent(out)::result
    integer::i,n
    real(real64)::droot,potential,release
    result=rfm_endpoint_release_result_t()
    if(.not.request%valid())return
    if(.not.ieee_is_finite(tolerance).or.tolerance<0.0_real64)return
    n=size(request%accepted_storage_cm)
    allocate(result%philip_potential_cm(n),result%darcy_potential_cm(n),result%release_to_matrix_cm(n), &
      result%candidate_storage_cm(n),result%candidate_wall_age_day(n),result%candidate_wall_sorptivity_cm_sqrt_day(n))
    do i=1,n
      droot=sqrt(request%accepted_wall_age_day(i)+request%step_duration_day)-sqrt(request%accepted_wall_age_day(i))
      result%philip_potential_cm(i)=request%chi_wall(i)*(4.0_real64/request%exchange_length_cm(i))* &
        request%wall_sorptivity_cm_sqrt_day(i)*droot*request%contact_thickness_cm(i)
      result%darcy_potential_cm(i)=8.0_real64*request%matrix_conductivity_cm_per_day(i)* &
        request%macro_to_matrix_head_difference_cm(i)/request%exchange_length_cm(i)**2* &
        request%step_duration_day*request%contact_thickness_cm(i)
      potential=max(result%philip_potential_cm(i),result%darcy_potential_cm(i))
      release=min(request%accepted_storage_cm(i),max(0.0_real64,potential))
      result%release_to_matrix_cm(i)=release
      result%candidate_storage_cm(i)=request%accepted_storage_cm(i)-release
      if(result%candidate_storage_cm(i)>tolerance)then
        result%candidate_wall_age_day(i)=request%accepted_wall_age_day(i)+request%step_duration_day
        result%candidate_wall_sorptivity_cm_sqrt_day(i)=request%wall_sorptivity_cm_sqrt_day(i)
      else
        result%candidate_storage_cm(i)=0.0_real64
        result%candidate_wall_age_day(i)=0.0_real64
        result%candidate_wall_sorptivity_cm_sqrt_day(i)=0.0_real64
      end if
    end do
    result%storage_start_cm=sum(request%accepted_storage_cm)
    result%release_total_cm=sum(result%release_to_matrix_cm)
    result%storage_end_cm=sum(result%candidate_storage_cm)
    result%mass_residual_cm=result%storage_start_cm-result%release_total_cm-result%storage_end_cm
    if(abs(result%mass_residual_cm)>tolerance)return
    result%valid=.true.
  end subroutine
end module mod_rfm_endpoint_release
