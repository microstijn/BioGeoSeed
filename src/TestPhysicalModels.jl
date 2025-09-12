# TestPhysicalModels.jl
# This module contains a suite of tests for the PhysicalModels.jl module.
# REVISED: Tests have been updated to match the corrected calculate_oxygen function
# and the new, scientifically robust biome parameters.
module TestPhysicalModels

using Test

# Bring the already-loaded PhysicalModels module into this module's scope.
using ..PhysicalModels

export run_physical_models_tests

"""
    run_physical_models_tests()

    Runs the complete test suite for the PhysicalModels module.
"""
function run_physical_models_tests()
    @testset "Physical Models Module Tests" begin

        @testset "Oxygen Profile Calculations" begin
            # --- Test Polar Biome (Weak OMZ) ---
            # Using the NEW parameters: z_omz=1000m, omz_intensity=180.0
            polar_surf = calculate_oxygen("Polar", 0.0)
            @test isapprox(polar_surf, 340.0, atol=0.1) # Should exactly match surface saturation

            polar_omz = calculate_oxygen("Polar", 1000.0) # Depth of OMZ core
            @test isapprox(polar_omz, 180.0, atol=0.1) # Should exactly match OMZ intensity

            polar_deep = calculate_oxygen("Polar", 4000.0)
            @test isapprox(polar_deep, 210.0, atol=0.1) # Should match deep value

            # --- Test Trade-Winds Biome (Deep, weak OMZ) ---
            # Using the NEW parameters: z_omz=1200m, omz_intensity=90.0
            tw_surf = calculate_oxygen("Trade-Winds", 0.0)
            @test isapprox(tw_surf, 220.0, atol=0.1) # Should exactly match surface saturation

            tw_omz = calculate_oxygen("Trade-Winds", 1200.0) # NEW Depth of OMZ core
            @test isapprox(tw_omz, 90.0, atol=0.1) # NEW low OMZ intensity

            tw_deep = calculate_oxygen("Trade-Winds", 4000.0)
            @test isapprox(tw_deep, 180.0, atol=0.1)
        end

        @testset "Error Handling" begin
            # Test that an invalid biome name returns nothing
            invalid_result = calculate_oxygen("Invalid Biome", 100.0)
            @test isnothing(invalid_result)
        end

    end
end

end # module TestPhysicalModels