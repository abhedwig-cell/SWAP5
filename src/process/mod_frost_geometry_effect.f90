module mod_frost_geometry_effect
  use, intrinsic::iso_fortran_env,only:real64
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  implicit none
  private
  integer,parameter,public::FROST_GEOMETRY_OK=0,FROST_GEOMETRY_INVALID=1,FROST_GEOMETRY_UNBRACKETED=2
  type,public::frost_geometry_result_t
    logical::available=.false.
    integer::status=FROST_GEOMETRY_INVALID,deepest_node=-1
    real(real64)::top_depth_cm=0._real64,bottom_depth_cm=0._real64
  end type
  public::evaluate_legacy_bracketed_frost_geometry
contains
  pure subroutine evaluate_legacy_bracketed_frost_geometry(temperature,surface_c,start_c,end_c,z,distance,result)
    real(real64),intent(in)::temperature(:),surface_c,start_c,end_c,z(:),distance(:)
    type(frost_geometry_result_t),intent(out)::result
    integer::n,i,bottom
    result=frost_geometry_result_t();n=size(temperature)
    if(n<1.or.size(z)/=n.or.size(distance)/=n)return
    if(any(.not.ieee_is_finite(temperature)).or.any(.not.ieee_is_finite(z)))return
    if(any(.not.ieee_is_finite(distance)))return
    if(.not.all(ieee_is_finite([surface_c,start_c,end_c])))return
    if(start_c<=end_c)return
    if(any(z>=0._real64).or.any(distance<=0._real64))return
    do i=2,n
      if(z(i)>=z(i-1))return
      if(abs(distance(i)-(z(i-1)-z(i)))>1.e-10_real64)return
    end do
    ! Retain decrement-before-test legacy indexing; the last node is excluded.
    do i=1,n-1
      if(temperature(i)<=end_c+1.e-6_real64)result%deepest_node=i
    end do
    bottom=result%deepest_node
    if(bottom>0)then
      result%status=FROST_GEOMETRY_UNBRACKETED
      if(temperature(bottom)>end_c.or.temperature(bottom+1)<end_c)return
      if(temperature(bottom)==temperature(bottom+1))return
      result%bottom_depth_cm=z(bottom+1)+distance(bottom+1)*(end_c-temperature(bottom+1))/ &
           (temperature(bottom)-temperature(bottom+1))
      if(.not.ieee_is_finite(result%bottom_depth_cm))return
      if(result%bottom_depth_cm<z(bottom+1)-1.e-10_real64.or.result%bottom_depth_cm>z(bottom)+1.e-10_real64)return
      do i=1,bottom
        if(temperature(i)>end_c+1.e-6_real64)cycle
        if(temperature(i)>end_c)return
        if(i==1)then
          if(surface_c<=end_c)then
            result%top_depth_cm=0._real64
          else
            result%top_depth_cm=z(i)-(z(i)-0._real64)*(temperature(i)-end_c)/(temperature(i)-surface_c)
          end if
        else
          if(temperature(i-1)<end_c.or.temperature(i)==temperature(i-1))return
          result%top_depth_cm=z(i)+distance(i)*(temperature(i)-end_c)/(temperature(i)-temperature(i-1))
        end if
        if(.not.ieee_is_finite(result%top_depth_cm))return
        if(result%top_depth_cm>1.e-10_real64.or.result%top_depth_cm<z(i)-1.e-10_real64)return
        result%top_depth_cm=min(0._real64,result%top_depth_cm)
        exit
      end do
    end if
    result%status=FROST_GEOMETRY_OK;result%available=.true.
  end subroutine
end module
