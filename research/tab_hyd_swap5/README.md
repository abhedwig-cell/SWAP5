# TAB-HYD SWAP5-native provider characterization

This research slice starts from the live `integration/f-ci-canonical` head and changes no production source.

Purpose:

1. test whether a table-backed constitutive provider can satisfy the current SWAP5 typed `constitutive_hydraulics_provider_t` contract;
2. compare that provider directly against the current qualified B1.10 default-MvG provider, avoiding the older public-SWAP typed-input and legacy `SWKIMPL=1` ambiguities;
3. keep the experiment explicitly bounded to the ordinary `SWKIMPL=0` value-provider contract.

The research provider samples the authoritative current MvG provider on a grid uniform in

`x = -ln(1-h)`

and evaluates theta, log(K), and log(C) with shape-preserving cubic Hermite interpolation and O(1) arithmetic interval indexing.

This is not a production implementation and is not an admission proposal.
