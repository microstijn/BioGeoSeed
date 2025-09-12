# PrognosticModel.jl
# This module defines the full prognostic model as a system of Ordinary
# Differential Equations (ODEs) to be solved with DifferentialEquations.jl.
module PrognosticModel

using ..Phytoplankton

struct ModelParameters
    phyto_params::PhytoParameters
    remin_rate::Float64 # Remineralization rate for detritus
    # Stoichiometric Ratios (Redfield Ratios)
    R_P_N::Float64      # P:N ratio (e.g., 1/16)
    R_P_Si::Float64     # P:Si ratio
    R_P_Fe::Float64     # P:Fe ratio
end

"""
    diffeq_function!(du, u, p, t)

The core function for the ODE solver. It calculates the time derivatives
for all state variables in place.
"""
function diffeq_function!(du, u, p::ModelParameters, t)
    # Unpack the state vector `u` for clarity
    # `u` contains the concentrations of our state variables
    phyto   = u[1]
    detritus = u[2]
    no3     = u[3]
    po4     = u[4]
    si      = u[5]
    fe      = u[6]

    # 1. Calculate Process Rates ---
    
    # Phytoplankton net growth (uptake of nutrients)
    phyto_net_growth = Phytoplankton.calculate_growth_rate(phyto, no3, po4, si, fe, t, p.phyto_params)
    
    # Remineralization of detritus (release of nutrients)
    remineralization = p.remin_rate * detritus
    
    # 2. Calculate Time Derivatives (du/dt) ---
    
    # d(phyto)/dt
    du[1] = phyto_net_growth

    # d(detritus)/dt = (phyto mortality) - remineralization
    phyto_mortality = p.phyto_params.mortality_rate * phyto
    du[2] = phyto_mortality - remineralization
    
    # d(nutrients)/dt = -uptake + remineralization
    # Uptake is based on phytoplankton gross growth and stoichiometric ratios
    gross_growth_term = phyto_net_growth + phyto_mortality # gross growth * phyto
    
    du[3] = -gross_growth_term + (remineralization)                  # d(NO3)/dt
    du[4] = -gross_growth_term * p.R_P_N + (remineralization * p.R_P_N) # d(PO4)/dt
    du[5] = -gross_growth_term * p.R_P_Si + (remineralization * p.R_P_Si) # d(Si)/dt
    du[6] = -gross_growth_term * p.R_P_Fe + (remineralization * p.R_P_Fe) # d(Fe)/dt

    return nothing
end

end # module PrognosticModel