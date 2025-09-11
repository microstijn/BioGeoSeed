# PhysicalModels.jl
# This new module is responsible for calculating key physical parameters of the
# marine environment, starting with the dissolved oxygen profile, which is the
# foundation of the new redox framework.

module PhysicalModels

export calculate_oxygen

#= --- Data Structures and Parameters --- =#

"""
    OxygenParameters

    A struct to hold all biome-specific parameters required for calculating
    the dissolved oxygen vertical profile.
"""
struct OxygenParameters
    O2_surf_sat::Float64  # Surface oxygen saturation concentration (μmol/kg)
    z_omz::Float64        # Depth of the Oxygen Minimum Zone (OMZ) core (m)
    omz_intensity::Float64# O2 concentration at the OMZ core (μmol/kg)
    O2_deep::Float64      # Deep-water oxygen concentration (μmol/kg)
    omz_width::Float64    # Vertical spread/width of the OMZ (m)
end

# A dictionary mapping biomes to their specific oxygen profile parameters.
# This data is synthesized from the "Enhancing Julia Package with Dissolved Oxygen.docx" specification.
const OXYGEN_PARAMS = Dict(
    "Polar" => OxygenParameters(340.0, 1000.0, 180.0, 210.0, 500.0), # Weak OMZ
    "Westerlies" => OxygenParameters(280.0, 800.0, 80.0, 150.0, 400.0), # Moderate OMZ
    "Trade-Winds" => OxygenParameters(220.0, 500.0, 5.0, 180.0, 300.0), # Intense OMZ
    "Coastal" => OxygenParameters(260.0, 300.0, 20.0, 100.0, 150.0)   # Shallow, intense OMZ
)


#= --- Public Interface --- =#

"""
    calculate_oxygen(biome::String, depth::Real) -> Union{Float64, Nothing}

    Calculates the dissolved oxygen concentration at a given depth.
    
    CORRECTED: This function now uses a more robust model of a Gaussian dip
    subtracted from a linear baseline, ensuring the profile is continuous
    and accurately represents the OMZ feature.
"""
function calculate_oxygen(biome::String, depth::Real)
    if !haskey(OXYGEN_PARAMS, biome)
        println(stderr, "Invalid biome name provided for oxygen calculation: $biome")
        return nothing
    end
    
    params = OXYGEN_PARAMS[biome]
    z = max(0.0, depth)

    # 1. Establish a simple linear baseline from the surface to the deep value.
    # We define a transition depth to prevent the linear trend from continuing indefinitely.
    transition_depth = params.z_omz * 2.0
    
    baseline = if z >= transition_depth
        params.O2_deep
    else
        # Linear interpolation between surface and deep values
        params.O2_surf_sat - (params.O2_surf_sat - params.O2_deep) * (z / transition_depth)
    end

    # 2. Calculate the magnitude of the required dip at the OMZ core.
    baseline_at_omz = params.O2_surf_sat - (params.O2_surf_sat - params.O2_deep) * (params.z_omz / transition_depth)
    dip_magnitude = baseline_at_omz - params.omz_intensity

    # 3. Define a Gaussian dip centered at the OMZ depth.
    exponent = -((z - params.z_omz)^2) / (2 * params.omz_width^2)
    dip = dip_magnitude * exp(exponent)
    
    # 4. Subtract the dip from the baseline to get the final concentration.
    concentration = baseline - dip
    
    return max(0.0, concentration)
end

end # module PhysicalModels

