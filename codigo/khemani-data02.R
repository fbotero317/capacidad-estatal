# Clientelismo y políticas públicas
# khemani-data02: Preparación de datos Lapop 2018: revisión de variables independientes y dependientes
# Felipe Botero
# 22 de julio de 2024

library(tidyverse)
library(dplyr)
library(ggplot2)
library(haven)

# Datos
lapop2018_filtrado <- readRDS("datos/lapop2018_filtrado.rds")


# Create vector with control variables
control <- c("q1", "q2", "ur", "adultos", "ed", "fs2", "fs8", "r1", "r4a", "gi0n", "vb2", "cp13")

# Create the regression formula dynamically
#formula <- as.formula(paste("salud ~ conocecompravoto +", paste(control, collapse = " + ")))
formula <- as.formula("salud ~ conocecompravoto")

# List of countries
countries <- c("México", "Guatemala", "El Salvador", "Honduras", 
               "Perú", "Paraguay", "República Dominicana", "Jamaica")

# Regresiones país por país para saber si se puede correr el modelo
formula <- as.formula("salud ~ conocecompravoto")

# México
country <- "México"
country_data <- subset(lapop2018_filtrado, pais == country)
country_data$salud <- as.factor(country_data$salud)
country_data$conocecompravoto <- as.factor(country_data$conocecompravoto)
model <- glm(formula, data = country_data, family = binomial)
assign(paste0("m_", gsub(" ", "_", country)), model)
cat("\nSummary for", country, ":\n")
print(summary(model))

# Guatemala
country <- "Guatemala"
country_data <- subset(lapop2018_filtrado, pais == country)
country_data$salud <- as.factor(country_data$salud)
country_data$conocecompravoto <- as.factor(country_data$conocecompravoto)
model <- glm(formula, data = country_data, family = binomial)
assign(paste0("m_", gsub(" ", "_", country)), model)
cat("\nSummary for", country, ":\n")
print(summary(model))

# El Salvador
country <- "El Salvador"
country_data <- subset(lapop2018_filtrado, pais == country)
country_data$salud <- as.factor(country_data$salud)
country_data$conocecompravoto <- as.factor(country_data$conocecompravoto)
model <- glm(formula, data = country_data, family = binomial)
assign(paste0("m_", gsub(" ", "_", country)), model)
cat("\nSummary for", country, ":\n")
print(summary(model))

# Honduras
country <- "Honduras"
country_data <- subset(lapop2018_filtrado, pais == country)
country_data$salud <- as.factor(country_data$salud)
country_data$conocecompravoto <- as.factor(country_data$conocecompravoto)
model <- glm(formula, data = country_data, family = binomial)
assign(paste0("m_", gsub(" ", "_", country)), model)
cat("\nSummary for", country, ":\n")
print(summary(model))

# Perú
country <- "Perú"
country_data <- subset(lapop2018_filtrado, pais == country)
country_data$salud <- as.factor(country_data$salud)
country_data$conocecompravoto <- as.factor(country_data$conocecompravoto)
model <- glm(formula, data = country_data, family = binomial)
assign(paste0("m_", gsub(" ", "_", country)), model)
cat("\nSummary for", country, ":\n")
print(summary(model))

# Paraguay
country <- "Paraguay"
country_data <- subset(lapop2018_filtrado, pais == country)
country_data$salud <- as.factor(country_data$salud)
country_data$conocecompravoto <- as.factor(country_data$conocecompravoto)
model <- glm(formula, data = country_data, family = binomial)
assign(paste0("m_", gsub(" ", "_", country)), model)
cat("\nSummary for", country, ":\n")
print(summary(model))

# República Dominicana
country <- "República Dominicana"
country_data <- subset(lapop2018_filtrado, pais == country)
country_data$salud <- as.factor(country_data$salud)
country_data$conocecompravoto <- as.factor(country_data$conocecompravoto)
model <- glm(formula, data = country_data, family = binomial)
assign(paste0("m_", gsub(" ", "_", country)), model)
cat("\nSummary for", country, ":\n")
print(summary(model))

# Jamaica
country <- "Jamaica"
country_data <- subset(lapop2018_filtrado, pais == country)
country_data$salud <- as.factor(country_data$salud)
country_data$conocecompravoto <- as.factor(country_data$conocecompravoto)
model <- glm(formula, data = country_data, family = binomial)
assign(paste0("m_", gsub(" ", "_", country)), model)
cat("\nSummary for", country, ":\n")
print(summary(model))



