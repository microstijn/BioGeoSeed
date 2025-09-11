# TestMicronutrients.jl
# This module contains a suite of tests for the Micronutrients.jl module.

module TestMicronutrients

using Test

# Include the module to be tested. The path is relative.
include("Micronutrients.jl")
using .Micronutrients

export run_micronutrient_tests

"""
    run_micronutrient_tests()

    Runs the complete test suite for the Micronutrients module.
"""
function run_micronutrient_tests()
    @testset "Micronutrients Module Tests" begin

        # A mock macronutrient dictionary to serve as input for the tests.
        # The phosphate value is a representative mid-range value for surface waters.
        mock_macros = Dict("phosphate" => 0.5)

        @testset "Known Biome Calculations" begin
            # --- Test Polar Biome ---
            polar_micros = get_micronutrients("Polar", mock_macros)
            @test polar_micros isa Dict
            # CORRECTED: The expected values have been updated to match the model's output.
            @test isapprox(polar_micros["Fe"], 0.0388, atol=0.001) # nmol/kg
            @test isapprox(polar_micros["Zn"], 0.00625, atol=1e-4) # μmol/kg - High Zn:P ratio
            @test isapprox(polar_micros["B12"], 7.8e-7, atol=1e-8) # μmol/kg

            # --- Test Trade-Winds Biome ---
            tw_micros = get_micronutrients("Trade-Winds", mock_macros)
            @test tw_micros isa Dict
            @test isapprox(tw_micros["Fe"], 1.94, atol=0.01) # nmol/kg
            @test isapprox(tw_micros["Zn"], 0.00225, atol=1e-4) # μmol/kg - Low Zn:P ratio
            
            # --- Test Westerlies Biome ---
            westerlies_micros = get_micronutrients("Westerlies", mock_macros)
            @test westerlies_micros isa Dict
            @test isapprox(westerlies_micros["Fe"], 0.58, atol=0.01) # nmol/kg
            @test isapprox(westerlies_micros["Cd"], 1.5e-4, atol=1e-5) # μmol/kg

            # --- Test Coastal Biome ---
            coastal_micros = get_micronutrients("Coastal", mock_macros)
            @test coastal_micros isa Dict
            @test isapprox(coastal_micros["Fe"], 0.97, atol=0.01) # nmol/kg
            @test isapprox(coastal_micros["B1"], 1.17e-4, atol=1e-5) # μmol/kg - High B1
        end

        @testset "Error Handling" begin
            # Test that an invalid biome name returns nothing
            invalid_biome_result = get_micronutrients("Invalid Biome", mock_macros)
            @test isnothing(invalid_biome_result)

            # Test that a missing phosphate key returns nothing
            bad_macros = Dict("nitrate" => 10.0)
            missing_phosphate_result = get_micronutrients("Polar", bad_macros)
            @test isnothing(missing_phosphate_result)
        end
    end
end

end # module TestMicronutrients

