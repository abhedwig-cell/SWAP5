  ! Private research closure for a positive upper pressure region and a
  ! bottom saturated region. Disconnection weights consume the configured
  ! physical pore deficit from depth upward. A vanishing layer has zero
  ! weight, so it cannot move the drainage level by whole compartments.
  pure subroutine evaluate_b111_pore_volume_connectivity(z,distance,dz,head,theta,theta_s,pond,critical,projection)
    real(real64),intent(in)::z(:),distance(:),dz(:),head(:),theta(:),theta_s(:),pond,critical
    type(b111_profile_groundwater_projection_t),intent(out)::projection
    type(b111_profile_groundwater_projection_t)::connected
    real(real64)::remaining,gap,amount,crossing,lower_head,level_delta
    integer::n,j
    call evaluate_b111_profile_groundwater_projection(z,distance,head,pond,projection)
    if(.not.projection%valid.or..not.projection%level_present)return
    n=size(head)
    if(n<3.or.head(1)<=0.0_real64.or.projection%crossing_lower_node<=1)return
    if(size(theta)/=n.or.size(theta_s)/=n.or.size(dz)/=n)then
      projection=b111_profile_groundwater_projection_t();return
    end if
    if(.not.ieee_is_finite(critical).or.any(.not.ieee_is_finite(theta)).or. &
       any(.not.ieee_is_finite(theta_s)).or.any(.not.ieee_is_finite(dz)).or.any(dz<=0.0_real64))then
      projection=b111_profile_groundwater_projection_t();return
    end if
    if(critical<=0.0_real64)return
    call evaluate_b111_profile_groundwater_projection(z,distance,max(head,0.0_real64),pond,connected)
    if(.not.connected%valid.or..not.connected%level_present)then
      projection=b111_profile_groundwater_projection_t();return
    end if
    remaining=critical;level_delta=0.0_real64
    do j=projection%crossing_lower_node,2,-1
      if(head(j)>=0.0_real64)cycle
      gap=dz(j)*max(0.0_real64,theta_s(j)-theta(j))
      if(gap<=0.0_real64)cycle
      if(j==projection%crossing_lower_node.and.gap>=critical)return
      amount=min(remaining,gap)
      lower_head=max(0.0_real64,head(j+1))
      crossing=z(j+1)+lower_head*distance(j+1)/(lower_head-head(j))
      level_delta=level_delta+(amount/critical)*(crossing-connected%level_cm)
      remaining=remaining-amount
      if(remaining<=0.0_real64)exit
    end do
    projection%level_cm=connected%level_cm+level_delta
    if(.not.ieee_is_finite(projection%level_cm))projection=b111_profile_groundwater_projection_t()
  end subroutine evaluate_b111_pore_volume_connectivity
