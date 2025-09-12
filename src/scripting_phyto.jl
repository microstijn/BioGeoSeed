using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using Revise
using BioGeoSeed

# This script sets up and runs a time-series simulation of the prognostic model.

using DifferentialEquations
using UnicodePlots

# Include the new modules
include(joinpath(@__DIR__, "Light.jl"))
include(joinpath(@__DIR__, "Phytoplankton.jl"))
include(joinpath(@__DIR__, "PrognosticModel.jl"))

# Parameters for a temperate biome like "Westerlies"
phyto_params = Phytoplankton.PhytoParameters(
    mu_max = 1.2,          # Max growth rate (1.2 per day)
    k_no3 = 1.0,           # Half-saturation for NO3 (μM)
    k_po4 = 0.1,           # Half-saturation for PO4 (μM)
    k_si = 2.0,            # Half-saturation for Si (μM)
    k_fe = 0.001,          # Half-saturation for Fe (nM -> μM)
    k_light = 30.0,        # Half-saturation for light (μEin m⁻² s⁻¹)
    par_max = 200.0,       # Max surface light
    mortality_rate = 0.1   # Mortality rate (0.1 per day)
)

model_params = PrognosticModel.ModelParameters(
    phyto_params,
    0.05,                  # Remineralization rate (0.05 per day)
    1/16,                  # P:N ratio
    1.0,                   # P:Si ratio (1:1 with N) -> R_Si_N = 16
    1/160000               # P:Fe ratio -> R_Fe_N = 1/10000
)

# Winter conditions: high nutrients, low phytoplankton
initial_conditions = [
    0.1,  # Phyto (μM N)
    0.5,  # Detritus (μM N)
    12.0, # NO3 (μM)
    12.0 * model_params.R_P_N, # PO4 (μM)
    15.0, # Si (μM)
    12.0 * model_params.R_P_Fe * 1000 # Fe (nM)
]
u0 = initial_conditions

# Simulate for one full year
tspan = (0.0, 365.0)

# Create the ODEProblem object
prob = ODEProblem(PrognosticModel.diffeq_function!, u0, tspan, model_params)

# Solve the problem
# Rosenbrock23 is a good solver for stiff ODEs, common in biogeochemistry

sol = solve(prob, Rosenbrock23(autodiff=false), saveat=1)

# Extract time points and specific variables from the solution object
time_points = sol.t
phyto_conc = [u[1] for u in sol.u] # Get the 1st variable (phyto) at each time point
no3_conc = [u[3] for u in sol.u]   # Get the 3rd variable (NO3)
si_conc = [u[5] for u in sol.u]    # Get the 5th variable (Si)

# Plot the phytoplankton bloom
println("\n--- Phytoplankton Spring Bloom ---")
plot_phyto = lineplot(time_points, phyto_conc,
                      title="Phytoplankton vs. Time",
                      xlabel="Day of Year",
                      ylabel="Phyto (μM N)",
                      name="Phyto",
                      width=80, height=20
)
println(plot_phyto)


# Plot the nutrient drawdown
plot_nutrients = lineplot(time_points, no3_conc,
                          title="Nutrients vs. Time",
                          xlabel="Day of Year",
                          ylabel="Nutrient (μM)",
                          name="NO3",
                          width=80, height=20
)
lineplot!(plot_nutrients, time_points, si_conc, name="Si") # Add silicate to the same plot
println(plot_nutrients)