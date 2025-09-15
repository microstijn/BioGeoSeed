# TestAssembler.jl
# A test suite for the main user-facing module, Assembler.jl.
module TestAssembler

using Test
# Bring the main entrypoint function into scope
using ..Assembler

export run_assembler_tests

"""
    run_assembler_tests(shapefile_path::String)

    Runs the complete test suite for the Assembler.jl module, focusing on
    function dispatch and the cascading effects of user data overrides.
"""
function run_assembler_tests(shapefile_path::String)
    @testset "Assembler Module Tests" begin
        
        if !isfile(shapefile_path)
            @warn "Shapefile not found at '$shapefile_path'. Skipping Assembler.jl tests."
            return
        end
        
        # Define standard test location
        lat, lon, depth = 30.0, -140.0, 800.0 # Pacific OMZ

        @testset "Function Dispatch" begin
            # Test that both calling conventions work and produce identical results
            seed_pos = generate_seed(lat, lon, depth, shapefile_path)
            seed_key = generate_seed(lat=lat, lon=lon, depth=depth, shapefile_path=shapefile_path)
            
            @test seed_pos isa Dict
            @test seed_key isa Dict
            @test seed_pos["no3_e"] ≈ seed_key["no3_e"]
            @test seed_pos["pi_e"] ≈ seed_key["pi_e"]
        end

        @testset "User Data Overrides" begin
            # Test 1: Oxygen Override
            # Get a baseline seed in an OMZ where denitrification is active
            baseline_seed = generate_seed(lat, lon, depth, shapefile_path)
            
            # Now, override with a high oxygen value, which should shut down denitrification
            oxic_data = Dict("oxygen" => 300.0)
            oxic_seed = generate_seed(lat=lat, lon=lon, depth=depth, shapefile_path=shapefile_path, user_data=oxic_data)
            
            # With denitrification suppressed, nitrate concentration should be higher
            @test oxic_seed["no3_e"] > baseline_seed["no3_e"]

            # Test 2: Phosphate Override
            phosphate_data = Dict("phosphate" => 5.0)
            phos_seed = generate_seed(lat=lat, lon=lon, depth=depth, shapefile_path=shapefile_path, user_data=phosphate_data)
            
            # The seed's phosphate should match the input
            @test phos_seed["pi_e"] == 5.0
            # Silicate should be much higher than the baseline due to the high phosphate
            @test phos_seed["si_e"] > baseline_seed["si_e"]
            
            # Test 3: Temperature Override
            temp_data = Dict("temperature" => 2.0)
            temp_seed = generate_seed(lat=lat, lon=lon, depth=depth, shapefile_path=shapefile_path, user_data=temp_data)
            
            # The pH in the metadata should be different from the baseline
            @test temp_seed["metadata"]["pH"] != baseline_seed["metadata"]["pH"]
        end
    end
end

end # module TestAssembler