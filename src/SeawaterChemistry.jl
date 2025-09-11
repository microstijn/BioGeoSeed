# SeawaterChemistry.jl
# This module calculates ambient seawater pH and dissolved CO2 concentration
# based on biome-specific parameters for temperature and atmospheric pCO2.

module SeawaterChemistry

export get_seawater_chemistry

#= --- Data Structures and Parameters --- =#

# A dictionary holding biome-specific parameters for the chemistry calculations,
# as specified in the new technical document.
const CHEMISTRY_PARAMS = Dict(
    # SST: Sea Surface Temperature (°C)
    # PCO2_ATM: Atmospheric CO2 partial pressure (μatm)
    "Polar" => (SST = -1.0, PCO2_ATM = 410.0),
    "Westerlies" => (SST = 15.0, PCO2_ATM = 420.0),
    "Trade-Winds" => (SST = 25.0, PCO2_ATM = 415.0),
    "Coastal" => (SST = 18.0, PCO2_ATM = 425.0) # Higher pCO2 due to local processes
)


#= --- Core Calculation Functions --- =#

"""
    _calculate_dissolved_co2(temp_C::Float64, pCO2_uatm::Float64) -> Float64

    Calculates the equilibrium concentration of dissolved CO2 in seawater using
    a simplified version of Henry's Law.
"""
function _calculate_dissolved_co2(temp_C::Float64, pCO2_uatm::Float64)
    # Simplified empirical formula for Henry's constant (Kh) in mol/(L·atm)
    # This is a temperature-dependent relationship.
    temp_K = temp_C + 273.15
    Kh = 0.034 * exp(2400 * ((1 / temp_K) - (1 / 298.15)))
    
    # Convert pCO2 from μatm to atm
    pCO2_atm = pCO2_uatm * 1e-6
    
    # Henry's Law: [CO2] = Kh * pCO2
    conc_mol_L = Kh * pCO2_atm
    
    # Convert from mol/L to μmol/kg (assuming seawater density ≈ 1.025 kg/L)
    conc_umol_kg = (conc_mol_L * 1e6) / 1.025
    return conc_umol_kg
end

"""
    _calculate_ph(temp_C::Float64, pCO2_uatm::Float64) -> Float64

    Calculates seawater pH using a simplified empirical model that accounts for
    temperature and CO2 concentration.
"""
function _calculate_ph(temp_C::Float64, pCO2_uatm::Float64)
    # Start with a pre-industrial baseline pH
    baseline_ph = 8.25
    
    # Adjust for modern pCO2 levels (acidification)
    ph_pco2_effect = -0.001 * (pCO2_uatm - 280.0)
    
    # Adjust for temperature (colder water absorbs more CO2, leading to lower pH)
    ph_temp_effect = -0.005 * (temp_C - 15.0)
    
    # Combine effects to get the final estimated pH
    final_ph = baseline_ph + ph_pco2_effect + ph_temp_effect
    return round(final_ph, digits=2)
end


#= --- Public Interface --- =#

"""
    get_seawater_chemistry(biome::String) -> Union{Dict{String, Float64}, Nothing}

    The primary public function. Calculates pH and dissolved CO2 for a given biome.
"""
function get_seawater_chemistry(biome::String)
    if !haskey(CHEMISTRY_PARAMS, biome)
        println(stderr, "Invalid biome name provided for chemistry: $biome")
        return nothing
    end
    
    params = CHEMISTRY_PARAMS[biome]
    
    dissolved_co2 = _calculate_dissolved_co2(params.SST, params.PCO2_ATM)
    ph = _calculate_ph(params.SST, params.PCO2_ATM)
    
    return Dict(
        "dissolved_co2" => dissolved_co2,
        "pH" => ph
    )
end

end # module SeawaterChemistry
