module mod_ppa_wu05a6_saturated_exchange_rate
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  real(real64), parameter :: LOG_RATIO_SEEP_FACE = log(10.0_real64)
  real(real64), parameter :: PI_R = acos(-1.0_real64)
  real(real64), parameter :: GEOM_FAC_SEEP = 16.0_real64

  type, public :: saturated_exchange_request_t
    integer :: num_domains = 0
    integer :: num_nodes = 0
    integer :: matrix_top_saturated_node = 1
    integer :: matrix_bottom_saturated_node = 0
    integer :: swsep = 0
    real(real64) :: matrix_level = 0.0_real64
    real(real64) :: step_duration = 0.0_real64
    real(real64) :: flow_reduction = 1.0_real64
    real(real64) :: shape_factor = 1.0_real64
    integer, allocatable :: bottom_domain(:)
    integer, allocatable :: top_macro_saturated_node(:)
    real(real64), allocatable :: macro_saturated_fraction(:)
    real(real64), allocatable :: macro_reference_level(:)
    real(real64), allocatable :: z(:)
    real(real64), allocatable :: dz(:)
    real(real64), allocatable :: matrix_head(:)
    real(real64), allocatable :: ksat_horizontal(:)
    real(real64), allocatable :: diameter(:)
    real(real64), allocatable :: domain_fraction(:,:)
    real(real64), allocatable :: cdarcy(:,:)
  contains
    procedure, public :: valid => saturated_exchange_request_valid
  end type saturated_exchange_request_t

  type, public :: saturated_exchange_result_t
    logical :: valid = .false.
    real(real64), allocatable :: signed_matrix_to_macro_amount_cm(:,:)
    real(real64), allocatable :: matrix_to_macro_amount_cm(:,:)
    real(real64), allocatable :: macro_to_matrix_amount_cm(:,:)
    real(real64), allocatable :: qexc_to_matrix_rate_cm_per_day(:,:)
  end type saturated_exchange_result_t

  public :: evaluate_saturated_exchange

