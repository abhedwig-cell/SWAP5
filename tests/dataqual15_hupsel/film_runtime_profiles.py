"""Read actual S5HR4 stock fields without relabelling any serialized bytes."""
import math,struct
from inspect_profiles import checked

def profile4(raw):
 checked(raw);assert raw[:8]==b'S5HR0004';clock,n=struct.unpack_from('=di',raw,8);assert n==34 and clock==int(clock)
 assert all(math.isfinite(x)for x in struct.unpack_from('=2d',raw,len(raw)-20))
 off=20
 for _ in range(6):
  size=struct.unpack_from('=i',raw,off)[0];assert 0<size<16777216;off+=4+size
 size=struct.unpack_from('=i',raw,off)[0];inner=raw[off+4:off+4+size];checked(inner)
 assert inner[:8]==b'S5HG0002'and struct.unpack_from('=d',inner,12)[0]==clock
 size=struct.unpack_from('=i',inner,84)[0];physical=inner[88:88+size];checked(physical)
 assert len(physical)+92==len(inner)and physical[:8]in (b'S5PT0003',b'S5PT0004')
 assert struct.unpack_from('=d',physical,136)[0]==clock and struct.unpack_from('=i',physical,148)[0]==n
 count=struct.unpack_from('=i',physical,164)[0];assert 3*n<count<8192
 vector=struct.unpack_from('='+str(count)+'d',physical,168);off=168+8*count
 read=lambda at,k:list(struct.unpack_from('='+str(k)+'d',physical,at))
 head=read(off,n);theta=read(off+8*n,n);pond,gwl=read(off+16*n,2);temperature=read(off+16*n+16,n)
 after=off+8*(3*n+2);canopy=0.
 if physical[:8]==b'S5PT0004':
  schema=struct.unpack_from('=i',physical,after+20)[0];assert schema in (0,2);canopy=read(after+24,1)[0]
 tail=len(physical)-4-8*(4*n+1);assert read(tail,n)==theta
 concentration=read(tail+8*n,n);dissolved=read(tail+16*n,n);sorbed=read(tail+24*n,n);surface=read(tail+32*n,1)[0]
 assert all(math.isfinite(x)for x in [*vector,*head,*theta,pond,gwl,*temperature,canopy,*concentration,*dissolved,*sorbed,surface])
 z=list(vector[:n]);dz=list(vector[n:2*n]);assert all(x>0 for x in dz)
 assert max(abs(t*c*d-m)for t,c,d,m in zip(theta,concentration,dz,dissolved))<1e-10
 return dict(day=int(clock),z_cm=z,dz_cm=dz,head_cm=head,theta=theta,temperature_c=temperature,
  concentration_mg_cm3=concentration,dissolved_mg_cm2=dissolved,sorbed_mg_cm2=sorbed,pond_cm=pond,groundwater_cm=gwl,
  canopy_cm=canopy,surface_solute_mg_cm2=surface,water_stock_cm=math.fsum(t*d for t,d in zip(theta,dz))+pond+canopy,
  solute_stock_mg_cm2=math.fsum(dissolved+sorbed)+surface)
