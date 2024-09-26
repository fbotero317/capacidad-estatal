

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
plan(multisession, workers = 30)  

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



#=======================#
# 4. Road density dpto ------
#=======================#

pop_hex <- st_transform(pop_hex, crs = 4686)
roads_colombia <- st_transform(roads_colombia, st_crs(col_dpto))

if(!file.exists("datos/spatial/roads_dpto_intersect.rds")){
  # Prepare parallelization
  plan(multisession, workers = 30)  
  
  intersections <- st_intersects(x = roads_colombia, y = col_dpto)
  
  # Initialize progress bar
  pb <- progress::progress_bar$new(format = "[:bar] :current/:total (:percent)", total = dim(roads_colombia)[1])
  
  # Define parallelized intersection function
  intersectFeatures <- future_map_dfr(1:dim(roads_colombia)[1], function(ix){
    pb$tick()
    st_intersection(x = roads_colombia[ix,], y = col_dpto[intersections[[ix]],])
  })
  plan(sequential)  # Reset the plan to the default single-core mode
  saveRDS(intersectFeatures, 
          file ="datos/spatial/roads_dpto_intersect.rds" ) 
  roads_by_department <- intersectFeatures
  
} else{
  
  roads_by_department <- readRDS("datos/spatial/roads_dpto_intersect.rds")
}

# Calculate the length of roads within each department #
roads_by_department$length_km <- st_length(roads_by_department) %>% 
  units::set_units("km") # Convert to kilometers

# Calculate department areas in square kilometers
col_dpto$area_km2 <- st_area(col_dpto) %>% 
  units::set_units("km^2") # Convert to square kilometers

road_lengths_per_dept <- roads_by_department %>%
  group_by(dpto_ccdgo) %>%  
  summarize(total_road_length_km = sum(length_km, na.rm = TRUE))


col_dpto <- col_dpto %>%
  left_join(st_drop_geometry(road_lengths_per_dept), by = "dpto_ccdgo") %>% 
  mutate(road_density = total_road_length_km / area_km2)

library(ggplot2)

ggplot(data = col_dpto) +
  geom_sf(aes(fill = road_density)) +
  scale_fill_viridis_c() +
  labs(title = "Road Density by Department in Colombia", fill = "Road Density\n(km/km²)")

#=======================#
# 5. Road density hex ------
#=======================#

roads_by_hex <- st_read("datos/spatial/roads_pop_intersect.geojson")

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
out <- col_dpto %>% 
  st_drop_geometry() %>% 
  select(dpto_ccdgo, area_km2, total_road_length_km, road_density)
arrow::write_parquet(out, "datos/spatial/colombia-departments_road_pop.parquet")

out <- roads_by_hex %>% 
  st_drop_geometry() %>% 
arrow::write_parquet(out, "datos/spatial/colombia-hex_road_pop.parquet")
