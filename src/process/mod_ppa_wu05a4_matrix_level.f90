! Restricted CALCGWL with macropores and zero critical unsaturated volume.
! Single bottom-connected saturated zone only; perched profiles are rejected.
module mod_ppa_wu05a4_matrix_level
  use, intrinsic::iso_fortran_env,only:real64
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  implicit none
  private
  public::matrix_level_from_heads
contains
  pure subroutine matrix_level_from_heads(head,z,dz,pond,level,top,ok)
    real(real64),intent(in)::head(:),z(:),dz(:),pond
    real(real64),intent(out)::level
    integer,intent(out)::top
    logical,intent(out)::ok
    integer::n,node,i
    level=999; top=0; ok=.false.
    n=size(head)
    if(n<1.or.size(z)/=n.or.size(dz)/=n)return
    if(.not.all(ieee_is_finite(head)).or..not.all(ieee_is_finite(z)))return
    if(.not.all(ieee_is_finite(dz)).or..not.ieee_is_finite(pond))return
    if(any(dz<=0).or.pond<0)return
    do i=2,n
      if(z(i)>=z(i-1))return
    end do
    if(head(n)<0)then
      if(any(head>=0))return
      top=n+1; ok=.true.; return
    end if
    node=n
    do while(node>1)
      node=node-1
      if(head(node)<0)then
        if(any(head(1:node)>=0))return
        level=z(node+1)+head(node+1)/(head(node+1)-head(node))*(z(node)-z(node+1))
        i=max(node-2,1)
        do while(z(i)-0.5_real64*dz(i)>level.and.i<n)
          i=i+1
        end do
        top=min(max(i,1),n); ok=.true.; return
      end if
    end do
    level=0
    if(head(1)>0)then
      if(pond<1.e-8_real64)then
        level=min(z(1)+head(1),pond)
      else
        level=pond
      end if
    end if
    top=1; ok=.true.
  end subroutine
end module
