# FONDECYT Local Data Extraction Script
# Purpose: Extract data from the local SQL dump file (no remote database needed!)
# Works with the dump-fondecyt-202507271125.sql file in your repo

library(DBI)
library(RSQLite)
library(dplyr)
library(readr)
library(stringr)

# =============================================================================
# OPTION 1: EXTRACT DATA DIRECTLY FROM SQL DUMP FILE
# =============================================================================

# Function to extract CREATE TABLE and INSERT statements for a specific table
extract_table_from_dump <- function(dump_file, table_name) {
  cat("Reading SQL dump file:", dump_file, "\n")
  
  # Read the entire dump file
  sql_content <- readLines(dump_file, warn = FALSE)
  
  # Find the CREATE TABLE statement for our table
  create_start <- grep(paste0("CREATE TABLE public\\.", table_name, " "), sql_content)
  
  if (length(create_start) == 0) {
    cat("❌ Table", table_name, "not found in dump file\n")
    return(NULL)
  }
  
  cat("✅ Found table", table_name, "at line", create_start, "\n")
  
  # Find the end of CREATE TABLE (look for the closing parenthesis and semicolon)
  create_end <- create_start
  for (i in create_start:length(sql_content)) {
    if (grepl("^\\);", sql_content[i])) {
      create_end <- i
      break
    }
  }
  
  # Extract CREATE TABLE statement
  create_statement <- sql_content[create_start:create_end]
  
  # Find INSERT statements for this table
  insert_pattern <- paste0("INSERT INTO public\\.", table_name, " ")
  insert_lines <- grep(insert_pattern, sql_content)
  
  cat("Found", length(insert_lines), "INSERT statements for", table_name, "\n")
  
  return(list(
    create_statement = create_statement,
    insert_lines = sql_content[insert_lines],
    total_inserts = length(insert_lines)
  ))
}

# Function to create a simple CSV from INSERT statements
extract_item_responses_from_dump <- function(dump_file = "dump-fondecyt-202507271125.sql", 
                                           output_file = "item_responses.csv") {
  
  cat("🔍 Extracting item responses from SQL dump...\n")
  
  # Extract the measurement_itemresponse table
  table_data <- extract_table_from_dump(dump_file, "measurement_itemresponse")
  
  if (is.null(table_data)) {
    return(NULL)
  }
  
  cat("📊 Processing", table_data$total_inserts, "INSERT statements...\n")
  
  # Parse INSERT statements to extract data
  # This is a simplified parser - might need adjustment based on actual data format
  all_rows <- list()
  
  for (i in 1:min(length(table_data$insert_lines), 1000)) {  # Limit to first 1000 for testing
    line <- table_data$insert_lines[i]
    
    # Extract values from INSERT statement
    # Pattern: INSERT INTO public.measurement_itemresponse VALUES (values...);
    values_match <- str_match(line, "VALUES \\((.+)\\);")
    
    if (!is.na(values_match[1, 2])) {
      values_str <- values_match[1, 2]
      
      # Split by comma, but be careful with quoted strings
      # This is a simple split - might need more sophisticated parsing
      values <- str_split(values_str, ",")[[1]]
      values <- str_trim(values)
      
      # Remove quotes from string values
      values <- str_replace_all(values, "^'|'$", "")
      values <- str_replace_all(values, "''", "'")  # Unescape single quotes
      
      all_rows[[i]] <- values
    }
    
    if (i %% 100 == 0) {
      cat("Processed", i, "rows...\n")
    }
  }
  
  if (length(all_rows) == 0) {
    cat("❌ No data extracted\n")
    return(NULL)
  }
  
  # Convert to data frame
  # Note: Column names would need to be extracted from CREATE TABLE statement
  max_cols <- max(sapply(all_rows, length))
  
  # Pad shorter rows with NAs
  all_rows <- lapply(all_rows, function(x) {
    if (length(x) < max_cols) {
      c(x, rep(NA, max_cols - length(x)))
    } else {
      x[1:max_cols]
    }
  })
  
  df <- do.call(rbind, all_rows)
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  
  # Generic column names (you'd want to get these from CREATE TABLE)
  colnames(df) <- paste0("col_", 1:ncol(df))
  
  # Save to CSV
  write_csv(df, output_file)
  
  cat("✅ Extracted", nrow(df), "rows to", output_file, "\n")
  cat("📋 Preview:\n")
  print(head(df, 3))
  
  return(df)
}

# =============================================================================
# OPTION 2: CONVERT TO SQLITE AND QUERY
# =============================================================================

