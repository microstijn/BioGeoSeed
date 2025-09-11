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

    Calculates the dissolved oxygen concentration at a given depth, modeling a
    three-layer structure: a saturated surface, an Oxygen Minimum Zone (OMZ),
    and stable deep water.

    # Returns
    - The dissolved oxygen concentration in μmol/kg.
    - Returns `nothing` if the biome name is invalid.
"""
function calculate_oxygen(biome::String, depth::Real)
    if !haskey(OXYGEN_PARAMS, biome)
        println(stderr, "Invalid biome name provided for oxygen calculation: $biome")
        return nothing
    end
    
    params = OXYGEN_PARAMS[biome]
    z = max(0.0, depth)

    # This model uses a double-sigmoid (logistic) function to create the characteristic
    # OMZ profile. One sigmoid decreases O2 from the surface to the OMZ core,
    # and the second increases it from the OMZ core to the deep-water value.

    # Part 1: Decrease from surface to OMZ minimum
    k1 = 4.0 / params.omz_width # Steepness factor
    omz_dip = params.O2_surf_sat - params.omz_intensity
    surface_to_omz = params.O2_surf_sat - omz_dip / (1.0 + exp(-k1 * (z - params.z_omz)))

    # Part 2: Increase from OMZ minimum to deep value
    k2 = 4.0 / params.omz_width # Steepness factor
    deep_rise = params.O2_deep - params.omz_intensity
    omz_to_deep = params.omz_intensity + deep_rise / (1.0 + exp(-k2 * (z - params.z_omz)))
    
    # The final concentration is determined by which part of the curve is dominant.
    # Below the OMZ core, the rise to the deep value is dominant.
    # Above the OMZ core, the fall from the surface is dominant.
    concentration = z > params.z_omz ? omz_to_deep : surface_to_omz
    
    return max(0.0, concentration)
end

end # module PhysicalModels
