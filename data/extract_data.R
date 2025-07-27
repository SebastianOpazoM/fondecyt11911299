# FONDECYT Data Extraction Script
# Purpose: Extract and join relational data into a single flat CSV file for analysis
# Run once to create the analysis dataset, then work with CSV

library(DBI)
library(RPostgreSQL)
library(dplyr)
library(readr)

# =============================================================================
# DATABASE CONNECTION (One-time use)
# =============================================================================

# Connect to database - replace with your credentials
connect_to_postgres <- function() {
  con <- dbConnect(
    PostgreSQL(),
    host = "localhost",                   # Local PostgreSQL server
    port = 5432,
    dbname = "fondecyt",                 # Database name from the dump
    user = Sys.getenv("USER"),           # Your system username
    password = ""                        # Usually empty for local setup
  )
  return(con)
}

# =============================================================================
# DATA EXTRACTION QUERY
# =============================================================================

# Main extraction query - focused on item responses as the primary data
get_item_responses_query <- function() {
  "
  SELECT 
    -- Item Response Info (PRIMARY)
    ir.id as response_id,
    ir.created_datetime as response_date,
    ir.last_edit_datetime as response_updated,
    ir.administration_id,
    ir.item_id,
    ir.subject_value_id,
    ir.was_skipped,
    
    -- Response Values
    ir.numeric_value,
    ir.character_value,
    
    -- Response Value (unified for analysis)
    CASE 
      WHEN ir.numeric_value IS NOT NULL THEN ir.numeric_value::text
      WHEN ir.character_value IS NOT NULL THEN ir.character_value
      ELSE NULL
    END as response_value,
    
    -- Response Type Indicator
    CASE 
      WHEN ir.numeric_value IS NOT NULL THEN 'numeric'
      WHEN ir.character_value IS NOT NULL THEN 'character'
      ELSE 'null'
    END as response_type,
    
    -- Additional info
    ir.response_time_options
    
  FROM measurement_itemresponse ir
  
  ORDER BY ir.id
  "
}

# Alternative simpler query focusing on just measurement data
get_measurements_only_query <- function() {
  "
  SELECT 
    -- Core identifiers
    rs.id as study_id,
    rs.name as study_name,
    rsub.id as subject_id,
    m.id as measure_id,
    m.name as measure_name,
    ma.id as administration_id,
    ir.id as response_id,
    i.id as item_id,
    
    -- Dates
    rs.created_at as study_created_date,
    rsub.created_at as subject_enrolled_date,
    ma.created_at as administration_date,
    ma.completed_at as administration_completed_date,
    ir.created_at as response_date,
    
    -- Item details
    i.text as item_text,
    i.item_number as item_number,
    it.name as item_type,
    
    -- Response value (unified)
    COALESCE(
      ir.integer_value::text,
      ir.decimal_value::text,
      ir.text_value,
      ir.boolean_value::text,
      ir.date_value::text
    ) as response_value,
    
    -- Response type
    CASE 
      WHEN ir.integer_value IS NOT NULL THEN 'integer'
      WHEN ir.decimal_value IS NOT NULL THEN 'decimal'
      WHEN ir.text_value IS NOT NULL THEN 'text'
      WHEN ir.boolean_value IS NOT NULL THEN 'boolean'
      WHEN ir.date_value IS NOT NULL THEN 'date'
      ELSE 'null'
    END as response_type
    
  FROM measurement_researchstudy rs
  JOIN measurement_researchsubject rsub ON rs.id = rsub.research_study_id
  JOIN measurement_measureadministration ma ON rsub.id = ma.research_subject_id
  JOIN measurement_measure m ON ma.measure_id = m.id
  JOIN measurement_itemresponse ir ON ma.id = ir.measure_administration_id
  JOIN measurement_item i ON ir.item_id = i.id
  JOIN measurement_itemtype it ON i.item_type_id = it.id
  
  ORDER BY rs.id, rsub.id, ma.id, i.item_number, ir.id
  "
}

# =============================================================================
# EXTRACTION FUNCTIONS
# =============================================================================

