"""Keep all six original Ubuntu artifact ZIPs verbatim, including harness refusals."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

from groundwater_snow_archive_storage import store_original

ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS = (
    ('ORIGINAL', 'O0', 14661250798, 11853844, '7b8e0631a29e9d53d3ceb7b6dddf409ecbd209c6f4423b872897fc91bba3bb64', 44799554543, '5534a17df5ecc382cd4b8415c5bbd7d3954a0ea6'),
    ('ORIGINAL', 'O2', 14659689431, 11788974, 'c28ea2d301858edfadb3138282ecc574a0ed035c5051f733d0e1fca9564befb0', 44799554543, '5534a17df5ecc382cd4b8415c5bbd7d3954a0ea6'),
    ('FOLLOWUPFAILED', 'O0', 14660427827, 5232458, '60f9e7d26fe2de64caca5e55b01883f447d6229d05062094d836ade0cada4a88', 44800237549, '7c5e1630f5e376c2c4c40ba861369fe857fbc6fd'),
    ('FOLLOWUPFAILED', 'O2', 14660096921, 5232458, '07caabefd255c0071d5e1efc2b6a099d458eaca106301e1944ac32fc623f99f5', 44800237549, '7c5e1630f5e376c2c4c40ba861369fe857fbc6fd'),
    ('FOLLOWUPPASS', 'O0', 14660827361, 25793222, '59fd090eb08a09fc1c25f398c0baea010e869dd0adbb276d6455cdee060c5964', 44800529082, '6e40385c9b871992641f7a601bbf0ec30f5f68d3'),
    ('FOLLOWUPPASS', 'O2', 14661356368, 25712313, '8a991951dadfc128095ee827f12440c7b25e851f0e9b0aceea9cd079686e0c93', 44800529082, '6e40385c9b871992641f7a601bbf0ec30f5f68d3'),
)


def main():
    p = argparse.ArgumentParser(description=__doc__); p.add_argument('--evidence', type=Path, required=True)
    a = p.parse_args(); proof = ROOT / 'integration/f-ci/nomacro-complete01'
    for role, opt, artifact, size, digest, run, source in ARTIFACTS:
        original = a.evidence / (f'FROST_DIVDRA_UBUNTU_{opt}_ORIGINAL_V1.zip' if role == 'ORIGINAL' else f'FROST_DIVDRA_UBUNTU_{role}_{opt}_ORIGINAL_V1.zip')
        assert original.stat().st_size == size and hashlib.sha256(original.read_bytes()).hexdigest() == digest
        name = f'FROST_DRAINAGE_UBUNTU_{role}_{opt}_RAW_ARCHIVE.zip'
        record = proof / Path(name).with_suffix('.json'); assert not record.exists()
        members = {}
        with zipfile.ZipFile(original) as z:
            assert len(z.namelist()) == len(set(z.namelist()))
            for member in z.namelist():
                raw = z.read(member); members[member] = dict(bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
        stored = store_original(original, proof, name)
        q = dict(status='ORIGINAL_UBUNTU_FROST_ARTIFACT_BYTES_PRESERVED_PENDING_ADMISSION', **stored,
            artifact_id=artifact, workflow_run=run, actual_producer_source=source, optimization=opt,
            original_role=role, members=members, canonical_admission=False,
            sealer_source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip())
        record.write_text(json.dumps(q, indent=2) + '\n', encoding='utf-8')
        print(role, opt, stored['bytes'], stored['sha256'], len(members), flush=True)


if __name__ == '__main__': main()
