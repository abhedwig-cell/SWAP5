module mod_rfm_ic_hydrostatic_head
 use,intrinsic::iso_fortran_env,only:real64
 use,intrinsic::ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 type,public::rfm_ic_hydrostatic_head_result_t
  logical::valid=.false.
  real(real64)::water_level_depth_cm=0.0_real64
  real(real64)::macropore_pressure_head_cm=0.0_real64
  real(real64)::macro_to_matrix_head_difference_cm=0.0_real64
 end type
 public::derive_rfm_ic_hydrostatic_head
contains
 pure subroutine derive_rfm_ic_hydrostatic_head(endpoint_bottom_depth_cm,contact_thickness_cm,water_column_height_cm, &
      matrix_node_depth_cm,matrix_pressure_head_cm,result)
  real(real64),intent(in)::endpoint_bottom_depth_cm,contact_thickness_cm,water_column_height_cm
  real(real64),intent(in)::matrix_node_depth_cm,matrix_pressure_head_cm
  type(rfm_ic_hydrostatic_head_result_t),intent(out)::result
  real(real64)::segment_top,water_level_depth,hmp
  result=rfm_ic_hydrostatic_head_result_t()
  if(.not.all(ieee_is_finite([endpoint_bottom_depth_cm,contact_thickness_cm,water_column_height_cm, &
       matrix_node_depth_cm,matrix_pressure_head_cm])))return
  if(endpoint_bottom_depth_cm<=0.0_real64.or.contact_thickness_cm<=0.0_real64)return
  if(water_column_height_cm<0.0_real64.or.water_column_height_cm>contact_thickness_cm)return
  segment_top=endpoint_bottom_depth_cm-contact_thickness_cm
  if(segment_top<0.0_real64)return
  if(matrix_node_depth_cm<segment_top.or.matrix_node_depth_cm>endpoint_bottom_depth_cm)return
  water_level_depth=endpoint_bottom_depth_cm-water_column_height_cm
  ! Elevation z is positive upward; using positive-downward depths d gives
  ! h_mp = phi_mp-z = (-d_water)-(-d_node) = d_node-d_water.
  hmp=matrix_node_depth_cm-water_level_depth
  result%water_level_depth_cm=water_level_depth
  result%macropore_pressure_head_cm=hmp
  result%macro_to_matrix_head_difference_cm=max(0.0_real64,hmp-matrix_pressure_head_cm)
  result%valid=.true.
 end subroutine
end module
