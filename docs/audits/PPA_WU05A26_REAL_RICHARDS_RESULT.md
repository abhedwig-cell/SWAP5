# PPA-WU05-A26 real Richards binding result

Date: 2026-10-01
Status: QUALIFIED
Qualified postimage: 42061642a6b2088fa76a8deca80a4b71f10a5771
Qualification run: 36901532625 — SUCCESS

The A26 matrix-source receipt is accepted by the existing A24 provider seam and a real Reference Richards solve.

Qualified under both -O0 and -O2:
- RFM source changes the Richards candidate relative to the zero-source reference;
- accepted matrix head remains immutable;
- repeated solve from the same accepted origin is bit-identical in head and water content;
- integrated Richards mass-balance residual remains within the hard oracle;
- no RFM physics is introduced inside the Richards solver.

Next: serialized backend transaction composition and guard replacement only in the qualified same postimage.
