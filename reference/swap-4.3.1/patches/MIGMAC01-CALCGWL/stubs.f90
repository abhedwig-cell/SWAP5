module MOD_grid
 integer::numnod
 real(8)::z(5000),dz(5000),disnod(5000),zbotcp(5000)
end module
module variables
 integer::swbotb,nodgwl,bpegwl,npegwl
 real(8)::gwlinp,h(5000),theta(5000),thetas(5000),pond,t1900
 real(8)::gwl,pegwl,pegwl_bot,gwlm1,gwlconv
end module
module MOD_swap_base
 integer::swmacro,i_instance=1
end module
module MOD_swap_mp
 real(8)::CritUndSatVol,gwlflcpzo
 integer::nodgwlflcpzo
end module
subroutine swap_error(a,b)
 character(*)::a,b
 print *,a,b
 error stop 'unexpected source error'
end subroutine
subroutine swap_warning(a,b)
 character(*)::a,b
 print *,a,b
 error stop 'unexpected source warning'
end subroutine
subroutine dtdpst(a,b,c)
 character(*)::a,c
 real(8)::b
 c='not used by quiet harness'
end subroutine
