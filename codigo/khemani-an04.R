# Clientelismo y políticas públicas
# Tabla de estadísticas descriptivas
# Felipe Botero
# 3 de septiembre de 2024

library(dplyr)
library(haven)
library(stargazer)
library(tidyr)
library(viridis)

# Datos
lapop2018_filtrado <- readRDS("datos/lapop2018_filtrado.rds")

# Define control variables
control <- c("conocecompravoto", "q1", "q2", "ur", "adultos", "ed", "r1", "r4a", "gi0n", "vb2")
labels <- c(
  "conocecompravoto" = "Aware of vote buying",
  "q1" = "Male/Female",
  "q2" = "Age",
  "ur" = "Urban/Rural",
  "adultos" = "No. adults in household",
  "ed" = "Education",
  "r1" = "Ownership of televisipn",
  "r4a" = "Ownership ofcell phone",
  "gi0n" = "Frequency of news consumption",
  "vb2" = "Voted in last election"
)

# Select control variables
selected_data <- lapop2018_filtrado[, control]

# Convert variables from haven_labelled to numeric
selected_data <- selected_data %>%
  mutate(across(everything(), ~ as.numeric(as_factor(.))))

# Create a table of descriptive statistics
descriptive_stats <- selected_data %>%
  summarise(across(everything(), list(
    n = ~sum(!is.na(.)),
    mean = ~mean(., na.rm = TRUE),
    sd = ~sd(., na.rm = TRUE),
    min = ~min(., na.rm = TRUE),
    max = ~max(., na.rm = TRUE)
  )))

# Reshape the data for stargazer: 
descriptive_summary <- descriptive_stats %>%
  pivot_longer(cols = everything(), names_to = c("variable", ".value"), 
               names_pattern = "(.*)_(.*)") %>%
  as.data.frame()

# Apply the variable labels
descriptive_summary$variable <- labels[descriptive_summary$variable]


# Set rownames as the variables and remove the 'variable' column
rownames(descriptive_summary) <- descriptive_summary$variable
descriptive_summary <- descriptive_summary[, -1]  # Remove the first column

# Use stargazer to create the LaTeX table
stargazer(descriptive_summary, 
          type = "latex", 
          summary = FALSE,
          title = "Descriptive Statistics for Quantitative Variables",
          digits = 2,
          out = "descriptive_stats_quantitative.tex")

# salud, carreteras, colegiospub

# Subset data
data_subset <- lapop2018_filtrado[, c("salud", "carreteras", "colegiospub")]

# Drop NAs
data_subset <- na.omit(data_subset)

# Convert data to long format
data_long <- pivot_longer(data_subset, cols = everything(), names_to = "Variable", values_to = "Response")

# Calculate percentages
data_long <- data_long %>%
  group_by(Variable, Response) %>%
  summarise(count = n()) %>%
  mutate(percentage = count / sum(count) * 100)

# Rename the facet labels
data_long$Variable <- factor(data_long$Variable, 
                             levels = c("salud", "carreteras", "colegiospub"), 
                             labels = c("Health", "Roads", "Public Schools"))

# Bar plots
# Ensure all facets use the same y-scale
ggplot(data_long, aes(x = Response, y = percentage, fill = Variable)) +
  geom_bar(stat = "identity", position = "dodge", show.legend = FALSE) +
  facet_wrap(~ Variable, scales = "fixed") +  # Use "fixed" to maintain the same y-scale across all facets
  scale_fill_viridis_d() +
  geom_text(aes(label = paste0(round(percentage, 1), "%")), 
            position = position_stack(vjust = 0.9), 
            size = 5, color = "black") +
  scale_x_discrete(labels = c("Satisfied", "Unsatisfied")) +
  labs(title = "Satisfaction with quality of public goods",
       x = NULL, y = NULL) +
  ylim(0, 60) +
  scale_y_continuous(breaks = seq(0, 60, by = 20)) +
  theme(
    text = element_text(size = 18),  
    plot.title = element_text(size = 20, face = "bold"),
    axis.text = element_text(size = 16),  
    strip.text = element_text(size = 18)
  )
ggsave("plots/satisfaction_quality_public_goods.png", width = 10, height = 6, dpi = 300)
