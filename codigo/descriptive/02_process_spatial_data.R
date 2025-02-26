

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
colombia_boundary <- sf::read_sf("datos/spatial/colombia_boundary.gpkg")
roads_colombia <- sf::read_sf("datos/spatial/colombia_roads.gpkg")
inters <- sf::read_sf("datos/spatial/roads_pop_intersect.geojson")


# 2. Aggregate population data to department level ----

# Perform the spatial join to assign each hexagon to a department
plan(multisession, workers = parallel::detectCores()-2)  

# Define a function to perform the spatial join on a subset of hexagons
perform_spatial_join <- function(hex_subset, departments) {
  # Perform the spatial join for this subset
  st_join(hex_subset, departments)
}

# Split the hexagons into chunks for parallel processing
pop_hex <- st_transform(pop_hex, st_crs(col_dpto))
hex_chunks <- split(pop_hex, sample(rep(1:32, length.out = nrow(pop_hex))))

# Use future_map_dfr to apply the function in parallel to each chunk
hex_departments_parallel <- future_map_dfr(hex_chunks, ~ perform_spatial_join(.x, col_dpto))

# Aggregating total population by department
total_population_by_dpto <- hex_departments_parallel %>%
  group_by(dpto_ccdgo) %>%  
  summarize(total_population = sum(population, na.rm = TRUE))



# 3. Calculate population density per square kilometer per department----

# Use projected CRS for area calculations
pop_hex <- st_transform(pop_hex, crs = 3116)
col_dpto <- st_transform(col_dpto, crs = 3116)

# Calculate the area of each department in square kilometers
col_dpto$area_km2 <- st_area(col_dpto) / 1e6  # Convert from square meters to square kilometers

# Join the total population with department data
col_dpto <- col_dpto %>%
  left_join(st_drop_geometry(total_population_by_dpto), by = "dpto_ccdgo")  

# Calculate population density: Population per square kilometer
col_dpto$population_density <- col_dpto$total_population / col_dpto$area_km2

library(ggplot2)

ggplot(col_dpto) +
  geom_sf(aes(fill = population_density)) +
  scale_fill_viridis_c(option = "plasma", direction = -1) +  # Use a color scale for better visualization
  theme_minimal() +
  labs(title = "Population Density by Department in Colombia", fill = "Density (Pop/km²)")



