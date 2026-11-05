"""Use the original rotation runner's literal fixtures, including accepted repair."""
import ast,base64,hashlib,io,sys,tarfile
from pathlib import Path

def prepare(root,out):
    runner=(root/'tests/nut-senescence/run_senescence.py').read_text()
    tree=ast.parse(runner)
    oracle=next(n.value.value for n in tree.body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='oracle'for t in n.targets))
    (out/'material_oracle.inc').write_text(oracle)
    names=['wofost_soil_declarations.f90','wofost_soil_amendments.f90','wofost_soil_cropresidues.f90','wofost_soil_orgmatn.f90','wofost_soil_rateconstants.f90','wofost_soil_watern.f90','management_soil.f90']
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode((root/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())))as t:
        raw={n:t.extractfile('SWAP/'+n).read()for n in names}
    assert hashlib.sha256(raw['management_soil.f90']).hexdigest()=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b'
    for name,body in raw.items():(out/name).write_bytes(body)
    sys.path.insert(0,str(root/'tests/nut-crop'))
    from prepare_oracle import prepare as crop
    crop(root,out,raw['management_soil.f90'])
    old=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Bio(fn) * NFracBio'
    new=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Hum(fn) * NFracHum'
    assert raw['wofost_soil_orgmatn.f90'].count(old)==1
    (out/'wofost_soil_orgmatn.f90').write_bytes(raw['wofost_soil_orgmatn.f90'].replace(old,new))
    text=(root/'tests/physics/test_ppa_wu05d2_mixed_application.f90').read_text()
    start=text.index('  subroutine initialize_application_config');end=text.index('  end subroutine initialize_state_and_forcing')+len('  end subroutine initialize_state_and_forcing')
    (out/'matrix_fixture.inc').write_text(text[start:end])
    # The authentic weather grid already owns swap_error. Only the independent
    # texture module is needed beside it; no duplicate error procedure is linked.
    texture=next(n.args[0].value for n in ast.walk(tree)if isinstance(n,ast.Call)and isinstance(n.func,ast.Attribute)and n.func.attr=='write_text'and n.args and isinstance(n.args[0],ast.Constant)and isinstance(n.args[0].value,str)and n.args[0].value.startswith('module MOD_texture_orgmat'))
    assert 'subroutine swap_error'in (out/'grid_stubs.f90').read_text()
    (out/'texture_module.f90').write_text(texture.split('subroutine swap_error',1)[0])
    return [out/'texture_module.f90',*[out/n for n in names[:-1]],out/'literal_crop_exchange.f90']
