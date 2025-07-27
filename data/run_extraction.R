#!/usr/bin/env Rscript

# FONDECYT Data Extraction Runner (LEGACY - uses PostgreSQL)
# Usage: Rscript run_extraction.R
# Note: This script is deprecated. Use extract_local_data.R instead.

cat("⚠️  LEGACY SCRIPT WARNING\n")
cat("========================\n")
cat("This script requires PostgreSQL setup and is no longer the main approach.\n")
cat("For the current extraction method, use: extract_local_data.R\n\n")

cat("Do you want to continue with the PostgreSQL method? (y/N): ")
response <- tolower(trimws(readLines("stdin", n=1)))

if (response != "y" && response != "yes") {
  cat("Switching to modern extraction method...\n\n")
  source("extract_local_data.R")
  main()
  quit(save = "no")
}

cat("\nContinuing with PostgreSQL method...\n")
cat("=====================================\n\n")

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
cat("1. Make sure PostgreSQL is set up (run setup_local_db.sh)\n")
cat("2. Database should be running on localhost:5432\n")
cat("3. Database name: fondecyt\n\n")

cat("🚀 RUNNING POSTGRESQL EXTRACTION...\n")

# NOTE: This tries to use extract_data.R which no longer exists
# This is kept for reference but will fail

# Run the extraction
tryCatch({
  cat("❌ ERROR: extract_data.R has been removed from this project.\n")
  cat("Use extract_local_data.R instead for dump-based extraction.\n")
}, error = function(e) {
  cat("❌ ERROR:", e$message, "\n")
  cat("💡 Use the modern extraction: source('extract_local_data.R'); main()\n")
})

cat("\n✅ Script complete!\n")
