#!/usr/bin/env Rscript

# FONDECYT Data Extraction Runner
# Usage: Rscript run_extraction.R

cat("FONDECYT Data Extraction\n")
cat("========================\n\n")

# Load the extraction script
source("extract_data.R")

# Check if required packages are installed
required_packages <- c("DBI", "RPostgreSQL", "dplyr", "readr")
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]

if(length(missing_packages) > 0) {
  cat("Installing missing packages:", paste(missing_packages, collapse = ", "), "\n")
  install.packages(missing_packages, repos = "https://cran.rstudio.com/")
}

# Load libraries
library(DBI)
library(RPostgreSQL)
library(dplyr)
library(readr)

cat("📋 BEFORE RUNNING:\n")
cat("1. Make sure you've edited the database credentials in extract_data.R\n")
cat("2. Update the connect_to_postgres() function with your actual:\n")
cat("   - host\n")
cat("   - user\n") 
cat("   - password\n\n")

cat("🚀 RUNNING EXTRACTION...\n")

# Run the extraction
tryCatch({
  responses_data <- extract_item_responses("fondecyt_item_responses.csv")
  cat("🎉 SUCCESS! Data saved to fondecyt_item_responses.csv\n")
}, error = function(e) {
  cat("❌ ERROR:", e$message, "\n")
  cat("💡 Make sure your database credentials are correct!\n")
})

cat("\n✅ Script complete!\n")