# Verificación de frecuencias y valores perdidos
## Valores perdidos
for (country in countries) {
  country_data <- subset(lapop2018_filtrado, pais == country)
  
  missing_values <- sum(is.na(country_data$salud)) +
    sum(is.na(country_data$conocecompravoto)) 
  sum(is.na(country_data[control]))
  
  cat("País:", country, "\n")
  cat("Total valores perdidos en variables clave:", missing_values, "\n\n")
}

## N por país
for (country in countries) {
  country_data <- subset(lapop2018_filtrado, pais == country)
  
  sample_size <- nrow(country_data)
  
  cat("País:", country, "\n")
  cat("N:", sample_size, "\n\n")
}

## Factor variables y frecuencias
for (country in countries) {
  country_data <- subset(lapop2018_filtrado, pais == country)
  
  # Factor levels y frecuncias
  salud_table <- table(country_data$salud)
  conocecompravoto_table <- table(country_data$conocecompravoto)
  
  cat("País:", country, "\n")
  cat("Niveles y frecuencias variable salud :\n")
  print(salud_table)
  cat("Niveles y frecuencias variable conocecompravoto:\n")
  print(conocecompravoto_table)
  cat("\n")
}



# Identificar variables de control problemáticas

test_model <- function(country_data, formula) {
  tryCatch({
    model <- glm(formula, data = country_data, family = binomial)
    return(model)
  }, error = function(e) {
    warning(paste("Error with formula:", deparse(formula)))
    return(NULL)
  })
}

# Loop through each country
for (country in countries) {
  # Subset the data for the current country
  country_data <- subset(lapop2018_filtrado, pais == country)
  
  # Ensure that 'salud' and 'conocecompravoto' are factors
  country_data$salud <- as.factor(country_data$salud)
  country_data$conocecompravoto <- as.factor(country_data$conocecompravoto)
  
  # Check factor levels and sample sizes
  salud_levels <- levels(country_data$salud)
  conocecompravoto_levels <- levels(country_data$conocecompravoto)
  
  cat("Country:", country, "\n")
  cat("Sample size:", nrow(country_data), "\n")
  cat("Salud levels:", paste(salud_levels, collapse = ", "), "\n")
  cat("Conocecompravoto levels:", paste(conocecompravoto_levels, collapse = ", "), "\n")
  
  # Test model with no control variables
  base_formula <- as.formula("salud ~ conocecompravoto")
  base_model <- test_model(country_data, base_formula)
  
  if (!is.null(base_model)) {
    # Test model with each individual control variable
    for (ctrl in control) {
      ctrl_formula <- as.formula(paste("salud ~ conocecompravoto +", ctrl))
      ctrl_model <- test_model(country_data, ctrl_formula)
      
      if (is.null(ctrl_model)) {
        cat("Problematic control variable:", ctrl, "\n")
      }
    }
    
    # Test model with all control variables
    all_controls_formula <- as.formula(paste("salud ~ conocecompravoto +", paste(control, collapse = " + ")))
    all_controls_model <- test_model(country_data, all_controls_formula)
    
    if (is.null(all_controls_model)) {
      cat("Problematic control variables: All controls\n")
    }
  } else {
    cat("Base model did not run successfully for", country, "\n")
  }
  
  cat("\n")
}


# Revisar problemas con variables de control problemáticas
library(haven) # For labelled data handling

# Define problematic controls and countries
problematic_controls <- c("fs2", "fs8", "cp13")
problematic_countries <- c("Perú", "Paraguay", "República Dominicana")

# Loop through each problematic country
for (country in problematic_countries) {
  country_data <- subset(lapop2018_filtrado, pais == country)
  
  # Convert labelled data to factors if necessary
  for (ctrl in problematic_controls) {
    if (inherits(country_data[[ctrl]], "haven_labelled")) {
      country_data[[ctrl]] <- as_factor(country_data[[ctrl]])
    }
  }
  
  # Check for missing values in problematic controls
  missing_values_summary <- sapply(problematic_controls, function(ctrl) sum(is.na(country_data[[ctrl]])))
  cat("Country:", country, "\n")
  cat("Missing values in problematic controls:\n")
  print(missing_values_summary)
  
  # Check levels for problematic controls
  levels_summary <- sapply(problematic_controls, function(ctrl) {
    if (any(!is.na(country_data[[ctrl]]))) {
      levels(factor(country_data[[ctrl]]))
    } else {
      NA
    }
  })
  cat("Levels of problematic controls:\n")
  print(levels_summary)
  
  cat("\n")
}
