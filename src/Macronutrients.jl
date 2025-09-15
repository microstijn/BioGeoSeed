# Macronutrients.jl
# REFACTORED: This module now calculates only the non-redox-sensitive macronutrients
# (phosphate and silicate). Nitrate and Ammonium have been moved to BiogeochemistryModels.jl.

module Macronutrients

# Export the main function and the parameters so they can be used by other modules.
export get_macronutrients, BIOME_PARAMS

#= --- Data Structures and Parameters --- =#

"""
    BiomeParameters

    A struct to hold all the biome-specific parameters required for macronutrient
    calculations. This organizes the constants from the scientific plan.
    REVISED: Ammonium (NH4) parameters have been moved to BiogeochemistryModels.jl.
"""
struct BiomeParameters
    # Parameters for the foundational phosphate profile equation
    znut::Float64         # Nutricline depth (m)
    kPO4::Float64         # Steepness of the phosphacline
    PO4_surf::Float64     # Surface phosphate concentration (μmol/kg)
    PO4_deep::Float64     # Deep-water phosphate concentration (μmol/kg)

    # Stoichiometric Ratios (RN_P is used by BiogeochemistryModels.jl)
    RN_P::Float64         # Nitrogen-to-Phosphorus ratio
    RSi_P::Float64        # Silicate-to-Phosphorus ratio

    # Parameters for the silicate deep-water regeneration term
    zmax::Float64         # Depth of the phosphate maximum (m)
    mSi::Float64          # Slope of deep silicate regeneration (μmol/kg/m)
end

# A dictionary mapping biome names to their specific parameter sets.
# REVISED: Ammonium parameters removed.
const BIOME_PARAMS = Dict(
    "Polar" => BiomeParameters(45.0, 0.08, 0.5, 2.5, 13.0, 40.0, 800.0, 0.04),
    "Westerlies" => BiomeParameters(60.0, 0.06, 0.1, 2.5, 15.5, 30.0, 1000.0, 0.03),
    "Trade-Winds" => BiomeParameters(125.0, 0.03, 0.01, 2.5, 23.0, 3.0, 1200.0, 0.02),
    "Coastal" => BiomeParameters(25.0, 0.1, 0.3, 2.5, 15.5, 20.0, 500.0, 0.05)
)


#= --- Core Calculation Functions --- =#

function _calculate_phosphate(params::BiomeParameters, depth::Real)
    z = max(0.0, depth)
    numerator = params.PO4_deep - params.PO4_surf
    denominator = 1.0 + exp(params.kPO4 * (z - params.znut))
    concentration = params.PO4_deep - (numerator / denominator)
    return max(0.0, concentration)
end

function _calculate_silicate(params::BiomeParameters, phosphate_conc::Float64, depth::Real)
    z = max(0.0, depth)
    base_conc = params.RSi_P * phosphate_conc
    deep_regen = params.mSi * max(0.0, z - params.zmax)
    concentration = base_conc + deep_regen
    return max(0.0, concentration)
end


#= --- Public Interface --- =#
"""
    get_macronutrients(biome::String, depth::Real) -> Union{Dict{String, Float64}, Nothing}

    Calculates the concentrations of non-redox-sensitive macronutrients.
    REVISED: No longer calculates ammonium.
"""
# In Macronutrients.jl

function get_macronutrients(biome::String, depth::Real; user_phosphate::Union{Float64, Nothing}=nothing)
    if !haskey(BIOME_PARAMS, biome)
        # MODIFIED LINE
        @warn "Invalid biome provided to macronutrient model: $biome"
        return nothing
    end
    
    params = BIOME_PARAMS[biome]
    
    local phosphate
    if !isnothing(user_phosphate)
        phosphate = user_phosphate
    else
        phosphate = _calculate_phosphate(params, depth)
    end
    
    silicate = _calculate_silicate(params, phosphate, depth)
    
    return Dict(
        "phosphate" => phosphate,
        "silicate" => silicate
    )
end

end # module Macronutrients