# TestMicronutrients.jl
# REFACTORED: This test suite now only tests for the non-redox-sensitive
# micronutrients.

module TestMicronutrients

using Test
using ..Micronutrients

export run_micronutrient_tests

"""
    run_micronutrient_tests()

    Runs the complete test suite for the Micronutrients module.
"""
function run_micronutrient_tests()
    @testset "Micronutrients Module Tests" begin

        mock_macros = Dict("phosphate" => 0.5)

        @testset "Known Biome Calculations" begin
            # --- Test Polar Biome ---
            polar_micros = get_micronutrients("Polar", mock_macros)
            @test polar_micros isa Dict
            # Test for a representative non-redox metal and a vitamin
            @test isapprox(polar_micros["Zn"], 0.00625, atol=1e-4)
            @test isapprox(polar_micros["B12"], 7.8e-7, atol=1e-8)
            
            # --- Test Westerlies Biome ---
            westerlies_micros = get_micronutrients("Westerlies", mock_macros)
            @test isapprox(westerlies_micros["Cd"], 1.5e-4, atol=1e-5)

            # Ensure removed keys are not present
            @test !haskey(polar_micros, "Fe")
            @test !haskey(polar_micros, "Mn")
        end

        @testset "Error Handling" begin
            # Test that an invalid biome name returns nothing
            invalid_biome_result = get_micronutrients("Invalid Biome", mock_macros)
            @test isnothing(invalid_biome_result)

            # Test that a missing phosphate key returns nothing
            bad_macros = Dict("nitrate" => 10.0) # Using nitrate intentionally
            missing_phosphate_result = get_micronutrients("Polar", bad_macros)
            @test isnothing(missing_phosphate_result)
        end
    end
end

end # module TestMicronutrients

