module mod_macropore_standard_storage
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_macropore_continuation_state, only: macropore_continuation_state_t, &
       copy_macropore_continuation_state
  use mod_ppa_wu05a5_top_partition, only: macropore_top_partition_result_t
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_result_t
  implicit none
  private

  type, public :: macropore_standard_storage_view_t
    logical :: valid=.false.
    integer :: num_domains=0
    integer :: num_nodes=0
    integer :: top_node=0
    integer,allocatable :: top_water_node(:)
    real(real64),allocatable :: wet_fraction(:,:)
    real(real64),allocatable :: normalized_water_cm(:,:)
    real(real64),allocatable :: water_level_cm(:)
    real(real64),allocatable :: total_water_cm(:)
  end type macropore_standard_storage_view_t

  type, public :: macropore_standard_candidate_receipt_t
    logical :: valid=.false.
    real(real64) :: accepted_top_cm=0.0_real64
    real(real64) :: returned_surface_cm=0.0_real64
    real(real64) :: internal_exchange_to_matrix_cm=0.0_real64
    real(real64) :: rapid_external_outflow_cm=0.0_real64
    real(real64) :: macro_storage_change_cm=0.0_real64
    real(real64) :: macro_balance_residual_cm=huge(1.0_real64)
  end type macropore_standard_candidate_receipt_t

  public :: derive_macropore_standard_storage_view
  public :: canonicalize_macropore_standard_storage
  public :: build_macropore_standard_candidate
  public :: apply_internal_covered_top_transfer

