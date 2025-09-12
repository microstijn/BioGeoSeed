# BiogeochemistryModels.jl
# REFACTORED: This module now implements a more sophisticated, dual-Gaussian
# model for nitrate and nitrite to realistically simulate the Secondary Nitrite Maximum (SNM).

module BiogeochemistryModels

using ..Macronutrients

export get_redox_sensitive_species

#= --- Data Structures and Parameters --- =#

# NEW: A struct to hold biome-specific parameters for the enhanced nitrite model.
struct NitriteModelParameters
    z_snm_offset::Float64 # Vertical offset of the SNM from the OMZ core (m)
    snm_width::Float64    # Vertical spread/width of the nitrite peak (m)
    nitrite_yield::Float64# The peak fraction of potential nitrate converted to nitrite
end

# A dictionary mapping biomes to their specific nitrite model parameters.
const NITRITE_PARAMS = Dict(
    "Polar" => NitriteModelParameters(50.0, 100.0, 0.05), # Weak, broad SNM
    "Westerlies" => NitriteModelParameters(75.0, 150.0, 0.15),
    "Trade-Winds" => NitriteModelParameters(100.0, 200.0, 0.30), # Pronounced, deep SNM
    "Coastal" => NitriteModelParameters(50.0, 100.0, 0.25)
)

#= --- Redox State Thresholds --- =#
const OXIC_THRESHOLD = 80.0
const SUBOXIC_THRESHOLD = 5.0
const ANOXIC_THRESHOLD = 0.1

#= --- Core Functions --- =#

function determine_redox_state(o2_conc::Float64)
    if o2_conc > OXIC_THRESHOLD; return "Oxic"
    elseif o2_conc > SUBOXIC_THRESHOLD; return "Suboxic"
    elseif o2_conc > ANOXIC_THRESHOLD; return "Anoxic"
    else; return "Sulfidic"; end
end

"""
    _calculate_nitrate_nitrite(potential_nitrate, o2_conc, biome, depth)

    REFACTORED: Implements a dual-Gaussian model for nitrate and nitrite.
"""
function _calculate_nitrate_nitrite(potential_nitrate::Float64, o2_conc::Float64, biome::String, depth::Float64)
    # Get parameters for the OMZ (from PhysicalModels) and SNM
    omz_params = PhysicalModels.OXYGEN_PARAMS[biome]
    snm_params = NITRITE_PARAMS[biome]
    z = depth

    # 1. Model Nitrate Consumption: A Gaussian dip centered on the OMZ core.
    # The dip is strongest when oxygen is lowest.
    nitrate_consumption_factor = (OXIC_THRESHOLD - min(o2_conc, OXIC_THRESHOLD)) / OXIC_THRESHOLD
    nitrate_dip_exponent = -((z - omz_params.z_omz)^2) / (2 * omz_params.omz_width^2)
    nitrate_dip = nitrate_consumption_factor * exp(nitrate_dip_exponent)
    
    nitrate = potential_nitrate * (1.0 - nitrate_dip)

    # 2. Model Nitrite Peak (SNM): A separate Gaussian peak, offset from the OMZ.
    z_snm = omz_params.z_omz + snm_params.z_snm_offset # Offset depth for the nitrite peak
    nitrite_peak_exponent = -((z - z_snm)^2) / (2 * snm_params.snm_width^2)
    
    # Nitrite only forms in a narrow window of suboxic conditions.
    nitrite_production_factor = if SUBOXIC_THRESHOLD < o2_conc <= OXIC_THRESHOLD
        1.0 - (o2_conc - SUBOXIC_THRESHOLD) / (OXIC_THRESHOLD - SUBOXIC_THRESHOLD)
    else
        0.0
    end
    
    # Calculate nitrite based on the potential nitrate, yield, and production factor.
    max_possible_nitrite = potential_nitrate * snm_params.nitrite_yield
    nitrite = max_possible_nitrite * nitrite_production_factor * exp(nitrite_peak_exponent)
    
    return max(0.0, nitrate), max(0.0, nitrite)
end

function _calculate_redox_metals(redox_state::String)
    if redox_state == "Anoxic" || redox_state == "Sulfidic"
        return 2.0, 5.0  # fe2, mn2
    else
        return 0.001, 0.0005
    end
end

function _calculate_sulfur_species(redox_state::String)
    sulfate_conc = 28000.0
    if redox_state == "Sulfidic"
        sulfide_conc = sulfate_conc * 0.1
        sulfate_conc *= 0.9
        return sulfate_conc, sulfide_conc
    else
        return sulfate_conc, 0.0
    end
end

#= --- Public Interface --- =#
function get_redox_sensitive_species(biome::String, o2_conc::Float64, phosphate::Float64, depth::Float64)
    if !haskey(Macronutrients.BIOME_PARAMS, biome); @error "Invalid biome: $biome"; return nothing; end
    
    redox_state = determine_redox_state(o2_conc)
    
    # We need to reach into PhysicalModels to get OMZ parameters for the new nitrite model
    # This indicates a potential need for a future refactor to pass parameters more cleanly
    if !haskey(PhysicalModels.OXYGEN_PARAMS, biome); @error "Missing OMZ params for biome: $biome"; return nothing; end

    params = Macronutrients.BIOME_PARAMS[biome]
    potential_nitrate = params.RN_P * phosphate

    # Use the new, more sophisticated nitrate/nitrite model
    nitrate, nitrite = _calculate_nitrate_nitrite(potential_nitrate, o2_conc, biome, depth)
    
    iron, manganese = _calculate_redox_metals(redox_state)
    sulfate, sulfide = _calculate_sulfur_species(redox_state)
    
    return Dict(
        "redox_state" => redox_state, "nitrate" => nitrate, "nitrite" => nitrite,
        "iron" => iron, "manganese" => manganese, "sulfate" => sulfate, "sulfide" => sulfide
    )
end

end # module BiogeochemistryModels

