module mod_ppa_wu05a6_top_inflow_limiter
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  type, public :: standard_inflow_limit_request_t
    integer :: num_domains = 0
    real(real64), allocatable :: accepted_storage_cm(:)
    real(real64), allocatable :: maximum_storage_cm(:)
    real(real64), allocatable :: minimum_storage_cm(:)
    real(real64), allocatable :: potential_top_vertical_cm(:)
    real(real64), allocatable :: potential_top_lateral_cm(:)
    real(real64), allocatable :: potential_interflow_sat_cm(:)
    real(real64), allocatable :: potential_matrix_sat_cm(:)
    real(real64), allocatable :: potential_outflow_cm(:)
    real(real64), allocatable :: redistribution_capacity_cm(:)
    real(real64), allocatable :: top_domain_fraction(:)
  contains
    procedure, public :: valid => standard_limit_request_valid
  end type standard_inflow_limit_request_t

  type, public :: standard_inflow_limit_result_t
    logical :: valid = .false.
    real(real64), allocatable :: inflow_fraction(:)
    real(real64), allocatable :: accepted_top_vertical_cm(:)
    real(real64), allocatable :: accepted_top_lateral_cm(:)
    real(real64), allocatable :: accepted_interflow_sat_cm(:)
    real(real64), allocatable :: accepted_matrix_sat_cm(:)
    real(real64), allocatable :: redistributed_top_cm(:)
    real(real64), allocatable :: outflow_fraction(:)
    real(real64), allocatable :: residual_outflow_excess_cm(:)
    real(real64) :: rejected_top_before_redistribution_cm = 0.0_real64
    real(real64) :: redistributed_total_cm = 0.0_real64
    real(real64) :: returned_surface_cm = 0.0_real64
    real(real64) :: top_receipt_residual_cm = huge(1.0_real64)
  end type standard_inflow_limit_result_t

  public :: evaluate_standard_inflow_limit

