
# 1. Set up environment -----
rm(list = ls())
gc()
if(!require(pacman)){install.packages('pacman');library(pacman)}
p_load(
  tidyverse,
  units,
  sf,
  geoarrow,
  purrr,
  furrr,
  future,
  parallel
)

# 2. Import data -----
pop_hex <- sf::read_sf(
  "datos/population/colombia/kontur_population_CO_20231101.gpkg")
col_dpto <- sf::read_sf(
  "datos/spatial/MGN2023_DPTO_POLITICO/MGN_ADM_DPTO_POLITICO.shp")
roads_by_hex <- st_read("datos/spatial/roads_pop_intersect.geojson")

#=======================#
# 5. Road density hex ------
#=======================#


# Calculate the length of roads within each hexagon #
roads_by_hex$length_km <- st_length(roads_by_hex) %>% 
  units::set_units("km") # Convert to kilometers

# Calculate hexagon areas in square kilometers
pop_hex$area_km2 <- st_area(pop_hex) %>% 
  units::set_units("km^2") # Convert to square kilometers

road_lengths_per_hex <- roads_by_hex %>%
  group_by(h3) %>%  
  summarize(total_road_length_km = sum(length_km, na.rm = TRUE))


roads_by_hex <- roads_by_hex %>%
  left_join(st_drop_geometry(road_lengths_per_dept), by = "h3") %>% 
  mutate(road_density = total_road_length_km / area_km2)


# Export -----

out <- roads_by_hex %>% 
  st_drop_geometry() %>% 
arrow::write_parquet(out, "datos/spatial/colombia-hex_road_pop.parquet")
