! B1.11 MACRORATE section C: final domain rates to matrix compartment rates.
module mod_ppa_wu05a4_exchange_aggregate
  use, intrinsic::iso_fortran_env,only:real64
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  implicit none
  private
  public::aggregate_matrix_exchange
contains
  subroutine aggregate_matrix_exchange(top,bottom,saturated_out,unsaturated_out,internal_in,matrix_in, &
      top_vertical,rapid,domain_exchange,matrix_exchange,total_exchange,total_rapid,ok)
    integer,intent(in)::top,bottom(:)
    real(real64),intent(in)::saturated_out(:,:),unsaturated_out(:,:),internal_in(:,:),matrix_in(:,:)
    real(real64),intent(in)::top_vertical(:),rapid(:)
    real(real64),allocatable,intent(out)::domain_exchange(:,:),matrix_exchange(:)
    real(real64),intent(out)::total_exchange,total_rapid
    logical,intent(out)::ok
    integer::nd,n,id,ic
    ok=.false.; total_exchange=0; total_rapid=0
    nd=size(saturated_out,1); n=size(saturated_out,2)
    if(nd<1.or.n<1.or.top<1.or.top>n) return
    if(size(bottom)/=nd.or.size(top_vertical)/=nd.or.size(rapid)/=n) return
    if(any(shape(unsaturated_out)/=shape(saturated_out))) return
    if(any(shape(internal_in)/=shape(saturated_out))) return
    if(any(shape(matrix_in)/=shape(saturated_out))) return
    if(any(bottom<top).or.any(bottom>n)) return
    if(.not.all(ieee_is_finite(saturated_out)).or..not.all(ieee_is_finite(unsaturated_out))) return
    if(.not.all(ieee_is_finite(internal_in)).or..not.all(ieee_is_finite(matrix_in))) return
    if(.not.all(ieee_is_finite(top_vertical)).or..not.all(ieee_is_finite(rapid))) return
    if(any(saturated_out<0).or.any(unsaturated_out<0).or.any(internal_in<0).or.any(matrix_in<0)) return
    if(any(top_vertical<0).or.any(rapid<0)) return
    allocate(domain_exchange(nd,n),matrix_exchange(n))
    domain_exchange=0; matrix_exchange=0
    do id=1,nd
      do ic=top,bottom(id)
        domain_exchange(id,ic)=saturated_out(id,ic)+unsaturated_out(id,ic) &
            -(internal_in(id,ic)+matrix_in(id,ic))
      end do
      ! Below-surface macropore entry draws from the overlying matrix cell,
      ! not from an external top source. Preserve source overwrite semantics.
      if(top>1) domain_exchange(id,top-1)=-top_vertical(id)
    end do
    do ic=1,n
      matrix_exchange(ic)=matrix_exchange(ic)+sum(domain_exchange(:,ic))
      total_exchange=total_exchange+matrix_exchange(ic)
      total_rapid=total_rapid+rapid(ic)
    end do
    ok=.true.
  end subroutine
end module
