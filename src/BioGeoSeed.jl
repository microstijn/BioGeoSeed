module BioGeoSeed

# Order is important for dependencies. Predictive modules are loaded first.
include("Provinces.jl")
include("Macronutrients.jl") # Must be included before BiogeochemistryModels
include("Micronutrients.jl")
include("OrganicMatter.jl")
include("SeawaterChemistry.jl")
include("PhysicalModels.jl")
include("BiogeochemistryModels.jl")
include("Assembler.jl")


# Test files are included next.
include("TestProvinces.jl")
include("TestMacronutrients.jl")
include("TestMicronutrients.jl")
include("TestOrganicMatter.jl")
include("TestSeawaterChemistry.jl")
include("TestPhysicalModels.jl")
include("TestBiogeochemistryModels.jl")
# Note: A test suite for BiogeochemistryModels.jl will be the next step.

# Expose the public functions from each predictive module
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

using .BiogeochemistryModels
export get_redox_sensitive_species

# Expose the main assembler function, which is the primary entry point for users
using .Assembler
export generate_seed

# Expose all the test functions so they can be run from a script
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

using .TestBiogeochemistryModels
export run_biogeochemistry_models_tests

end # module BioGeoSeed

