# OrganicMatter.jl
# This module calculates the concentration and biochemical composition of dissolved
# and particulate organic matter (DOC and POC) based on the biome and depth.

module OrganicMatter

export get_organic_matter

#= --- Data Structures and Parameters --- =#

"""
    OrganicPoolParameters

    A struct to hold biome-specific parameters for calculating the bulk
    concentration of an organic matter pool (DOC or POC).
"""
struct OrganicPoolParameters
    C_surf::Float64     # Surface concentration (μmol C/kg)
    C_deep::Float64     # Deep-water refractory concentration (μmol C/kg)
    z_decay::Float64    # e-folding depth scale for remineralization (m)
end

# A dictionary mapping biomes to their specific parameter sets for both DOC and POC.
# This data is synthesized from Section 5.1 of the scientific plan.
const ORGANIC_PARAMS = Dict(
    "Polar" => (
        DOC = OrganicPoolParameters(60.0, 40.0, 100.0),
        POC = OrganicPoolParameters(5.0, 0.1, 150.0)
    ),
    "Westerlies" => (
        DOC = OrganicPoolParameters(65.0, 40.0, 120.0),
        POC = OrganicPoolParameters(6.0, 0.1, 180.0)
    ),
    "Trade-Winds" => (
        DOC = OrganicPoolParameters(50.0, 40.0, 200.0),
        POC = OrganicPoolParameters(2.0, 0.1, 250.0)
    ),
    "Coastal" => (
        DOC = OrganicPoolParameters(80.0, 45.0, 80.0),
        POC = OrganicPoolParameters(15.0, 0.2, 100.0)
    )
)

# A nested dictionary defining the biochemical composition (%) of organic matter.
# Structure: Biome -> Depth Zone -> Pool -> Component -> Percentage
# This data is synthesized from Table 4 of the scientific plan.
const BIOCHEMICAL_COMPOSITION = Dict(
    "Euphotic" => Dict(
        "Westerlies_Coastal" => Dict(
            "POM" => Dict("protein"=>45, "carbohydrate"=>30, "lipid"=>12),
            "DOM" => Dict("protein"=>15, "carbohydrate"=>35, "lipid"=>8)
        ),
        "Trade-Winds" => Dict(
            "POM" => Dict("protein"=>30, "carbohydrate"=>40, "lipid"=>17),
            "DOM" => Dict("protein"=>10, "carbohydrate"=>25, "lipid"=>7)
        )
    ),
    "Mesopelagic" => Dict( # Below the euphotic zone, composition becomes more uniform
        "All" => Dict(
            "POM" => Dict("protein"=>20, "carbohydrate"=>15, "lipid"=>7),
            "DOM" => Dict("protein"=>5, "carbohydrate"=>15, "lipid"=>3)
        )
    ),
    "Deep" => Dict( # In the deep ocean, only the most refractory components remain
        "All" => Dict(
            "POM" => Dict("protein"=>8, "carbohydrate"=>8, "lipid"=>3),
            "DOM" => Dict("protein"=>2, "carbohydrate"=>4, "lipid"=>1)
        )
    )
)


#= --- Core Calculation Functions --- =#

"""
    _calculate_bulk_pool(params::OrganicPoolParameters, depth::Real) -> Float64

    Calculates the total concentration of an organic pool (DOC or POC) at a given depth
    using an exponential decay model.
"""
function _calculate_bulk_pool(params::OrganicPoolParameters, depth::Real)
    z = max(0.0, depth) # Ensure depth is non-negative
    return params.C_deep + (params.C_surf - params.C_deep) * exp(-z / params.z_decay)
end

"""
    _partition_pool(biome::String, depth::Real, total_conc::Float64, pool_type::String)

    Partitions a bulk organic pool into its biochemical constituents.
"""
function _partition_pool(biome::String, depth::Real, total_conc::Float64, pool_type::String)
    # CORRECTED: Map the public-facing pool type (DOC/POC) to the internal key (DOM/POM)
    # used in the BIOCHEMICAL_COMPOSITION dictionary.
    composition_pool_key = if pool_type == "DOC"
        "DOM"
    elseif pool_type == "POC"
        "POM"
    else
        # This case should not be reached with the current implementation.
        println(stderr, "Invalid pool_type provided to _partition_pool: $pool_type")
        return Dict{String, Float64}()
    end

    # 1. Determine the depth zone
    depth_zone = if depth <= 150
        "Euphotic"
    elseif depth <= 1000
        "Mesopelagic"
    else
        "Deep"
    end

    # 2. Select the correct composition rules
    composition_rules = if depth_zone == "Euphotic"
        # In the euphotic zone, composition depends on the biome's productivity
        if biome == "Trade-Winds"
            BIOCHEMICAL_COMPOSITION[depth_zone]["Trade-Winds"][composition_pool_key]
        else # Polar, Westerlies, and Coastal are more productive
            BIOCHEMICAL_COMPOSITION[depth_zone]["Westerlies_Coastal"][composition_pool_key]
        end
    else
        # In deeper water, composition is more uniform across biomes
        BIOCHEMICAL_COMPOSITION[depth_zone]["All"][composition_pool_key]
    end

    # 3. Calculate the concentration of each component
    protein_conc = total_conc * (composition_rules["protein"] / 100.0)
    carb_conc = total_conc * (composition_rules["carbohydrate"] / 100.0)
    lipid_conc = total_conc * (composition_rules["lipid"] / 100.0)

    return Dict(
        "$(pool_type)_protein" => protein_conc,
        "$(pool_type)_carbohydrate" => carb_conc,
        "$(pool_type)_lipid" => lipid_conc
    )
end


#= --- Public Interface --- =#

"""
    get_organic_matter(biome::String, depth::Real) -> Union{Dict{String, Float64}, Nothing}

    Calculates the concentrations of DOC, POC, and their biochemical constituents.

    # Returns
    - A `Dict` mapping component names (e.g., "DOC_total", "POC_protein") to their
      concentrations in μmol C/kg.
    - Returns `nothing` if the biome name is invalid.
"""
function get_organic_matter(biome::String, depth::Real)
    if !haskey(ORGANIC_PARAMS, biome)
        println(stderr, "Invalid biome name provided for organic matter: $biome")
        return nothing
    end

    # 1. Calculate bulk DOC and POC concentrations
    doc_params = ORGANIC_PARAMS[biome].DOC
    poc_params = ORGANIC_PARAMS[biome].POC
    total_doc = _calculate_bulk_pool(doc_params, depth)
    total_poc = _calculate_bulk_pool(poc_params, depth)

    # 2. Partition each pool into biochemical components
    doc_components = _partition_pool(biome, depth, total_doc, "DOC")
    poc_components = _partition_pool(biome, depth, total_poc, "POC")

    # 3. Combine all results into a single dictionary
    results = merge(doc_components, poc_components)
    results["DOC_total"] = total_doc
    results["POC_total"] = total_poc

    return results
end

end # module OrganicMatter

