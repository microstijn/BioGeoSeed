# BiogeochemistryModels.jl
# REWRITTEN: This module now implements a scientifically robust, process-based
# model for all redox-sensitive nitrogen species (Nitrate, Nitrite, Ammonium)
# that is causally linked to the dissolved oxygen profile.
# REVISED: Replaced discrete redox state logic with continuous inhibition functions
# and added an anammox process to balance the N-cycle.
module BiogeochemistryModels

using ..Macronutrients
using ..PhysicalModels

export get_redox_sensitive_species

#= --- Data Structures and Parameters --- =#

struct NitrogenModelParameters
    # PNM (Primary Nitrite Maximum) Parameters
    z_pnm::Float64          # Depth of the PNM peak (m)
    width_pnm::Float64      # Width of the PNM peak (m)
    yield_pnm::Float64      # Yield factor for PNM from potential nitrate

    # SNM (Secondary Nitrite Maximum) Parameters
    width_snm_factor::Float64 # Factor to scale SNM width relative to OMZ width
    yield_snm::Float64      # Yield factor for SNM from consumed nitrate

    # Ammonium Parameters
    NH4_surf::Float64       # Surface ammonium concentration (μmol/kg)
    NH4_max_surf::Float64   # Max concentration at the shallow subsurface peak (μmol/kg)
    z_nh4_surf::Float64     # Depth of the shallow ammonium peak (m)
    sigma_nh4_surf::Float64 # Width of the shallow ammonium peak (m)
    nh4_omz_yield::Float64  # Yield factor for deep ammonium peak in the OMZ
    
    # Nitrate Deficit Parameter
    denit_factor::Float64   # Max fraction of nitrate consumed in the OMZ
    
    # NEW: Anammox Parameter
    k_anammox::Float64      # Rate constant for the anammox reaction
end

const NITROGEN_PARAMS = Dict(
    "Polar" => NitrogenModelParameters(100.0, 50.0, 0.02, 0.5, 0.0, 0.2, 1.0, 60.0, 25.0, 0.05, 0.0, 0.0),
    "Westerlies" => NitrogenModelParameters(90.0, 40.0, 0.08, 0.6, 0.4, 0.1, 0.8, 80.0, 30.0, 0.3, 0.5, 0.03),
    "Trade-Winds" => NitrogenModelParameters(150.0, 60.0, 0.05, 0.8, 0.2, 0.05, 0.3, 120.0, 40.0, 0.1, 0.15, 0.01),
    "Coastal" => NitrogenModelParameters(70.0, 35.0, 0.12, 0.5, 0.6, 0.5, 2.0, 50.0, 20.0, 0.8, 0.8, 0.05) # Higher anammox rate
)

#= --- Redox State Constants (for inhibition scaling) --- =#
# NEW: Half-saturation constants (k_o2) for oxygen inhibition in μmol/kg
# These replace the old hard-coded thresholds[cite: 28, 29, 30].
const K_O2_DENIT = 10.0  # Denitrification is inhibited by moderate oxygen
const K_O2_METAL = 5.0   # Fe/Mn reduction is strongly inhibited by oxygen
const K_O2_SULFATE = 0.5 # Sulfate reduction requires near-anoxic conditions

#= --- Core Functions --- =#

# REMOVED: The discrete determine_redox_state function is no longer needed.

"""
    _calculate_inhibition_factor(o2_conc, k_o2)

NEW: Calculates a smooth inhibition factor for an anaerobic process based on oxygen.
The factor smoothly approaches 1.0 at low O2 and 0.0 at high O2.
k_o2 is the half-saturation constant for oxygen inhibition. This replaces the
discontinuous 'if/else' logic as recommended in the technical review.
"""
function _calculate_inhibition_factor(o2_conc::Float64, k_o2::Float64)
    return k_o2 / (k_o2 + o2_conc)
end

