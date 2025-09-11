# TestSeawaterChemistry.jl
# This module contains a suite of tests for the SeawaterChemistry.jl module.

module TestSeawaterChemistry

using Test

# Bring the already-loaded SeawaterChemistry module into this module's scope.
include("SeawaterChemistry.jl")
using .SeawaterChemistry

export run_seawater_chemistry_tests

"""
    run_seawater_chemistry_tests()

    Runs the complete test suite for the SeawaterChemistry module.
"""
function run_seawater_chemistry_tests()
    @testset "Seawater Chemistry Module Tests" begin

        @testset "Known Biome Calculations" begin
            # --- Test Polar Biome (Cold, low pCO2 effect) ---
            polar_chem = get_seawater_chemistry("Polar")
            @test polar_chem isa Dict
            @test isapprox(polar_chem["pH"], 8.20, atol=0.01)
            @test isapprox(polar_chem["dissolved_co2"], 29.34, atol=0.1)

            # --- Test Westerlies Biome (Temperate) ---
            westerlies_chem = get_seawater_chemistry("Westerlies")
            @test westerlies_chem isa Dict
            @test isapprox(westerlies_chem["pH"], 8.11, atol=0.01)
            @test isapprox(westerlies_chem["dissolved_co2"], 18.42, atol=0.1)
            
            # --- Test Trade-Winds Biome (Warm) ---
            tw_chem = get_seawater_chemistry("Trade-Winds")
            @test tw_chem isa Dict
            @test isapprox(tw_chem["pH"], 8.06, atol=0.01)

            # --- Test Coastal Biome (High pCO2 effect) ---
            coastal_chem = get_seawater_chemistry("Coastal")
            @test coastal_chem isa Dict
            @test isapprox(coastal_chem["pH"], 8.09, atol=0.01)
        end

        @testset "Error Handling" begin
            # Test that an invalid biome name returns nothing
            invalid_result = get_seawater_chemistry("Invalid Biome")
            @test isnothing(invalid_result)
        end

    end
end

end # module TestSeawaterChemistry
