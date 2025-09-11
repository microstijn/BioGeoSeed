# Micronutrients.jl
# This module calculates the concentrations of key micronutrients (trace metals and vitamins)
# based on the biogeochemical biome, location, and macronutrient context.

module Micronutrients

export get_micronutrients

#= --- Data Structures and Parameters --- =#

# A dictionary holding biome-specific parameters for the mechanistic iron model.
# Data is from Section 4.1 and Table 1 of the scientific plan.
# D_flux: Representative dust deposition flux (g⋅m⁻²⋅y⁻¹)
# S_Fe: Fractional solubility of iron in dust (%)
# MLD: Mixed Layer Depth (m)
const IRON_PARAMS = Dict(
    "Polar" => (D_flux=0.1, S_Fe=10.0, MLD=50.0),
    "Westerlies" => (D_flux=1.0, S_Fe=15.0, MLD=50.0),
    "Trade-Winds" => (D_flux=10.0, S_Fe=5.0, MLD=50.0), # Higher flux, lower solubility near sources
    "Coastal" => (D_flux=2.0, S_Fe=10.0, MLD=40.0)
)

# A dictionary of trace metal to phosphate molar ratios (mmol:mol).
# This data is from Table 3 of the scientific plan.
const TRACE_METAL_RATIOS = Dict(
    "Polar" => Dict("Zn"=>12.5, "Cd"=>0.7, "Ni"=>0.7, "Cu"=>1.75, "Co"=>0.15, "Mn"=>1.5),
    "Westerlies" => Dict("Zn"=>6.5, "Cd"=>0.3, "Ni"=>1.2, "Cu"=>0.4, "Co"=>0.15, "Mn"=>0.45),
    "Trade-Winds" => Dict("Zn"=>4.5, "Cd"=>0.4, "Ni"=>1.0, "Cu"=>0.3, "Co"=>0.15, "Mn"=>0.35),
    "Coastal" => Dict("Zn"=>5.5, "Cd"=>0.2, "Ni"=>0.85, "Cu"=>0.3, "Co"=>0.15, "Mn"=>0.75)
)

# A dictionary of characteristic surface concentrations for B-vitamins (in pM).
# This data is from Section 4.3 of the scientific plan.
const VITAMIN_CONCS = Dict(
    "Polar" => Dict("B1"=>50.0, "B12"=>0.8),
    "Westerlies" => Dict("B1"=>40.0, "B12"=>1.0),
    "Trade-Winds" => Dict("B1"=>20.0, "B12"=>2.0),
    "Coastal" => Dict("B1"=>120.0, "B12"=>20.0)
)


#= --- Core Calculation Functions --- =#

"""
    _calculate_iron(biome::String) -> Float64

    Calculates dissolved iron concentration using a steady-state box model.
"""
function _calculate_iron(biome::String)
    # Constants for the iron calculation
    F_FE_IN_DUST = 0.035       # Mass fraction of iron in dust (unitless)
    MOLAR_MASS_FE = 55.845     # g/mol
    SECONDS_PER_YEAR = 31536000.0
    LAMBDA_FE = 1e-7           # First-order removal rate constant for Fe (s⁻¹) - an assumed value
    SEAWATER_DENSITY = 1025.0  # kg/m³

    params = IRON_PARAMS[biome]
    
    # Convert dust flux from g⋅m⁻²⋅y⁻¹ to mol Fe⋅m⁻²⋅s⁻¹
    flux_g_fe = params.D_flux * F_FE_IN_DUST
    flux_mol_fe = flux_g_fe / MOLAR_MASS_FE
    j_fe = flux_mol_fe / SECONDS_PER_YEAR # Molar flux of iron

    # Calculate concentration in mol/m³
    solubility = params.S_Fe / 100.0
    conc_mol_m3 = (j_fe * solubility) / (LAMBDA_FE * params.MLD)

    # Convert to μmol/kg
    conc_umol_kg = (conc_mol_m3 * 1e6) / SEAWATER_DENSITY
    
    # Return concentration in nmol/kg for typical oceanographic units
    return conc_umol_kg * 1000.0
end

"""
    _calculate_proxied_metals(biome::String, phosphate_conc::Float64) -> Dict{String, Float64}

    Calculates concentrations of trace metals using phosphate as a proxy.
"""
function _calculate_proxied_metals(biome::String, phosphate_conc::Float64)
    metal_concs = Dict{String, Float64}()
    ratios = TRACE_METAL_RATIOS[biome]

    for (metal, ratio) in ratios
        # Convert ratio from mmol/mol to mol/mol, then calculate concentration
        conc = (ratio / 1000.0) * phosphate_conc
        metal_concs[metal] = conc
    end
    return metal_concs
end

"""
    _calculate_vitamins(biome::String) -> Dict{String, Float64}

    Retrieves characteristic concentrations for B-vitamins.
"""
function _calculate_vitamins(biome::String)
    vitamin_concs_pm = VITAMIN_CONCS[biome]
    vitamin_concs_umol_kg = Dict{String, Float64}()

    for (vitamin, conc_pm) in vitamin_concs_pm
        # Convert from pM (pmol/L) to μmol/kg
        # 1 pM = 1e-12 mol/L. Assume 1 L ≈ 1.025 kg seawater.
        conc_mol_kg = (conc_pm * 1e-12) / 1.025
        conc_umol_kg = conc_mol_kg * 1e6
        vitamin_concs_umol_kg[vitamin] = conc_umol_kg
    end
    return vitamin_concs_umol_kg
end


#= --- Public Interface --- =#

"""
    get_micronutrients(biome::String, macronutrients::Dict) -> Union{Dict{String, Float64}, Nothing}

    Calculates concentrations of all relevant micronutrients for a given biome,
    using the pre-calculated macronutrient concentrations.

    # Arguments
    - `biome`: The name of the biome (e.g., "Polar").
    - `macronutrients`: A Dict from `get_macronutrients`, must contain "phosphate".

    # Returns
    - A `Dict` mapping micronutrient names to their concentrations (μmol/kg, except Fe in nmol/kg).
    - Returns `nothing` if the biome name is invalid.
"""
function get_micronutrients(biome::String, macronutrients::Dict)
    if !haskey(IRON_PARAMS, biome)
        println(stderr, "Invalid biome name provided for micronutrients: $biome")
        return nothing
    end

    if !haskey(macronutrients, "phosphate")
        println(stderr, "Macronutrient dictionary must contain a 'phosphate' key.")
        return nothing
    end

    phosphate_conc = macronutrients["phosphate"]

    # Calculate each group of micronutrients
    iron = Dict("Fe" => _calculate_iron(biome))
    proxied_metals = _calculate_proxied_metals(biome, phosphate_conc)
    vitamins = _calculate_vitamins(biome)

    # Merge all dictionaries into one and return
    return merge(iron, proxied_metals, vitamins)
end

end # module Micronutrients
