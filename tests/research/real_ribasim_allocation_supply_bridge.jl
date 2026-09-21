using Ribasim
using DataFrames
using DataInterpolations: LinearInterpolation, integral

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function model_path(root::AbstractString, name::AbstractString)
    return joinpath(root, "generated_testmodels", name, "ribasim.toml")
end

function check_fair_distribution(root::AbstractString)
    path = model_path(root, "fair_distribution")
    require(isfile(path), "fair_distribution model was not generated")

    model = Ribasim.run(path)
    user_demand = model.integrator.p.p_independent.user_demand

    ratios = user_demand.allocated ./ user_demand.demand
    require(!isempty(ratios), "fair_distribution produced no UserDemand ratios")
    require(
        all(isapprox.(ratios, 0.5; atol = 1.0e-10, rtol = 1.0e-10)),
        "real Ribasim fair-distribution allocated/demand ratio differs from 0.5",
    )
    require(
        all(user_demand.allocated .<= user_demand.demand .+ 1.0e-12),
        "real Ribasim allocated water exceeds demand",
    )

    println("RIBASIM_REAL_19A_FAIR_DISTRIBUTION=PASS count=$(length(ratios))")
end

function check_supplied_against_physical_flow(root::AbstractString)
    path = model_path(root, "level_demand")
    require(isfile(path), "level_demand model was not generated")

    model = Ribasim.Model(path)
    Ribasim.solve!(model)

    allocation_table = DataFrame(Ribasim.allocation_data(model))
    names_present = Set(Symbol.(names(allocation_table)))
    for name in (:demand, :allocated, :supplied)
        require(name in names_present, "allocation output missing column $(name)")
    end

    flow_table = DataFrame(Ribasim.flow_data(model))
    flow_user = flow_table[flow_table.link_id .== 2, :]
    require(!isempty(flow_user), "expected UserDemand physical link 2 is absent")

    itp = LinearInterpolation(
        flow_user.flow_rate,
        Ribasim.seconds_since.(flow_user.time, model.config.starttime),
    )

    user_rows = allocation_table[
        (allocation_table.node_id .== 3) .&
        (allocation_table.demand_priority .== 2),
        :,
    ]
    require(nrow(user_rows) >= 5, "insufficient UserDemand allocation records")

    times = Ribasim.seconds_since.(user_rows.time, model.config.starttime)
    supplied_numeric = diff(integral.(Ref(itp), times)) ./ model.config.solver.saveat

    require(
        length(supplied_numeric[3:end]) == length(user_rows.supplied[4:end]),
        "lag-aligned supplied series lengths differ",
    )
    require(
        all(isapprox.(supplied_numeric[3:end], user_rows.supplied[4:end]; atol = 1.0e-3)),
        "lag-aligned Ribasim supplied output does not match integrated physical link flow",
    )

    require(
        all(user_rows.allocated .<= user_rows.demand .+ 1.0e-10),
        "real Ribasim allocation output exceeds UserDemand demand",
    )

    println(
        "RIBASIM_REAL_19A_SUPPLIED_LINKFLOW=PASS records=$(nrow(user_rows)) lag_records=1",
    )
end

function check_two_basin_route_priority(root::AbstractString)
    path = model_path(root, "two_basin_user_demand")
    require(isfile(path), "two_basin_user_demand model was not generated")

    model = Ribasim.run(path)
    flow_table = DataFrame(Ribasim.flow_data(model))
    fallback = filter(
        [:from_node_id, :to_node_id] => ==((4, 5)) ∘ tuple,
        flow_table,
    )
    require(!isempty(fallback), "fallback Basin4 -> UserDemand5 physical flow is absent")

    t0 = model.integrator.sol.prob.tspan[1]
    tend = model.integrator.sol.prob.tspan[2]
    times = Ribasim.seconds_since.(fallback.time, model.config.starttime)
    expected = 1.0e-3 .+ 1.0e-3 .* (times .- t0) ./ (tend - t0)

    require(
        all(isapprox.(fallback.flow_rate, expected; atol = 5.0e-6)),
        "real Ribasim fallback route does not match preregistered priority ramp",
    )

    println(
        "RIBASIM_REAL_19A_ROUTE_PRIORITY=PASS samples=$(nrow(fallback)) first=$(first(fallback.flow_rate)) last=$(last(fallback.flow_rate))",
    )
end

function main()
    length(ARGS) == 1 || error("usage: real_ribasim_allocation_supply_bridge.jl <ribasim-root>")
    root = abspath(ARGS[1])

    check_fair_distribution(root)
    check_supplied_against_physical_flow(root)
    check_two_basin_route_priority(root)

    println("RIBASIM_REAL_19A_BRIDGE=PASS")
end

main()
