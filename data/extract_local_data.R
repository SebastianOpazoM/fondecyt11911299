# FONDECYT Local Data Extraction Script
# Purpose: Extract data from SQL dump files (handles multiple/updated dumps!)
# Automatically detects and works with any FONDECYT SQL dump in this folder

library(DBI)
library(RSQLite)
library(dplyr)
library(readr)
library(stringr)

# =============================================================================
# DUMP FILE MANAGEMENT
# =============================================================================

# Function to find all SQL dump files in the current directory
find_dump_files <- function(pattern = "dump.*fondecyt.*\\.sql$") {
  dump_files <- list.files(".", pattern = pattern, ignore.case = TRUE)
  return(dump_files)
}

# Function to get the most recent dump file
get_latest_dump <- function(pattern = "dump.*fondecyt.*\\.sql$") {
  dump_files <- find_dump_files(pattern)
  
  if (length(dump_files) == 0) {
    cat("❌ No SQL dump files found matching pattern:", pattern, "\n")
    cat("Expected files like: dump-fondecyt-YYYYMMDDHHMI.sql\n")
    return(NULL)
  }
  
  # Get file info to find the most recent
  file_info <- file.info(dump_files)
  file_info$filename <- rownames(file_info)
  
  # Sort by modification time (most recent first)
  latest_file <- file_info[order(file_info$mtime, decreasing = TRUE), ]$filename[1]
  
  cat("📁 Found", length(dump_files), "dump file(s):\n")
  for (i in 1:length(dump_files)) {
    marker <- if (dump_files[i] == latest_file) "👉 " else "   "
    cat(marker, dump_files[i], "\n")
  }
  
  cat("\n✅ Using latest dump:", latest_file, "\n")
  return(latest_file)
}

