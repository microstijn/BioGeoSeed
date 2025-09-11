# Macronutrients.jl
# This module calculates the vertical concentration profiles of major macronutrients
# (phosphate, nitrate, silicate) based on the biogeochemical biome.

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
end

# A dictionary mapping biome names to their specific parameter sets.
# This data is synthesized from Table 2 of the project's scientific plan.
# Note: A single value is chosen for ranges to create a deterministic model.
const BIOME_PARAMS = Dict{String, BiomeParameters}(
    "Polar" => BiomeParameters(
        45.0,   # znut
        0.08,   # kPO4 (High steepness)
        0.5,    # PO4_surf
        2.5,    # PO4_deep (Pacific/Indian average)
        13.0,   # RN_P
        40.0,   # RSi_P
        500.0,  # zmax
        0.001   # mSi
    ),
    "Westerlies" => BiomeParameters(
        60.0,   # znut
        0.07,   # kPO4 (High steepness)
        0.1,    # PO4_surf
        2.5,    # PO4_deep
        15.5,   # RN_P
        30.0,   # RSi_P
        800.0,  # zmax
        0.001
    ),
    "Trade-Winds" => BiomeParameters(
        125.0,  # znut (Gyre value)
        0.03,   # kPO4 (Low steepness for gyre)
        0.01,   # PO4_surf
        2.5,    # PO4_deep
        23.0,   # RN_P (High value for N-fixation)
        3.0,    # RSi_P (Low value for picocyanobacteria)
        800.0,  # zmax
        0.0005
    ),
    "Coastal" => BiomeParameters(
        25.0,   # znut
        0.1,    # kPO4 (Very high steepness)
        0.3,    # PO4_surf
        2.5,    # PO4_deep
        15.5,   # RN_P
        20.0,   # RSi_P
        500.0,  # zmax
        0.001
    )
)


#= --- Core Calculation Functions --- =#

"""
    calculate_phosphate(params::BiomeParameters, depth::Real) -> Float64

    Calculates the phosphate concentration at a given depth using a sigmoidal function.
"""
function calculate_phosphate(params::BiomeParameters, depth::Real)
    # Clamp depth to be non-negative
    z = max(0.0, float(depth))
    
    numerator = params.PO4_deep - params.PO4_surf
    denominator = 1.0 + exp(params.kPO4 * (z - params.znut))
    
    concentration = params.PO4_deep - (numerator / denominator)
    return max(0.0, concentration) # Ensure non-negative result
end

"""
    calculate_nitrate(params::BiomeParameters, phosphate_conc::Float64) -> Float64

    Calculates nitrate concentration based on phosphate and a biome-specific N:P ratio.
"""
function calculate_nitrate(params::BiomeParameters, phosphate_conc::Float64)
    concentration = params.RN_P * phosphate_conc
    return max(0.0, concentration)
end

"""
    calculate_silicate(params::BiomeParameters, phosphate_conc::Float64, depth::Real) -> Float64

    Calculates silicate concentration based on phosphate, a Si:P ratio,
    and a linear deep-water regeneration term.
"""
function calculate_silicate(params::BiomeParameters, phosphate_conc::Float64, depth::Real)
    z = max(0.0, float(depth))
    
    base_conc = params.RSi_P * phosphate_conc
    deep_regen = params.mSi * max(0.0, z - params.zmax)
    
    concentration = base_conc + deep_regen
    return max(0.0, concentration)
end


"""
    get_macronutrients(biome::String, depth::Real) -> Union{Dict{String, Float64}, Nothing}

    The primary public function. Calculates the concentrations of all major
    macronutrients for a given biome and depth.

    # Arguments
    - `biome`: The name of the biome (e.g., "Polar", "Westerlies").
    - `depth`: The depth in meters.

    # Returns
    - A `Dict` mapping nutrient names to their concentrations (μmol/kg).
    - Returns `nothing` if the biome name is invalid.
"""
function get_macronutrients(biome::String, depth::Real)
    # Check if the provided biome name is valid.
    if !haskey(BIOME_PARAMS, biome)
        println(stderr, "Invalid biome name provided: $biome")
        return nothing
    end
    
    # Retrieve the parameter set for the given biome.
    params = BIOME_PARAMS[biome]
    
    # Calculate the concentration of each nutrient in sequence.
    phosphate = calculate_phosphate(params, depth)
    nitrate = calculate_nitrate(params, phosphate)
    silicate = calculate_silicate(params, phosphate, depth)
    
    # Return the results in a dictionary.
    return Dict(
        "phosphate" => phosphate,
        "nitrate"   => nitrate,
        "silicate"  => silicate
    )
end

end # module Macronutrients