function _calculate_nitrogen_cycle(potential_nitrate::Float64, o2_conc::Float64, biome::String, depth::Real)
    omz_params = PhysicalModels.OXYGEN_PARAMS[biome]
    n_params = NITROGEN_PARAMS[biome]
    z = depth

    # REVISED: Use a smooth "permission" factor for all anaerobic OMZ processes.
    denit_permission_factor = _calculate_inhibition_factor(o2_conc, K_O2_DENIT)

    # 1. Model Nitrate with OMZ deficit (Denitrification)
    nitrate_loss_magnitude = potential_nitrate * n_params.denit_factor * denit_permission_factor
    deficit_exponent = -((z - omz_params.z_omz)^2) / (2 * omz_params.omz_width^2)
    nitrate_deficit = nitrate_loss_magnitude * exp(deficit_exponent)
    nitrate = potential_nitrate - nitrate_deficit

    # 2. Model Nitrite (Sum of two Gaussian peaks: PNM and SNM)
    pnm_exponent = -((z - n_params.z_pnm)^2) / (2 * n_params.width_pnm^2)
    pnm_peak = (potential_nitrate * n_params.yield_pnm) * exp(pnm_exponent)
    
    # REVISED: SNM peak now scales smoothly with the denitrification permission factor[cite: 32].
    snm_amplitude = (nitrate_deficit * n_params.yield_snm)
    snm_width = omz_params.omz_width * n_params.width_snm_factor
    snm_exponent = -((z - omz_params.z_omz)^2) / (2 * snm_width^2)
    snm_peak = snm_amplitude * exp(snm_exponent)
    initial_nitrite = pnm_peak + snm_peak

    # 3. Model Ammonium (Sum of two Gaussian peaks: shallow and deep)
    shallow_peak_height = n_params.NH4_max_surf - n_params.NH4_surf
    shallow_exponent = -((z - n_params.z_nh4_surf)^2) / (2 * n_params.sigma_nh4_surf^2)
    shallow_ammonium = n_params.NH4_surf + shallow_peak_height * exp(shallow_exponent)

    # REVISED: Deep OMZ accumulation also scales smoothly with the permission factor[cite: 33].
    deep_peak_amplitude = n_params.nh4_omz_yield * denit_permission_factor
    deep_exponent = -((z - omz_params.z_omz)^2) / (2 * omz_params.omz_width^2)
    deep_ammonium_peak = deep_peak_amplitude * exp(deep_exponent)
    initial_ammonium = shallow_ammonium + deep_ammonium_peak

    # 4. NEW: Add an Anammox Sink for Nitrite and Ammonium
    # This addresses the scientific review's finding of an incomplete N-cycle.
    # Anammox consumes the excess nitrite produced by denitrification, a key N-loss pathway.
    anammox_rate = n_params.k_anammox * initial_nitrite * initial_ammonium * denit_permission_factor

    # Apply the sink to both nitrite and ammonium pools
    final_nitrite = initial_nitrite - anammox_rate
    final_ammonium = initial_ammonium - anammox_rate
    
    return max(0.0, nitrate), max(0.0, final_nitrite), max(0.0, final_ammonium)
end


function _calculate_redox_metals(o2_conc::Float64)
    # REVISED: Calculate concentrations based on a smooth transition instead of a discrete state[cite: 34].
    permission_factor = _calculate_inhibition_factor(o2_conc, K_O2_METAL)
    
    # Concentrations now scale continuously from a baseline (oxic) to a maximum (anoxic) value.
    fe2 = 0.001 + (2.0 - 0.001) * permission_factor
    mn2 = 0.0005 + (5.0 - 0.0005) * permission_factor
    return fe2, mn2
end

function _calculate_sulfur_species(o2_conc::Float64)
    # REVISED: Calculate concentrations based on a smooth transition.
    permission_factor = _calculate_inhibition_factor(o2_conc, K_O2_SULFATE)
    
    sulfate_conc_initial = 28000.0
    sulfide_production = (sulfate_conc_initial * 0.1) * permission_factor
    
    final_sulfate = sulfate_conc_initial - sulfide_production
    final_sulfide = sulfide_production
    return final_sulfate, final_sulfide
end

#= --- Public Interface --- =#
function get_redox_sensitive_species(biome::String, o2_conc::Float64, phosphate::Float64, depth::Real)
    if !haskey(Macronutrients.BIOME_PARAMS, biome); @error "Invalid biome: $biome"; return nothing; end 
    if !haskey(PhysicalModels.OXYGEN_PARAMS, biome); @error "Missing OMZ params for biome: $biome"; return nothing; end

    # Calculate potential nitrate from phosphate stoichiometry
    macro_params = Macronutrients.BIOME_PARAMS[biome]
    potential_nitrate = macro_params.RN_P * phosphate

    # Calculate N species based on the new causal model
    nitrate, nitrite, ammonium = _calculate_nitrogen_cycle(potential_nitrate, o2_conc, biome, depth)
    
    # REVISED: Pass o2_conc directly to the metal and sulfur functions.
    iron, manganese = _calculate_redox_metals(o2_conc)
    sulfate, sulfide = _calculate_sulfur_species(o2_conc)
    
    return Dict(
        # The "redox_state" string is removed as it's no longer used by the model.
        "nitrate" => nitrate, "nitrite" => nitrite, "ammonium" => ammonium,
        "iron" => iron, "manganese" => manganese, "sulfate" => sulfate, "sulfide" => sulfide
    )
end

end # module BiogeochemistryModels