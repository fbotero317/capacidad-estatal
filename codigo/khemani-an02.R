# Clientelismo y políticas públicas
# Tablas de regresiones de salud, educación y carreteras
# Felipe Botero
# 15 de agostode 2024

library(broom)
library(dplyr)
library(tidyr)
library(stargazer)


####### Salud #######

# Lista de países y modelos correspondientes
countries <- c("México", "Guatemala", "El Salvador", "Honduras", 
               "Perú", "Paraguay", "República Dominicana", "Jamaica")

# Crear una lista para almacenar los resultados
results <- list()

# Extraer los coeficientes y significancia para cada modelo
for (country in countries) {
  model_name <- paste0("m_salud_", gsub(" ", "_", country))
  model <- get(model_name)
  
  # Obtener los coeficientes y los p-values
  coef_pvalues <- tidy(model) %>% 
    filter(term %in% c("conocecompravotoNo", "ed")) %>%
    mutate(significance = case_when(
      p.value < 0.1 ~ "*",
      TRUE ~ ""
    )) %>%
    mutate(estimate = paste0(round(estimate, 3), significance)) %>%
    dplyr::select(term, estimate) %>%
    spread(term, estimate)
  
  coef_pvalues$pais <- country
  results[[country]] <- coef_pvalues
}

# Combinar todos los resultados en una sola tabla
summary_table <- bind_rows(results)

# Renombrar las columnas para tener las etiquetas deseadas
summary_table <- summary_table %>%
  rename(
    `País` = `pais`,
    `Conoce de compra de votos` = `conocecompravotoNo`,
    `Educación` = `ed`
  )

# Calcular el porcentaje de personas que conocen la compra de votos en cada país
percentages <- lapop2018_filtrado %>%
  filter(conocecompravoto == "Sí") %>%
  group_by(pais) %>%
  summarise(`Porcentaje de personas que reportan haberse enterado de la compra de votos en su entorno` = n() / nrow(lapop2018_filtrado %>% filter(pais == first(pais))) * 100)

# Renombrar la columna 'pais' a 'País' para hacer el join
percentages <- percentages %>%
  rename(`País` = pais)

# Unir la tabla de coeficientes con el porcentaje
final_table <- summary_table %>%
  left_join(percentages, by = "País")

# Reordenar las columnas
final_table <- final_table %>%
  dplyr::select(
    `País`,
    `Porcentaje de personas que reportan haberse enterado de la compra de votos en su entorno`,
    `Conoce de compra de votos`,
    `Educación`
  )

# Guardar la tabla final como archivo txt usando stargazer
stargazer(as.data.frame(final_table), 
          type = "text", 
          summary = FALSE, 
          rownames = FALSE,
          title = "Coeficientes de la prevalencia de compra de votos y la percepción de la calidad de los servicios de salud",
          out = "tabla_resumen_salud.txt")


####### Educación #######

# Lista de países y modelos correspondientes
countries <- c("México", "Guatemala", "El Salvador", "Honduras", 
               "Perú", "Paraguay", "República Dominicana", "Jamaica")

# Crear una lista para almacenar los resultados de educación
results_edu <- list()

# Extraer los coeficientes y significancia para cada modelo de educación
for (country in countries) {
  model_name <- paste0("m_colegios_", gsub(" ", "_", country))
  model <- get(model_name)
  
  # Obtener los coeficientes y los p-values
  coef_pvalues <- tidy(model) %>% 
    filter(term %in% c("conocecompravotoNo", "ed")) %>%
    mutate(significance = case_when(
      p.value < 0.1 ~ "*",
      TRUE ~ ""
    )) %>%
    mutate(estimate = paste0(round(estimate, 3), significance)) %>%
    dplyr::select(term, estimate) %>%
    spread(term, estimate)
  
  coef_pvalues$pais <- country
  results_edu[[country]] <- coef_pvalues
}

# Combinar todos los resultados en una sola tabla
summary_table_edu <- bind_rows(results_edu)

