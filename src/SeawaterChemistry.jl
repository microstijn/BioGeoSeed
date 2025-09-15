# SeawaterChemistry.jl
# This module calculates ambient seawater pH and dissolved CO2 concentration
# based on biome-specific parameters for temperature and atmospheric pCO2.
module SeawaterChemistry

using ..PhysicalModels

export get_seawater_chemistry

#= --- Data Structures and Parameters --- =#

const CHEMISTRY_PARAMS = Dict(
    # SST: Sea Surface Temperature (°C)
    # PCO2_ATM: Atmospheric CO2 partial pressure (μatm)
    "Polar" => (SST = -1.0, PCO2_ATM = 410.0),
    "Westerlies" => (SST = 15.0, PCO2_ATM = 420.0),
    "Trade-Winds" => (SST = 25.0, PCO2_ATM = 415.0),
    "Coastal" => (SST = 18.0, PCO2_ATM = 425.0)
)

#= --- Core Calculation Functions --- =#

"""
    _calculate_dissolved_co2(temp_C::Real, pCO2_uatm::Real) -> Float64

    Calculates the equilibrium concentration of dissolved CO2 in seawater.
"""
# MODIFIED: Changed Float64 to Real for flexibility
function _calculate_dissolved_co2(temp_C::Real, pCO2_uatm::Real)
    temp_K = temp_C + 273.15
    Kh = 0.034 * exp(2400 * ((1 / temp_K) - (1 / 298.15)))
    
    pCO2_atm = pCO2_uatm * 1e-6
    
    conc_mol_L = Kh * pCO2_atm
    
    conc_umol_kg = (conc_mol_L * 1e6) / 1.025
    return conc_umol_kg
end

"""
    _calculate_ph(temp_C::Real, pCO2_uatm::Real) -> Float64

    Calculates seawater pH using a simplified empirical model.
"""
# MODIFIED: Changed Float64 to Real for flexibility
function _calculate_ph(temp_C::Real, pCO2_uatm::Real)
    baseline_ph = 8.25
    ph_pco2_effect = -0.001 * (pCO2_uatm - 280.0)
    ph_temp_effect = -0.005 * (temp_C - 15.0)
    
    final_ph = baseline_ph + ph_pco2_effect + ph_temp_effect
    return round(final_ph, digits=2)
end

#= --- Public Interface --- =#

"""
    get_seawater_chemistry(biome::String; user_temp::Union{Real, Nothing}=nothing) -> Union{Dict{String, Float64}, Nothing}

    Calculates pH and dissolved CO2 for a given biome,
    optionally using a user-provided temperature.
"""
function get_seawater_chemistry(biome::String, o2_params::PhysicalModels.OxygenParameters, o2_conc_at_depth::Real; user_temp::Union{Real, Nothing}=nothing)
    if !haskey(CHEMISTRY_PARAMS, biome)
        @warn "Invalid biome name provided for chemistry: $biome"
        return nothing
    end
    
    params = CHEMISTRY_PARAMS[biome]
    
    local temp_to_use
    if !isnothing(user_temp)
        temp_to_use = user_temp
    else
        temp_to_use = params.SST
    end
    
    # --- BIOLOGICAL PUMP IMPLEMENTATION START ---
    
    # 1. Calculate the surface-equilibrium CO2 concentration
    co2_surface = _calculate_dissolved_co2(temp_to_use, params.PCO2_ATM)
    
    # 2. Calculate Apparent Oxygen Utilization (AOU)
    # This is the difference between what the oxygen *should* be (surface saturation) and what it is.
    o2_saturated = o2_params.O2_surf_sat
    aou = o2_saturated - o2_conc_at_depth
    
    # 3. Convert AOU to CO2 produced via respiration (using a C:O2 ratio of ~0.77)
    co2_produced = max(0.0, aou) * 0.77
    
    # 4. The final CO2 concentration is the sum of the surface value and what's been added at depth.
    final_co2 = co2_surface + co2_produced
    
    # --- BIOLOGICAL PUMP IMPLEMENTATION END ---
    
    ph = _calculate_ph(temp_to_use, params.PCO2_ATM)
    
    return Dict(
        "dissolved_co2" => final_co2,
        "pH" => ph
    )
end

end # module SeawaterChemistry