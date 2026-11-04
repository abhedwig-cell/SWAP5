! Input-owner fixture only; unchanged B1.11 owns all oxygen physics.
module MOD_arrays
 integer,parameter::macp=34,matab=4
end module
module MOD_grid
 integer,parameter::numnod=34
 integer::layer(34)=1
 real(8)::dz(34)=0d0,ztopcp(34)=0d0,zbotcp(34)=0d0
end module
module parameters
 real(8),parameter::pi=3.1415926535897932384626433832795d0
end module
module doln
 logical::do_ln_trans=.false.
end module
module atmosphere_interface
 real(8)::tav=0d0
end module
module plant_interface
 real(8)::max_resp_factor=0d0,q10_root=0d0,c_mroot=0d0,f_senes=0d0
end module
module MOD_cropdevelopment
 real(8)::q10_microbial=0d0,specific_resp_humus=0d0,rootradius_m=0d0,srl=0d0
 real(8)::wroot_node_top(34)=0d0
 real(8)::campbell_h100=-100d0,campbell_h500=-500d0,gfp_h100=-100d0
end module
module MOD_texture_orgmat
 real(8)::orgmat(34)=0d0,psand(34)=0d0,bdens(34)=0d0
end module
module MOD_SoilTemperature
 real(8)::tsoil(34)=0d0
end module
module variables
 real(8)::theta(34)=0d0,h(34)=0d0,dimoca(34)=0d0
end module
module MOD_MvG
 integer::swsophy=0,iHWCKmodel(34)=1,numtablay(34)=4
 real(8)::cofgen(24,34)=0d0,sptab(7,4,34)=0d0
contains
 real(8) function watcon(node,head)
  integer,intent(in)::node
  real(8),intent(in)::head
  ! Same explicit unimodal analytical owner as the admitted assembled fixture.
  watcon=cofgen(1,node)+(cofgen(2,node)-cofgen(1,node))* &
   (1d0+(cofgen(4,node)*abs(min(0d0,head)))**cofgen(6,node))**(-cofgen(7,node))
 end function
end module
subroutine swap_error(location,message)
 character(*),intent(in)::location,message
 print *,location,message
 error stop 1
end subroutine