# Renombrar las columnas para tener las etiquetas deseadas
summary_table_edu <- summary_table_edu %>%
  rename(
    `País` = `pais`,
    `Conoce de compra de votos` = `conocecompravotoNo`,
    `Educación` = `ed`
  )

# Calcular el porcentaje de personas que conocen la compra de votos en cada país
percentages_edu <- lapop2018_filtrado %>%
  filter(conocecompravoto == "Sí") %>%
  group_by(pais) %>%
  summarise(`Porcentaje de personas que reportan haberse enterado de la compra de votos en su entorno` = round(n() / nrow(lapop2018_filtrado %>% filter(pais == first(pais))) * 100,2))

# Renombrar la columna 'pais' a 'País' para hacer el join
percentages_edu <- percentages_edu %>%
  rename(`País` = pais)

# Unir la tabla de coeficientes con el porcentaje
final_table_edu <- summary_table_edu %>%
  left_join(percentages_edu, by = "País")

# Reordenar las columnas
final_table_edu <- final_table_edu %>%
  dplyr::select(
    `País`,
    `Porcentaje de personas que reportan haberse enterado de la compra de votos en su entorno`,
    `Conoce de compra de votos`,
    `Educación`
  )

# Guardar la tabla final como archivo txt usando stargazer
stargazer(as.data.frame(final_table_edu), 
          type = "text", 
          summary = FALSE, 
          rownames = FALSE,
          title = "Coeficientes de la prevalencia de compra de votos y la percepción de la calidad de los servicios de educación",
          out = "tabla_resumen_educacion.txt")


####### Carreteras #######
# Crear una lista para almacenar los resultados de carreteras
results_car <- list()

# Extraer los coeficientes y significancia para cada modelo de carreteras
for (country in countries) {
  model_name <- paste0("m_carreteras_", gsub(" ", "_", country))
  model <- get(model_name)
  
  # Obtener los coeficientes y los p-values
  coef_pvalues <- tidy(model) %>% 
    filter(term %in% c("conocecompravotoNo", "ed")) %>%
    mutate(significance = case_when(
      p.value < 0.1 ~ "*",
      TRUE ~ ""
    )) %>%
    mutate(estimate = paste0(round(estimate, 3), significance)) %>%
    dplyr::select(term, estimate) %>%
    spread(term, estimate)
  
  coef_pvalues$pais <- country
  results_car[[country]] <- coef_pvalues
}

# Combinar todos los resultados en una sola tabla
summary_table_car <- bind_rows(results_car)

# Renombrar las columnas para tener las etiquetas deseadas
summary_table_car <- summary_table_car %>%
  rename(
    `País` = `pais`,
    `Conoce de compra de votos` = `conocecompravotoNo`,
    `Educación` = `ed`
  )

# Calcular el porcentaje de personas que conocen la compra de votos en cada país
percentages_car <- lapop2018_filtrado %>%
  filter(conocecompravoto == "Sí") %>%
  group_by(pais) %>%
  summarise(`Porcentaje de personas que reportan haberse enterado de la compra de votos en su entorno` = round(n() / nrow(lapop2018_filtrado %>% filter(pais == first(pais))) * 100,2))

# Renombrar la columna 'pais' a 'País' para hacer el join
percentages_car <- percentages_car %>%
  rename(`País` = pais)

# Unir la tabla de coeficientes con el porcentaje
final_table_car <- summary_table_car %>%
  left_join(percentages_car, by = "País")

# Reordenar las columnas
final_table_car <- final_table_car %>%
  dplyr::select(
    `País`,
    `Porcentaje de personas que reportan haberse enterado de la compra de votos en su entorno`,
    `Conoce de compra de votos`,
    `Educación`
  )

# Guardar la tabla final como archivo txt usando stargazer
stargazer(as.data.frame(final_table_car), 
          type = "text", 
          summary = FALSE, 
          rownames = FALSE,
          title = "Coeficientes de la prevalencia de compra de votos y la percepción de la calidad de la infraestructura vial",
          out = "tabla_resumen_carreteras.txt")

