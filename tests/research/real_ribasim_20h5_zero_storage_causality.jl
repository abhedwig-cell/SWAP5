using Ribasim
using JuMP
import BasicModelInterface as BMI

const DAY = 86400.0
const INJECTION = 7.999914667576883
const ALLOC_TOL = 0.05
const FACTOR_TOL = 1.0e-6
const STORAGE_TOL = 0.05

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function inspect(path::AbstractString, label::AbstractString; fix_storage_zero::Bool)
    model = BMI.initialize(Ribasim.Model, path)
    (; p_independent) = model.integrator.p
    allocation = p_independent.allocation
    require(length(allocation.allocation_models) == 1, "expected one allocation model")
    am = only(allocation.allocation_models)

    basin_id = Ribasim.NodeID(:Basin, 2, p_independent)
    root_id = Ribasim.NodeID(:UserDemand, 3, p_independent)
    external_id = Ribasim.NodeID(:UserDemand, 4, p_independent)

    infiltration = BMI.get_value_ptr(model, "basin.infiltration")
    require(length(infiltration) == 1, "expected one Basin infiltration value")
    infiltration[1] = INJECTION / DAY

    storage_var = am.problem[:basin_storage_change][basin_id]

    if fix_storage_zero
        # Reproduce the exact single-network update_allocation! preparation
        # sequence, then impose the diagnostic ΔS = 0 constraint only after
        # Ribasim has established the physical-state-derived variable bounds.
        # This avoids changing model semantics while preventing JuMP's fixed
        # variable from blocking Ribasim's bound refresh in set_simulation_data!.
        (; integrator) = model
        (; u, p, t) = integrator
        du = Ribasim.get_du(integrator)
        Ribasim.water_balance!(du, u, p, t)
        Ribasim.update_control_states!(am, p_independent)
        Ribasim.set_simulation_data!(am, integrator)
        Ribasim.reset_demand_coefficients(am)
        Ribasim.set_demands!(am, integrator)
        Ribasim.warm_start!(am, integrator)

        JuMP.set_lower_bound(storage_var, 0.0)
        JuMP.set_upper_bound(storage_var, 0.0)

        Ribasim.delete_temporary_constraints!(am)
        Ribasim.optimize!(am, model)
    else
        Ribasim.update_allocation!(model)
    end

    alpha = JuMP.value(am.problem[:low_storage_factor][basin_id])
    storage_change = JuMP.value(storage_var) * am.scaling.storage
    root_alloc = JuMP.value(
        am.problem[:user_demand_allocated][root_id, Int32(2)]
    ) * am.scaling.flow * DAY
    external_alloc = JuMP.value(
        am.problem[:user_demand_allocated][external_id, Int32(3)]
    ) * am.scaling.flow * DAY
    implicit_negative = am.implicit_negative_forcing_volume[basin_id]

    println(
        "RIBASIM_REAL_20H5_LP label=$label " *
        "low_storage_factor=$alpha storage_change_m3=$storage_change " *
        "implicit_negative_forcing_m3=$implicit_negative " *
        "root_alloc_m3_day=$root_alloc external_alloc_m3_day=$external_alloc"
    )

    BMI.finalize(model)
    return (
        alpha=alpha,
        storage_change=storage_change,
        root=root_alloc,
        external=external_alloc,
        implicit_negative=implicit_negative,
    )
end

function main()
    length(ARGS) == 1 || error("usage: real_ribasim_20h5_zero_storage_causality.jl <ribasim.toml>")
    path = abspath(ARGS[1])
    require(isfile(path), "Ribasim input missing")

    free = inspect(path, "storage_free"; fix_storage_zero=false)
    require(isapprox(free.implicit_negative, INJECTION; atol=0.01, rtol=0.0), "free case infiltration did not reach LP")
    require(isapprox(free.alpha, 1.0; atol=FACTOR_TOL, rtol=0.0), "free storage case alpha is not 1")
    require(isapprox(free.root, 40.0; atol=ALLOC_TOL, rtol=0.0), "free storage root allocation is not full demand")
    require(isapprox(free.external, 20.0; atol=ALLOC_TOL, rtol=0.0), "free storage external allocation is not full demand")
    require(isapprox(free.storage_change, -35.99991466757688; atol=STORAGE_TOL, rtol=0.0), "free storage change differs from frozen reference")

    fixed = inspect(path, "storage_fixed_zero"; fix_storage_zero=true)
    require(isapprox(fixed.implicit_negative, INJECTION; atol=0.01, rtol=0.0), "fixed case infiltration did not reach LP")
    require(isapprox(fixed.alpha, 0.0; atol=FACTOR_TOL, rtol=0.0), "zero-storage case alpha did not collapse to 0")
    require(isapprox(fixed.root, 32.0; atol=ALLOC_TOL, rtol=0.0), "zero-storage root allocation differs from 32")
    require(isapprox(fixed.external, 0.0; atol=ALLOC_TOL, rtol=0.0), "zero-storage external allocation is nonzero")
    require(abs(fixed.storage_change) <= STORAGE_TOL, "zero-storage constraint not satisfied")

    println(
        "RIBASIM_REAL_20H5_ZERO_STORAGE_FACTOR_CAUSALITY=PASS " *
        "free_alpha=$(free.alpha) fixed_alpha=$(fixed.alpha) " *
        "free_storage_change_m3=$(free.storage_change) fixed_storage_change_m3=$(fixed.storage_change)"
    )
end

main()
