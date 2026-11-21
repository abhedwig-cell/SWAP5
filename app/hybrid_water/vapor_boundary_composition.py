"""Compose unchanged vapor hydraulics with bounded original bottom/drainage modes."""
import hashlib,re,struct
from pathlib import Path
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def selected_context(selected):
 drain,bottom=selected.get('SWDRA'),selected.get('SWBOTB')
 if selected.get('SWSNOW')!=0 or drain not in (0,1) or bottom not in (5,6,8) or (drain,bottom)==(1,6):return None
 return dict(drainage=drain,bottom=bottom,native_domain_version=5)


def context(project):
 if not project.input_directory:return None
 from experimental_project import switches
 return selected_context(switches((Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')))


def enabled(project):
 if context(project) is None:return False
 from hydraulic_vapor import describe
 return describe(project) is not None


def check_daily_output(active):
 for key,value in dict(NPRINTDAY=1,SWMONTH=0,SWODAT=0,PERIOD=1,SWRES=1).items():
  values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]+)',active)
  if len(values)!=1 or re.fullmatch(r'[+-]?\d+[ \t]*',values[0]) is None or int(values[0])!=value:raise ValueError('Vapor boundary composition requires original daily reset output: '+key)
 values=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^\r\n]+)',active)
 if len(values)>1 or values and values[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F'):raise ValueError('Vapor boundary composition excludes per-step output')


def native_source(original):
 text=original.decode('cp1252').replace('\r\n','\n')
 if SHA(text.encode('cp1252'))!='a181df32399d64a4052f4e8d3d11133bb7388fd890c8f0e9139594bbc29877b0':raise ValueError('Changed complete original vapor native3 owner')
 edits=[('.or.swdra/=1.or.swbotb/=6)', '.or.(swdra/=0.and.swdra/=1).or.(swbotb/=5.and.swbotb/=6.and.swbotb/=8).or.(swdra==1.and.swbotb==6))'),('expected(1:14)=[3,','expected(1:14)=[5,')]
 for before,after in edits:
  if text.count(before)!=1:raise ValueError('Changed exact vapor boundary native seam')
  text=text.replace(before,after,1)
 return text.encode('cp1252')


def terminal_source(original):
 # The complete old terminal body is checked by its existing source owner.
 # Only its runtime domain import/assertion changes; every ledger term stays
 # literal, including qdrtot and the actual original signed qbot exchange.
 edits=[('ivolbeg,ipondbeg,issnowbeg,isicbeg,swkimpl\n','ivolbeg,ipondbeg,issnowbeg,isicbeg,swkimpl,swbotb\n'),('swmacro/=0.or.swsnow/=0.or.swdra/=1.or.swfrost/=0.or.swhyst/=0.or.swkimpl/=0','swmacro/=0.or.swsnow/=0.or.(swdra/=0.and.swdra/=1).or.(swbotb/=5.and.swbotb/=6.and.swbotb/=8).or.swfrost/=0.or.swhyst/=0.or.swkimpl/=0')]
 text=original
 for before,after in edits:
  if text.count(before)!=1:raise ValueError('Changed complete analytical terminal receipt seam')
  text=text.replace(before,after,1)
 edits=[('  use iso_fortran_env, only: real128','  use iso_fortran_env, only: real128\n  use ieee_arithmetic, only: ieee_is_finite'),('subroutine model7_terminal_water_terms(terms)','subroutine model7_terminal_water_terms(terms,boundary_flux)'),('    real(8), intent(out) :: terms(28)','    real(8), intent(in), optional :: boundary_flux\n    real(8), intent(out) :: terms(28)'),('    qbotts=qbot*dt','    qbotts=qbot*dt\n    if(present(boundary_flux))then\n      if(.not.ieee_is_finite(boundary_flux))error stop \'Nonfinite analytical boundary trial receipt\'\n      qbotts=boundary_flux*dt\n    end if'),('function model7_terminal_water_residual() result(residual)','function model7_terminal_water_residual(boundary_flux) result(residual)'),('    call model7_terminal_water_terms(terms)','    call model7_terminal_water_terms(terms,boundary_flux)'),('    real(8) :: terms(28)','    real(8), intent(in), optional :: boundary_flux\n    real(8) :: terms(28)')]
 for before,after in edits:
  if text.count(before)!=1:raise ValueError('Changed analytical trial boundary flux argument seam')
  text=text.replace(before,after,1)
 return text


def terminal_guard(project,original):
 selected=context(project)
 if selected is None or selected['bottom']==6:return original
 flux='-kmean(NN+1)*hgrad(NN+1)'
 before='model7_terminal_water_residual()'
 if original.count(before)!=1:raise ValueError('Changed analytical terminal guard call')
 if selected['bottom']==8:
  # Follow the literal qualified lower-boundary receipt's IF(flboth) owner.
  # The closed branch never evaluates a gradient that the original solver
  # need not define for that branch; no physical flux or state is assigned.
  opening=original.replace(before,'model7_terminal_water_residual('+flux+')',1)
  closed=original.replace(before,'model7_terminal_water_residual(0d0)',1)
  return '\n         if(flboth)then'+opening+'\n         else'+closed+'\n         end if'
 return original.replace(before,'model7_terminal_water_residual('+flux+')',1)


def head_parent_inverse(text,project,parent_sha):
 selected=context(project)
 if selected is None:raise ValueError('No bounded vapor boundary source owner')
 actual=text;bottom=selected['bottom']
 if SHA(text.encode('cp1252'))!=parent_digest(bottom):raise ValueError('Foreign complete vapor boundary HeadCalc postimage')
 if bottom in (5,8):
  from lower_boundary_receipt import render_headcalc
  for anchor in ('         budget_step=projected_water_residual()','            budget_step = projected_water_residual()'):
   indent=anchor[:len(anchor)-len(anchor.lstrip())]
   if bottom==8:lines=['if(swmacro==0.and.swbotb==8)then','  if(flboth)then','    budget_step=projected_water_residual(-kmean(NN+1)*hgrad(NN+1))','  else','    budget_step=projected_water_residual(0d0)','  end if','else','  budget_step=projected_water_residual()','end if']
   else:lines=['if(swmacro==0.and.swbotb==5)then','  budget_step=projected_water_residual(-kmean(NN+1)*hgrad(NN+1))','else','  budget_step=projected_water_residual()','end if']
   rendered='\n'.join(indent+line for line in lines)
   if text.count(rendered)!=1:raise ValueError('Changed literal original boundary step receipt')
   text=text.replace(rendered,anchor,1)
  if render_headcalc(text,bottom)!=actual:raise ValueError('Incomplete qualified boundary receipt inverse')
 else:
  # Literal already qualified daily_host linear-pond Jacobian; no tangent,
  # flux or capacity is introduced by this composition.
  before='   use hybrid_step_budget, only: projected_water_residual'
  after=before+', linear_pond_top_jacobian\n   use variables, only: rsro, rsroexp, pondmx'
  old='   if (ftoph) dFdhM(1) = dFdhM(1) + kmean(1)/disnod(1)'
  new='   if (ftoph) then\n      if (flrunoff .and. rsroexp==1d0 .and. rsro>=1d-3) then\n         dFdhM(1)=dFdhM(1)+linear_pond_top_jacobian(kmean(1)/disnod(1),dt,pond,pondmx,rsro)\n      else\n         dFdhM(1)=dFdhM(1)+kmean(1)/disnod(1)\n      end if\n   end if'
  import ast
  literals=[n.value for n in ast.walk(ast.parse(Path(__file__).with_name('daily_host.py').read_text())) if isinstance(n,ast.Constant) and isinstance(n.value,str)]
  if after not in literals or new not in literals:raise ValueError('Changed qualified linear pond tangent source')
  if text.count(after)!=1 or text.count(new)!=1:raise ValueError('Changed complete linear pond HeadCalc parent')
  text=text.replace(after,before,1).replace(new,old,1)
 if SHA(text.encode('cp1252'))!=parent_sha:raise ValueError('Foreign complete pre-boundary analytical HeadCalc')
 return False


def parent_digest(bottom):
 return {6:'356fdea44df04ecb97f68936be0102c36b63f730d5c63950c8ad0ce453c313df',5:'86846f45207441207b24d71954b28ad4690a0a5ab6aca17883ecd3c1fb4a997d',8:'5f416dd85126383e39f2211f394b18590b1420cfbc2c49c408f7b4ec89de73d2'}[bottom]


def metadata(project):
 selected=context(project)
 if selected is None:return None
 return dict(policy='original-vapor-bounded-drainage-bottom-composition-v1',**selected,source_sha256=SHA(Path(__file__).read_bytes().replace(b'\r\n',b'\n')),physical_equations_changed=False,new_physical_water_store=False,fixed_absolute_water_limit_cm=1e-10,old_native3_and_native4_unchanged=True,original_boundary_flux_owner='boundbottom/headcalc',trial_action='Unchanged original Newton nonconvergence and rollback only')


def cde_offset(aux,nodes,project=None):
 if aux[:8]!=b'S5HBC005' or len(aux)<104:raise ValueError('Incomplete CDE vapor boundary domain')
 domain=struct.unpack_from('<14i',aux,48);layers=domain[2]
 if not 1<=layers<=1000 or domain[:12]!=(5,nodes,layers,0,1,0,0,0,0,0,1,2) or domain[12] not in (0,1) or domain[13] not in (5,6,8) or domain[12:]==(1,6):raise ValueError('Foreign CDE vapor boundary domain')
 count=14+2*layers;size=4*count
 if len(aux)<48+2*size:raise ValueError('Incomplete CDE vapor boundary witness')
 header=struct.unpack_from('<'+str(count)+'i',aux,48)
 if header!=struct.unpack_from('<'+str(count)+'i',aux,48+size):raise ValueError('Foreign CDE vapor boundary witness')
 models,flags=header[14:14+layers],header[14+layers:]
 if any(m not in range(1,12) for m in models) or any(f not in (0,1) for f in flags) or not any(flags) or any(f and m<8 for m,f in zip(models,flags)):raise ValueError('Foreign CDE vapor boundary layers')
 if project is not None:
  from hydraulic_vapor import describe
  selected=describe(project);boundary=context(project)
  if selected is None or boundary is None or domain[12:]!=(boundary['drainage'],boundary['bottom']) or tuple(selected['models'])!=models or tuple(f if m>=8 else 0 for m,f in zip(selected['models'],selected['SWVAPOR']))!=flags:raise ValueError('CDE vapor boundary native differs from actual project')
 return 48+2*size
