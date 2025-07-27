# FONDECYT CSV Data Analysis Script
# Purpose: Analyze the extracted CSV data (no database connection needed)

library(dplyr)
library(ggplot2)
library(lubridate)
library(readr)
library(tidyr)
library(stringr)

# =============================================================================
# DATA LOADING
# =============================================================================

# Load the extracted CSV data
load_research_data <- function(file_path = "fondecyt_research_data.csv") {
  # Check if CSV file exists
  if (!file.exists(csv_file)) {
    stop("CSV file not found. Run data/extract_local_data.R first to create the data file.")
  }
  
  cat("Loading data from", file_path, "...\n")
  data <- read_csv(file_path, show_col_types = FALSE)
  
  # Convert date columns
  date_cols <- c("study_created_date", "subject_enrolled_date", "administration_date", 
                 "administration_completed_date", "response_date")
  
  for (col in date_cols) {
    if (col %in% names(data)) {
      data[[col]] <- as_datetime(data[[col]])
    }
  }
  
  cat("✅ Loaded", nrow(data), "rows with", ncol(data), "columns\n")
  return(data)
}

# Load expenses data
load_expenses_data <- function(file_path = "fondecyt_expenses_data.csv") {
  if (!file.exists(file_path)) {
    stop("Expenses CSV file not found. Run extract_expenses_data() first.")
  }
  
  data <- read_csv(file_path, show_col_types = FALSE)
  data$expense_date <- as_date(data$expense_date)
  data$expense_created_date <- as_datetime(data$expense_created_date)
  
  return(data)
}

# =============================================================================
# ANALYSIS FUNCTIONS
# =============================================================================

# Overview of the dataset
data_overview <- function(data) {
  cat("\n📊 DATASET OVERVIEW\n")
  cat("===================\n")
  
  cat("Dimensions:", nrow(data), "rows ×", ncol(data), "columns\n")
  cat("Date range:", min(data$study_created_date, na.rm = TRUE), "to", 
      max(data$administration_date, na.rm = TRUE), "\n\n")
  
  cat("Unique counts:\n")
  cat("- Studies:", length(unique(data$study_id)), "\n")
  cat("- Subjects:", length(unique(data$subject_id)), "\n")
  cat("- Measures:", length(unique(data$measure_id)), "\n")
  cat("- Administrations:", length(unique(data$administration_id)), "\n")
  cat("- Items:", length(unique(data$item_id)), "\n")
  cat("- Responses:", length(unique(data$response_id)), "\n\n")
  
  cat("Response types:\n")
  print(table(data$response_type))
  
  cat("\nMost common measures:\n")
  measure_counts <- data %>% 
    count(measure_name, sort = TRUE) %>% 
    head(10)
  print(measure_counts)
}

