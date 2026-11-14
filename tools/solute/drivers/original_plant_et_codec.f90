! Direct contract driver for the actual original plant_interface extension.
program original_plant_et_codec
  use plant_interface
  implicit none
  integer :: unit, bytes
  character(20)::mode
  call get_command_argument(1,mode)
  if(trim(mode)=='consume')then
    open(newunit=unit,file='component.bin',access='stream',form='unformatted',status='old')
    call hybrid_plant_et_checkpoint(unit,.true.)
    close(unit)
    stop
  end if
  swcf=1;cf=.8d0;ch=50d0;albedo=.23d0;rsc=70d0;rsw=0d0
  kdif=.6d0;kdir=.7d0;vcover=.4d0;co2=360d0
  fco2amax=1d0;fco2eff=1d0;fco2tra=1d0
  if(trim(mode)=='invalid-write')fco2tra=-1d0
  open(newunit=unit,file='component.bin',access='stream',form='unformatted',status='replace')
  call hybrid_plant_et_checkpoint(unit,.false.)
  close(unit)
  inquire(file='component.bin',size=bytes)
  if(bytes/=100)error stop 'Wrong physical plant ET block size'
  swcf=0;cf=0d0;ch=0d0;albedo=0d0;rsc=0d0;rsw=0d0
  kdif=0d0;kdir=0d0;vcover=0d0;co2=0d0
  fco2amax=0d0;fco2eff=0d0;fco2tra=0d0
  open(newunit=unit,file='component.bin',access='stream',form='unformatted',status='old')
  call hybrid_plant_et_checkpoint(unit,.true.)
  close(unit)
  if(swcf/=1.or.any([cf,ch,albedo,rsc,rsw,kdif,kdir,vcover,co2,fco2amax,fco2eff,fco2tra] /= &
                    [.8d0,50d0,.23d0,70d0,0d0,.6d0,.7d0,.4d0,360d0,1d0,1d0,1d0])) &
    error stop 'Original plant ET component did not roundtrip exactly'
  print *,'ORIGINAL_PLANT_ET_CODEC_EXACT',bytes
end program
