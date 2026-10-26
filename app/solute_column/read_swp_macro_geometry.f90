! File geometry adapter. No hydraulic trial or committed state is owned here.
module mod_column_swp_macro_geometry
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_ppa_wu05a5_multi_domain_process,only:macropore_geometry_config_t
 implicit none
 private
 public::import_column_macro_geometry
contains
 subroutine import_column_macro_geometry(path,g,matrix_area_fraction)
 character(*),intent(in)::path
 type(macropore_geometry_config_t),intent(out)::g
 real(real64),allocatable,intent(out)::matrix_area_fraction(:)
 integer::nodes,domains,top_node,potential_bottom(64),u,code
 real(real64)::dz(256),z(256),static_volume(256),matrix_fraction(256),diameter(256),fractions(64*256)
 namelist /macro_geometry/nodes,domains,top_node,potential_bottom,dz,z,static_volume,matrix_fraction,diameter,fractions
 nodes=0;domains=0;top_node=0;potential_bottom=0;dz=0d0;z=0d0;static_volume=0d0;matrix_fraction=0d0;diameter=0d0;fractions=0d0
 open(newunit=u,file=trim(path),status='old',action='read',iostat=code)
 call require(code==0,'geometry input open')
 read(u,nml=macro_geometry,iostat=code);close(u)
 call require(code==0,'geometry input grammar')
 call require(nodes>=2.and.nodes<=256.and.domains>=1.and.domains<=64,'geometry dimensions')
 call require(top_node>=1.and.top_node<=nodes,'geometry top node')
 call require(all(ieee_is_finite(dz(:nodes))).and.all(ieee_is_finite(z(:nodes))).and. &
  all(ieee_is_finite(static_volume(:nodes))).and.all(ieee_is_finite(matrix_fraction(:nodes))).and. &
  all(ieee_is_finite(diameter(:nodes))).and.all(ieee_is_finite(fractions(:domains*nodes))),'finite geometry')
 call require(all(dz(:nodes)>0d0).and.all(matrix_fraction(:nodes)>0d0).and.all(matrix_fraction(:nodes)<=1d0),'matrix geometry')
 call require(all(abs(matrix_fraction(:nodes)*dz(:nodes)+static_volume(:nodes)-dz(:nodes))<1d-12),'matrix/static partition')
 g%num_nodes=nodes;g%num_domains=domains;g%top_node=top_node
 g%dz=dz(:nodes);g%static_volume_cp=static_volume(:nodes);g%characteristic_diameter=diameter(:nodes)
 g%potential_bottom_domain=potential_bottom(:domains);g%domain_fraction=reshape(fractions(:domains*nodes),[domains,nodes])
 call require(g%valid(),'production geometry contract')
 matrix_area_fraction=matrix_fraction(:nodes)
 end subroutine
 subroutine require(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then;print '(a)','SWP_MACRO_GEOMETRY_REJECTED: '//label;error stop 1;end if
 end subroutine
end module
