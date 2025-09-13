# Step 0: Setup
using Pkg
# Ensure necessary packages are installed

using DifferentialEquations Optim CSV DataFrames Dates 
using Optim
using UnicodePlots
using CSV
using DataFrames
using Dates

using CSV
using DataFrames
using Dates

# --- Step 1: Load and Process BATS Data (handling mixed delimiters) ---
println("Loading 'bats_bottle.txt' with custom header parsing...")

# Part 1: Manually find and parse the comma-separated header line.
# We read the file line-by-line until we find the first line that is NOT a comment.
header_line = ""
first_data_line_num = 0
open(raw"D:\BATS\bats_bottle.txt") do f
    for (i, line) in enumerate(eachline(f))
        if !startswith(line, '#')
            header_line = line
            first_data_line_num = i + 1 # The data starts on the very next line.
            break
        end
    end
end

# Split the extracted header line by commas and convert the names to symbols for the DataFrame.
headers = Symbol.(split(header_line, ','))

# Part 2: Read the space-delimited data, applying the correct headers.
# We now tell CSV.read to skip directly to the data and use our manually parsed headers.
df = CSV.read(raw"D:\BATS\bats_bottle.txt", DataFrame, 
              header=headers,              # Manually provide the parsed headers
              skipto=first_data_line_num,  # Skip all lines before the actual data
              delim=' ',                   # Use a space as the delimiter for the data rows
              ignorerepeated=true,         # Treat multiple spaces as a single delimiter
              missingstrings=["nd"])       # Correctly interpret "no data" entries

# Part 3: The rest of the processing remains the same as before.
# Rename columns for easier access
rename!(df, 
    :"N+N(uM/kg)" => :nitrate,
    :"Chl_a(ug/L)" => :chla
)

# Filter for surface data and drop any rows with missing values
surface_df = filter(row -> row.depth < 10, df)
dropmissing!(surface_df, [:nitrate, :chla])

# Convert dates and calculate the 'Day of Year'
dates = [Date(string(d), "yyyymmdd") for d in surface_df.date_ymd]
surface_df.day_of_year = dayofyear.(dates)

# Group by each unique sampling day and average the measurements
daily_df = combine(groupby(surface_df, :day_of_year),
    :chla => mean => :chla_mean,
    :nitrate => mean => :no3_mean
)

# Extract the final, clean data into the arrays our model uses
bats_time = daily_df.day_of_year
bats_no3 = daily_df.no3_mean
bats_chla_real = daily_df.chla_mean

# Perform the unit conversion for Chlorophyll-a (μg/L -> μM N)
conversion_factor = (50.0 / 12.01) * (16.0 / 106.0)
bats_phyto_uM_N = bats_chla_real .* conversion_factor

println("...Real data processing complete. Found $(length(bats_time)) valid data points.\n")

# --- Include the model code provided by the user ---

module Light
    export calculate_light_limitation
    function calculate_light_limitation(t::Real, par_max::Float64, k_light::Float64)
        surface_par = par_max * (1.0 - cos(2.0 * π * t / 365.0)) / 2.0
        light_limitation_factor = surface_par / (k_light + surface_par)
        return light_limitation_factor
    end
end

module Phytoplankton
    using Base: @kwdef
    using ..Light
    export calculate_growth_rate, PhytoParameters
    @kwdef struct PhytoParameters
        mu_max::Float64; k_no3::Float64; k_po4::Float64; k_si::Float64
        k_fe::Float64; k_light::Float64; par_max::Float64; mortality_rate::Float64
    end
    function calculate_growth_rate(phyto::Float64, no3::Float64, po4::Float64, si::Float64, fe::Float64, t::Float64, params::PhytoParameters)
        lim_no3 = no3 / (params.k_no3 + no3)
        lim_po4 = po4 / (params.k_po4 + po4)
        lim_si  = si / (params.k_si + si)
        lim_fe  = fe / (params.k_fe + fe)
        lim_light = Light.calculate_light_limitation(t, params.par_max, params.k_light)
        gross_growth = params.mu_max * lim_no3 * lim_po4 * lim_si * lim_fe * lim_light
        net_growth_rate = (gross_growth * phyto) - (params.mortality_rate * phyto)
        return net_growth_rate
    end
end

module PrognosticModel
    using Base: @kwdef
    using ..Phytoplankton
    export ModelParameters, diffeq_function!

    @kwdef struct ModelParameters
        phyto_params::Phytoplankton.PhytoParameters
        remin_rate::Float64
        R_P_N::Float64
        R_P_Si::Float64
        R_P_Fe::Float64
    end
    
    function diffeq_function!(du, u, p::ModelParameters, t)
        phyto, detritus, no3, po4, si, fe = u
        phyto_net_growth = Phytoplankton.calculate_growth_rate(phyto, no3, po4, si, fe, t, p.phyto_params)
        remineralization = p.remin_rate * detritus
        phyto_mortality = p.phyto_params.mortality_rate * phyto
        gross_growth_term = phyto_net_growth + phyto_mortality
        du[1] = phyto_net_growth
        du[2] = phyto_mortality - remineralization
        du[3] = -gross_growth_term + remineralization
        du[4] = -gross_growth_term * p.R_P_N + (remineralization * p.R_P_N)
        du[5] = -gross_growth_term * p.R_P_Si + (remineralization * p.R_P_Si)
        du[6] = -gross_growth_term * p.R_P_Fe + (remineralization * p.R_P_Fe)
        return nothing
    end
