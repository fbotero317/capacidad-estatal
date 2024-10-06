
# 1. Set up environment -----
rm(list = ls())
gc()
if(!require(pacman)){install.packages('pacman');library(pacman)}
p_load(
  tidyverse,
  data.table,
  units,
  sf,
  geoarrow,
  rio
)


# 2. Import data -----
pop_hex <- sf::read_sf(
  "datos/population/colombia/kontur_population_CO_20231101.gpkg")
roads_by_hex <- import("datos/spatial/colombia-hex_road_pop.parquet")
col_boundary <- read_sf("datos/spatial/colombia_boundary.gpkg")

# Calculate hexagon areas in square kilometers
pop_hex$area_km2 <- st_area(pop_hex) %>% 
  units::set_units("km^2") 
df <- roads_by_hex %>% select(h3, population, road_density) %>% distinct()

# 3. Plot correlation ------ 
ggplot(df, aes(x = population, y = road_density)) +
  geom_point(color = "blue", alpha = 0.6) +  # Scatter plot points with some transparency
  labs(
    title = "Population Density vs Road Density in Colombian Hexagons",
    x = "Population Density (per hexagon)",
    y = "Road Density (per hexagon)"
  ) +
  theme_minimal()  # Clean, minimal theme

model <- lm(road_density ~ population, data = df)
slope <- coef(model)[2]

ggplot(df, aes(x = population, y = road_density)) +
  geom_point(color = "blue", alpha = 0.6, shape = 'o') +  # Scatter plot points with some transparency
  geom_smooth(method = "lm", color = "red", se = TRUE) +  # Add regression line with confidence interval
  labs(
    title = "Population Density vs Road Density in Colombian Hexagons",
    x = "Population Density (per hexagon)",
    y = "Road Density (per hexagon)",
    caption = paste("Slope of the regression line:", round(slope, 4))
  ) +
  theme_minimal()  # Clean, minimal theme








ggsave(plot = last_plot(),
       file = "~/Downloads/fig1.jpg",
       height = 9.4,
       width = 9.4,
       units = 'cm')


# 4. Plot map of colombia in quintiles ---------
pop_hex <- pop_hex %>% 
  mutate(pop_density = population/area_km2)


# plot at hexagon level #
pop_hex <- pop_hex %>% 
  mutate(quintile = cut(pop_density, 
                        breaks = quantile(pop_density, 
                                          probs = seq(0, 1, length.out = 6) ),
                        labels = FALSE,
                        right = T) )

ggplot() +
  geom_sf(data = pop_hex, aes(fill = quintile), color = NA, size = 0) +
  geom_sf(data = col_boundary, fill = NA, color = "black", size = 0.5) +
  theme_minimal() +
  scale_fill_viridis_c(option = "magma") +  # Optional: Customize the color scale
  labs(title = "Population Distribution by Hexagons in Colombia")


