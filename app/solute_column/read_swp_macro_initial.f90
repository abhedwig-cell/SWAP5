! Native source preparation boundary. No Richards attempt or time advancement.
module mod_column_swp_macro_initial
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite,ieee_value,ieee_quiet_nan
 use mod_column_swp_macro_geometry
 use mod_ppa_wu05a5_multi_domain_process
 use mod_macropore_dynamic_shrinkage
 use mod_macropore_continuation_state
 use mod_macropore_standard_storage
 implicit none
 private
 type,public::native_macro_initial_t
  type(macropore_geometry_config_t)::geometry
  type(dynamic_shrinkage_config_t)::shrinkage
  type(macropore_continuation_state_t)::state
  type(macropore_standard_storage_view_t)::storage
  real(real64),allocatable::z(:),matrix_fraction(:),theta(:),theta_s(:),theta_r(:)
  real(real64),allocatable::sorptivity_max(:),sorptivity_alpha(:),darcy(:,:)
  real(real64)::rapid_kd=0d0,groundwater=0d0,drain_level=0d0,static_bottom=0d0,rapid_exponent=0d0
  integer::cutoff=0
 end type
 public::import_column_macro_initial
contains
 subroutine import_column_macro_initial(path,initial)
 character(*),intent(in)::path
 type(native_macro_initial_t),intent(out)::initial
 integer::nodes,domains,top_node,potential_bottom(64),layers,layer(256),cutoff,surface_node,i,n,nd,u,code
 real(real64)::dz(256),z(256),static_volume(256),matrix_fraction(256),diameter(256),fractions(64*256)
 real(real64)::theta(256),theta_s(256),theta_r(256),theta_crack(256),geometry_factor(256)
 real(real64)::kim_a(256),kim_b(256),kim_c(256),kim_d(256),minimum_subsidence(256)
 real(real64)::dynamic_volume(256),subsidence(256),sorptivity_max(256),sorptivity_alpha(256),hydrostatic_drain_theta(256)
 real(real64)::volume(64*256),water(64*256),darcy(64*256),domain_water(64)
 real(real64)::groundwater,static_bottom,drain_level,rapid_exponent,rapid_kd,nan
 real(real64),allocatable::dynamic(:),sub(:)
 type(macropore_geometry_result_t)::g
 logical::ok
 namelist /macro_geometry/nodes,domains,top_node,potential_bottom,dz,z,static_volume,matrix_fraction,diameter,fractions
 namelist /macro_initial/layers,layer,cutoff,surface_node,groundwater,static_bottom,drain_level,rapid_exponent,rapid_kd, &
  theta,theta_s,theta_r,theta_crack,geometry_factor,kim_a,kim_b,kim_c,kim_d,minimum_subsidence,dynamic_volume, &
  subsidence,sorptivity_max,sorptivity_alpha,hydrostatic_drain_theta,volume,water,darcy,domain_water
 call import_column_macro_geometry(path,initial%geometry,initial%matrix_fraction)
 n=initial%geometry%num_nodes;nd=initial%geometry%num_domains
 ! Missing required data must fail, including floating-point omissions.
 nan=ieee_value(0d0,ieee_quiet_nan);layers=0;layer=0;cutoff=0;surface_node=0
 groundwater=nan;static_bottom=nan;drain_level=nan;rapid_exponent=nan;rapid_kd=nan
 theta=nan;theta_s=nan;theta_r=nan;theta_crack=nan;geometry_factor=nan
 kim_a=nan;kim_b=nan;kim_c=nan;kim_d=nan;minimum_subsidence=nan
 dynamic_volume=nan;subsidence=nan;sorptivity_max=nan;sorptivity_alpha=nan;hydrostatic_drain_theta=nan
 volume=nan;water=nan;darcy=nan;domain_water=nan;z=nan
 open(newunit=u,file=trim(path),status='old',action='read',iostat=code);call require(code==0,'initial input open')
 read(u,nml=macro_geometry,iostat=code);call require(code==0,'geometry grammar')
 read(u,nml=macro_initial,iostat=code);close(u);call require(code==0,'initial grammar')
 call require(layers>=1.and.layers<=25.and.all(layer(:n)>=1).and.all(layer(:n)<=layers),'source layers')
 call require(cutoff>=1.and.cutoff<=n.and.surface_node>=1.and.surface_node<=n,'initial active nodes')
 call finite(z(:n));call finite(theta(:n));call finite(theta_s(:n));call finite(theta_r(:n))
 call finite(sorptivity_max(:n));call finite(sorptivity_alpha(:n));call finite(dynamic_volume(:n));call finite(subsidence(:n))
 call finite(minimum_subsidence(:n));call finite(hydrostatic_drain_theta(:n));call finite(volume(:nd*n))
 call finite(water(:nd*n));call finite(darcy(:nd*n));call finite(domain_water(:nd))
 call finite([groundwater,static_bottom,drain_level,rapid_exponent,rapid_kd])
 call require(all(theta(:n)>=theta_r(:n)).and.all(theta(:n)<=theta_s(:n)).and.all(theta_s(:n)>theta_r(:n)), &
  'initial moisture limits')
 call require(all(sorptivity_max(:n)>0d0).and.all(sorptivity_alpha(:n)>0d0),'computed sorptivity domain')
 initial%shrinkage%enabled=.true.;initial%shrinkage%surface_crack_area_node_supplied=.true.
 initial%shrinkage%surface_crack_area_node=surface_node
 initial%shrinkage%theta_s=theta_s(:n);initial%shrinkage%theta_crack=theta_crack(:n)
 initial%shrinkage%geometry_factor=geometry_factor(:n);allocate(initial%shrinkage%kim(n))
 ! Explicitly prepared source coefficients, retaining original SHRINKPAR's finite
 ! iteration. The admitted modern characteristic-point preparer remains unchanged.
 do i=1,n
  initial%shrinkage%kim(i)=clay_kim_shrinkage_t(kim_a(i),kim_b(i),kim_c(i),kim_d(i))
 end do
 call derive_dynamic_minimum_subsidence(initial%shrinkage,initial%geometry%dz,ok)
 call require(ok,'production minimum subsidence')
 call require(maxval(abs(initial%shrinkage%minimum_subsidence_cm-minimum_subsidence(:n)))<=1d-12,'source minimum subsidence')
 call prepare_initial_dynamic_crack_profile(initial%shrinkage,theta(:n),initial%geometry%dz, &
  initial%matrix_fraction,top_node,cutoff,dynamic,sub,ok)
 call require(ok,'production initial dynamic profile')
 call require(maxval(abs(dynamic-dynamic_volume(:n)))<=1d-12.and.maxval(abs(sub-subsidence(:n)))<=1d-12,'source dynamic profile')
 call evaluate_macropore_geometry(initial%geometry,dynamic,g);call require(g%valid,'production initial geometry')
 call require(maxval(abs(g%volume_domain_cp-reshape(volume(:nd*n),[nd,n])))<=1d-12,'source domain volumes')
 call prepare_rapid_drain_reference_kd(initial%shrinkage,z(:n),initial%geometry%dz,hydrostatic_drain_theta(:n), &
  initial%geometry%static_volume_cp,initial%geometry%domain_fraction(1,:),initial%geometry%characteristic_diameter, &
  static_bottom,drain_level,1,rapid_exponent,initial%rapid_kd,ok)
 call require(ok.and.abs(initial%rapid_kd-rapid_kd)<=1d-12,'source rapid reference')
 call initial%state%initialize(nd,n,ok);call require(ok,'typed initial state')
 initial%state%icp_bottom_domain=g%bottom_domain;initial%state%volume_domain_cp=g%volume_domain_cp
 initial%state%dynamic_volume_cp=dynamic;initial%state%water_domain_cp=reshape(water(:nd*n),[nd,n])
 call require(all(initial%state%water_domain_cp>=0d0).and.all(domain_water(:nd)>=0d0),'negative initial water')
 call require(maxval(abs(sum(initial%state%water_domain_cp,dim=2)-domain_water(:nd)))<=1d-12,'source initial domain stocks')
 call canonicalize_macropore_standard_storage(initial%state,top_node,z(:n),initial%geometry%dz,initial%storage,ok)
 call require(ok,'canonical initial storage')
 call require(maxval(abs(initial%storage%total_water_cm-domain_water(:nd)))<=1d-12,'initial storage mass')
 initial%z=z(:n);initial%theta=theta(:n);initial%theta_s=theta_s(:n);initial%theta_r=theta_r(:n)
 initial%sorptivity_max=sorptivity_max(:n);initial%sorptivity_alpha=sorptivity_alpha(:n)
 initial%darcy=reshape(darcy(:nd*n),[nd,n]);call require(all(initial%darcy>=0d0),'negative Darcy coefficient')
 initial%groundwater=groundwater;initial%drain_level=drain_level;initial%static_bottom=static_bottom
 initial%rapid_exponent=rapid_exponent;initial%cutoff=cutoff
 end subroutine
 subroutine finite(x)
 real(real64),intent(in)::x(:)
 call require(all(ieee_is_finite(x)),'nonfinite or omitted initial data')
 end subroutine
 subroutine require(ok,message)
 logical,intent(in)::ok
 character(*),intent(in)::message
 if(.not.ok)then;print '(a)','SWP_MACRO_INITIAL_REJECTED: '//message;error stop 1;end if
 end subroutine
end module