contains

  pure logical function saturated_exchange_request_valid(self) result(ok)
    class(saturated_exchange_request_t), intent(in) :: self
    integer :: nd,n

    nd=self%num_domains
    n=self%num_nodes
    ok=nd>0 .and. n>0 .and. self%matrix_top_saturated_node>=1 .and. &
         self%matrix_top_saturated_node<=n .and. self%matrix_bottom_saturated_node>=0 .and. &
         self%matrix_bottom_saturated_node<=n .and. self%step_duration>0.0_real64 .and. &
         self%flow_reduction>=0.0_real64 .and. self%shape_factor>=0.0_real64
    if(.not.ok)return

    ok=allocated(self%bottom_domain) .and. allocated(self%top_macro_saturated_node) .and. &
         allocated(self%macro_saturated_fraction) .and. allocated(self%macro_reference_level) .and. &
         allocated(self%z) .and. allocated(self%dz) .and. allocated(self%matrix_head) .and. &
         allocated(self%ksat_horizontal) .and. allocated(self%diameter) .and. &
         allocated(self%domain_fraction) .and. allocated(self%cdarcy)
    if(.not.ok)return

    ok=size(self%bottom_domain)==nd .and. size(self%top_macro_saturated_node)==nd .and. &
         size(self%macro_saturated_fraction)==nd .and. size(self%macro_reference_level)==nd .and. &
         size(self%z)==n .and. size(self%dz)==n .and. size(self%matrix_head)==n .and. &
         size(self%ksat_horizontal)==n .and. size(self%diameter)==n .and. &
         all(shape(self%domain_fraction)==[nd,n]) .and. all(shape(self%cdarcy)==[nd,n])
    if(.not.ok)return

    ok=all(self%macro_saturated_fraction>=0.0_real64) .and. &
         all(self%macro_saturated_fraction<=1.0_real64) .and. all(self%dz>0.0_real64) .and. &
         all(self%ksat_horizontal>=0.0_real64) .and. all(self%diameter>0.0_real64) .and. &
         all(self%domain_fraction>=0.0_real64) .and. all(self%cdarcy>=0.0_real64)
  end function saturated_exchange_request_valid

  subroutine evaluate_saturated_exchange(request,result)
    type(saturated_exchange_request_t),intent(in)::request
    type(saturated_exchange_result_t),intent(out)::result

    integer::id,ic,ic_bottom,nd,n
    real(real64)::hmp,hma,delh,recres,res_hor,res_vrt,res_rad,matrix_fraction,signed_amount

    result=saturated_exchange_result_t()
    if(.not.request%valid())return

    nd=request%num_domains
    n=request%num_nodes
    allocate(result%signed_matrix_to_macro_amount_cm(nd,n),result%matrix_to_macro_amount_cm(nd,n), &
         result%macro_to_matrix_amount_cm(nd,n),result%qexc_to_matrix_rate_cm_per_day(nd,n))
    result%signed_matrix_to_macro_amount_cm=0.0_real64
    result%matrix_to_macro_amount_cm=0.0_real64
    result%macro_to_matrix_amount_cm=0.0_real64
    result%qexc_to_matrix_rate_cm_per_day=0.0_real64

    do id=1,nd
      if(request%bottom_domain(id)<request%matrix_top_saturated_node .or. &
         request%matrix_bottom_saturated_node<=0)cycle
      ic_bottom=min(request%bottom_domain(id),request%matrix_bottom_saturated_node)

      do ic=request%matrix_top_saturated_node,ic_bottom
        hmp=request%macro_reference_level(id)-request%z(ic)
        if(hmp<1.0e-8_real64)hmp=0.0_real64
        hma=request%matrix_head(ic)
        delh=hmp-hma

        if(hmp<1.0e-8_real64 .and. delh>0.0_real64)delh=0.0_real64
        if(abs(delh)<1.0e-8_real64)delh=0.0_real64
        if(hma<0.0_real64)delh=0.0_real64

        signed_amount=0.0_real64

        if(delh>0.0_real64)then
          recres=request%cdarcy(id,ic)
          if(ic==request%top_macro_saturated_node(id)) &
               recres=request%macro_saturated_fraction(id)*recres
          signed_amount=-request%flow_reduction*recres*delh*request%step_duration

        else if(delh<0.0_real64)then
          matrix_fraction=1.0_real64
          if(ic==request%matrix_top_saturated_node)then
            matrix_fraction=(request%matrix_level-(request%z(ic)-0.5_real64*request%dz(ic))) / &
                 request%dz(ic)
          end if

          if(hmp>0.0_real64)then
            recres=request%cdarcy(id,ic)*matrix_fraction
          else
            if(request%swsep==1)then
              res_hor=request%diameter(ic)**2/(8.0_real64*request%dz(ic)*request%ksat_horizontal(ic))
              res_vrt=request%dz(ic)/request%ksat_horizontal(ic)
              res_rad=request%diameter(ic)*LOG_RATIO_SEEP_FACE/(PI_R*request%ksat_horizontal(ic))
              recres=request%domain_fraction(id,ic)/(res_hor+res_vrt+res_rad)*matrix_fraction
            else
              recres=request%shape_factor*GEOM_FAC_SEEP/request%diameter(ic)**2 * &
                   request%ksat_horizontal(ic)*request%dz(ic)*matrix_fraction
            end if
          end if
          signed_amount=-request%flow_reduction*recres*delh*request%step_duration
        end if

        result%signed_matrix_to_macro_amount_cm(id,ic)=signed_amount
        if(signed_amount>0.0_real64)then
          result%matrix_to_macro_amount_cm(id,ic)=signed_amount
        else if(signed_amount<0.0_real64)then
          result%macro_to_matrix_amount_cm(id,ic)=-signed_amount
        end if
        result%qexc_to_matrix_rate_cm_per_day(id,ic)= &
             (result%macro_to_matrix_amount_cm(id,ic)-result%matrix_to_macro_amount_cm(id,ic)) / &
             request%step_duration
      end do
    end do

    result%valid=.true.
  end subroutine evaluate_saturated_exchange

end module mod_ppa_wu05a6_saturated_exchange_rate
