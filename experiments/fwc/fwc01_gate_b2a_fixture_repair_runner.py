from pathlib import Path
import fwc01_gate_b2a_physical_falling_slug_mass as gate

# Fixture-only repair after the first CI attempt proved that the FWC branch
# did not contain the ROSS-branch catalog path. Scientific constants, cases,
# timesteps and acceptance criteria remain frozen in the original gate.
gate.CATALOG = Path("integration/f-fwc/F-FWC01_GATE_B2A_MATERIAL_FIXTURE.json")

if __name__ == "__main__":
    gate.main()
