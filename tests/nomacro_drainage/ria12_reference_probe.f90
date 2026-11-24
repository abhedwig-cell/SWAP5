! Complete original RIA/TTUTIL routines; no constitutive formula is copied.
program actual_original_ria12_probe
  use MOD_RIA,only:RIA_Reader,WCRIA,RIAderivative,SingleKcomponents
  use DoublePrec,only:dp
  use SHPvariables,only:nLayer,iLayer,SWRCpars,UHCCpars,HeatOn
  use KVapor,only:VaporCond,DefaultTemperature
  use MOD_swap_base,only:unit_log
  use,intrinsic::ieee_arithmetic,only:ieee_is_finite
  implicit none
  character(len=2048)::input,heads,dump
  integer::samples,index,ios,models(2),count
  logical::rdinar
  external::rdinar
  real(8)::head
  real(dp)::theta,capacity,k,kliq,kvap
  call get_command_argument(1,input)
  call get_command_argument(2,heads)
  call get_command_argument(3,dump)
  if(len_trim(input)==0.or.len_trim(heads)==0.or.len_trim(dump)==0)error stop 'Missing original RIA probe input'
  unit_log=6
  call rdinit(31,6,trim(input))
  call RIA_Reader()
  if(nLayer/=2.or.HeatOn.or.VaporCond)error stop 'Unselected original RIA12 component domain'
  if(rdinar('IHWCKMODEL'))then
    count=2
    call rdfinr('IHWCKMODEL',12,12,models,2,count)
    if(count/=2.or.any(models/=12))error stop 'Foreign original per-layer RIA12 model'
  else
    call rdsinr('IHWCKMODEL',12,12,models(1))
  end if
  ! Dump the original arrays in their original column-major layout. The
  ! independent Python reader maps these to the new native witness explicitly.
  open(33,file=trim(dump),status='new',form='unformatted',access='stream')
  write(33)nLayer,storage_size(0.0_dp)/8,SWRCpars,UHCCpars
  close(33)
  open(32,file=trim(heads),status='old',action='read')
  read(32,*,iostat=ios)samples
  if(ios/=0.or.samples<1)error stop 'Invalid original RIA sample count'
  do index=1,samples
    read(32,*,iostat=ios)head
    if(ios/=0.or..not.ieee_is_finite(head))error stop 'Invalid original RIA sample head'
    do iLayer=1,nLayer
      theta=WCRIA(real(head,dp))
      capacity=RIAderivative(real(head,dp))
      call SingleKcomponents(real(head,dp),DefaultTemperature,k,kliq,kvap)
      if(.not.all(ieee_is_finite([theta,capacity,k,kliq,kvap])))error stop 'Nonfinite original RIA sample'
      if(min(theta,capacity,k,kliq)<0.0_dp.or.kvap/=0.0_dp.or.k/=kliq) &
         error stop 'Invalid original NoVapor RIA sample'
      write(*,'(a,3(1x,i0),6(1x,es25.17e3))')'ACTUAL_ORIGINAL_RIA12_SAMPLE',12,iLayer,index, &
        head,dble(theta),dble(capacity),dble(k),dble(kliq),dble(kvap)
    end do
  end do
  close(32)
end program
