# BiogeochemistryModels.jl
# REFACTORED: This module now implements a more sophisticated, dual-Gaussian
# model for nitrate and nitrite to realistically simulate the Secondary Nitrite Maximum (SNM).

module BiogeochemistryModels

using ..Macronutrients
using ..PhysicalModels 

export get_redox_sensitive_species

#= --- Data Structures and Parameters --- =#

struct NitriteModelParameters
    z_snm_offset::Float64 
    snm_width::Float64    
    nitrite_yield::Float64
end

const NITRITE_PARAMS = Dict(
    "Polar" => NitriteModelParameters(50.0, 100.0, 0.05),
    "Westerlies" => NitriteModelParameters(75.0, 150.0, 0.15),
    "Trade-Winds" => NitriteModelParameters(100.0, 200.0, 0.30),
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
function _calculate_nitrate_nitrite(potential_nitrate::Float64, o2_conc::Float64, biome::String, depth::Real)
    omz_params = PhysicalModels.OXYGEN_PARAMS[biome]
    snm_params = NITRITE_PARAMS[biome]
    z = depth

    # 1. Model Nitrate Consumption
    nitrate_consumption_factor = if o2_conc >= OXIC_THRESHOLD
        0.0
    elseif o2_conc <= SUBOXIC_THRESHOLD
        0.99 
    else 
        0.99 * (1.0 - (o2_conc - SUBOXIC_THRESHOLD) / (OXIC_THRESHOLD - SUBOXIC_THRESHOLD))
    end
    
    nitrate_dip_exponent = -((z - omz_params.z_omz)^2) / (2 * omz_params.omz_width^2)
    nitrate_dip = nitrate_consumption_factor * exp(nitrate_dip_exponent)
    
    nitrate = potential_nitrate * (1.0 - nitrate_dip)

    # 2. Model Nitrite Peak (SNM)
    z_snm = omz_params.z_omz + snm_params.z_snm_offset 
    nitrite_peak_exponent = -((z - z_snm)^2) / (2 * snm_params.snm_width^2)
    
    nitrite_production_factor = if SUBOXIC_THRESHOLD < o2_conc <= OXIC_THRESHOLD
        1.0 - (o2_conc - SUBOXIC_THRESHOLD) / (OXIC_THRESHOLD - SUBOXIC_THRESHOLD)
    else
        0.0
    end
    
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
# CORRECTED: The type annotation for `depth` is changed from ::Float64 to ::Real
function get_redox_sensitive_species(biome::String, o2_conc::Float64, phosphate::Float64, depth::Real)
    if !haskey(Macronutrients.BIOME_PARAMS, biome); @error "Invalid biome: $biome"; return nothing; end
    
    redox_state = determine_redox_state(o2_conc)
    
    if !haskey(PhysicalModels.OXYGEN_PARAMS, biome); @error "Missing OMZ params for biome: $biome"; return nothing; end

    params = Macronutrients.BIOME_PARAMS[biome]
    potential_nitrate = params.RN_P * phosphate

    nitrate, nitrite = _calculate_nitrate_nitrite(potential_nitrate, o2_conc, biome, depth)
    
    iron, manganese = _calculate_redox_metals(redox_state)
    sulfate, sulfide = _calculate_sulfur_species(redox_state)
    
    return Dict(
        "redox_state" => redox_state, "nitrate" => nitrate, "nitrite" => nitrite,
        "iron" => iron, "manganese" => manganese, "sulfate" => sulfate, "sulfide" => sulfide
    )
end

end # module BiogeochemistryModels

