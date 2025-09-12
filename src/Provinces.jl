# Provinces.jl
# This module provides functions to determine the Longhurst Biogeochemical Province
# and its parent biome for a given latitude and longitude.

module Provinces

# Required package for reading shapefiles.
using Shapefile
import GeoInterface
using Logging

# Export the primary public function.
export get_biome

#= --- Global Variables --- =#
const PROVINCES_CACHE = Ref{Any}(nothing)

# A complete and authoritative mapping from each province code to its parent biome.
# CORRECTED: Added the 'CCAL' province code to the map.
const BIOME_MAP = Dict(
    "APLR" => "Polar", "ARCT" => "Polar", "ARCH" => "Coastal", "BENG" => "Coastal",
    "BERS" => "Westerlies", "BKPL" => "Coastal", "BRAZ" => "Coastal", "CALC" => "Coastal",
    "CARI" => "Coastal", "CHIL" => "Coastal", "CHIN" => "Coastal", "EAFR" => "Coastal",
    "EURA" => "Westerlies", "FKLD" => "Coastal", "GUIA" => "Coastal", "GUIN" => "Coastal",
    "GULF" => "Coastal", "HUMB" => "Coastal", "INDW" => "Coastal", "JAVA" => "Coastal",
    "KAMS" => "Westerlies", "KURO" => "Westerlies", "MEDI" => "Westerlies", "MONS" => "Coastal",
    "NADR" => "Westerlies", "NASE" => "Coastal", "NASW" => "Westerlies", "NATR" => "Trade-Winds",
    "NECS" => "Coastal", "NEWZ" => "Westerlies", "NPPF" => "Westerlies", "NPTG" => "Trade-Winds",
    "NPTE" => "Trade-Winds", "OCEA" => "Westerlies", "PEQD" => "Trade-Winds", "PNEC" => "Coastal",
    "PSAE" => "Westerlies", "PSAW" => "Westerlies", "REDS" => "Coastal", "SANT" => "Polar",
    "SATL" => "Trade-Winds", "SGS" => "Polar", "SOUT" => "Westerlies", "SSTC" => "Westerlies",
    "SUND" => "Coastal", "TAS" => "Westerlies", "TASM" => "Westerlies", "TEDP" => "Trade-Winds",
    "TPLU" => "Coastal", "WARM" => "Trade-Winds", "WAFR" => "Coastal", "ETRA" => "Trade-Winds",
    "ANTA" => "Polar", "AUSW" => "Coastal", "ALSE" => "Coastal", "CCAL" => "Coastal"
)

#= --- Core Functions --- =#
function _point_in_polygon(point, polygon::Shapefile.Polygon)
    x, y = point
    is_inside = false
    for ring in GeoInterface.getring(polygon)
        num_vertices = length(ring)
        p1 = ring[end]
        for i in 1:num_vertices
            p2 = ring[i]
            if p1.y == p2.y == y && x >= min(p1.x, p2.x) && x <= max(p1.x, p2.x)
                return true
            end
            if (y > min(p1.y, p2.y)) && (y <= max(p1.y, p2.y)) && (x <= max(p1.x, p2.x))
                if p1.y != p2.y
                    x_intersection = (y - p1.y) * (p2.x - p1.x) / (p2.y - p1.y) + p1.x
                    if p1.x == p2.x || x <= x_intersection
                        is_inside = !is_inside
                    end
                end
            end
            p1 = p2
        end
    end
    return is_inside
end

function _load_provinces(shapefile_path::String)
    try
        table = Shapefile.Table(shapefile_path)
        province_data = [(row.ProvCode, Shapefile.shape(row)) for row in table]
        return province_data
    catch e
        @error "Error loading shapefile at '$shapefile_path': $e"
        return nothing
    end
end

function get_biome(lat::Real, lon::Real, shapefile_path::String)
    if isnothing(PROVINCES_CACHE[])
        @info "Loading and caching province data from shapefile..."
        PROVINCES_CACHE[] = _load_provinces(shapefile_path)
        if !isnothing(PROVINCES_CACHE[])
             @info "...loading complete."
        end
    end
    
    if isnothing(PROVINCES_CACHE[]); @error "Cache is empty."; return nothing, nothing; end
    
    point = (lon, lat)

    for (prov_code, polygon) in PROVINCES_CACHE[]
        if _point_in_polygon(point, polygon)
            # REVISED: Check if the province code exists and provide a helpful error if it doesn't.
            if haskey(BIOME_MAP, prov_code)
                biome = BIOME_MAP[prov_code]
                return biome, prov_code
            else
                @error "Found point in province with code '$prov_code', but this code is not defined in BIOME_MAP. Please add it."
                return "Unknown Biome", prov_code
            end
        end
    end
    
    return nothing, nothing
end

end # module Provinces

