# TestOrganicMatter.jl
# This module contains a suite of tests for the OrganicMatter.jl module.

module TestOrganicMatter

using Test

# Include the module to be tested. The path is relative.
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
            # High protein percentage in POM
            protein_poc_percent = (coastal_surface["POC_protein"] / coastal_surface["POC_total"]) * 100
            @test isapprox(protein_poc_percent, 45.0, atol=1)

            # --- Test Trade-Winds Biome (Oligotrophic Deep) ---
            tw_deep = get_organic_matter("Trade-Winds", 2000.0)
            @test tw_deep isa Dict
            # DOC and POC should be close to refractory deep values
            @test isapprox(tw_deep["DOC_total"], 40.0, atol=0.1)
            @test isapprox(tw_deep["POC_total"], 0.1, atol=0.01)
            # Low protein percentage in DOM
            protein_dom_percent = (tw_deep["DOC_protein"] / tw_deep["DOC_total"]) * 100
            @test isapprox(protein_dom_percent, 2.0, atol=0.1)

            # --- Test Mesopelagic Zone ---
            westerlies_meso = get_organic_matter("Westerlies", 500.0)
            @test westerlies_meso isa Dict
            # Check partitioning for Mesopelagic zone
            carb_pom_percent = (westerlies_meso["POC_carbohydrate"] / westerlies_meso["POC_total"]) * 100
            @test isapprox(carb_pom_percent, 15.0, atol=1)
        end

        @testset "Edge Case Handling" begin
            # Test depth 0, should equal surface values
            polar_zero = get_organic_matter("Polar", 0)
            @test polar_zero["DOC_total"] == 60.0
            @test polar_zero["POC_total"] == 5.0

            # Test negative depth, should be treated as 0
            polar_neg = get_organic_matter("Polar", -100)
            @test polar_neg["DOC_total"] == 60.0
        end

        @testset "Error Handling" begin
            # Test that an invalid biome name returns nothing
            invalid_result = get_organic_matter("Invalid Biome", 100)
            @test isnothing(invalid_result)
        end

    end
end

end # module TestOrganicMatter
