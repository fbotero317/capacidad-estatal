
# 1. Set up environment ----
rm(list = ls())
library(pacman)
p_load(
  sf,
  tidyverse,
  osmdata
)


# 1. Import data --------
pop_hex <- sf::read_sf("datos/population/colombia/kontur_population_CO_20231101.gpkg")
bbox<- osmdata::getbb("colombia")
roads <- sf::read_sf("datos/spatial/GRIP4_Region2_vector_shp/GRIP4_region2.shp")
col_dpto <- sf::read_sf("datos/spatial/MGN2023_DPTO_POLITICO/MGN_ADM_DPTO_POLITICO.shp")
colombia_boundary <- sf::read_sf("datos/spatial/colombia_boundary.gpkg")


# 2. Prepare data -----
roads <- st_transform(roads, st_crs(colombia_boundary))
roads_colombia <- st_intersection(roads, colombia_boundary)
st_write(roads_colombia, "datos/spatial/colombia_roads.gpkg")


# 3. Calculate road density using the H3 hexagons ----
pop_hex <- st_transform(pop_hex, st_crs(roads_colombia))
roads_in_hexagons <- st_intersection(roads_colombia, pop_hex)