# Study-level analysis
analyze_studies <- function(data) {
  cat("\n🔬 STUDY ANALYSIS\n")
  cat("=================\n")
  
  study_summary <- data %>%
    group_by(study_id, study_name) %>%
    summarise(
      subjects = n_distinct(subject_id),
      measures = n_distinct(measure_id),
      administrations = n_distinct(administration_id),
      responses = n_distinct(response_id),
      start_date = min(subject_enrolled_date, na.rm = TRUE),
      last_activity = max(administration_date, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(subjects))
  
  print(study_summary)
  return(study_summary)
}

# Subject enrollment over time
analyze_enrollment <- function(data) {
  enrollment <- data %>%
    distinct(subject_id, subject_enrolled_date) %>%
    filter(!is.na(subject_enrolled_date)) %>%
    mutate(
      enrollment_month = floor_date(subject_enrolled_date, "month")
    ) %>%
    count(enrollment_month, name = "new_subjects") %>%
    arrange(enrollment_month) %>%
    mutate(cumulative_subjects = cumsum(new_subjects))
  
  return(enrollment)
}

# Measure completion analysis
analyze_completion <- function(data) {
  completion <- data %>%
    group_by(measure_name) %>%
    summarise(
      total_administrations = n_distinct(administration_id),
      completed_administrations = n_distinct(administration_id[!is.na(administration_completed_date)]),
      completion_rate = completed_administrations / total_administrations,
      avg_response_rate = mean(!is.na(response_value)),
      .groups = "drop"
    ) %>%
    arrange(desc(total_administrations))
  
  return(completion)
}

# Response pattern analysis
analyze_responses <- function(data) {
  cat("\n📝 RESPONSE ANALYSIS\n")
  cat("====================\n")
  
  # Response completeness by measure
  response_summary <- data %>%
    group_by(measure_name) %>%
    summarise(
      total_items = n_distinct(item_id),
      total_expected_responses = n(),
      actual_responses = sum(!is.na(response_value)),
      response_rate = actual_responses / total_expected_responses,
      .groups = "drop"
    ) %>%
    arrange(desc(response_rate))
  
  cat("Response rates by measure:\n")
  print(head(response_summary, 10))
  
  # Numeric response summary
  numeric_responses <- data %>%
    filter(response_type %in% c("integer", "decimal")) %>%
    mutate(numeric_value = as.numeric(response_value)) %>%
    filter(!is.na(numeric_value))
  
  if (nrow(numeric_responses) > 0) {
    cat("\nNumeric response summary:\n")
    cat("Range:", min(numeric_responses$numeric_value), "to", max(numeric_responses$numeric_value), "\n")
    cat("Mean:", round(mean(numeric_responses$numeric_value), 2), "\n")
    cat("Median:", round(median(numeric_responses$numeric_value), 2), "\n")
  }
  
  return(response_summary)
}

# =============================================================================
# VISUALIZATION FUNCTIONS
# =============================================================================

# Plot enrollment timeline
plot_enrollment <- function(data) {
  enrollment <- analyze_enrollment(data)
  
  ggplot(enrollment, aes(x = enrollment_month)) +
    geom_col(aes(y = new_subjects), fill = "steelblue", alpha = 0.7) +
    geom_line(aes(y = cumulative_subjects), color = "red", size = 1) +
    labs(
      title = "Subject Enrollment Over Time",
      x = "Month",
      y = "Number of Subjects",
      subtitle = "Bars: New enrollments, Line: Cumulative total"
    ) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

# Plot measure usage
plot_measure_usage <- function(data) {
  measure_usage <- data %>%
    count(measure_name, sort = TRUE) %>%
    head(15) %>%
    mutate(measure_name = fct_reorder(measure_name, n))
  
  ggplot(measure_usage, aes(x = measure_name, y = n)) +
    geom_col(fill = "darkgreen", alpha = 0.7) +
    coord_flip() +
    labs(
      title = "Most Frequently Used Measures",
      x = "Measure",
      y = "Number of Responses"
    ) +
    theme_minimal()
}

# Plot completion rates
plot_completion_rates <- function(data) {
  completion <- analyze_completion(data)
  
  ggplot(completion, aes(x = reorder(measure_name, completion_rate), y = completion_rate)) +
    geom_col(fill = "orange", alpha = 0.7) +
    coord_flip() +
    labs(
      title = "Measure Completion Rates",
      x = "Measure",
      y = "Completion Rate",
      subtitle = "Proportion of administrations that were completed"
    ) +
    theme_minimal() +
    scale_y_continuous(labels = scales::percent_format())
}

# Plot response distributions for numeric items
plot_numeric_responses <- function(data, measure_filter = NULL) {
  numeric_data <- data %>%
    filter(response_type %in% c("integer", "decimal")) %>%
    mutate(numeric_value = as.numeric(response_value)) %>%
    filter(!is.na(numeric_value))
  
  if (!is.null(measure_filter)) {
    numeric_data <- numeric_data %>% filter(measure_name == measure_filter)
  }
  
  if (nrow(numeric_data) == 0) {
    cat("No numeric responses found.\n")
    return(NULL)
  }
  
  ggplot(numeric_data, aes(x = numeric_value)) +
    geom_histogram(bins = 30, fill = "purple", alpha = 0.7) +
    facet_wrap(~measure_name, scales = "free") +
    labs(
      title = "Distribution of Numeric Responses",
      x = "Response Value",
      y = "Frequency"
    ) +
    theme_minimal()
}

# =============================================================================
# COMPREHENSIVE ANALYSIS REPORT
# =============================================================================

generate_analysis_report <- function(data_file = "fondecyt_research_data.csv") {
  cat("🔍 GENERATING COMPREHENSIVE ANALYSIS REPORT\n")
  cat("============================================\n")
  
  # Load data
  data <- load_research_data(data_file)
  
  # Run all analyses
  data_overview(data)
  study_summary <- analyze_studies(data)
  response_summary <- analyze_responses(data)
  completion_analysis <- analyze_completion(data)
  
  # Create visualizations
  cat("\n📊 Creating visualizations...\n")
  
  p1 <- plot_enrollment(data)
  ggsave("enrollment_timeline.png", p1, width = 10, height = 6, dpi = 300)
  
  p2 <- plot_measure_usage(data)
  ggsave("measure_usage.png", p2, width = 10, height = 8, dpi = 300)
  
  p3 <- plot_completion_rates(data)
  ggsave("completion_rates.png", p3, width = 10, height = 8, dpi = 300)
  
  p4 <- plot_numeric_responses(data)
  if (!is.null(p4)) {
    ggsave("numeric_responses.png", p4, width = 12, height = 8, dpi = 300)
  }
  
  cat("\n✅ Analysis complete! Check the generated PNG files.\n")
  
  # Return summary data for further analysis
  return(list(
    data = data,
    study_summary = study_summary,
    response_summary = response_summary,
    completion_analysis = completion_analysis
  ))
}

# =============================================================================
# USAGE EXAMPLES
# =============================================================================

cat("FONDECYT CSV Analysis Script Loaded\n")
cat("===================================\n\n")

cat("QUICK START:\n")
cat("1. Make sure you have your CSV file from data/extract_local_data.R\n")
cat("2. Run: results <- generate_analysis_report()\n")
cat("3. Explore specific analyses:\n")
cat("   - data_overview(results$data)\n")
cat("   - plot_enrollment(results$data)\n")
cat("   - analyze_completion(results$data)\n\n")

cat("CUSTOM ANALYSIS:\n")
cat("data <- load_research_data('your_file.csv')\n")
cat("# Then use any of the analysis functions...\n")
