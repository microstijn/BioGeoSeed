# Macronutrients.jl
# This module calculates the vertical concentration profiles of major macronutrients
# (phosphate, nitrate, silicate, and ammonium) based on the biogeochemical biome.

module Macronutrients

export get_macronutrients

#= --- Data Structures and Parameters --- =#

"""
    BiomeParameters

    A struct to hold all the biome-specific parameters required for macronutrient
    calculations. This organizes the constants from the scientific plan.
"""
struct BiomeParameters
    # Parameters for the foundational phosphate profile equation
    znut::Float64         # Nutricline depth (m)
    kPO4::Float64         # Steepness of the phosphacline
    PO4_surf::Float64     # Surface phosphate concentration (μmol/kg)
    PO4_deep::Float64     # Deep-water phosphate concentration (μmol/kg)

    # Stoichiometric Ratios
    RN_P::Float64         # Nitrogen-to-Phosphorus ratio
    RSi_P::Float64        # Silicate-to-Phosphorus ratio

    # Parameters for the silicate deep-water regeneration term
    zmax::Float64         # Depth of the phosphate maximum (m)
    mSi::Float64          # Slope of deep silicate regeneration (μmol/kg/m)
    
    # NEW: Parameters for the ammonium (NH4) profile
    NH4_surf::Float64     # Surface ammonium concentration (μmol/kg)
    NH4_max::Float64      # Max concentration at the subsurface peak (μmol/kg)
    z_NH4_max::Float64    # Depth of the ammonium peak (m)
    sigma_NH4::Float64    # Width/spread of the ammonium peak (m)
end

# A dictionary mapping biome names to their specific parameter sets.
# This data is synthesized from Table 2 and Section 2.2 of the new specification.
const BIOME_PARAMS = Dict(
    "Polar" => BiomeParameters(45.0, 0.08, 0.5, 2.5, 13.0, 40.0, 800.0, 0.04, 0.2, 1.0, 60.0, 25.0),
    "Westerlies" => BiomeParameters(60.0, 0.06, 0.1, 2.5, 15.5, 30.0, 1000.0, 0.03, 0.1, 0.8, 80.0, 30.0),
    "Trade-Winds" => BiomeParameters(125.0, 0.03, 0.01, 2.5, 23.0, 3.0, 1200.0, 0.02, 0.05, 0.3, 120.0, 40.0),
    "Coastal" => BiomeParameters(25.0, 0.1, 0.3, 2.5, 15.5, 20.0, 500.0, 0.05, 0.5, 2.0, 50.0, 20.0)
)


#= --- Core Calculation Functions --- =#

function _calculate_phosphate(params::BiomeParameters, depth::Real)
    z = max(0.0, depth)
    numerator = params.PO4_deep - params.PO4_surf
    denominator = 1.0 + exp(params.kPO4 * (z - params.znut))
    concentration = params.PO4_deep - (numerator / denominator)
    return max(0.0, concentration)
end

function _calculate_nitrate(params::BiomeParameters, phosphate_conc::Float64)
    concentration = params.RN_P * phosphate_conc
    return max(0.0, concentration)
end

function _calculate_silicate(params::BiomeParameters, phosphate_conc::Float64, depth::Real)
    z = max(0.0, depth)
    base_conc = params.RSi_P * phosphate_conc
    deep_regen = params.mSi * max(0.0, z - params.zmax)
    concentration = base_conc + deep_regen
    return max(0.0, concentration)
end

"""
    _calculate_ammonium(params::BiomeParameters, depth::Real) -> Float64

    NEW: Calculates ammonium concentration, modeling a subsurface maximum with a
    Gaussian peak.
"""
function _calculate_ammonium(params::BiomeParameters, depth::Real)
    z = max(0.0, depth)
    peak_height = params.NH4_max - params.NH4_surf
    exponent = -((z - params.z_NH4_max)^2) / (2 * params.sigma_NH4^2)
    concentration = params.NH4_surf + peak_height * exp(exponent)
    return max(0.0, concentration)
end


"""
    get_macronutrients(biome::String, depth::Real) -> Union{Dict{String, Float64}, Nothing}

    The primary public function. Calculates the concentrations of all major
    macronutrients for a given biome and depth.
"""
function get_macronutrients(biome::String, depth::Real)
    if !haskey(BIOME_PARAMS, biome)
        println(stderr, "Invalid biome name provided: $biome")
        return nothing
    end
    
    params = BIOME_PARAMS[biome]
    
    # Calculate each nutrient in sequence
    phosphate = _calculate_phosphate(params, depth)
    nitrate = _calculate_nitrate(params, phosphate)
    silicate = _calculate_silicate(params, phosphate, depth)
    ammonium = _calculate_ammonium(params, depth) # NEW
    
    return Dict(
        "phosphate" => phosphate,
        "nitrate" => nitrate,
        "silicate" => silicate,
        "ammonium" => ammonium, # NEW
    )
end

end # module Macronutrients