# Function to convert PostgreSQL dump to SQLite (requires some manual work)
create_sqlite_from_dump <- function(dump_file = "dump-fondecyt-202507271125.sql",
                                   sqlite_file = "fondecyt.sqlite") {
  
  cat("⚠️  This function provides instructions for manual conversion.\n")
  cat("PostgreSQL to SQLite conversion requires some manual steps:\n\n")
  
  cat("1. Install pgloader (if not already installed):\n")
  cat("   brew install pgloader  # macOS\n")
  cat("   apt-get install pgloader  # Ubuntu\n\n")
  
  cat("2. OR use online converter tools\n")
  cat("3. OR manually clean up the SQL file for SQLite compatibility\n\n")
  
  cat("For now, use extract_item_responses_from_dump() to get data directly!\n")
}

# Function to query SQLite database (if you have one)
query_sqlite_database <- function(sqlite_file = "fondecyt.sqlite", 
                                 output_file = "item_responses.csv") {
  
  if (!file.exists(sqlite_file)) {
    cat("❌ SQLite file not found:", sqlite_file, "\n")
    cat("Use create_sqlite_from_dump() first or extract_item_responses_from_dump()\n")
    return(NULL)
  }
  
  # Connect to SQLite
  con <- dbConnect(SQLite(), sqlite_file)
  
  tryCatch({
    # Query item responses
    query <- "
    SELECT 
      id as response_id,
      created_at as response_date,
      updated_at as response_updated,
      
      CASE 
        WHEN integer_value IS NOT NULL THEN CAST(integer_value AS TEXT)
        WHEN decimal_value IS NOT NULL THEN CAST(decimal_value AS TEXT)
        WHEN text_value IS NOT NULL THEN text_value
        WHEN boolean_value IS NOT NULL THEN CAST(boolean_value AS TEXT)
        WHEN date_value IS NOT NULL THEN CAST(date_value AS TEXT)
        ELSE NULL
      END as response_value,
      
      CASE 
        WHEN integer_value IS NOT NULL THEN 'integer'
        WHEN decimal_value IS NOT NULL THEN 'decimal'
        WHEN text_value IS NOT NULL THEN 'text'
        WHEN boolean_value IS NOT NULL THEN 'boolean'
        WHEN date_value IS NOT NULL THEN 'date'
        ELSE 'null'
      END as response_type,
      
      integer_value,
      decimal_value,
      text_value,
      boolean_value,
      date_value
      
    FROM measurement_itemresponse
    ORDER BY id
    "
    
    data <- dbGetQuery(con, query)
    write_csv(data, output_file)
    
    cat("✅ Extracted", nrow(data), "item responses from SQLite\n")
    return(data)
    
  }, finally = {
    dbDisconnect(con)
  })
}

# =============================================================================
# SIMPLE APPROACH: LOAD AS LOCAL POSTGRESQL
# =============================================================================

setup_local_postgres <- function() {
  cat("🐘 Setting up local PostgreSQL database:\n\n")
  
  cat("1. Install PostgreSQL (if not installed):\n")
  cat("   brew install postgresql  # macOS\n")
  cat("   brew services start postgresql\n\n")
  
  cat("2. Create database and load dump:\n")
  cat("   createdb fondecyt_local\n")
  cat("   psql fondecyt_local < dump-fondecyt-202507271125.sql\n\n")
  
  cat("3. Then update extract_data.R to connect to localhost:\n")
  cat("   host = 'localhost'\n")
  cat("   dbname = 'fondecyt_local'\n")
  cat("   user = 'your_local_username'\n")
  cat("   password = 'your_local_password'\n\n")
  
  cat("This gives you the full PostgreSQL functionality!\n")
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

extract_data_from_local_dump <- function() {
  cat("🏠 FONDECYT Local Data Extraction\n")
  cat("=================================\n\n")
  
  cat("You have several options:\n\n")
  
  cat("Option 1 - Direct extraction from dump (simple but limited):\n")
  cat("  data <- extract_item_responses_from_dump()\n\n")
  
  cat("Option 2 - Set up local PostgreSQL (full functionality):\n") 
  cat("  setup_local_postgres()\n\n")
  
  cat("Option 3 - Convert to SQLite (moderate functionality):\n")
  cat("  create_sqlite_from_dump()\n\n")
  
  cat("Recommendation: Try Option 1 first for a quick test!\n")
}

# =============================================================================
# USAGE
# =============================================================================

cat("FONDECYT Local Data Extraction Script Loaded\n")
cat("===========================================\n\n")

extract_data_from_local_dump()

cat("\n🚀 Quick start:\n")
cat("data <- extract_item_responses_from_dump()\n")
