module mod_fmr_divdra_dislayer_binding
 use, intrinsic :: iso_fortran_env,only:real64
 use, intrinsic :: ieee_arithmetic,only:ieee_is_finite
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_drainage_spatial_distribution,only:drainage_distribution_parameters_t,drainage_node_transfer_t, &
      drainage_distribution_diagnostics_t,drainage_multilevel_diagnostics_t,distribute_single_level_signed_divdra, &
      distribute_multilevel_signed_divdra,DRAIN_DIST_OK
 use mod_drainage_discharge_layer_transform
 use mod_fmr_divdra_runtime_binding,only:fmr_bind_single_level_signed_divdra,fmr_bind_multilevel_signed_divdra, &
      fmr_divdra_binding_diagnostics_t,fmr_divdra_multilevel_binding_diagnostics_t
 use mod_drainage_b19_separate_infiltration_adapter,only:drainage_b19_separate_infiltration_parameters_t, &
      drainage_b19_separate_infiltration_result_t,distribute_single_level_separate_infiltration_b19, &
      distribute_multilevel_separate_infiltration_b19,DRAIN_B19_INF_OK
 use mod_fmr_divdra_separate_infiltration_binding,only:fmr_bind_separate_infiltration, &
      fmr_divdra_separate_infiltration_binding_diagnostics_t
 implicit none
 private
 integer,parameter,public::FMR_DIVDRA_DISLAYER_OK=0,FMR_DIVDRA_DISLAYER_REJECTED=1,FMR_DIVDRA_DISLAYER_PREBOUND=2
 type,public::fmr_divdra_dislayer_diagnostics_t
  integer::status=FMR_DIVDRA_DISLAYER_REJECTED
  logical::published=.false.
  real(real64),allocatable::authoritative_scalar_transfer(:)
  type(discharge_layer_diagnostics_t),allocatable::levels(:)
 end type
 public::fmr_bind_dislayer
contains
 subroutine fmr_bind_dislayer(p,view,q,controls,target,diagnostics,inf_controls)
  type(drainage_distribution_parameters_t),intent(in)::p(:)
  type(process_hydraulic_view_t),intent(in)::view
  real(real64),intent(in)::q(:)
  type(discharge_layer_top_control_t),intent(in)::controls(:)
  real(real64),allocatable,intent(inout)::target(:,:)
  type(fmr_divdra_dislayer_diagnostics_t),intent(out)::diagnostics
  type(drainage_b19_separate_infiltration_parameters_t),optional,intent(in)::inf_controls(:)
  real(real64),allocatable::scratch(:,:),tops(:)
  type(fmr_divdra_binding_diagnostics_t)::single
  type(fmr_divdra_multilevel_binding_diagnostics_t)::multi
  type(fmr_divdra_separate_infiltration_binding_diagnostics_t)::inf
  type(drainage_node_transfer_t)::nodes
  type(drainage_distribution_diagnostics_t)::sd
  type(drainage_multilevel_diagnostics_t)::md
  type(drainage_b19_separate_infiltration_result_t)::result
  real(real64),allocatable::raw(:,:),raw_single(:)
  integer::i,n,st
  diagnostics=fmr_divdra_dislayer_diagnostics_t();diagnostics%authoritative_scalar_transfer=q
  if(allocated(target))then
   diagnostics%status=FMR_DIVDRA_DISLAYER_PREBOUND;return
  end if
  n=size(p)
  if(n<1.or.size(q)/=n.or.size(controls)/=n)return
  if(.not.all(ieee_is_finite(q)).or..not.ieee_is_finite(view%groundwater_level))return
  allocate(tops(n));tops=0
  do i=1,n
   if(.not.finite_parameters(p(i)))return
   select case(controls(i)%mode)
   case(0)
    cycle
   case(1)
    if(.not.ieee_is_finite(controls(i)%top_level))return
    tops(i)=controls(i)%top_level
   case(2)
    if(controls(i)%dramet<1.or.controls(i)%dramet>3)return
    call derive_dynamic_discharge_layer_top(controls(i)%dramet,controls(i)%fraction,view%groundwater_level, &
         controls(i)%drain_bottom,controls(i)%shape,controls(i)%head_difference,tops(i),st)
    if(st/=DISLAYER_OK)return
   case default
    return
   end select
   if(tops(i)>0.0_real64.or.tops(i)<p(i)%zbotcp(p(i)%active_nodes))return
  end do
  if(present(inf_controls))then
   if(n==1)then
    if(size(inf_controls)/=1)return
    call distribute_single_level_separate_infiltration_b19(p(1),view,q(1),inf_controls(1),result,raw_single)
    if(.not.result%available)return
    allocate(scratch(1,size(result%nodal_transfer)));scratch(1,:)=result%nodal_transfer
   else
    call distribute_multilevel_separate_infiltration_b19(p,view,q,inf_controls,scratch,st,raw)
    if(st/=DRAIN_B19_INF_OK)return
   end if
  else if(n==1)then
   call distribute_single_level_signed_divdra(p(1),view,q(1),nodes,sd,raw_single)
   if(sd%status/=DRAIN_DIST_OK.or..not.sd%evaluated)return
   allocate(scratch(1,size(nodes%soil_to_drain_rate)));scratch(1,:)=nodes%soil_to_drain_rate
  else
   call distribute_multilevel_signed_divdra(p,view,q,scratch,md,raw)
   if(md%status/=DRAIN_DIST_OK.or..not.md%evaluated)return
  end if
  if(n==1)then
   allocate(raw(1,size(scratch,2)));raw=scratch
   if(allocated(raw_single))raw(1,:)=raw_single
  end if
  allocate(diagnostics%levels(n))
  do i=1,n
   if(controls(i)%mode/=0)then
    ! Clip the owner's physical weights before its final-node accounting
    ! residual can be amplified by renormalizing a tiny retained support.
    scratch(i,:)=raw(i,:)
    call apply_discharge_layer_top(p(i)%dz,tops(i),q(i),scratch(i,:),diagnostics%levels(i))
    if(diagnostics%levels(i)%status/=DISLAYER_OK)return
   end if
   if(abs(sum(scratch(i,:))-q(i))>1.e-14_real64)return
  end do
  call move_alloc(scratch,target);diagnostics%status=FMR_DIVDRA_DISLAYER_OK;diagnostics%published=.true.
 end subroutine
 logical function finite_parameters(p)result(ok)
  type(drainage_distribution_parameters_t),intent(in)::p
  ok=.false.
  if(.not.allocated(p%dz).or..not.allocated(p%zbotcp).or..not.allocated(p%saturated_conductivity).or. &
       .not.allocated(p%horizontal_anisotropy_factor))return
  if(p%active_nodes<1)return
  if(size(p%dz)/=p%active_nodes.or.size(p%zbotcp)/=p%active_nodes.or. &
       size(p%saturated_conductivity)/=p%active_nodes.or.size(p%horizontal_anisotropy_factor)/=p%active_nodes)return
  ok=all(ieee_is_finite(p%dz)).and.all(ieee_is_finite(p%zbotcp)).and. &
       all(ieee_is_finite(p%saturated_conductivity)).and.all(ieee_is_finite(p%horizontal_anisotropy_factor)).and. &
       ieee_is_finite(p%drain_spacing)
 end function
end module
