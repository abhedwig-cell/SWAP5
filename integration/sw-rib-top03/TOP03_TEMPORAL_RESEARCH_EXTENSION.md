# Adaptive diagnostic extension

The preregistered 0.25-day grids fail to complete after initial successful solves. Do not compare partial endpoint results as a convergence sequence. Extend the same experiment with a 0.001953125-day interval to isolate initial wetting. Record stop_code 0 complete, 1 nonconverged solve, 2 positive qtop outside the bounded profile; record solver status and route. No physics or solver iteration limit changes. Bottom mode 7 is retained: the reported accepted bottom flux is solver-owned, not assumed equal to the requested initial-conductivity flux.