end

# Step 1: Data Acquisition and Preparation
bats_time = [30.0, 60.0, 90.0, 120.0, 150.0, 210.0, 300.0, 360.0]
bats_chla = [0.1, 0.2, 0.8, 0.6, 0.2, 0.1, 0.1, 0.1]
bats_no3 = [1.8, 1.5, 0.2, 0.1, 0.05, 0.05, 0.8, 1.7]
conversion_factor = (50.0 / 12.01) * (16.0 / 106.0)
bats_phyto_uM_N = bats_chla .* conversion_factor

# Step 2: Define the Objective (Cost) Function
function run_simulation(params_vec)
    phyto_params_test = Phytoplankton.PhytoParameters(
        mu_max=params_vec[1], mortality_rate=params_vec[2], k_light=params_vec[3], k_no3=params_vec[4],
        k_po4=0.05, k_si=1.0, k_fe=0.0001, par_max=200.0
    )
    model_params = PrognosticModel.ModelParameters(
        phyto_params=phyto_params_test, remin_rate=0.05,
        R_P_N=1/16, R_P_Si=1.0, R_P_Fe=1/160000
    )
    u0 = [0.05, 0.2, 2.0, 2.0*model_params.R_P_N, 3.0, 2.0*model_params.R_P_Fe*1000]
    tspan = (0.0, 365.0)
    prob = ODEProblem(PrognosticModel.diffeq_function!, u0, tspan, model_params)
    return solve(prob, Rosenbrock23(autodiff=false), saveat=1, verbose=false)
end

function cost_function(p)
    solution = run_simulation(p)
    if solution.retcode != :Success; return 1e10; end
    sim_phyto = solution(bats_time; idxs=1).u
    sim_no3 = solution(bats_time; idxs=3).u
    phyto_rmse = sqrt(sum((sim_phyto .- bats_phyto_uM_N).^2) / length(bats_phyto_uM_N)) / (sum(bats_phyto_uM_N)/length(bats_phyto_uM_N))
    no3_rmse = sqrt(sum((sim_no3 .- bats_no3).^2) / length(bats_no3)) / (sum(bats_no3)/length(bats_no3))
    return phyto_rmse + no3_rmse
end

# Step 3: Configure the Optimization Algorithm
initial_params = [1.2, 0.15, 40.0, 0.5]
lower_bounds = [0.5, 0.05, 10.0, 0.1]
upper_bounds = [2.5, 0.50, 80.0, 2.0]

# Step 4: Execute Fitting and Evaluate Results
println("Running optimization...")
result = optimize(cost_function, lower_bounds, upper_bounds, initial_params, Fminbox(NelderMead()),
                  Optim.Options(g_tol = 1e-6, iterations = 200, show_trace=false))
println("...Optimization complete!\n")

# --- Analysis and Plotting ---
best_fit_params = Optim.minimizer(result)
println("--- RESULTS ---")
println("Initial Parameters: $initial_params")
println("Best Fit Parameters (mu_max, mortality, k_light, k_no3):")
println(round.(best_fit_params, digits=3))
println("Final Cost (RMSE): $(round(Optim.minimum(result), digits=4))\n")

println("--- VALIDATION PLOTS ---")
# Run simulations with initial and final parameters for plotting
sol_initial = run_simulation(initial_params)
sol_optimized = run_simulation(best_fit_params)
time_points = 0:1:365

# Plot Phytoplankton
plot_phyto = lineplot(time_points, [u[1] for u in sol_initial(time_points).u], name="Initial", title="Phytoplankton vs. BATS Data", xlabel="Day of Year", ylabel="Phyto (μM N)", width=80, height=15)
lineplot!(plot_phyto, time_points, [u[1] for u in sol_optimized(time_points).u], name="Optimized")
scatterplot!(plot_phyto, bats_time, bats_phyto_uM_N, name="BATS Data")
println(plot_phyto)

# Plot Nitrate
plot_no3 = lineplot(time_points, [u[3] for u in sol_initial(time_points).u], name="Initial", title="Nitrate vs. BATS Data", xlabel="Day of Year", ylabel="NO3 (μM)", width=80, height=15)
lineplot!(plot_no3, time_points, [u[3] for u in sol_optimized(time_points).u], name="Optimized")
scatterplot!(plot_no3, bats_time, bats_no3, name="BATS Data")
println(plot_no3)