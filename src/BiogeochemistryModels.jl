# BiogeochemistryModels.jl
# This new module implements the "redox tower" logic, determining the overall
# redox state of the environment and calculating the concentrations of all
# redox-sensitive chemical species based on the dissolved oxygen concentration.

module BiogeochemistryModels

# CORRECTED: Use `..` to correctly refer to the sibling Macronutrients module
# within the parent BioGeoSeed package.
using ..Macronutrients

export get_redox_sensitive_species

#= --- Redox State Thresholds --- =#
# Oxygen concentration thresholds (μmol/kg) that define the redox states.
const OXIC_THRESHOLD = 80.0
const SUBOXIC_THRESHOLD = 5.0
const ANOXIC_THRESHOLD = 0.1

#= --- Core Functions --- =#

"""
    determine_redox_state(o2_conc::Float64) -> String

    Determines the categorical redox state based on dissolved oxygen concentration.
"""
function determine_redox_state(o2_conc::Float64)
    if o2_conc > OXIC_THRESHOLD
        return "Oxic"
    elseif o2_conc > SUBOXIC_THRESHOLD
        return "Suboxic"
    elseif o2_conc > ANOXIC_THRESHOLD
        return "Anoxic"
    else
        return "Sulfidic"
    end
end

"""
    _calculate_nitrate_nitrite(redox_state::String, potential_nitrate::Float64)

    Calculates nitrate and nitrite. In suboxic conditions, a fraction of nitrate
    is converted to nitrite.
"""
function _calculate_nitrate_nitrite(redox_state::String, potential_nitrate::Float64)
    if redox_state == "Oxic" || redox_state == "Suboxic"
        # In suboxic conditions, we model a 20% conversion of nitrate to nitrite
        nitrite_fraction = (redox_state == "Suboxic") ? 0.2 : 0.0
        nitrite = potential_nitrate * nitrite_fraction
        nitrate = potential_nitrate * (1.0 - nitrite_fraction)
        return nitrate, nitrite
    else
        # In anoxic/sulfidic conditions, all nitrate/nitrite is assumed to be consumed.
        return 0.0, 0.0
    end
end

"""
    _calculate_redox_metals(redox_state::String)

    Calculates dissolved Fe and Mn. Concentrations are negligible in oxic waters
    but increase significantly in anoxic conditions.
"""
function _calculate_redox_metals(redox_state::String)
    # These are simplified, representative concentrations for anoxic waters.
    if redox_state == "Anoxic" || redox_state == "Sulfidic"
        fe2_conc = 2.0  # μmol/kg
        mn2_conc = 5.0  # μmol/kg
        return fe2_conc, mn2_conc
    else
        return 0.001, 0.0005 # Trace amounts in oxic/suboxic waters
    end
end

"""
    _calculate_sulfur_species(redox_state::String)

    Calculates sulfate and sulfide. Sulfate is constant until sulfidic conditions,
    where it is reduced to sulfide.
"""
function _calculate_sulfur_species(redox_state::String)
    sulfate_conc = 28000.0 # Relatively constant concentration in seawater (μmol/kg)
    
    if redox_state == "Sulfidic"
        # Model a 10% reduction of sulfate to sulfide in the most extreme reducing conditions.
        sulfide_conc = sulfate_conc * 0.1
        sulfate_conc *= 0.9
        return sulfate_conc, sulfide_conc
    else
        return sulfate_conc, 0.0
    end
end

#= --- Public Interface --- =#
function get_redox_sensitive_species(biome::String, o2_conc::Float64, phosphate::Float64)
    if !haskey(Macronutrients.BIOME_PARAMS, biome)
        @error "Invalid biome provided to redox model: $biome"
        return nothing
    end
    
    # 1. Determine the overall redox state
    redox_state = determine_redox_state(o2_conc)
    
    # 2. Calculate potential nitrate from phosphate (logic moved from Macronutrients)
    params = Macronutrients.BIOME_PARAMS[biome]
    potential_nitrate = params.RN_P * phosphate

    # 3. Calculate concentrations based on the redox state
    nitrate, nitrite = _calculate_nitrate_nitrite(redox_state, potential_nitrate)
    iron, manganese = _calculate_redox_metals(redox_state)
    sulfate, sulfide = _calculate_sulfur_species(redox_state)
    
    return Dict(
        "redox_state" => redox_state, # Include state as metadata
        "nitrate" => nitrate,
        "nitrite" => nitrite,
        "iron" => iron,
        "manganese" => manganese,
        "sulfate" => sulfate,
        "sulfide" => sulfide
    )
end

end # module BiogeochemistryModels

