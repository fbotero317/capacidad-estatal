

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
roads_colombia <- sf::read_sf("datos/spatial/colombia_roads.gpkg")


#=======================#
# 3. Road density dpto ------
#=======================#

pop_hex <- st_transform(pop_hex, crs = 4686)
roads_colombia <- st_transform(roads_colombia, st_crs(col_dpto))

if(!file.exists("datos/spatial/roads_dpto_intersect.rds")){
  # Prepare parallelization
  plan(multisession, workers = parallel::detectCores()-1)  
  
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

# Join departments with their respective road density
col_dpto <- col_dpto %>%
  left_join(st_drop_geometry(road_lengths_per_dept), by = "dpto_ccdgo") %>% 
  mutate(road_density = total_road_length_km / area_km2)


#===================================#
# 4. Population density dpto ------
#===================================#
if(!file.exists("datos/spatial/pop_dpto_intersect.rds")){
  # Prepare parallelization
  plan(multisession, workers = parallel::detectCores()-1)  
  
  intersections <- st_intersects(x = pop_hex, y = col_dpto)
  
  # Initialize progress bar
  pb <- progress::progress_bar$new(format = "[:bar] :current/:total (:percent)", total = dim(roads_colombia)[1])
  
  # Define parallelized intersection function
  intersectFeatures <- future_map_dfr(1:dim(pop_hex)[1], function(ix){
    pb$tick()
    st_intersection(x = pop_hex[ix,], y = col_dpto[intersections[[ix]],])
  })
  plan(sequential)  # Reset the plan to the default single-core mode
  saveRDS(intersectFeatures, 
          file ="datos/spatial/pop_dpto_intersect.rds" ) 
  pop_by_department <- intersectFeatures
  
} else{
  
  pop_by_department <- readRDS("datos/spatial/pop_dpto_intersect.rds")
}



# 5. Export -----
out <- col_dpto %>% 
  st_drop_geometry() %>% 
  select(dpto_ccdgo, area_km2, total_road_length_km, road_density, population_density)
arrow::write_parquet(out, "datos/spatial/colombia-departments_road_pop.parquet")

# End