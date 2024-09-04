
# 1. Set up environment ----
rm(list = ls())
library(pacman)
p_load(
  sf,
  tidyverse,
  osmdata,
  purrr
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



intersections <- st_intersects(x = pop_hex, y = roads_colombia)

pb <- progress::progress_bar$new(format = "[:bar] :current/:total (:percent)", total = dim(pop_hex)[1])

intersectFeatures <- map_dfr(1:dim(pop_hex)[1], function(ix){
  pb$tick()
  st_intersection(x = pop_hex[ix,], y = roads_colombia[intersections[[ix]],])
})

sf::write_sf(intersectFeatures, "datos/spatial/roads_pop_intersect.gpkg")
