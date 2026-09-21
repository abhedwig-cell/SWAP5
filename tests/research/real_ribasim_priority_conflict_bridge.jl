using Ribasim
using DataFrames

const DAY = 86400.0
const SUPPLY = 32.0 / DAY
const ROOT_DEMAND = 40.0 / DAY
const EXTERNAL_DEMAND = 20.0 / DAY

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function priority_index(priorities, priority::Int)
    idx = findfirst(==(Int32(priority)), priorities)
    isnothing(idx) && error("demand priority $priority not present in pinned Ribasim model")
    return idx
end

function user_allocated(model, node_id::Int, priority::Int)
    (; p_independent) = model.integrator.p
    (; user_demand, allocation) = p_independent
    id = Ribasim.NodeID(:UserDemand, node_id, p_independent)
    idx = priority_index(allocation.demand_priorities_all, priority)
    return user_demand.allocated[id.idx, idx], user_demand.demand[id.idx, idx]
end

function physical_link_flow(model, from_id::Int, to_id::Int)
    df = DataFrame(Ribasim.flow_data(model))
    rows = df[(df.from_node_id .== from_id) .& (df.to_node_id .== to_id), :]
    require(!isempty(rows), "physical link $from_id -> $to_id is absent")
    return rows
end

function check_constant_flow(rows, expected::Float64, label::AbstractString)
    require(
        all(isapprox.(rows.flow_rate, expected; atol = 1.0e-9, rtol = 1.0e-7)),
        "$label physical flow differs from preregistered value",
    )
end

function check_case(
        root::AbstractString,
        model_name::AbstractString;
        root_priority::Int,
        external_priority::Int,
        expected_root::Float64,
        expected_external::Float64,
    )
    path = joinpath(root, "generated_testmodels", model_name, "ribasim.toml")
    require(isfile(path), "$model_name was not generated")

    model = Ribasim.run(path)

    root_alloc, root_demand = user_allocated(model, 3, root_priority)
    ext_alloc, ext_demand = user_allocated(model, 4, external_priority)

    require(isapprox(root_demand, ROOT_DEMAND; atol = 1.0e-12), "root demand changed")
    require(
        isapprox(ext_demand, EXTERNAL_DEMAND; atol = 1.0e-12),
        "external demand changed",
    )
    require(root_alloc <= root_demand + 1.0e-12, "root allocation exceeds demand")
    require(ext_alloc <= ext_demand + 1.0e-12, "external allocation exceeds demand")

    expected_root_rate = expected_root / DAY
    expected_external_rate = expected_external / DAY

    require(
        isapprox(root_alloc, expected_root_rate; atol = 1.0e-9, rtol = 1.0e-7),
        "$model_name root allocation differs from preregistered split",
    )
    require(
        isapprox(ext_alloc, expected_external_rate; atol = 1.0e-9, rtol = 1.0e-7),
        "$model_name external allocation differs from preregistered split",
    )
    require(
        isapprox(root_alloc + ext_alloc, SUPPLY; atol = 1.0e-9, rtol = 1.0e-7),
        "$model_name total allocated UserDemand differs from 32 m3/day",
    )

    root_flow = physical_link_flow(model, 2, 3)
    ext_flow = physical_link_flow(model, 2, 4)
    source_flow = physical_link_flow(model, 1, 2)

    check_constant_flow(root_flow, expected_root_rate, "$model_name root")
    check_constant_flow(ext_flow, expected_external_rate, "$model_name external")
    check_constant_flow(source_flow, SUPPLY, "$model_name source")

    require(
        length(root_flow.flow_rate) == length(ext_flow.flow_rate),
        "$model_name recipient physical-flow series lengths differ",
    )
    require(
        all(
            isapprox.(
                root_flow.flow_rate .+ ext_flow.flow_rate,
                SUPPLY;
                atol = 2.0e-9,
                rtol = 1.0e-7,
            ),
        ),
        "$model_name total physical UserDemand flow differs from source supply",
    )

    basin = DataFrame(Ribasim.basin_data(model))
    basin2 = basin[basin.node_id .== 2, :]
    require(!isempty(basin2), "$model_name Basin 2 output is absent")
    require(
        all(isapprox.(basin2.level, 1.0; atol = 1.0e-6, rtol = 1.0e-7)),
        "$model_name Basin level did not remain at the preregistered 1 m hold",
    )

    println(
        "RIBASIM_REAL_19B_CASE=PASS model=$model_name " *
        "root_m3_day=$(root_alloc * DAY) external_m3_day=$(ext_alloc * DAY) " *
        "samples=$(length(root_flow.flow_rate))",
    )

    return (
        root_alloc = root_alloc,
        ext_alloc = ext_alloc,
        root_flow = root_flow,
        ext_flow = ext_flow,
        basin = basin2,
    )
end

function main()
    length(ARGS) == 1 || error("usage: real_ribasim_priority_conflict_bridge.jl <ribasim-root>")
    root = abspath(ARGS[1])

    root_first = check_case(
        root,
        "swap5_priority_root_first";
        root_priority = 2,
        external_priority = 3,
        expected_root = 32.0,
        expected_external = 0.0,
    )
    external_first = check_case(
        root,
        "swap5_priority_external_first";
        root_priority = 3,
        external_priority = 2,
        expected_root = 12.0,
        expected_external = 20.0,
    )

    require(
        isapprox(
            root_first.root_alloc + root_first.ext_alloc,
            external_first.root_alloc + external_first.ext_alloc;
            atol = 1.0e-10,
        ),
        "priority reversal changed total real Ribasim managed allocation",
    )
    require(
        length(root_first.basin.level) == length(external_first.basin.level),
        "priority cases have different Basin trajectory lengths",
    )
    require(
        all(
            isapprox.(
                root_first.basin.level,
                external_first.basin.level;
                atol = 1.0e-6,
                rtol = 1.0e-7,
            ),
        ),
        "priority reversal changed the pinned real Ribasim Basin trajectory",
    )

    println("RIBASIM_REAL_19B_PRIORITY_CONFLICT=PASS")
end

main()
