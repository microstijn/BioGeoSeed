# BiogeochemistryModels.jl
# REWRITTEN: This module now implements a scientifically robust, process-based
# model for all redox-sensitive nitrogen species (Nitrate, Nitrite, Ammonium)
# that is causally linked to the dissolved oxygen profile.
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

    # Ammonium Parameters (moved from Macronutrients.jl)
    NH4_surf::Float64       # Surface ammonium concentration (μmol/kg)
    NH4_max_surf::Float64   # Max concentration at the shallow subsurface peak (μmol/kg)
    z_nh4_surf::Float64     # Depth of the shallow ammonium peak (m)
    sigma_nh4_surf::Float64 # Width of the shallow ammonium peak (m)
    nh4_omz_yield::Float64  # Yield factor for deep ammonium peak in the OMZ
    
    # Nitrate Deficit Parameter
    denit_factor::Float64   # Max fraction of nitrate consumed in the OMZ
end

const NITROGEN_PARAMS = Dict(
    "Polar" => NitrogenModelParameters(100.0, 50.0, 0.02, 0.5, 0.0, 0.2, 1.0, 60.0, 25.0, 0.05, 0.0),
    "Westerlies" => NitrogenModelParameters(90.0, 40.0, 0.08, 0.6, 0.4, 0.1, 0.8, 80.0, 30.0, 0.3, 0.5),
    "Trade-Winds" => NitrogenModelParameters(150.0, 60.0, 0.05, 0.8, 0.2, 0.05, 0.3, 120.0, 40.0, 0.1, 0.15),
    "Coastal" => NitrogenModelParameters(70.0, 35.0, 0.12, 0.5, 0.6, 0.5, 2.0, 50.0, 20.0, 0.8, 0.8)
)

#= --- Redox State Thresholds --- =#
const OXIC_THRESHOLD = 60.0
const SUBOXIC_THRESHOLD = 5.0
const ANOXIC_THRESHOLD = 0.1

#= --- Core Functions --- =#

function determine_redox_state(o2_conc::Float64)
    if o2_conc > OXIC_THRESHOLD; return "Oxic"
    elseif o2_conc > SUBOXIC_THRESHOLD; return "Suboxic"
    elseif o2_conc > ANOXIC_THRESHOLD; return "Anoxic"
    else; return "Sulfidic"; end
end

function _calculate_nitrogen_cycle(potential_nitrate::Float64, o2_conc::Float64, biome::String, depth::Real)
    omz_params = PhysicalModels.OXYGEN_PARAMS[biome]
    n_params = NITROGEN_PARAMS[biome]
    z = depth

    # Factor representing OMZ intensity (0 for oxic, 1 for fully anoxic)
    omz_intensity_factor = max(0.0, 1.0 - omz_params.omz_intensity / OXIC_THRESHOLD)

    # 1. Model Nitrate with OMZ deficit (Denitrification)
    nitrate_loss_magnitude = potential_nitrate * n_params.denit_factor * omz_intensity_factor
    deficit_exponent = -((z - omz_params.z_omz)^2) / (2 * omz_params.omz_width^2)
    nitrate_deficit = nitrate_loss_magnitude * exp(deficit_exponent)
    nitrate = potential_nitrate - nitrate_deficit

    # 2. Model Nitrite (Sum of two Gaussian peaks: PNM and SNM)
    # Peak 1: Primary Nitrite Maximum (PNM) - always present near the oxycline
    pnm_exponent = -((z - n_params.z_pnm)^2) / (2 * n_params.width_pnm^2)
    pnm_peak = (potential_nitrate * n_params.yield_pnm) * exp(pnm_exponent)
    
    # Peak 2: Secondary Nitrite Maximum (SNM) - appears in suboxic OMZs
    # CORRECTED: SNM peak now scales smoothly with OMZ intensity instead of using a hard threshold.
    snm_amplitude = (nitrate_deficit * n_params.yield_snm) * omz_intensity_factor
    snm_width = omz_params.omz_width * n_params.width_snm_factor
    snm_exponent = -((z - omz_params.z_omz)^2) / (2 * snm_width^2)
    snm_peak = snm_amplitude * exp(snm_exponent)
    nitrite = pnm_peak + snm_peak

    # 3. Model Ammonium (Sum of two Gaussian peaks: shallow and deep)
    # Peak 1: Shallow subsurface maximum (from microbial activity)
    shallow_peak_height = n_params.NH4_max_surf - n_params.NH4_surf
    shallow_exponent = -((z - n_params.z_nh4_surf)^2) / (2 * n_params.sigma_nh4_surf^2)
    shallow_ammonium = n_params.NH4_surf + shallow_peak_height * exp(shallow_exponent)

    # Peak 2: Deep OMZ accumulation (from inhibited nitrification)
    deep_peak_amplitude = n_params.nh4_omz_yield * omz_intensity_factor
    deep_exponent = -((z - omz_params.z_omz)^2) / (2 * omz_params.omz_width^2)
    deep_ammonium_peak = deep_peak_amplitude * exp(deep_exponent)
    ammonium = shallow_ammonium + deep_ammonium_peak

    return max(0.0, nitrate), max(0.0, nitrite), max(0.0, ammonium)
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
function get_redox_sensitive_species(biome::String, o2_conc::Float64, phosphate::Float64, depth::Real)
    if !haskey(Macronutrients.BIOME_PARAMS, biome); @error "Invalid biome: $biome"; return nothing; end
    
    redox_state = determine_redox_state(o2_conc)
    
    if !haskey(PhysicalModels.OXYGEN_PARAMS, biome); @error "Missing OMZ params for biome: $biome"; return nothing; end

    # Calculate potential nitrate from phosphate stoichiometry
    macro_params = Macronutrients.BIOME_PARAMS[biome]
    potential_nitrate = macro_params.RN_P * phosphate

    # Calculate N species based on the new causal model
    nitrate, nitrite, ammonium = _calculate_nitrogen_cycle(potential_nitrate, o2_conc, biome, depth)
    
    iron, manganese = _calculate_redox_metals(redox_state)
    sulfate, sulfide = _calculate_sulfur_species(redox_state)
    
    return Dict(
        "redox_state" => redox_state, "nitrate" => nitrate, "nitrite" => nitrite, "ammonium" => ammonium,
        "iron" => iron, "manganese" => manganese, "sulfate" => sulfate, "sulfide" => sulfide
    )
end

end # module BiogeochemistryModels