contains

  pure logical function standard_limit_request_valid(self) result(ok)
    class(standard_inflow_limit_request_t), intent(in) :: self
    integer :: nd

    nd=self%num_domains
    ok=nd>0
    if(.not.ok)return
    ok=allocated(self%accepted_storage_cm) .and. allocated(self%maximum_storage_cm) .and. &
         allocated(self%minimum_storage_cm) .and. &
         allocated(self%potential_top_vertical_cm) .and. allocated(self%potential_top_lateral_cm) .and. &
         allocated(self%potential_interflow_sat_cm) .and. allocated(self%potential_matrix_sat_cm) .and. &
         allocated(self%potential_outflow_cm) .and. allocated(self%redistribution_capacity_cm) .and. &
         allocated(self%top_domain_fraction)
    if(.not.ok)return
    ok=size(self%accepted_storage_cm)==nd .and. size(self%maximum_storage_cm)==nd .and. &
         size(self%minimum_storage_cm)==nd .and. &
         size(self%potential_top_vertical_cm)==nd .and. size(self%potential_top_lateral_cm)==nd .and. &
         size(self%potential_interflow_sat_cm)==nd .and. size(self%potential_matrix_sat_cm)==nd .and. &
         size(self%potential_outflow_cm)==nd .and. size(self%redistribution_capacity_cm)==nd .and. &
         size(self%top_domain_fraction)==nd
    if(.not.ok)return
    ok=all(self%accepted_storage_cm>=0.0_real64) .and. all(self%maximum_storage_cm>=0.0_real64) .and. &
         all(self%minimum_storage_cm>=0.0_real64) .and. all(self%minimum_storage_cm<=self%maximum_storage_cm) .and. &
         all(self%potential_top_vertical_cm>=0.0_real64) .and. all(self%potential_top_lateral_cm>=0.0_real64) .and. &
         all(self%potential_interflow_sat_cm>=0.0_real64) .and. all(self%potential_matrix_sat_cm>=0.0_real64) .and. &
         all(self%potential_outflow_cm>=0.0_real64) .and. all(self%redistribution_capacity_cm>=0.0_real64) .and. &
         all(self%top_domain_fraction>=0.0_real64) .and. &
         abs(sum(self%top_domain_fraction)-1.0_real64)<=1.0e-12_real64
  end function standard_limit_request_valid

  subroutine evaluate_standard_inflow_limit(request,result)
    type(standard_inflow_limit_request_t), intent(in) :: request
    type(standard_inflow_limit_result_t), intent(out) :: result

    real(real64), allocatable :: inflow_total(:), rejected_top(:), deficit(:), deficit_rel(:), outflow_excess(:)
    real(real64) :: temporary_storage, excess, top_potential, factor, pp_total, share, transfer
    real(real64) :: requested_top_total, final_top_total
    integer, allocatable :: order(:)
    integer :: nd,id,jd,i,j,tmp

    result=standard_inflow_limit_result_t()
    if(.not.request%valid())return
    nd=request%num_domains
    allocate(result%inflow_fraction(nd),result%accepted_top_vertical_cm(nd), &
         result%accepted_top_lateral_cm(nd),result%accepted_interflow_sat_cm(nd), &
         result%accepted_matrix_sat_cm(nd),result%redistributed_top_cm(nd),result%outflow_fraction(nd), &
         result%residual_outflow_excess_cm(nd),inflow_total(nd),rejected_top(nd),deficit(nd),deficit_rel(nd), &
         outflow_excess(nd),order(nd))

    inflow_total=request%potential_top_vertical_cm+request%potential_top_lateral_cm + &
         request%potential_interflow_sat_cm+request%potential_matrix_sat_cm
    result%inflow_fraction=1.0_real64
    result%accepted_top_vertical_cm=0.0_real64
    result%accepted_top_lateral_cm=0.0_real64
    result%accepted_interflow_sat_cm=0.0_real64
    result%accepted_matrix_sat_cm=0.0_real64
    result%redistributed_top_cm=0.0_real64
    result%outflow_fraction=1.0_real64
    result%residual_outflow_excess_cm=0.0_real64
    rejected_top=0.0_real64
    outflow_excess=0.0_real64

    do id=1,nd
      temporary_storage=request%accepted_storage_cm(id)+inflow_total(id)-request%potential_outflow_cm(id)
      if(temporary_storage>request%maximum_storage_cm(id)+1.0e-7_real64 .and. inflow_total(id)>0.0_real64)then
        excess=temporary_storage-request%maximum_storage_cm(id)
        result%inflow_fraction(id)=max(0.0_real64,1.0_real64-excess/inflow_total(id))
      end if
      if(inflow_total(id)<0.0_real64)result%inflow_fraction(id)=0.0_real64

      factor=result%inflow_fraction(id)
      result%accepted_top_vertical_cm(id)=factor*request%potential_top_vertical_cm(id)
      result%accepted_top_lateral_cm(id)=factor*request%potential_top_lateral_cm(id)
      result%accepted_interflow_sat_cm(id)=factor*request%potential_interflow_sat_cm(id)
      result%accepted_matrix_sat_cm(id)=factor*request%potential_matrix_sat_cm(id)
      rejected_top(id)=(1.0_real64-factor) * &
           (request%potential_top_vertical_cm(id)+request%potential_top_lateral_cm(id))
      if (temporary_storage < request%minimum_storage_cm(id)) &
           outflow_excess(id)=request%minimum_storage_cm(id)-temporary_storage
    end do

    result%rejected_top_before_redistribution_cm=sum(rejected_top)
    excess=result%rejected_top_before_redistribution_cm
    deficit=request%redistribution_capacity_cm
    do id=1,nd
      if(request%maximum_storage_cm(id)>1.0e-30_real64)then
        deficit_rel(id)=deficit(id)/request%maximum_storage_cm(id)
      else
        deficit_rel(id)=0.0_real64
      end if
      order(id)=id
    end do

    do i=1,nd-1
      do j=i+1,nd
        if(deficit_rel(order(i))>deficit_rel(order(j)))then
          tmp=order(i); order(i)=order(j); order(j)=tmp
        end if
      end do
    end do

    pp_total=1.0_real64
    do i=1,nd
      jd=order(i)
      top_potential=request%potential_top_vertical_cm(jd)+request%potential_top_lateral_cm(jd)
      if(deficit(jd)>1.0e-7_real64 .and. top_potential>1.0e-7_real64 .and. excess>1.0e-12_real64)then
        if(pp_total>1.0e-30_real64)then
          share=request%top_domain_fraction(jd)/pp_total
        else
          share=0.0_real64
        end if
        transfer=min(share*excess,deficit(jd))
        factor=transfer/top_potential
        result%accepted_top_vertical_cm(jd)=result%accepted_top_vertical_cm(jd) + &
             factor*request%potential_top_vertical_cm(jd)
        result%accepted_top_lateral_cm(jd)=result%accepted_top_lateral_cm(jd) + &
             factor*request%potential_top_lateral_cm(jd)
        result%redistributed_top_cm(jd)=transfer
        excess=max(0.0_real64,excess-transfer)
        deficit(jd)=max(0.0_real64,deficit(jd)-transfer)
        outflow_excess(jd)=max(0.0_real64,outflow_excess(jd)-transfer)
      end if
      pp_total=pp_total-request%top_domain_fraction(jd)
    end do

    result%redistributed_total_cm=sum(result%redistributed_top_cm)
    result%returned_surface_cm=max(0.0_real64,excess)

    do id=1,nd
      result%residual_outflow_excess_cm(id)=outflow_excess(id)
      if (outflow_excess(id)>1.0e-7_real64) then
        if (request%potential_outflow_cm(id)>outflow_excess(id)) then
          result%outflow_fraction(id)=max(0.0_real64, &
               1.0_real64-outflow_excess(id)/request%potential_outflow_cm(id))
        else
          result%outflow_fraction(id)=0.0_real64
        end if
      end if
    end do

    requested_top_total=sum(request%potential_top_vertical_cm)+sum(request%potential_top_lateral_cm)
    final_top_total=sum(result%accepted_top_vertical_cm)+sum(result%accepted_top_lateral_cm)
    result%top_receipt_residual_cm=final_top_total+result%returned_surface_cm-requested_top_total
    result%valid=abs(result%top_receipt_residual_cm)<=1.0e-12_real64
  end subroutine evaluate_standard_inflow_limit

end module mod_ppa_wu05a6_top_inflow_limiter
