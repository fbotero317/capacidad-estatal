# Clientelismo y políticas públicas
# Regresiones calidad servicios públicos
# Felipe Botero
# 19 de julio de 2024

library(tidyverse)
library(ggplot2)
library(MASS)
if(!require("stargazer"))install.packages("stargazer")
library(stargazer)

# Datos
lapop2018_filtrado <- readRDS("datos/lapop2018_filtrado.rds")

# List of countries
countries <- c("México", "Guatemala", "El Salvador", "Honduras", 
               "Perú", "Paraguay", "República Dominicana", "Jamaica")

# crear vector con variables de control
control <- c("q1", "q2", "ur", "adultos", "ed", "r1", "r4a", "gi0n", "vb2")


# Variable dependiente: calidad de servicios públicos
# salud, carreteras, colegiospub

## OJO:
# Variable independiente: conocecompravoto (no hay datos para colombia)
# Variable independiente: vendiovoto (sí hay datos para colombia)


# Regresiones
## Regresión 1: salud ~ conocecompravoto + control

# Create the regression formula dynamically
formula <- as.formula(paste("salud ~ conocecompravoto +", paste(control, collapse = " + ")))

# Loop through each country
for (country in countries) {
  # Subset the data for the current country
  country_data <- subset(lapop2018_filtrado, pais == country)
  
  # Ensure that 'salud' and 'conocecompravoto' are factors
  country_data$salud <- as.factor(country_data$salud)
  country_data$conocecompravoto <- as.factor(country_data$conocecompravoto)
  
  # Run the logistic regression with control variables
  model_name <- paste0("m_salud_", gsub(" ", "_", country)) # Replace spaces with underscores for valid names
  model <- glm(formula, data = country_data, family = binomial)
  
  # Store the regression model in the environment
  assign(model_name, model)
}

# Table of results
# Create an empty list to store models
models_list <- list()

# Loop through each country again to store models in a list
for (country in countries) {
  model_name <- paste0("m_salud_", gsub(" ", "_", country))
  models_list[[country]] <- get(model_name)
}

# Generate table
# Labels for independent variables
labels <- c(
  "conocecompravoto" = "Conoce de compra de votos",
  "q1" = "Sexo",
  "q2" = "Edad",
  "ur" = "Urbano/rural",
  "adultos" = "No. adultos en hogar",
  "ed" = "Educación",
  "r1" = "Propietario de televisor",
  "r4a" = "Propietario de celular",
  "gi0n" = "Frecuencia consulta noticias",
  "vb2" = "Votó en últimas elecciones"
)

# Generate table
stargazer(models_list, 
          type = "text", # or html
          title = "Percepción de calidad de los servicios de salud",
          dep.var.labels = "Salud",
          covariate.labels = labels,
          column.labels = countries,
          out = "regresiones_salud.txt"
)


## Regresión 2: carreteras ~ conocecompravoto + control

# Regression formula
formula <- as.formula(paste("carreteras ~ conocecompravoto +", paste(control, collapse = " + ")))

# List of countries
countries <- c("México", "Guatemala", "El Salvador", "Honduras", 
               "Perú", "Paraguay", "República Dominicana", "Jamaica")

# Loop through each country
for (country in countries) {
  # Subset the data for the current country
  country_data <- subset(lapop2018_filtrado, pais == country)
  
  # Ensure that 'carreteras' and 'conocecompravoto' are factors
  country_data$carreteras <- as.factor(country_data$carreteras)
  country_data$conocecompravoto <- as.factor(country_data$conocecompravoto)
  
  # Run the logistic regression with control variables
  model_name <- paste0("m_carreteras_", gsub(" ", "_", country)) 
  model <- glm(formula, data = country_data, family = binomial)
  
  # Store the regression model in the environment
  assign(model_name, model)
}

# Table of results
# Create an empty list to store models
models_list <- list()

# Loop through each country again to store models in a list
for (country in countries) {
  model_name <- paste0("m_carreteras_", gsub(" ", "_", country))
  models_list[[country]] <- get(model_name)
}

# Generate table
# Labels for independent variables
labels <- c(
  "conocecompravoto" = "Conoce de compra de votos",
  "q1" = "Sexo",
  "q2" = "Edad",
  "ur" = "Urbano/rural",
  "adultos" = "No. adultos en hogar",
  "ed" = "Educación",
  "r1" = "Propietario de televisor",
  "r4a" = "Propietario de celular",
  "gi0n" = "Frecuencia consulta noticias",
  "vb2" = "Votó en últimas elecciones"
)

# Generate table
stargazer(models_list, 
          type = "text", # or html
          title = "Percepción de calidad de la infraestructura vial",
          dep.var.labels = "Infraestructura vial",
          covariate.labels = labels,
          column.labels = countries,
          out = "regresiones_carreteras.txt"
)

## Regresión 3: colegiospub ~ conocecompravoto + control

# Regression formula
formula <- as.formula(paste("colegiospub ~ conocecompravoto +", paste(control, collapse = " + ")))


# Loop through each country
for (country in countries) {
  # Subset the data for the current country
  country_data <- subset(lapop2018_filtrado, pais == country)
  
  # Ensure that 'colegiospub' and 'conocecompravoto' are factors
  country_data$colegiospub <- as.factor(country_data$colegiospub)
  country_data$conocecompravoto <- as.factor(country_data$conocecompravoto)
  
  # Run the logistic regression with control variables
  model_name <- paste0("m_colegios_", gsub(" ", "_", country)) 
  model <- glm(formula, data = country_data, family = binomial)
  
  # Store the regression model in the environment
  assign(model_name, model)
}

# Table of results
# Create an empty list to store models
models_list <- list()

# Loop through each country again to store models in a list
for (country in countries) {
  model_name <- paste0("m_colegios_", gsub(" ", "_", country))
  models_list[[country]] <- get(model_name)
}

# Generate table
# Labels for independent variables
labels <- c(
  "conocecompravoto" = "Conoce de compra de votos",
  "q1" = "Sexo",
  "q2" = "Edad",
  "ur" = "Urbano/rural",
  "adultos" = "No. adultos en hogar",
  "ed" = "Educación",
  "r1" = "Propietario de televisor",
  "r4a" = "Propietario de celular",
  "gi0n" = "Frecuencia consulta noticias",
  "vb2" = "Votó en últimas elecciones"
)

# Generate table
stargazer(models_list, 
          type = "text", # or html
          title = "Percepción de calidad de los colegios públicos",
          dep.var.labels = "Infraestructura vial",
          covariate.labels = labels,
          column.labels = countries,
          out = "regresiones_colegios.txt"
)
