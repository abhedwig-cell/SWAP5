using Ribasim
using JuMP
import BasicModelInterface as BMI

const DAY = 86400.0
const INJECTION = 7.999914667576883
const FACTOR_TOL = 1.0e-6
const RATE_TOL = 0.01
const ALLOC_TOL = 0.05

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function inspect(path::AbstractString, label::AbstractString, infiltration_m3_day::Float64)
    model = BMI.initialize(Ribasim.Model, path)
    (; integrator) = model
    (; p_independent, state_and_time_dependent_cache) = integrator.p
    basin_id = Ribasim.NodeID(:Basin, 2, p_independent)
    root_id = Ribasim.NodeID(:UserDemand, 3, p_independent)
    external_id = Ribasim.NodeID(:UserDemand, 4, p_independent)

    infiltration = BMI.get_value_ptr(model, "basin.infiltration")
    infiltration[1] = infiltration_m3_day / DAY

    du = Ribasim.get_du(integrator)
    Ribasim.water_balance!(du, integrator.u, integrator.p, integrator.t)

    physical_factor = state_and_time_dependent_cache.current_low_storage_factor[basin_id.idx]
    physical_infiltration_m3_day = du.infiltration[basin_id.idx] * DAY

    allocation = p_independent.allocation
    require(length(allocation.allocation_models) == 1, "expected one allocation model")
    am = only(allocation.allocation_models)

    Ribasim.update_allocation!(model)

    lp_factor = JuMP.value(am.problem[:low_storage_factor][basin_id])
    root_alloc = JuMP.value(
        am.problem[:user_demand_allocated][root_id, Int32(2)]
    ) * am.scaling.flow * DAY
    ext_alloc = JuMP.value(
        am.problem[:user_demand_allocated][external_id, Int32(3)]
    ) * am.scaling.flow * DAY
    implicit_negative = am.implicit_negative_forcing_volume[basin_id]

    println(
        "RIBASIM_REAL_20H4_FACTOR label=$label " *
        "physical_low_storage_factor=$physical_factor " *
        "lp_low_storage_factor=$lp_factor " *
        "physical_infiltration_m3_day=$physical_infiltration_m3_day " *
        "implicit_negative_forcing_m3=$implicit_negative " *
        "root_alloc_m3_day=$root_alloc external_alloc_m3_day=$ext_alloc"
    )

    BMI.finalize(model)
    return (
        physical_factor=physical_factor,
        lp_factor=lp_factor,
        physical_infiltration=physical_infiltration_m3_day,
        root=root_alloc,
        external=ext_alloc,
    )
end

function main()
    length(ARGS) == 1 || error("usage: real_ribasim_20h4_physical_lp_factor.jl <ribasim.toml>")
    path = abspath(ARGS[1])
    require(isfile(path), "Ribasim input missing")

    control = inspect(path, "control", 0.0)
    require(isapprox(control.physical_factor, 1.0; atol=FACTOR_TOL, rtol=0.0), "control physical factor is not 1")
    require(isapprox(control.lp_factor, 1.0; atol=FACTOR_TOL, rtol=0.0), "control LP factor is not 1")
    require(abs(control.physical_infiltration) <= RATE_TOL, "control physical infiltration is nonzero")
    require(isapprox(control.root, 32.0; atol=ALLOC_TOL, rtol=0.0), "control root allocation differs from 32")
    require(isapprox(control.external, 0.0; atol=ALLOC_TOL, rtol=0.0), "control external allocation is nonzero")

    injected = inspect(path, "injected", INJECTION)
    require(isapprox(injected.physical_factor, 1.0; atol=FACTOR_TOL, rtol=0.0), "injected physical factor is not 1")
    require(isapprox(injected.physical_infiltration, INJECTION; atol=RATE_TOL, rtol=0.0), "injected physical infiltration is not full forcing")
    require(isapprox(injected.lp_factor, 0.0; atol=FACTOR_TOL, rtol=0.0), "injected LP factor did not collapse to 0")
    require(isapprox(injected.root, 32.0; atol=ALLOC_TOL, rtol=0.0), "injected root allocation differs from 32")
    require(isapprox(injected.external, 0.0; atol=ALLOC_TOL, rtol=0.0), "injected external allocation is nonzero")
    require(
        injected.physical_factor - injected.lp_factor > 0.99,
        "physical and LP low-storage factors are not materially separated",
    )

    println(
        "RIBASIM_REAL_20H4_PHYSICAL_LP_FACTOR_SEPARATION=PASS " *
        "physical_factor=$(injected.physical_factor) lp_factor=$(injected.lp_factor)"
    )
end

main()
