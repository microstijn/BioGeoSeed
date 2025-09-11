module BioGeoSeed

# Order is important: include module files before their test files.
include("Provinces.jl")
include("Macronutrients.jl")
include("Micronutrients.jl")
include("OrganicMatter.jl")
include("Assembler.jl")
include("SeawaterChemistry.jl")
include("PhysicalModels.jl")

include("TestProvinces.jl")
include("TestMacronutrients.jl")
include("TestMicronutrients.jl")
include("TestOrganicMatter.jl")
include("TestSeawaterChemistry.jl")
include("TestPhysicalModels.jl")

# Expose the public functions from each module
using .Provinces
export get_biome

using .Macronutrients
export get_macronutrients

using .Micronutrients
export get_micronutrients 

using .OrganicMatter
export get_organic_matter

using .SeawaterChemistry
export get_seawater_chemistry

using .PhysicalModels
export calculate_oxygen

# Expose the main assembler function
using .Assembler
export generate_seed

# Expose the test functions
using .TestProvinces
export run_provinces_tests

using .TestMacronutrients
export run_macronutrient_tests

using .TestMicronutrients
export run_micronutrient_tests

using .TestOrganicMatter
export run_organic_matter_tests

using .TestSeawaterChemistry
export run_seawater_chemistry_tests

using .TestPhysicalModels
export run_physical_models_tests


end # module BioGeoSeed

