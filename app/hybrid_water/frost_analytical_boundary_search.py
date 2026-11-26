"""Reuse existing numerical search only for explicit non1 Frost bottom6."""
from pathlib import Path
import hashlib
from model7_terminal_water import SEARCH
PARENT_SHA='15bac3d3cc0ee41918b5c6bf53aa75f50c85a1bbc0f56db66431045ab9d87a69'
SEARCH_SHA='SEARCH_DIGEST'
IMPORT='   use hybrid_step_budget, only: projected_water_residual'
COMPOSED_IMPORT=IMPORT+', linear_pond_top_jacobian\n   use variables, only: rsro, rsroexp, pondmx'
JACOBIAN='   if (ftoph) dFdhM(1) = dFdhM(1) + kmean(1)/disnod(1)'
COMPOSED_JACOBIAN='   if (ftoph) then\n      if (flrunoff .and. rsroexp==1d0 .and. rsro>=1d-3) then\n         dFdhM(1)=dFdhM(1)+linear_pond_top_jacobian(kmean(1)/disnod(1),dt,pond,pondmx,rsro)\n      else\n         dFdhM(1)=dFdhM(1)+kmean(1)/disnod(1)\n      end if\n   end if'


def selected(item):
    return bool(item and item.get('analytical_frost_models') and any(x!=1 for x in item['analytical_frost_models']) and item['bottom']==6 and item['implicit']==item['hysteresis']==0 and item['drainage'] in (0,1))


def metadata(item):
    if not selected(item):return None
    assert hashlib.sha256(SEARCH.encode()).hexdigest()==SEARCH_SHA
    return dict(policy='existing-explicit-analytical-zero-flux6-frost-search-composition-v1',provider_lf_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),complete_parent_headcalc_lf_sha256=PARENT_SHA,inherited_numerical_search_sha256=SEARCH_SHA,linear_pond_operator='hybrid_step_budget.linear_pond_top_jacobian',search_scope='Original analytical fully saturated closed-bottom flux null mode; original default-model1 numerical diagonal, no physical capacity change',absolute_water_limit_cm='1e-10',physical_equations_changed=False,accepted_state_or_flux_assignment_added=False,iteration_or_retry_limits_changed=False,new_native_state=False)


def source(before):
    assert hashlib.sha256(before.encode('cp1252')).hexdigest()==PARENT_SHA,'Foreign complete Frost zero-flux6 search parent'
    assert hashlib.sha256(SEARCH.encode()).hexdigest()==SEARCH_SHA
    edits=[(IMPORT,COMPOSED_IMPORT),(JACOBIAN,COMPOSED_JACOBIAN),('end subroutine jacobian_F',SEARCH+'end subroutine jacobian_F')]
    after=before
    for old,new in edits:
        assert after.count(old)==1,'Foreign existing Frost Newton seam'
        after=after.replace(old,new,1)
    return after


def inverse(after):
    before=after
    for old,new in [(IMPORT,COMPOSED_IMPORT),(JACOBIAN,COMPOSED_JACOBIAN),('end subroutine jacobian_F',SEARCH+'end subroutine jacobian_F')]:
        assert before.count(new)==1,'Foreign actual composed Frost Newton operator'
        before=before.replace(new,old,1)
    assert hashlib.sha256(before.encode('cp1252')).hexdigest()==PARENT_SHA and source(before)==after
    return before


def apply_build(output,item):
    if not selected(item):return
    path=Path(output)/'headcalc.f90';path.write_text(source(path.read_text(encoding='cp1252')),encoding='cp1252')


def validate(bundle,item):
    if selected(item):inverse((Path(bundle)/'headcalc.f90').read_text(encoding='cp1252'))
