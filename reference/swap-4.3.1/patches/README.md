# B1 patch series

Each accepted B0 -> B1 correction receives its own directory named by stable audit ID, for example:

```text
patches/SWAP-011/
    finding.md
    fix.patch
    qualification.md
    tests/
```

A patch directory may exist while a finding is still being qualified, but it is not part of B1 until its audit ID appears in `../b1-manifest.yml`.

Patch order in the manifest is normative because later corrections may depend on earlier admitted corrections.

A model-development experiment must not be stored as an admitted B1 patch merely because it improves behaviour. B1 contains confirmed defect corrections only.
