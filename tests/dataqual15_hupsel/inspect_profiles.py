"""Read retained native fields; never construct, modify or resume a checkpoint.

Field order is the actual S5HR0003/S5HG0002/pond-thermal stream ABI. The existing
111 native typed decoder controls remain the restart authority, not this reader.
"""
import math,struct,zlib

def checked(raw):
 assert len(raw)>12 and zlib.crc32(raw[:-4])==struct.unpack_from('=I',raw,len(raw)-4)[0]

def profile(raw):
 checked(raw);assert raw[:8]==b'S5HR0003';clock,n=struct.unpack_from('=di',raw,8);assert n==34 and clock==int(clock)
 pos=20
 for _ in range(6):
  size=struct.unpack_from('=i',raw,pos)[0];assert 0<size<16777216;pos+=4+size
 size=struct.unpack_from('=i',raw,pos)[0];inner=raw[pos+4:pos+4+size];checked(inner)
 assert inner[:8]==b'S5HG0002'and struct.unpack_from('=d',inner,12)[0]==clock
 size=struct.unpack_from('=i',inner,84)[0];physical=inner[88:88+size];checked(physical)
 assert len(physical)+92==len(inner)and physical[:8]in [b'S5PT0001',b'S5PT0003',b'S5PT0004']
 # fmr_template_t writes eight int64 identities plus one default integer.
 # The rest of the exact stream header is defined in mod_pond_thermal_restart_file.
 assert struct.unpack_from('=d',physical,136)[0]==clock and struct.unpack_from('=i',physical,148)[0]==n
 count=struct.unpack_from('=i',physical,164)[0];assert 3*n<count<8192
 vector=struct.unpack_from('='+str(count)+'d',physical,168);pos=168+8*count
 read=lambda at,k:list(struct.unpack_from('='+str(k)+'d',physical,at))
 head=read(pos,n);theta=read(pos+8*n,n);pond,gwl=read(pos+16*n,2);temperature=read(pos+16*n+16,n)
 canopy=0.;after=pos+8*(3*n+2)
 if physical[:8]==b'S5PT0004':
  schema=struct.unpack_from('=i',physical,after+20)[0];assert schema in [0,2];canopy=read(after+24,1)[0]
 tail=len(physical)-4-8*(4*n+1);chemical_theta=read(tail,n);assert chemical_theta==theta
 concentration=read(tail+8*n,n);dissolved=read(tail+16*n,n);sorbed=read(tail+24*n,n);surface=read(tail+32*n,1)[0]
 values=[*vector,*head,*theta,pond,gwl,*temperature,canopy,*concentration,*dissolved,*sorbed,surface];assert all(math.isfinite(x)for x in values)
 z=list(vector[:n]);dz=list(vector[n:2*n]);assert all(x>0 for x in dz)
 assert max(abs(t*c*d-m)for t,c,d,m in zip(theta,concentration,dz,dissolved))<1e-10
 return dict(day=int(clock),z_cm=z,dz_cm=dz,head_cm=head,theta=theta,temperature_c=temperature,
  concentration_mg_cm3=concentration,dissolved_mg_cm2=dissolved,sorbed_mg_cm2=sorbed,
  pond_cm=pond,canopy_cm=canopy,surface_solute_mg_cm2=surface,groundwater_cm=gwl,
  water_stock_cm=math.fsum(t*d for t,d in zip(theta,dz))+pond+canopy,
  solute_stock_mg_cm2=math.fsum(dissolved+sorbed)+surface)
