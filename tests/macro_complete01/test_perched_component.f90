program perched_component
use MOD_grid,only:numnod,z,zbotcp,dz,disnod
use MOD_swap_base,only:swmacro
use MOD_swap_mp,only:CritUndSatVol,nodgwlflcpzo,gwlflcpzo
use variables,only:swbotb,gwlinp,h,pond,t1900,theta,thetas,gwl,nodgwl,bpegwl,npegwl,pegwl,pegwl_bot,gwlm1,gwlconv
use MOD_gwl,only:calcgwl,no_deltaGWL_warning
implicit none
integer::u,i,j,k,ncases
real(8),allocatable::hc(:,:),tc(:,:)
real(8)::bottom
open(newunit=u,file='CONTEXTS.txt',status='old')
read(u,*)numnod,swbotb,CritUndSatVol
bottom=0d0
 do i=1,numnod
 read(u,*)dz(i),thetas(i)
 z(i)=bottom-.5d0*dz(i);bottom=bottom-dz(i);zbotcp(i)=bottom
 if(i==1)then
  disnod(i)=.5d0*dz(i)
 else
  disnod(i)=.5d0*(dz(i-1)+dz(i))
 end if
 end do
 disnod(numnod+1)=.5d0*dz(numnod)
 read(u,*)ncases;allocate(hc(numnod,ncases),tc(numnod,ncases))
 do k=1,ncases
 read(u,*)hc(:,k),tc(:,k)
 end do
 close(u)
 no_deltaGWL_warning=.true.;gwlm1=-59d0;gwlconv=1d9;gwlinp=-59d0;pond=0d0;t1900=35797.505d0
 do j=0,1
 swmacro=j
 do k=1,ncases
  h(1:numnod)=hc(:,k);theta(1:numnod)=tc(:,k)
  call calcgwl()
  write(*,*)j,k,gwl,nodgwl,gwlflcpzo,nodgwlflcpzo,pegwl,npegwl,bpegwl,pegwl_bot
 end do
 end do
end program
