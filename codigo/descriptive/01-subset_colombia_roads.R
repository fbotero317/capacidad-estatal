
# 1. Set up environment ----
rm(list = ls())
library(pacman)
p_load(
  sf,
  tidyverse,
  osmdata
)

# 2. Import data --------
roads <- sf::read_sf("datos/spatial/GRIP4_Region2_vector_shp/GRIP4_region2.shp")
colombia_boundary <- sf::read_sf("datos/spatial/colombia_boundary.gpkg")

roads <- st_transform(roads, st_crs(colombia_boundary))
roads_colombia <- st_intersection(roads, colombia_boundary)
st_write(roads_colombia, "datos/spatial/colombia_roads.gpkg")
