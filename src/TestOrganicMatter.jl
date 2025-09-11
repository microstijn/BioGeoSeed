# TestOrganicMatter.jl
# This module contains a suite of tests for the OrganicMatter.jl module.

module TestOrganicMatter

using Test

# Bring the already-loaded OrganicMatter module into this module's scope.
include("OrganicMatter.jl")
using .OrganicMatter

export run_organic_matter_tests

"""
    run_organic_matter_tests()

    Runs the complete test suite for the OrganicMatter module.
"""
function run_organic_matter_tests()
    @testset "Organic Matter Module Tests" begin

        @testset "Known Biome Calculations" begin
            # --- Test Coastal Biome (Productive Surface) ---
            coastal_surface = get_organic_matter("Coastal", 10.0)
            @test coastal_surface isa Dict
            # High total DOC and POC
            @test coastal_surface["DOC_total"] > 75.0
            @test coastal_surface["POC_total"] > 13.0
            # Test for a specific amino acid to confirm monomer partitioning
            @test haskey(coastal_surface, "gly_e")
            @test coastal_surface["gly_e"] > 0
            # NEW: Test for DON and DOP
            @test haskey(coastal_surface, "DON")
            @test haskey(coastal_surface, "DOP")
            @test coastal_surface["DON"] > 5.0 # High DON in productive surface waters
            @test isapprox(coastal_surface["DOC_total"] / coastal_surface["DON"], 14.0, atol=0.1)


            # --- Test Trade-Winds Biome (Oligotrophic Deep) ---
            tw_deep = get_organic_matter("Trade-Winds", 2000.0)
            @test isapprox(tw_deep["DOC_total"], 40.0, atol=0.1)
            @test isapprox(tw_deep["POC_total"], 0.1, atol=0.01)
            # Test for a specific sugar
            @test haskey(tw_deep, "glc_D_e") 
            @test tw_deep["glc_D_e"] > 0
            # NEW: Test for DON and DOP in deep, refractory DOM
            @test haskey(tw_deep, "DON")
            @test haskey(tw_deep, "DOP")
            @test isapprox(tw_deep["DOC_total"] / tw_deep["DON"], 40.0, atol=0.1) # High C:N
            @test isapprox(tw_deep["DOC_total"] / tw_deep["DOP"], 1500.0, atol=1) # Very high C:P
        end

        @testset "Edge Case Handling" begin
            # Test depth 0, should equal surface values
            polar_zero = get_organic_matter("Polar", 0)
            @test polar_zero["DOC_total"] == 60.0
            @test polar_zero["POC_total"] == 5.0
        end

        @testset "Error Handling" begin
            # Test that an invalid biome name returns nothing
            invalid_result = get_organic_matter("Invalid Biome", 100)
            @test isnothing(invalid_result)
        end
    end
end

end # module TestOrganicMatter

