# Micronutrients.jl
# REFACTORED: This module now calculates only the non-redox-sensitive micronutrients.
# Iron and Manganese have been moved to BiogeochemistryModels.jl.

module Micronutrients

export get_micronutrients

#= --- Data Structures and Parameters --- =#

# REFACTORED: Ratios for Fe and Mn have been removed as they are now redox-sensitive.
const TRACE_METAL_RATIOS = Dict(
    "Polar" => Dict("Zn"=>12.5, "Cd"=>0.7, "Ni"=>0.7, "Cu"=>1.75, "Co"=>0.15),
    "Westerlies" => Dict("Zn"=>6.5, "Cd"=>0.3, "Ni"=>1.2, "Cu"=>0.4, "Co"=>0.15),
    "Trade-Winds" => Dict("Zn"=>4.5, "Cd"=>0.4, "Ni"=>1.0, "Cu"=>0.3, "Co"=>0.15),
    "Coastal" => Dict("Zn"=>5.5, "Cd"=>0.2, "Ni"=>0.85, "Cu"=>0.3, "Co"=>0.15)
)

# A dictionary of characteristic surface concentrations for B-vitamins (in pM).
const VITAMIN_CONCS = Dict(
    "Polar" => Dict("B1"=>50.0, "B12"=>0.8),
    "Westerlies" => Dict("B1"=>40.0, "B12"=>1.0),
    "Trade-Winds" => Dict("B1"=>20.0, "B12"=>2.0),
    "Coastal" => Dict("B1"=>120.0, "B12"=>20.0)
)


#= --- Core Calculation Functions --- =#

function _calculate_proxied_metals(biome::String, phosphate_conc::Float64)
    metal_concs = Dict{String, Float64}()
    ratios = TRACE_METAL_RATIOS[biome]
    for (metal, ratio) in ratios
        # Convert ratio from mmol/mol to mol/mol, then calculate concentration in umol/kg
        metal_concs[metal] = (ratio / 1000.0) * phosphate_conc
    end
    return metal_concs
end

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
function get_micronutrients(biome::String, macronutrients::Dict)
    if !haskey(TRACE_METAL_RATIOS, biome)
        # MODIFIED LINE
        @warn "Invalid biome provided for micronutrients: $biome"
        return nothing
    end
    if !haskey(macronutrients, "phosphate")
        # MODIFIED LINE
        @error "Macronutrient dictionary must contain a 'phosphate' key."
        return nothing
    end

    phosphate_conc = macronutrients["phosphate"]
    
    proxied_metals = _calculate_proxied_metals(biome, phosphate_conc)
    vitamins = _calculate_vitamins(biome)

    return merge(proxied_metals, vitamins)
end

end # module Micronutrients

