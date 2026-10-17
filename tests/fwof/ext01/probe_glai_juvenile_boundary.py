"""Research-only isolated calculation of juvenile GLAIEX boundary semantics.

This executable is a *source-formula probe*, not a call to the actual PCSE or
Fortran model kernels and not scientific equivalence evidence.
"""
from dataclasses import dataclass

@dataclass(frozen=True)
class Case:
    dvs: float
    lai: float
    laiexp: float = 0.2
    rgrlai: float = 0.0075
    dteff: float = 15.0
    rftra: float = 0.5
    rfrgrl: float = 1.0

def pcse_source_expression(c):
    multiplier = c.rftra * c.rfrgrl if c.dvs < 0.2 and c.lai < 0.75 else 1.0
    return c.laiexp * c.rgrlai * c.dteff * multiplier

def swap5_fortran_source_expression(c):
    base = c.rftra * c.laiexp * c.rgrlai * c.dteff
    return base * c.rfrgrl if c.dvs < 0.2 and c.lai < 0.75 else base

def main():
    for dvs, lai in ((0.199, 0.74), (0.2, 0.74), (0.199, 0.75), (0.2, 0.75)):
        case = Case(dvs, lai)
        python_rate = pcse_source_expression(case)
        fortran_rate = swap5_fortran_source_expression(case)
        print(f"DVS={dvs}, LAI={lai}: PCSE={python_rate:.9f}, Fortran={fortran_rate:.9f}, difference={fortran_rate-python_rate:+.9f}")
        assert (abs(fortran_rate-python_rate) < 1e-15) == (dvs < 0.2 and lai < 0.75)
    print("SOURCE_FORMULA_BOUNDARY_PROBE_PASS (not kernel-science equivalence)")

if __name__ == "__main__":
    main()