# Extract data and save to CSV
extract_item_responses <- function(output_file = "fondecyt_item_responses.csv") {
  
  cat("Connecting to database...\n")
  con <- connect_to_postgres()
  
  tryCatch({
    cat("Extracting item responses data...\n")
    
    # Execute query
    cat("Running extraction query...\n")
    query <- get_item_responses_query()
    data <- dbGetQuery(con, query)
    
    cat("Extracted", nrow(data), "rows with", ncol(data), "columns\n")
    
    # Save to CSV
    cat("Saving to", output_file, "...\n")
    write_csv(data, output_file)
    
    cat("✅ Data extraction complete!\n")
    cat("📁 File saved:", output_file, "\n")
    cat("📊 Dimensions:", nrow(data), "rows ×", ncol(data), "columns\n")
    
    # Show preview
    cat("\n📋 Preview of extracted data:\n")
    print(head(data, 5))
    
    # Show summary
    cat("\n📈 Summary:\n")
    cat("- Total item responses:", nrow(data), "\n")
    cat("- Response types:", paste(unique(data$response_type), collapse = ", "), "\n")
    cat("- Non-null responses:", sum(!is.na(data$response_value)), "\n")
    cat("- Response rate:", round(sum(!is.na(data$response_value)) / nrow(data) * 100, 1), "%\n")
    
    return(data)
    
  }, error = function(e) {
    cat("❌ Error during extraction:", e$message, "\n")
    return(NULL)
  }, finally = {
    dbDisconnect(con)
    cat("Database connection closed.\n")
  })
}

# Legacy function for backward compatibility
extract_research_data <- function(output_file = "fondecyt_research_data.csv", simple_query = TRUE) {
  
  cat("⚠️  Note: This function now defaults to item responses extraction.\n")
  cat("Use extract_item_responses() for the new focused approach.\n\n")
  
  return(extract_item_responses(output_file))
}

# Extract just expenses data
extract_expenses_data <- function(output_file = "fondecyt_expenses_data.csv") {
  cat("Connecting to database for expenses extraction...\n")
  con <- connect_to_postgres()
  
  tryCatch({
    query <- "
    SELECT 
      e.id as expense_id,
      e.amount,
      e.description as expense_description,
      e.date as expense_date,
      e.created_at as expense_created_date,
      ea.name as expense_area,
      ea.description as area_description,
      esa.name as expense_subarea,
      esa.description as subarea_description
    FROM expenses_expense e
    JOIN expenses_expensearea ea ON e.expense_area_id = ea.id
    LEFT JOIN expenses_expensesubarea esa ON e.expense_subarea_id = esa.id
    ORDER BY e.date, ea.name
    "
    
    data <- dbGetQuery(con, query)
    write_csv(data, output_file)
    
    cat("✅ Expenses data extracted!\n")
    cat("📁 File saved:", output_file, "\n")
    cat("📊 Total expenses:", nrow(data), "\n")
    
    return(data)
    
  }, error = function(e) {
    cat("❌ Error:", e$message, "\n")
    return(NULL)
  }, finally = {
    dbDisconnect(con)
  })
}

# =============================================================================
# USAGE INSTRUCTIONS
# =============================================================================

cat("FONDECYT Data Extraction Script Loaded\n")
cat("=====================================\n\n")

cat("INSTRUCTIONS:\n")
cat("1. Edit the database credentials in connect_to_postgres() function\n")
cat("2. Run the main extraction command:\n\n")

cat("   # Extract item responses (one row per response):\n")
cat("   responses_data <- extract_item_responses('my_responses.csv')\n\n")

cat("   # Extract expenses data:\n")
cat("   expenses_data <- extract_expenses_data('my_expenses_data.csv')\n\n")

cat("3. Once you have your CSV files, you can work with them directly:\n")
cat("   data <- read_csv('my_responses.csv')\n")
cat("   # Then run your analysis...\n\n")

cat("The script will create a CSV where each row is an item response.\n")
cat("This gives you a clean foundation to add related table data later! 📊\n")