# Function to choose dump file interactively
choose_dump_file <- function() {
  dump_files <- find_dump_files()
  
  if (length(dump_files) == 0) {
    cat("❌ No SQL dump files found in current directory\n")
    return(NULL)
  }
  
  if (length(dump_files) == 1) {
    cat("📁 Using only available dump file:", dump_files[1], "\n")
    return(dump_files[1])
  }
  
  cat("📁 Multiple dump files found:\n")
  for (i in 1:length(dump_files)) {
    cat(i, ":", dump_files[i], "\n")
  }
  
  cat("\nEnter number (1-", length(dump_files), ") or press Enter for latest: ")
  choice <- readline()
  
  if (choice == "" || choice == "\n") {
    return(get_latest_dump())
  }
  
  choice_num <- as.numeric(choice)
  if (is.na(choice_num) || choice_num < 1 || choice_num > length(dump_files)) {
    cat("Invalid choice, using latest dump\n")
    return(get_latest_dump())
  }
  
  return(dump_files[choice_num])
}

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
extract_item_responses_from_dump <- function(dump_file = NULL, 
                                           output_file = NULL,
                                           auto_latest = TRUE) {
  
  # Auto-detect dump file if not specified
  if (is.null(dump_file)) {
    if (auto_latest) {
      dump_file <- get_latest_dump()
    } else {
      dump_file <- choose_dump_file()
    }
    
    if (is.null(dump_file)) {
      return(NULL)
    }
  }
  
  # Auto-generate output filename if not specified
  if (is.null(output_file)) {
    # Extract date from filename if possible
    date_match <- str_extract(dump_file, "\\d{12}")  # YYYYMMDDHHMI
    if (!is.na(date_match)) {
      output_file <- paste0("item_responses_", date_match, ".csv")
    } else {
      output_file <- paste0("item_responses_", format(Sys.Date(), "%Y%m%d"), ".csv")
    }
  }
  
  cat("🔍 Extracting item responses from:", dump_file, "\n")
  cat("📁 Output file:", output_file, "\n\n")
  
  # Check if dump file exists
  if (!file.exists(dump_file)) {
    cat("❌ Dump file not found:", dump_file, "\n")
    return(NULL)
  }
  
  # Extract the measurement_itemresponse table
  table_data <- extract_table_from_dump(dump_file, "measurement_itemresponse")
  
  if (is.null(table_data)) {
    return(NULL)
  }
  
  cat("📊 Processing", table_data$total_inserts, "INSERT statements...\n")
  
  # Parse INSERT statements to extract data
  # This is a simplified parser - might need adjustment based on actual data format
  all_rows <- list()
  
  # Process all INSERT statements (not just first 1000)
  total_inserts <- length(table_data$insert_lines)
  process_count <- min(total_inserts, 10000)  # Process up to 10K for testing, increase as needed
  
  for (i in 1:process_count) {
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
    
    if (i %% 1000 == 0) {
      cat("Processed", i, "/", process_count, "rows (", round(i/process_count*100, 1), "%)\n")
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
  
  # Create metadata file
  metadata_file <- str_replace(output_file, "\\.csv$", "_metadata.txt")
  writeLines(c(
    paste("Source dump file:", dump_file),
    paste("Extraction date:", Sys.time()),
    paste("Rows extracted:", nrow(df)),
    paste("Columns:", ncol(df)),
    paste("File size:", file.size(dump_file), "bytes"),
    paste("Output file:", output_file)
  ), metadata_file)
  
  cat("📄 Metadata saved to:", metadata_file, "\n")
  
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
  
  cat("3. Use database-based approach if needed for complex queries\n")
  cat("   (Note: This project now uses direct dump parsing)\n")
  cat("   host = 'localhost'\n")
  cat("   dbname = 'fondecyt_local'\n")
  cat("   user = 'your_local_username'\n")
  cat("   password = 'your_local_password'\n\n")
  
  cat("But the current approach (direct parsing) is simpler!\n")
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

# Main execution
main <- function() {
  cat("🚀 FONDECYT Data Extraction Tool\n")
  cat("================================\n\n")
  
  # Find available dump files
  dump_files <- find_dump_files()
  
  if (length(dump_files) == 0) {
    cat("❌ No FONDECYT dump files found in current directory\n")
    cat("   Looking for files matching pattern: dump.*fondecyt.*\\.sql$\n")
    return(invisible(NULL))
  }
  
  cat("📁 Found", length(dump_files), "dump file(s):\n")
  for (i in seq_along(dump_files)) {
    file_info <- file.info(dump_files[i])
    cat("  ", i, ".", basename(dump_files[i]), 
        "(", format(file_info$size, units = "MB"), ",", 
        "modified:", format(file_info$mtime, "%Y-%m-%d %H:%M"), ")\n")
  }
  cat("\n")
  
  # Extract data using auto-detection (latest file by default)
  result <- extract_item_responses_from_dump()
  
  if (!is.null(result)) {
    cat("\n🎉 Extraction completed successfully!\n")
    cat("You can now use the CSV file for analysis in R or other tools.\n")
  } else {
    cat("\n❌ Extraction failed. Please check the dump file and try again.\n")
  }
}

cat("FONDECYT Local Data Extraction Script Loaded\n")
cat("===========================================\n\n")

cat("📋 Available functions:\n")
cat("• find_dump_files()                     - Find all FONDECYT dump files\n")
cat("• get_latest_dump()                     - Get the most recent dump file\n")
cat("• choose_dump_file()                    - Interactively choose a dump file\n")
cat("• extract_item_responses_from_dump()    - Extract data (auto-detects latest file)\n")
cat("• main()                                - Run complete extraction workflow\n\n")

cat("🚀 Quick start examples:\n")
cat("# Auto-extract from latest dump:\n")
cat("result <- extract_item_responses_from_dump()\n\n")
cat("# Choose specific dump file:\n")
cat("result <- extract_item_responses_from_dump(auto_latest = FALSE)\n\n")
cat("# Run complete workflow:\n")
cat("main()\n\n")

# Run if script is called directly
if (!interactive()) {
  main()
}
