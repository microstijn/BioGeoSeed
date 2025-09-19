# PhysicalModels.jl
# This module is responsible for calculating key physical parameters of the
# marine environment, starting with the dissolved oxygen profile, which is the
# foundation of the new redox framework.
module PhysicalModels

export calculate_oxygen, OXYGEN_PARAMS 

#= Data Structures and Parameters  =#

"""
    OxygenParameters

    A struct to hold all biome-specific parameters required for calculating
    the dissolved oxygen vertical profile.
    REVISED: Parameters now support a more realistic profile with a distinct OMZ.
"""
struct OxygenParameters
    O2_surf_sat::Float64  # Surface oxygen saturation concentration (μmol/kg)
    O2_deep::Float64      # Deep-water oxygen concentration (μmol/kg)
    z_oxycline::Float64   # Depth of the main oxycline (m)
    k_oxycline::Float64   # Steepness of the oxycline
    z_omz::Float64        # Depth of the Oxygen Minimum Zone (OMZ) core (m)
    omz_intensity::Float64# O2 concentration at the OMZ core (μmol/kg)
    omz_width::Float64    # Vertical spread/width of the OMZ (m)
end

# A dictionary mapping biomes to their specific oxygen profile parameters.
const OXYGEN_PARAMS = Dict(
    "Polar" => OxygenParameters(340.0, 210.0, 150.0, 0.05, 1000.0, 180.0, 500.0), # Very weak OMZ
    "Westerlies" => OxygenParameters(280.0, 150.0, 100.0, 0.04, 800.0, 40.0, 350.0), # Shallow, intense OMZ
    "Trade-Winds" => OxygenParameters(220.0, 180.0, 200.0, 0.03, 1200.0, 90.0, 450.0), # Deep, weak OMZ
    "Coastal" => OxygenParameters(260.0, 100.0, 80.0, 0.06, 400.0, 15.0, 200.0)    # Shallow, very intense OMZ
)


#= --- Public Interface --- =#

"""
    calculate_oxygen(biome::String, depth::Real) -> Union{Float64, Nothing}

    Calculates the dissolved oxygen concentration at a given depth.
    
    CORRECTED: The surface correction factor now decays to zero at the OMZ core,
    ensuring that both the surface and OMZ boundary conditions are met exactly.
"""
function calculate_oxygen(biome::String, depth::Real)
    if !haskey(OXYGEN_PARAMS, biome)
        @warn "Invalid biome name provided for oxygen calculation: $biome"
        return nothing
    end
    
    params = OXYGEN_PARAMS[biome]
    z = max(0.0, depth)

    # 1. Model the main profile with a sharp oxycline using a logistic function.
    logistic_decay = (params.O2_surf_sat - params.O2_deep) / (1.0 + exp(params.k_oxycline * (z - params.z_oxycline)))
    baseline_profile = params.O2_deep + logistic_decay

    # 2. Calculate the magnitude of the OMZ dip relative to the baseline profile.
    baseline_at_omz_core = params.O2_deep + (params.O2_surf_sat - params.O2_deep) / (1.0 + exp(params.k_oxycline * (params.z_omz - params.z_oxycline)))
    dip_magnitude = baseline_at_omz_core - params.omz_intensity

    # 3. Model the OMZ dip as a negative Gaussian function centered at the OMZ core.
    exponent = -((z - params.z_omz)^2) / (2 * params.omz_width^2)
    omz_dip = dip_magnitude * exp(exponent)
    
    # 4. Calculate a correction to cancel the dip's effect at the surface.
    # The baseline value at z=0 is calculated first.
    baseline_at_zero = params.O2_deep + (params.O2_surf_sat - params.O2_deep) / (1.0 + exp(-params.k_oxycline * params.z_oxycline))
    # The OMZ dip also has a non-zero value at the surface.
    dip_at_zero = dip_magnitude * exp(-(params.z_omz^2) / (2 * params.omz_width^2))
    # The total correction needed at z=0 is the difference between the target and the calculated value.
    total_correction_at_zero = params.O2_surf_sat - (baseline_at_zero - dip_at_zero)
    # This correction is applied with a linear decay that becomes zero at the OMZ core depth,
    # ensuring the OMZ intensity boundary condition is not affected.
    correction_factor = max(0.0, 1.0 - z / params.z_omz)
    correction = total_correction_at_zero * correction_factor

    # 5. Combine the components to get the final concentration.
    concentration = baseline_profile - omz_dip + correction
    
    return max(0.0, concentration)
end

end # module PhysicalModels