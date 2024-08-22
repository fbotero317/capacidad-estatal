# Clientelismo y políticas públicas
# Efectos marginales de la variable "conocecompravotoNo" en el modelo de salud
# Felipe Botero
# 15 de agostode 2024

inicio <- Sys.time()

library(tidyverse)
library(ggplot2)
if (!require("margins")) install.packages("margins")
library(margins)

library(dplyr)

#### Efectos marginales Salud
# Crear una lista para almacenar los efectos marginales para educación
marginal_effects_salud <- list()

for (country in countries) {
  model_name <- paste0("m_salud_", gsub(" ", "_", country))
  model <- get(model_name)
  
  # Calcular los efectos marginales para conocecompravoto
  margins_model <- margins(model, variables = "conocecompravoto")
  
  # Convertir los resultados en un dataframe manejable
  marginal_effects_summary <- as.data.frame(summary(margins_model))
  
  # Asegurarnos de que los efectos marginales sean numéricos y formatearlos
  marginal_effects_summary <- marginal_effects_summary %>%
    mutate(across(where(is.numeric), ~ round(., 2)))
  
  # Almacenar los efectos marginales en la lista
  marginal_effects_salud[[country]] <- marginal_effects_summary
}

# Unir todos los resultados en una sola tabla
marginal_effects_table_salud <- bind_rows(marginal_effects_salud, .id = "País")

# Ver la tabla de efectos marginales
print(marginal_effects_table_salud)

# Crear gráfico de los efectos marginales
# Rotar los países para facilitar la lectura
marginal_effects_table_salud <- marginal_effects_table_salud %>%
  mutate(País = factor(País, levels = rev(sort(unique(País)))))

ggplot(marginal_effects_table, aes(x = País, y = AME, ymin = lower, ymax = upper)) +
  geom_pointrange() +
  geom_hline(yintercept = 0, linetype = "dashed") +
  coord_flip() +  # Invertir el eje para facilitar la lectura
  labs(title = "Efectos marginales de saber de la compra de votos\nen la percepción la calidad de los servicios de salud",
       x = NULL,
       y = "Efecto marginal promedio") +
  theme_minimal()

#### Efectos marginales Educación
# Crear una lista para almacenar los efectos marginales para educación
marginal_effects_educacion <- list()

# Calcular los efectos marginales para cada país
for (country in countries) {
  model_name <- paste0("m_colegios_", gsub(" ", "_", country))
  model <- get(model_name)
  
  # Calcular los efectos marginales para conocecompravoto
  margins_model <- margins(model, variables = "conocecompravoto")
  
  # Convertir los resultados en un dataframe manejable
  marginal_effects_summary <- as.data.frame(summary(margins_model))
  
  # Asegurarnos de que los efectos marginales sean numéricos y formatearlos
  marginal_effects_summary <- marginal_effects_summary %>%
    mutate(across(where(is.numeric), ~ round(., 4)))
  
  # Almacenar los efectos marginales en la lista
  marginal_effects_educacion[[country]] <- marginal_effects_summary
}

# Unir todos los resultados en una sola tabla
marginal_effects_table_educacion <- bind_rows(marginal_effects_educacion, .id = "País")

# Ver la tabla de efectos marginales
print(marginal_effects_table_educacion)


# Crear gráfico de los efectos marginales para la educación

marginal_effects_table_educacion <- marginal_effects_table_educacion %>%
  mutate(País = factor(País, levels = rev(sort(unique(País)))))

ggplot(marginal_effects_table_educacion, aes(x = País, y = AME, ymin = lower, ymax = upper)) +
  geom_pointrange() +
  geom_hline(yintercept = 0, linetype = "dashed") +
  coord_flip() +  # Invertir el eje para facilitar la lectura
  labs(title = "Efectos marginales de saber de la compra de votos\nen la percepción la calidad de los servicios de educación",
       x = NULL,
       y = "Efecto marginal promedio") +
  theme_minimal()

#### Efectos marginales vías
# Crear una lista para almacenar los efectos marginales para carreteras
marginal_effects_carreteras <- list()

# Calcular los efectos marginales para cada país
for (country in countries) {
  model_name <- paste0("m_carreteras_", gsub(" ", "_", country))
  model <- get(model_name)
  
  # Calcular los efectos marginales para conocecompravoto
  margins_model <- margins(model, variables = "conocecompravoto")
  
  # Convertir los resultados en un dataframe manejable
  marginal_effects_summary <- as.data.frame(summary(margins_model))
  
  # Asegurarnos de que los efectos marginales sean numéricos y formatearlos
  marginal_effects_summary <- marginal_effects_summary %>%
    mutate(across(where(is.numeric), ~ round(., 4)))
  
  # Almacenar los efectos marginales en la lista
  marginal_effects_carreteras[[country]] <- marginal_effects_summary
}

# Unir todos los resultados en una sola tabla
marginal_effects_table_carreteras <- bind_rows(marginal_effects_carreteras, .id = "País")

# Ver la tabla de efectos marginales
print(marginal_effects_table_carreteras)

# Crear un gráfico de los efectos marginales para carreteras
# Rotar los países para facilitar la lectura
marginal_effects_table_carreteras <- marginal_effects_table_carreteras %>%
  mutate(País = factor(País, levels = rev(sort(unique(País)))))

ggplot(marginal_effects_table_carreteras, aes(x = País, y = AME, ymin = lower, ymax = upper)) +
  geom_pointrange() +
  geom_hline(yintercept = 0, linetype = "dashed") +
  coord_flip() +  # Invertir el eje para facilitar la lectura
  labs(title = "Efectos marginales de saber de la compra de votos\nen la percepción la calidad de la infraestructura vial",
       x = NULL,
       y = "Efecto marginal promedio") +
  theme_minimal()

fin <- Sys.time()
fin - inicio

