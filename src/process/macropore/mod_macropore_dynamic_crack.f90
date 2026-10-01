module mod_macropore_dynamic_crack
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  type, public :: macropore_dynamic_crack_request_t
    integer :: num_nodes = 0
    real(real64), allocatable :: theta_previous(:)
    real(real64), allocatable :: theta_current(:)
    real(real64), allocatable :: theta_s(:)
    real(real64), allocatable :: theta_crack(:)
    real(real64), allocatable :: dz(:)
    real(real64), allocatable :: shrinkage_relative(:)
    real(real64), allocatable :: matrix_fraction(:)
    real(real64), allocatable :: geometry_factor(:)
    real(real64), allocatable :: minimum_subsidence_cm(:)
    real(real64), allocatable :: prior_dynamic_volume_cm(:)
  contains
    procedure, public :: valid => dynamic_crack_request_valid
  end type macropore_dynamic_crack_request_t

  type, public :: macropore_dynamic_crack_result_t
    logical :: valid = .false.
    real(real64), allocatable :: dynamic_volume_cm(:)
  end type macropore_dynamic_crack_result_t

  public :: evaluate_macropore_dynamic_crack

contains

  pure logical function dynamic_crack_request_valid(self) result(ok)
    class(macropore_dynamic_crack_request_t),intent(in)::self
    integer::n
    n=self%num_nodes
    ok=n>0 .and. allocated(self%theta_previous) .and. allocated(self%theta_current) .and. &
         allocated(self%theta_s) .and. allocated(self%theta_crack) .and. allocated(self%dz) .and. &
         allocated(self%shrinkage_relative) .and. allocated(self%matrix_fraction) .and. &
         allocated(self%geometry_factor) .and. allocated(self%minimum_subsidence_cm) .and. &
         allocated(self%prior_dynamic_volume_cm)
    if(.not.ok)return
    ok=size(self%theta_previous)==n .and. size(self%theta_current)==n .and. size(self%theta_s)==n .and. &
         size(self%theta_crack)==n .and. size(self%dz)==n .and. size(self%shrinkage_relative)==n .and. &
         size(self%matrix_fraction)==n .and. size(self%geometry_factor)==n .and. &
         size(self%minimum_subsidence_cm)==n .and. size(self%prior_dynamic_volume_cm)==n
    if(.not.ok)return
    ok=all(self%theta_s>=self%theta_crack) .and. all(self%dz>0.0_real64) .and. &
         all(self%shrinkage_relative>=0.0_real64) .and. all(self%shrinkage_relative<1.0_real64) .and. &
         all(self%matrix_fraction>=0.0_real64) .and. all(self%geometry_factor>0.0_real64) .and. &
         all(self%minimum_subsidence_cm>=0.0_real64) .and. all(self%prior_dynamic_volume_cm>=0.0_real64)
  end function dynamic_crack_request_valid

  subroutine evaluate_macropore_dynamic_crack(request,result)
    type(macropore_dynamic_crack_request_t),intent(in)::request
    type(macropore_dynamic_crack_result_t),intent(out)::result
    integer::ic,n
    real(real64)::neighbor,crit,vl_shri,subsidy,dynamic

    result=macropore_dynamic_crack_result_t()
    if(.not.request%valid())return
    n=request%num_nodes
    allocate(result%dynamic_volume_cm(n))
    result%dynamic_volume_cm=0.0_real64

    do ic=1,n
      dynamic=0.0_real64
      if(request%theta_current(ic)<request%theta_s(ic)-1.0e-4_real64)then
        neighbor=0.0_real64
        if(ic>1)neighbor=max(neighbor,request%prior_dynamic_volume_cm(ic-1))
        if(ic<n)neighbor=max(neighbor,request%prior_dynamic_volume_cm(ic+1))

        if(request%theta_current(ic)>request%theta_previous(ic)-1.0e-8_real64 .and. &
           (request%prior_dynamic_volume_cm(ic)>0.0_real64 .or. neighbor>0.0_real64))then
          crit=request%theta_s(ic)
        else
          crit=request%theta_crack(ic)
        end if

        if(request%theta_current(ic)<crit)then
          vl_shri=request%shrinkage_relative(ic)*request%dz(ic)
          subsidy=(1.0_real64-(1.0_real64-request%shrinkage_relative(ic))** &
               (1.0_real64/request%geometry_factor(ic)))*request%dz(ic)
          subsidy=max(subsidy,request%minimum_subsidence_cm(ic))
          if(request%dz(ic)-subsidy>1.0e-12_real64)then
            dynamic=request%matrix_fraction(ic)*(vl_shri-subsidy)*request%dz(ic) / &
                 (request%dz(ic)-subsidy)
          end if
        end if
      end if
      result%dynamic_volume_cm(ic)=max(0.0_real64,dynamic)
    end do
    result%valid=.true.
  end subroutine evaluate_macropore_dynamic_crack

end module mod_macropore_dynamic_crack
