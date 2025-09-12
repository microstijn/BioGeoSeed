# Phytoplankton.jl
# This module defines the phytoplankton state variable and its growth dynamics
# based on multi-nutrient and light co-limitation.
module Phytoplankton

# Use the built-in @kwdef macro to enable keyword arguments for the struct.
using Base: @kwdef
using ..Light

export calculate_growth_rate
export PhytoParameters

@kwdef struct PhytoParameters
    mu_max::Float64       # Max growth rate (per day)
    k_no3::Float64        # Half-saturation constant for Nitrate
    k_po4::Float64        # Half-saturation constant for Phosphate
    k_si::Float64         # Half-saturation constant for Silicate
    k_fe::Float64         # Half-saturation constant for Iron
    k_light::Float64      # Half-saturation constant for Light
    par_max::Float64      # Maximum surface PAR
    mortality_rate::Float64 # Mortality/grazing rate (per day)
end

"""
    calculate_growth_rate(phyto, no3, po4, si, fe, t, params)

Calculates the net growth rate of phytoplankton (growth - mortality) based on
a multiplicative co-limitation model for nutrients and light.
"""
function calculate_growth_rate(phyto::Float64, no3::Float64, po4::Float64, si::Float64, fe::Float64, t::Float64, params::PhytoParameters)
    
    # Calculate limitation term for each nutrient
    lim_no3 = no3 / (params.k_no3 + no3)
    lim_po4 = po4 / (params.k_po4 + po4)
    lim_si  = si / (params.k_si + si)
    lim_fe  = fe / (params.k_fe + fe)
    
    # Get light limitation from the Light module
    lim_light = Light.calculate_light_limitation(t, params.par_max, params.k_light)
    
    # Calculate gross growth rate
    # NOTE: Changed from min() to multiplication to align with the technical review's
    # recommendation for synergistic co-limitation.
    gross_growth = params.mu_max * lim_no3 * lim_po4 * lim_si * lim_fe * lim_light
    
    # Net growth is gross growth minus losses
    net_growth_rate = (gross_growth * phyto) - (params.mortality_rate * phyto)
    
    return net_growth_rate
end

end # module Phytoplankton