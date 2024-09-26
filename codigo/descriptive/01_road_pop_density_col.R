

# 1. Set up environment ----
rm(list = ls())
library(pacman)
p_load(
  sf,
  tidyverse,
  osmdata,
  purrr,
  furrr,
  doParallel
)


# 1. Import data --------
col_dpto <- sf::read_sf("datos/spatial/MGN2023_DPTO_POLITICO/MGN_ADM_DPTO_POLITICO.shp")
colombia_boundary <- sf::read_sf("datos/spatial/colombia_boundary.gpkg")

# Load data ----
roads_colombia <- sf::read_sf("datos/spatial/colombia_roads.gpkg")
pop_hex <- sf::read_sf("datos/population/colombia/kontur_population_CO_20231101.gpkg")

# 2. Prepare data -----


# 3. Calculate road density using the H3 hexagons ----
pop_hex <- st_transform(pop_hex, st_crs(roads_colombia))

# roads_in_hexagons <- st_intersection(roads_colombia, pop_hex)

# Prepare parallelization
plan(multisession, workers = 20)  

intersections <- st_intersects(x = pop_hex, y = roads_colombia)

# Initialize progress bar
pb <- progress::progress_bar$new(format = "[:bar] :current/:total (:percent)", total = dim(pop_hex)[1])

# Define parallelized intersection function
intersectFeatures <- future_map_dfr(1:dim(pop_hex)[1], function(ix){
  pb$tick()
  st_intersection(x = pop_hex[ix,], y = roads_colombia[intersections[[ix]],])
})
plan(sequential)  # Reset the plan to the default single-core mode
# sf::write_sf(intersectFeatures, "datos/spatial/roads_pop_intersect.gpkg")

# 4. Export -----

## Option 1: Chunking ----
# Define the chunk size (adjust this based on your memory capacity)
chunk_size <- 5000

# Calculate the number of chunks needed
n_chunks <- ceiling(nrow(intersectFeatures) / chunk_size)

# Loop through each chunk and write to the GeoPackage file
# Initialize progress bar
pb <- progress::progress_bar$new(format = "[:bar] :current/:total (:percent)", total = dim(pop_hex)[1])

for (i in 1:n_chunks) {
  pb$tick()
  start_row <- (i - 1) * chunk_size + 1
  end_row <- min(i * chunk_size, nrow(intersectFeatures))
  
  # Extract the chunk
  chunk <- intersectFeatures[start_row:end_row, ]
  
  # Write the chunk to the GeoPackage
  sf::write_sf(chunk, "datos/spatial/roads_pop_intersect.gpkg", layer = "roads_pop_intersect", append = (i > 1))
}

## Option 2: GeoJSON ----
sf::write_sf(intersectFeatures, "datos/spatial/roads_pop_intersect.geojson")

















