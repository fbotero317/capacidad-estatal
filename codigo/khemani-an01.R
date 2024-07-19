# Clientelismo y políticas públicas
# Regresiones calidad servicios públicos
# Felipe Botero
# 19 de julio de 2024

library(tidyverse)
library(ggplot2)
library(MASS)
if(!require("stargazer")) install.packages("stargazer")
library(stargazer)

# Datos
lapop2018_filtrado <- readRDS("datos/lapop2018_filtrado.rds")

# crear vector con variables de control
control <- c("q1", "q2", "ur", "q12c", "q12bn", "ed", "fs2", "fs8", "r1", "r4a", "gi0n", "vb2", "cp13")

# Variable dependiente: calidad de servicios públicos
# carreteras, colegiospub, salud
# Variable independiente: clientelismo


# Regresiones
# Regresión 1: calidad de carreteras y vendió voto modelos independientes por país
###


# México
mfull <- as.formula(paste("salud ~ vendiovoto +", paste(control, collapse = " + ")))
mi <- polr(mfull, data = lapop2018 %>% filter(pais == "México"), Hess = TRUE)

summary(mi)

# Bucle para regresiones para todos los países
modelos_por_pais <- list()
for (pais in unique(lapop2018_filtrado$pais)) {
  mfull <- as.formula(paste("salud ~ vendiovoto +", paste(control, collapse = " + ")))
  datos_pais <- lapop2018_filtrado %>% filter(pais == pais)
  if (nrow(datos_pais) > 0 && !all(is.na(datos_pais$salud))) {
    cat("Ajustando modelo para el país:", pais, "\n")
    modelo <- polr(mfull, data = datos_pais, Hess = TRUE)
    modelos_por_pais[[pais]] <- list(modelo = modelo, resumen = summary(modelo))
  } else {
    cat("No hay datos suficientes para el país:", pais, "\n")
  }
}
print(names(modelos_por_pais))

if (length(modelos_por_pais) > 0) {
  for (pais in names(modelos_por_pais)) {
    if (!is.null(modelos_por_pais[[pais]]$resumen)) {
      cat("\nResumen del modelo para el país:", pais, "\n")
      print(modelos_por_pais[[pais]]$resumen)
    } else {
      cat("\nNo se encontró el resumen del modelo para el país:", pais, "\n")
    }
  }
} else {
  cat("No hay modelos ajustados para mostrar resúmenes.\n")
}

# Tabla
stargazer(modelos_por_pais,
          title = "Resultados de los Modelos por País",
          type = "text",
          column.labels = names(modelos_por_pais),
          covariate.labels = c("Vendiovoto", control),
          dep.var.labels = "Salud",
          out = "resultados_modelos.html",
          keep.stat = c("n", "ll", "aic"))
# mejorar las tablas
