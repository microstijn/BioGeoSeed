# TestPhysicalModels.jl
# This module contains a suite of tests for the PhysicalModels.jl module.

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
            polar_surf = calculate_oxygen("Polar", 0.0)
            @test isapprox(polar_surf, 340.0, atol=0.1) # Should exactly match surface saturation

            polar_omz = calculate_oxygen("Polar", 1000.0) # Depth of OMZ core
            @test isapprox(polar_omz, 180.0, atol=0.1) # Should exactly match OMZ intensity

            polar_deep = calculate_oxygen("Polar", 4000.0)
            @test isapprox(polar_deep, 210.0, atol=0.1) # Should match deep value

            # --- Test Trade-Winds Biome (Intense OMZ) ---
            tw_surf = calculate_oxygen("Trade-Winds", 0.0)
            @test isapprox(tw_surf, 220.0, atol=0.1) # Should exactly match surface saturation

            tw_omz = calculate_oxygen("Trade-Winds", 500.0) # Depth of OMZ core
            @test isapprox(tw_omz, 5.0, atol=0.1) # Should exactly match low OMZ intensity

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

