# TestBiogeochemistryModels.jl
# This module contains a suite of tests for the BiogeochemistryModels.jl module,
# ensuring the "redox tower" logic is correctly implemented.

module TestBiogeochemistryModels

using Test
using ..BiogeochemistryModels

export run_biogeochemistry_models_tests

"""
    run_biogeochemistry_models_tests()

    Runs the complete test suite for the BiogeochemistryModels module.
"""
function run_biogeochemistry_models_tests()
    @testset "Biogeochemistry Models Tests" begin

        # Use a representative biome and phosphate value for all tests
        test_biome = "Westerlies"
        test_phosphate = 1.0 # umol/kg

        @testset "Redox State Calculations" begin
            # Test Oxic Conditions (> 80 uM O2) ---
            oxic_species = get_redox_sensitive_species(test_biome, 200.0, test_phosphate)
            @test oxic_species isa Dict
            @test oxic_species["redox_state"] == "Oxic"
            @test oxic_species["nitrate"] > 15.0 # Should be at its potential maximum
            @test oxic_species["nitrite"] == 0.0
            @test oxic_species["iron"] < 0.01 # Should be trace
            @test oxic_species["sulfide"] == 0.0

            # Test Suboxic Conditions (5-80 uM O2) ---
            suboxic_species = get_redox_sensitive_species(test_biome, 40.0, test_phosphate)
            @test suboxic_species["redox_state"] == "Suboxic"
            @test suboxic_species["nitrate"] > 10.0 # Partially consumed
            @test suboxic_species["nitrite"] > 3.0  # Nitrite should accumulate
            @test suboxic_species["iron"] < 0.01

            # Test Anoxic Conditions (0.1-5 uM O2) ---
            anoxic_species = get_redox_sensitive_species(test_biome, 1.0, test_phosphate)
            @test anoxic_species["redox_state"] == "Anoxic"
            @test anoxic_species["nitrate"] == 0.0 # Fully consumed
            @test anoxic_species["nitrite"] == 0.0 # Fully consumed
            @test anoxic_species["iron"] > 1.0     # Iron should be high
            @test anoxic_species["sulfide"] == 0.0

            # Test Sulfidic Conditions (< 0.1 uM O2) ---
            sulfidic_species = get_redox_sensitive_species(test_biome, 0.05, test_phosphate)
            @test sulfidic_species["redox_state"] == "Sulfidic"
            @test sulfidic_species["nitrate"] == 0.0
            @test sulfidic_species["sulfate"] < 28000.0 # Sulfate should be partially consumed
            @test sulfidic_species["sulfide"] > 2000.0  # Sulfide should be high
        end

        @testset "Error Handling" begin
            # Test that an invalid biome name returns nothing
            invalid_result = get_redox_sensitive_species("Invalid Biome", 100.0, test_phosphate);
            @test isnothing(invalid_result)
        end
    end
end

end # module TestBiogeochemistryModels