contains

  subroutine derive_macropore_standard_storage_view(state,top_node,z,dz,view)
    type(macropore_continuation_state_t),intent(in)::state
    integer,intent(in)::top_node
    real(real64),intent(in)::z(:),dz(:)
    type(macropore_standard_storage_view_t),intent(out)::view

    integer::nd,n,id,ic,bottom,topw
    real(real64)::total,capacity,remaining,vol,frac,zbottom

    view=macropore_standard_storage_view_t()
    if(.not.state%ready())return
    nd=state%num_domains
    n=state%num_nodes
    if(top_node<1 .or. top_node>n .or. size(z)/=n .or. size(dz)/=n .or. any(dz<=0.0_real64))return

    view%num_domains=nd
    view%num_nodes=n
    view%top_node=top_node
    allocate(view%top_water_node(nd),view%wet_fraction(nd,n),view%normalized_water_cm(nd,n), &
         view%water_level_cm(nd),view%total_water_cm(nd))
    view%wet_fraction=0.0_real64
    view%normalized_water_cm=0.0_real64

    do id=1,nd
      bottom=state%icp_bottom_domain(id)
      if(bottom<top_node .or. bottom>n)return
      if(state%volume_domain_cp(id,bottom)<=1.0e-8_real64)return
      if(any(state%volume_domain_cp(id,top_node:bottom)<0.0_real64))return
      if(any(state%water_domain_cp(id,top_node:bottom)<-1.0e-12_real64))return

      total=sum(max(0.0_real64,state%water_domain_cp(id,top_node:bottom)))
      capacity=sum(state%volume_domain_cp(id,top_node:bottom))
      if(total>capacity+1.0e-10_real64)return
      total=min(max(total,0.0_real64),capacity)
      view%total_water_cm(id)=total

      remaining=total
      topw=bottom
      do ic=bottom,top_node,-1
        vol=state%volume_domain_cp(id,ic)
        if(vol<=1.0e-12_real64)then
          if(remaining>1.0e-12_real64)return
          cycle
        end if
        if(remaining>=vol-1.0e-12_real64)then
          view%normalized_water_cm(id,ic)=vol
          view%wet_fraction(id,ic)=1.0_real64
          remaining=max(0.0_real64,remaining-vol)
          topw=ic
          if(remaining<=1.0e-12_real64)exit
        else
          view%normalized_water_cm(id,ic)=remaining
          frac=remaining/vol
          view%wet_fraction(id,ic)=max(0.0_real64,min(1.0_real64,frac))
          topw=ic
          remaining=0.0_real64
          exit
        end if
      end do
      if(remaining>1.0e-10_real64)return

      if(total<=1.0e-12_real64)then
        topw=bottom
        view%normalized_water_cm(id,:)=0.0_real64
        view%wet_fraction(id,:)=0.0_real64
      end if
      view%top_water_node(id)=topw

      zbottom=z(bottom)-0.5_real64*dz(bottom)
      view%water_level_cm(id)=zbottom + sum(view%wet_fraction(id,top_node:bottom)*dz(top_node:bottom))
    end do

    view%valid=.true.
  end subroutine derive_macropore_standard_storage_view

  subroutine canonicalize_macropore_standard_storage(state,top_node,z,dz,view,ok)
    type(macropore_continuation_state_t),intent(inout)::state
    integer,intent(in)::top_node
    real(real64),intent(in)::z(:),dz(:)
    type(macropore_standard_storage_view_t),intent(out)::view
    logical,intent(out)::ok

    call derive_macropore_standard_storage_view(state,top_node,z,dz,view)
    ok=view%valid
    if(.not.ok)return
    state%water_domain_cp=view%normalized_water_cm
  end subroutine canonicalize_macropore_standard_storage

  subroutine build_macropore_standard_candidate(accepted,geometry,top_partition,qexc_rate,rapid_cp_cm, &
       step_duration,top_node,z,dz,candidate,view,receipt,ok)
    type(macropore_continuation_state_t),intent(in)::accepted
    type(macropore_geometry_result_t),intent(in)::geometry
    type(macropore_top_partition_result_t),intent(in)::top_partition
    real(real64),intent(in)::qexc_rate(:,:)
    real(real64),intent(in)::rapid_cp_cm(:)
    real(real64),intent(in)::step_duration
    integer,intent(in)::top_node
    real(real64),intent(in)::z(:),dz(:)
    type(macropore_continuation_state_t),intent(inout)::candidate
    type(macropore_standard_storage_view_t),intent(out)::view
    type(macropore_standard_candidate_receipt_t),intent(out)::receipt
    logical,intent(out)::ok

    integer::nd,n,id
    real(real64)::old_total,new_total,capacity,top_amount,exchange_amount,rapid_amount

    receipt=macropore_standard_candidate_receipt_t()
    ok=.false.
    if(.not.accepted%ready() .or. .not.geometry%valid .or. .not.top_partition%valid)return
    if(step_duration<=0.0_real64)return
    nd=accepted%num_domains
    n=accepted%num_nodes
    if(geometry%num_domains/=nd .or. geometry%num_nodes/=n .or. top_partition%num_domains/=nd)return
    if(.not.all(shape(qexc_rate)==[nd,n]) .or. size(rapid_cp_cm)/=n)return
    if(any(rapid_cp_cm<0.0_real64))return

    call copy_macropore_continuation_state(accepted,candidate,ok)
    if(.not.ok)return
    ! Carry trial geometry and crack history in the same candidate owner as water.
    candidate%volume_domain_cp=geometry%volume_domain_cp
    candidate%dynamic_volume_cp=geometry%dynamic_volume_cp
    candidate%icp_bottom_domain=geometry%bottom_domain
    candidate%water_domain_cp=0.0_real64

    do id=1,nd
      old_total=sum(accepted%water_domain_cp(id,top_node:accepted%icp_bottom_domain(id)))
      top_amount=top_partition%accepted_vertical_cm(id)+top_partition%accepted_lateral_cm(id)
      ! Include water returned from compartments deactivated by the new geometry.
      exchange_amount=sum(qexc_rate(id,top_node:n))*step_duration
      rapid_amount=0.0_real64
      if(id==1)rapid_amount=sum(rapid_cp_cm(top_node:n))
      new_total=old_total+top_amount-exchange_amount-rapid_amount
      capacity=sum(geometry%volume_domain_cp(id,top_node:geometry%bottom_domain(id)))
      if(new_total<-1.0e-10_real64 .or. new_total>capacity+1.0e-10_real64)return
      new_total=min(max(new_total,0.0_real64),capacity)

      ! Store total provisionally at the active bottom; canonicalizer redistributes bottom-up.
      candidate%water_domain_cp(id,geometry%bottom_domain(id))=new_total
    end do

    call canonicalize_macropore_standard_storage(candidate,top_node,z,dz,view,ok)
    if(.not.ok)return

    receipt%accepted_top_cm=top_partition%accepted_total_cm
    receipt%returned_surface_cm=top_partition%returned_surface_cm
    receipt%internal_exchange_to_matrix_cm=sum(qexc_rate)*step_duration
    receipt%rapid_external_outflow_cm=sum(rapid_cp_cm)
    receipt%macro_storage_change_cm=sum(candidate%water_domain_cp)-sum(accepted%water_domain_cp)
    receipt%macro_balance_residual_cm=receipt%macro_storage_change_cm - &
         (receipt%accepted_top_cm-receipt%internal_exchange_to_matrix_cm-receipt%rapid_external_outflow_cm)
    receipt%valid=abs(receipt%macro_balance_residual_cm)<=1.0e-10_real64
    ok=receipt%valid
  end subroutine build_macropore_standard_candidate

  subroutine apply_internal_covered_top_transfer(candidate,geometry,top_node,covered_domain_cm,z,dz,view,ok)
    type(macropore_continuation_state_t),intent(inout)::candidate
    type(macropore_geometry_result_t),intent(in)::geometry
    integer,intent(in)::top_node
    real(real64),intent(in)::covered_domain_cm(:),z(:),dz(:)
    type(macropore_standard_storage_view_t),intent(out)::view
    logical,intent(out)::ok
    integer::id
    real(real64)::total,capacity

    ok=.false.
    if(.not.candidate%ready() .or. .not.geometry%valid)return
    if(top_node<=1 .or. top_node/=geometry%top_node)return
    if(size(covered_domain_cm)/=candidate%num_domains .or. any(covered_domain_cm<0.0_real64))return
    do id=1,candidate%num_domains
      total=sum(candidate%water_domain_cp(id,top_node:geometry%bottom_domain(id)))+covered_domain_cm(id)
      capacity=sum(geometry%volume_domain_cp(id,top_node:geometry%bottom_domain(id)))
      if(total>capacity+1.0e-10_real64)return
      candidate%water_domain_cp(id,:)=0.0_real64
      candidate%water_domain_cp(id,geometry%bottom_domain(id))=min(max(total,0.0_real64),capacity)
    end do
    call canonicalize_macropore_standard_storage(candidate,top_node,z,dz,view,ok)
  end subroutine apply_internal_covered_top_transfer

end module mod_macropore_standard_storage
