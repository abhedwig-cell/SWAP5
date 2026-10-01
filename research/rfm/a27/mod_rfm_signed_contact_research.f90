module mod_rfm_signed_contact_research
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 type,public::signed_contact_request_t
  logical::finite_contact=.false.
  real(real64)::dt=0.,storage=0.,capacity=0.,area=0.,bottom_depth=0.,length=0.,chi=0.,age=0.
  real(real64),allocatable::depth(:),thickness(:),matrix_head(:),conductivity(:),sorptivity(:),donor_water(:),receiver_space(:)
 end type
 type,public::signed_contact_result_t
  logical::valid=.false.
  real(real64)::storage_candidate=0.,ledger_residual=0.
  real(real64),allocatable::matrix_gain(:),matrix_loss(:)
 end type
 public::evaluate_signed_contact
contains
 pure subroutine evaluate_signed_contact(q,r)
  type(signed_contact_request_t),intent(in)::q
  type(signed_contact_result_t),intent(out)::r
  real(real64)::phi,hmp,dh,darcy,philip,rate,rootdiff,fill,release
  real(real64)::lo,hi,wetlo,cd,cp,cross
  integer::i,n
  r=signed_contact_result_t()
  if(.not.all(ieee_is_finite([q%dt,q%storage,q%capacity,q%area,q%bottom_depth,q%length,q%chi,q%age])))return
  if(q%dt<=0.or.q%capacity<=0.or.q%storage<0.or.q%storage>q%capacity.or.q%area<=0.or.q%area>1.or.q%length<=0.or.q%chi<0.or.q%age<0)return
  if(.not.allocated(q%depth).or..not.allocated(q%thickness).or..not.allocated(q%matrix_head).or..not.allocated(q%conductivity).or..not.allocated(q%sorptivity).or..not.allocated(q%donor_water).or..not.allocated(q%receiver_space))return
  n=size(q%depth)
  if(n<1)return
  if(size(q%thickness)/=n.or.size(q%matrix_head)/=n.or.size(q%conductivity)/=n.or.size(q%sorptivity)/=n.or.size(q%donor_water)/=n.or.size(q%receiver_space)/=n)return
  if(.not.all(ieee_is_finite(q%depth)).or..not.all(ieee_is_finite(q%thickness)).or..not.all(ieee_is_finite(q%matrix_head)).or..not.all(ieee_is_finite(q%conductivity)).or..not.all(ieee_is_finite(q%sorptivity)).or..not.all(ieee_is_finite(q%donor_water)).or..not.all(ieee_is_finite(q%receiver_space)))return
  if(any(q%depth<0).or.any(q%depth>q%bottom_depth).or.any(q%thickness<=0).or.any(q%conductivity<0).or.any(q%sorptivity<0).or.any(q%donor_water<0).or.any(q%receiver_space<0))return
  if(q%capacity/q%area>q%bottom_depth)return
  allocate(r%matrix_gain(n),r%matrix_loss(n));r%matrix_gain=0.;r%matrix_loss=0.
  phi=-q%bottom_depth+q%storage/q%area
  rootdiff=q%dt/(sqrt(q%age+q%dt)+sqrt(q%age))
  do i=1,n
   hmp=max(0._real64,phi+q%depth(i));dh=hmp-q%matrix_head(i)
   darcy=8._real64*q%conductivity(i)*q%thickness(i)*dh*q%dt/q%length**2
   if(q%finite_contact)then
    ! Integrate over the vertical contact segment, not its representative point.
    lo=max(0._real64,q%depth(i)-q%thickness(i)/2)
    hi=min(q%bottom_depth,q%depth(i)+q%thickness(i)/2)
    cd=8._real64*q%conductivity(i)*q%dt/q%length**2
    if(q%matrix_head(i)>=0.)then
     rate=cd*(.5_real64*(max(0._real64,phi+hi)**2-max(0._real64,phi+lo)**2)-q%matrix_head(i)*(hi-lo))
    else
     wetlo=max(lo,-phi);rate=0._real64
     if(hi>wetlo)then
      cp=q%chi*4._real64/q%length*q%sorptivity(i)*rootdiff
      if(cd>0.)then
       cross=max(wetlo,min(hi,cp/cd-phi+q%matrix_head(i)))
       rate=cp*(cross-wetlo)+cd*((phi-q%matrix_head(i))*(hi-cross)+.5_real64*(hi**2-cross**2))
      else
       rate=cp*(hi-wetlo)
      endif
     endif
    endif
   else if(q%matrix_head(i)>=0.)then
    ! Saturated contact: signed Darcy only. No second Philip contribution.
    rate=darcy
   else if(phi+q%depth(i)>0.)then
    ! Wetted macropore facing unsaturated matrix: preserve A22A max law.
    philip=q%chi*4._real64/q%length*q%sorptivity(i)*rootdiff*q%thickness(i)
    rate=max(philip,max(0._real64,darcy))
   else
    rate=0._real64
   endif
   if(rate>=0.)then
    r%matrix_gain(i)=min(rate,q%receiver_space(i))
   else
    r%matrix_loss(i)=min(-rate,q%donor_water(i))
   endif
  enddo
  fill=sum(r%matrix_loss);release=sum(r%matrix_gain)
  if(fill>0.)r%matrix_loss=r%matrix_loss*min(1._real64,(q%capacity-q%storage)/fill)
  if(release>0.)r%matrix_gain=r%matrix_gain*min(1._real64,q%storage/release)
  r%storage_candidate=q%storage+sum(r%matrix_loss)-sum(r%matrix_gain)
  r%ledger_residual=r%storage_candidate-q%storage-sum(r%matrix_loss)+sum(r%matrix_gain)
  r%valid=ieee_is_finite(r%storage_candidate).and.abs(r%ledger_residual)<1e-12_real64.and.r%storage_candidate>=-1e-12_real64.and.r%storage_candidate<=q%capacity+1e-12_real64
 end subroutine
end module
