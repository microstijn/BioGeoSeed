# Light.jl
# This module calculates the photosynthetically active radiation (PAR)
# available for phytoplankton growth.
module Light

export calculate_light_limitation

"""
    calculate_light_limitation(t, params)

Calculates a seasonal light limitation factor based on the day of the year.
Simulates a sinusoidal seasonal cycle of light availability.
"""
function calculate_light_limitation(t::Real, par_max::Float64, k_light::Float64)
    # Simulate a sinusoidal seasonal cycle for surface PAR (Photosynthetically Active Radiation)
    # t is the day of the year
    surface_par = par_max * (1.0 - cos(2.0 * π * t / 365.0)) / 2.0
    
    # Michaelis-Menten limitation term for light
    light_limitation_factor = surface_par / (k_light + surface_par)
    
    return light_limitation_factor
end

end # module Light