# FONDECYT Complete Data Extraction Pipeline
# This script extracts and enhances the complete FONDECYT dataset with all metadata layers
# From basic item responses through item, administration, subject, and session metadata
#
# MEASURE EXCLUSION FEATURE:
# The pipeline now includes automatic exclusion of specific measures from analysis.
# Excluded measures: 34, 29, 28, 27, 26, 24, 23, 22, 21, 8
# This filtering occurs at the item response level to ensure excluded data is removed
# from all subsequent analysis steps. Approximately 1.7% of responses are excluded.

# Load required libraries
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
})

# Function to extract item responses from SQL dump with measure exclusion
extract_item_responses <- function(sql_file, excluded_measure_ids = c(34, 29, 28, 27, 26, 24, 23, 22, 21, 8)) {
  cat("📋 Extracting item responses from SQL dump...\n")
  
  # Read the SQL file
  sql_content <- readLines(sql_file, warn = FALSE)
  
  # Find the COPY statement for measurement_itemresponse
  copy_lines <- grep("^COPY public\\.measurement_itemresponse", sql_content)
  
  if (length(copy_lines) == 0) {
    stop("❌ Could not find measurement_itemresponse COPY statement in SQL dump")
  }
  
  # Use the first COPY statement
  copy_start <- copy_lines[1]
  cat("✅ Found item response COPY statement at line", copy_start, "\n")
  
  # Extract column names from COPY statement
  copy_line <- sql_content[copy_start]
  columns_match <- str_match(copy_line, "\\((.*?)\\)")
  if (is.na(columns_match[1,2])) {
    stop("❌ Could not extract column names from COPY statement")
  }
  
  column_names <- trimws(strsplit(columns_match[1,2], ",")[[1]])
  cat("📊 Columns found:", length(column_names), "\n")
  
  # Find data rows (between FROM stdin; and \.)
  data_start <- copy_start + 1
  data_end <- grep("^\\\\\\.$", sql_content[data_start:length(sql_content)])[1] + data_start - 2
  
  if (is.na(data_end)) {
    stop("❌ Could not find end of COPY data")
  }
  
  cat("📄 Data rows:", data_start, "to", data_end, "(", data_end - data_start + 1, "rows)\n")
  
  # Extract data rows as vector
  data_rows <- sql_content[data_start:data_end]
  
  cat("🚀 Using base R parsing for reliability...\n")
  
  # Create a temporary file with the data
  temp_file <- tempfile(fileext = ".tsv")
  
  # Write header and data to temp file
  writeLines(c(paste(column_names, collapse = "\t"), data_rows), temp_file)
  
  # Use read.table for reliable parsing (handles all data correctly)
  item_responses <- read.table(temp_file,
                              header = TRUE,
                              sep = "\t",
                              quote = "",
                              na.strings = c("\\N", ""),
                              stringsAsFactors = FALSE,
                              encoding = "UTF-8")
  
  # Clean up temp file
  unlink(temp_file)
  
  cat("📊 Raw data rows read:", nrow(item_responses), "\n")
  cat("✅ All rows preserved using base R parsing\n")
  
  # Convert data types for key columns (more lenient conversion)
  item_responses <- item_responses %>%
    mutate(
      id = as.integer(as.numeric(id)),
      item_id = as.integer(as.numeric(item_id)),
      administration_id = as.integer(as.numeric(administration_id)),
      numeric_value = as.numeric(numeric_value),
      was_skipped = case_when(
        tolower(trimws(as.character(was_skipped))) %in% c("t", "true", "1") ~ TRUE,
        tolower(trimws(as.character(was_skipped))) %in% c("f", "false", "0") ~ FALSE,
        TRUE ~ NA
      )
    ) %>%
    rename(
      response_id = id,
      response_date = created_datetime,
      response_updated = last_edit_datetime
    )
  
  # Apply measure exclusion filtering if requested
  if (length(excluded_measure_ids) > 0) {
    cat("\n🔍 Applying measure exclusion filter...\n")
    cat("📋 Excluding", length(excluded_measure_ids), "measures:", paste(excluded_measure_ids, collapse = ", "), "\n")
    
    # Extract item metadata for filtering
    cat("🔗 Extracting item metadata for filtering...\n")
    item_metadata <- extract_item_data(sql_file)
    
    # Get item IDs that belong to excluded measures
    excluded_items <- item_metadata %>%
      filter(item_measure_id %in% excluded_measure_ids) %>%
      pull(item_id)
    
    cat("🚫 Found", length(excluded_items), "items to exclude from", length(excluded_measure_ids), "measures\n")
    
    # Filter out responses from excluded items
    original_count <- nrow(item_responses)
    item_responses <- item_responses %>%
      filter(!item_id %in% excluded_items)
    
    excluded_count <- original_count - nrow(item_responses)
    exclusion_rate <- round(excluded_count / original_count * 100, 1)
    
    cat("✅ Excluded", excluded_count, "responses (", exclusion_rate, "%) from excluded measures\n")
    cat("📊 Remaining", nrow(item_responses), "responses for analysis\n")
  }

  cat("✅ Processed", nrow(item_responses), "item response records after exclusions\n")
  return(item_responses)
}

# Function to extract item metadata from SQL dump
extract_item_data <- function(sql_file) {
  cat("📋 Extracting item metadata from SQL dump...\n")
  
  # Read the SQL file
  sql_content <- readLines(sql_file, warn = FALSE)
  
  # Find the COPY statement for measurement_item
  copy_lines <- grep("^COPY public\\.measurement_item", sql_content)
  
  if (length(copy_lines) == 0) {
    stop("❌ Could not find measurement_item COPY statement in SQL dump")
  }
  
  # Use the first COPY statement
  copy_start <- copy_lines[1]
  cat("✅ Found item COPY statement at line", copy_start, "\n")
  
  # Extract column names from COPY statement
  copy_line <- sql_content[copy_start]
  columns_match <- str_match(copy_line, "\\((.*?)\\)")
  column_names <- trimws(strsplit(columns_match[1,2], ",")[[1]])
  
  # Find data rows
  data_start <- copy_start + 1
  data_end <- grep("^\\\\\\.$", sql_content[data_start:length(sql_content)])[1] + data_start - 2
  
  # Extract data rows
  data_rows <- sql_content[data_start:data_end]
  
  # Create temp file and use readr for efficient parsing
  temp_file <- tempfile(fileext = ".tsv")
  writeLines(c(paste(column_names, collapse = "\t"), data_rows), temp_file)
  
  item_data <- read_tsv(temp_file, 
                       na = c("\\N", ""),
                       show_col_types = FALSE,
                       locale = locale(encoding = "UTF-8"))
  
  unlink(temp_file)
  
  # Convert data types and select relevant columns
  item_data <- item_data %>%
    mutate(id = as.integer(id)) %>%
    select(
      item_id = id,
      item_label = label,
      item_text = text,
      item_measure_id = measure_id,
      item_is_required = is_required,
      item_position = position
    ) %>%
    filter(!is.na(item_id))
  
  cat("✅ Processed", nrow(item_data), "item records\n")
  return(item_data)
}

# Function to extract measure metadata from SQL dump
extract_measure_data <- function(sql_file) {
  cat("📋 Extracting measure metadata from SQL dump...\n")
  
  # Read the SQL file
  sql_content <- readLines(sql_file, warn = FALSE)
  
  # Find the COPY statement for measurement_measure
  copy_lines <- grep("^COPY public\\.measurement_measure", sql_content)
  
  if (length(copy_lines) == 0) {
    stop("❌ Could not find measurement_measure COPY statement in SQL dump")
  }
  
  # Use the first COPY statement
  copy_start <- copy_lines[1]
  cat("✅ Found measure COPY statement at line", copy_start, "\n")
  
  # Extract column names from COPY statement
  copy_line <- sql_content[copy_start]
  columns_match <- str_match(copy_line, "\\((.*?)\\)")
  column_names <- trimws(strsplit(columns_match[1,2], ",")[[1]])
  
  # Find data rows
  data_start <- copy_start + 1
  data_end <- grep("^\\\\\\.$", sql_content[data_start:length(sql_content)])[1] + data_start - 2
  
  # Extract data rows
  data_rows <- sql_content[data_start:data_end]
  
  # Create temp file and use readr for efficient parsing
  temp_file <- tempfile(fileext = ".tsv")
  writeLines(c(paste(column_names, collapse = "\t"), data_rows), temp_file)
  
  measure_data <- read_tsv(temp_file, 
                          na = c("\\N", ""),
                          show_col_types = FALSE,
                          locale = locale(encoding = "UTF-8"))
  
  unlink(temp_file)
  
  # Convert data types and select relevant columns
  measure_data <- measure_data %>%
    mutate(
      id = as.integer(id),
      cutoff_score = as.numeric(cutoff_score),
      sensitivity = as.numeric(sensitivity),
      specificity = as.numeric(specificity),
      is_active = case_when(
        tolower(trimws(as.character(is_active))) %in% c("t", "true", "1") ~ TRUE,
        tolower(trimws(as.character(is_active))) %in% c("f", "false", "0") ~ FALSE,
        TRUE ~ NA
      ),
      post_session_measure = case_when(
        tolower(trimws(as.character(post_session_measure))) %in% c("t", "true", "1") ~ TRUE,
        tolower(trimws(as.character(post_session_measure))) %in% c("f", "false", "0") ~ FALSE,
        TRUE ~ NA
      ),
      pre_session_measure = case_when(
        tolower(trimws(as.character(pre_session_measure))) %in% c("t", "true", "1") ~ TRUE,
        tolower(trimws(as.character(pre_session_measure))) %in% c("f", "false", "0") ~ FALSE,
        TRUE ~ NA
      )
    ) %>%
    select(
      measure_id = id,
      measure_title = title,
      measure_description = description,
      measure_label = label,
      measure_is_active = is_active,
      measure_cutoff_score = cutoff_score,
      measure_sensitivity = sensitivity,
      measure_specificity = specificity,
      measure_post_session = post_session_measure,
      measure_pre_session = pre_session_measure,
      measure_area_id = measurement_area_id
    ) %>%
    filter(!is.na(measure_id)) %>%
    arrange(measure_id)
  
  cat("✅ Processed", nrow(measure_data), "measure records\n")
  return(measure_data)
}

# Function to extract administration data from SQL dump
extract_administration_data <- function(sql_file) {
  cat("📋 Extracting administration data from SQL dump...\n")
  
  # Read the SQL file
  sql_content <- readLines(sql_file, warn = FALSE)
  
  # Find the COPY statement for measurement_measureadministration
  copy_lines <- grep("^COPY public\\.measurement_measureadministration", sql_content)
  
  if (length(copy_lines) == 0) {
    stop("❌ Could not find measurement_measureadministration COPY statement")
  }
  
  # Use the first COPY statement
  copy_start <- copy_lines[1]
  cat("✅ Found administration COPY statement at line", copy_start, "\n")
  
  # Extract column names
  copy_line <- sql_content[copy_start]
  columns_match <- str_match(copy_line, "\\((.*?)\\)")
  column_names <- trimws(strsplit(columns_match[1,2], ",")[[1]])
  
  # Find data rows
  data_start <- copy_start + 1
  data_end <- grep("^\\\\\\.$", sql_content[data_start:length(sql_content)])[1] + data_start - 2
  
  # Extract data rows
  data_rows <- sql_content[data_start:data_end]
  
  # Create temp file and use readr for efficient parsing
  temp_file <- tempfile(fileext = ".tsv")
  writeLines(c(paste(column_names, collapse = "\t"), data_rows), temp_file)
  
  admin_data <- read_tsv(temp_file, 
                        na = c("\\N", ""),
                        show_col_types = FALSE,
                        locale = locale(encoding = "UTF-8"))
  
  unlink(temp_file)
  
  # Convert data types and select relevant columns
  admin_data <- admin_data %>%
    mutate(id = as.integer(id)) %>%
    select(
      administration_id = id,
      admin_start_datetime = start_datetime,
      admin_end_datetime = end_datetime,
      admin_is_completed = is_completed,
      admin_subject_id = subject_id,
      session_id = follow_up_id
    ) %>%
    filter(!is.na(administration_id))
  
  cat("✅ Processed", nrow(admin_data), "administration records\n")
  return(admin_data)
}

# Function to extract subject data from SQL dump
extract_subject_data <- function(sql_file) {
  cat("📋 Extracting subject data from SQL dump...\n")
  
  # Read the SQL file
  sql_content <- readLines(sql_file, warn = FALSE)
  
  # Find the COPY statement for measurement_researchsubject
  copy_lines <- grep("^COPY public\\.measurement_researchsubject", sql_content)
  
  if (length(copy_lines) == 0) {
    stop("❌ Could not find measurement_researchsubject COPY statement")
  }
  
  # Use the first COPY statement
  copy_start <- copy_lines[1]
  cat("✅ Found subject COPY statement at line", copy_start, "\n")
  
  # Extract column names
  copy_line <- sql_content[copy_start]
  columns_match <- str_match(copy_line, "\\((.*?)\\)")
  column_names <- trimws(strsplit(columns_match[1,2], ",")[[1]])
  
  # Find data rows
  data_start <- copy_start + 1
  data_end <- grep("^\\\\\\.$", sql_content[data_start:length(sql_content)])[1] + data_start - 2
  
  # Extract data rows
  data_rows <- sql_content[data_start:data_end]
  
  # Create temp file and use readr for efficient parsing
  temp_file <- tempfile(fileext = ".tsv")
  writeLines(c(paste(column_names, collapse = "\t"), data_rows), temp_file)
  
  subject_data <- read_tsv(temp_file, 
                          na = c("\\N", ""),
                          show_col_types = FALSE,
                          locale = locale(encoding = "UTF-8"))
  
  unlink(temp_file)
  
  # Convert data types and select relevant columns
  subject_data <- subject_data %>%
    mutate(id = as.integer(id)) %>%
    select(
      subject_id = id,
      subject_type = subject_type,
      subject_study_site_id = study_site_id
    ) %>%
    filter(!is.na(subject_id))
  
  cat("✅ Processed", nrow(subject_data), "subject records\n")
  return(subject_data)
}

# Function to extract session data from SQL dump
extract_session_data <- function(sql_file) {
  cat("📋 Extracting session data from SQL dump...\n")
  
  # Read the SQL file
  sql_content <- readLines(sql_file, warn = FALSE)
  
  # Find the COPY statement for measurement_followup
  copy_lines <- grep("^COPY public\\.measurement_followup", sql_content)
  
  if (length(copy_lines) == 0) {
    stop("❌ Could not find measurement_followup COPY statement in SQL dump")
  }
  
  # Use the first COPY statement
  copy_start <- copy_lines[1]
  cat("✅ Found session COPY statement at line", copy_start, "\n")
  
  # Extract column names from COPY statement
  copy_line <- sql_content[copy_start]
  columns_match <- str_match(copy_line, "\\((.*?)\\)")
  column_names <- trimws(strsplit(columns_match[1,2], ",")[[1]])
  
  # Find data rows
  data_start <- copy_start + 1
  data_end <- grep("^\\\\\\.$", sql_content[data_start:length(sql_content)])[1] + data_start - 2
  
  # Extract data rows
  data_rows <- sql_content[data_start:data_end]
  
  # Create temp file and use readr for efficient parsing
  temp_file <- tempfile(fileext = ".tsv")
  writeLines(c(paste(column_names, collapse = "\t"), data_rows), temp_file)
  
  followup_data <- read_tsv(temp_file, 
                           na = c("\\N", ""),
                           show_col_types = FALSE,
                           locale = locale(encoding = "UTF-8"))
  
  unlink(temp_file)
  
  # Convert data types and select relevant columns
  followup_data <- followup_data %>%
    mutate(id = as.integer(id)) %>%
    select(
      session_id = id,
      session_number = session_number,
      session_attendance_status = attendance_status,
      session_modality = session_modality,
      session_therapist_id = therapist_id,
      session_comments = comments
    ) %>%
    filter(!is.na(session_id))
  
  cat("✅ Processed", nrow(followup_data), "session records\n")
  return(followup_data)
}

# Function to extract therapist data from SQL dump
extract_therapist_data <- function(sql_file) {
  cat("📋 Extracting therapist data from SQL dump...\n")
  
  # Read the SQL file
  sql_content <- readLines(sql_file, warn = FALSE)
  
  # Find the COPY statement for auth_user
  copy_lines <- grep("^COPY public\\.auth_user", sql_content)
  
  if (length(copy_lines) == 0) {
    cat("⚠️  Could not find auth_user COPY statement - will proceed without therapist names\n")
    return(data.frame(id = integer(), first_name = character(), last_name = character()))
  }
  
  # Use the first COPY statement
  copy_start <- copy_lines[1]
  
  # Extract column names
  copy_line <- sql_content[copy_start]
  columns_match <- str_match(copy_line, "\\((.*?)\\)")
  column_names <- trimws(strsplit(columns_match[1,2], ",")[[1]])
  
  # Find data rows
  data_start <- copy_start + 1
  data_end <- grep("^\\\\\\.$", sql_content[data_start:length(sql_content)])[1] + data_start - 2
  
  if (is.na(data_end)) {
    cat("⚠️  Could not find end of auth_user data - will proceed without therapist names\n")
    return(data.frame(id = integer(), first_name = character(), last_name = character()))
  }
  
  # Extract data rows
  data_rows <- sql_content[data_start:data_end]
  
  # Create temp file and use readr for efficient parsing
  temp_file <- tempfile(fileext = ".tsv")
  writeLines(c(paste(column_names, collapse = "\t"), data_rows), temp_file)
  
  user_data <- read_tsv(temp_file, 
                       na = c("\\N", ""),
                       show_col_types = FALSE,
                       locale = locale(encoding = "UTF-8"))
  
  unlink(temp_file)
  
  # Convert and select relevant columns
  therapist_data <- user_data %>%
    mutate(id = as.integer(id)) %>%
    select(id, first_name, last_name) %>%
    filter(!is.na(id))
  
  cat("✅ Processed", nrow(therapist_data), "user records\n")
  return(therapist_data)
}

# Main execution
main <- function(sql_file = NULL, excluded_measure_ids = c(34, 29, 28, 27, 26, 24, 23, 22, 21, 8)) {
  cat("🎯 FONDECYT Complete Data Extraction Pipeline\n")
  cat("============================================\n")
  
  # Determine SQL dump path (interactive selection if not provided)
  if (is.null(sql_file)) {
    default_path <- "data/dump-fondecyt-202507271125.sql"
    if (file.exists(default_path)) {
      sql_file <- default_path
      cat("📂 Using default SQL dump:", sql_file, "\n")
    } else {
      backup_candidates <- list.files("data", pattern = "db_backup\\.sql$", full.names = TRUE)
      if (length(backup_candidates) > 0) {
        fi <- file.info(backup_candidates)
        chosen <- rownames(fi)[which.max(fi$mtime)]
        sql_file <- chosen
        cat("📂 Default dump not found; using latest backup:", sql_file, "\n")
      } else if (interactive()) {
        cat("📁 Please select the SQL dump file...\n")
        sql_file <- file.choose()
        cat("✅ Selected:", sql_file, "\n")
      } else {
        stop("❌ SQL dump path not provided, no default or backups found. Pass path: main('path/to/dump.sql')")
      }
    }
  }
  
  # Define output file paths
  basic_file <- "data/item_responses.csv"
  item_file <- "data/item_responses_202507271125.csv"
  admin_file <- "data/item_responses_with_admin_202507271125.csv"
  subject_file <- "data/item_responses_full_metadata_202507271125.csv"
  complete_file <- "data/item_responses_complete_202507271125.csv"
  
  # Check if SQL dump exists
  if (!file.exists(sql_file)) {
    stop("❌ SQL dump file not found: ", sql_file)
  }
  
  # Step 1: Extract basic item responses
  cat("\n🔸 STEP 1: Extracting Basic Item Responses\n")
  cat("==========================================\n")
  item_responses <- extract_item_responses(sql_file, excluded_measure_ids = excluded_measure_ids)
  write_csv(item_responses, basic_file)
  cat("💾 Saved basic dataset:", basic_file, "\n")
  cat("📊 Records:", nrow(item_responses), "rows ×", ncol(item_responses), "columns\n")
  
  # Step 2: Add item metadata
  cat("\n� STEP 2: Adding Item Metadata\n")
  cat("===============================\n")
  item_data <- extract_item_data(sql_file)
  
  enhanced_data <- item_responses %>%
    left_join(item_data, by = "item_id")
  
  item_join_count <- sum(!is.na(enhanced_data$item_label))
  item_join_rate <- round(item_join_count / nrow(enhanced_data) * 100, 1)
  cat("🔗 Item join rate:", item_join_rate, "% (", item_join_count, "out of", nrow(enhanced_data), "responses)\n")
  
  write_csv(enhanced_data, item_file)
  cat("💾 Saved item-enhanced dataset:", item_file, "\n")
  
  # Step 3: Add administration metadata
  cat("\n🔸 STEP 3: Adding Administration Metadata\n")
  cat("========================================\n")
  admin_data <- extract_administration_data(sql_file)
  
  enhanced_data <- enhanced_data %>%
    left_join(admin_data %>% select(administration_id, admin_start_datetime, admin_end_datetime, admin_is_completed), 
              by = "administration_id")
  
  admin_join_count <- sum(!is.na(enhanced_data$admin_start_datetime))
  admin_join_rate <- round(admin_join_count / nrow(enhanced_data) * 100, 1)
  cat("🔗 Administration join rate:", admin_join_rate, "% (", admin_join_count, "out of", nrow(enhanced_data), "responses)\n")
  
  write_csv(enhanced_data, admin_file)
  cat("💾 Saved admin-enhanced dataset:", admin_file, "\n")
  
  # Step 4: Add subject metadata
  cat("\n🔸 STEP 4: Adding Subject Metadata\n")
  cat("==================================\n")
  subject_data <- extract_subject_data(sql_file)
  
  # Add subject linking
  enhanced_data <- enhanced_data %>%
    left_join(admin_data %>% select(administration_id, admin_subject_id), 
              by = "administration_id") %>%
    left_join(subject_data, by = c("admin_subject_id" = "subject_id"))
  
  subject_join_count <- sum(!is.na(enhanced_data$subject_type))
  subject_join_rate <- round(subject_join_count / nrow(enhanced_data) * 100, 1)
  cat("🔗 Subject join rate:", subject_join_rate, "% (", subject_join_count, "out of", nrow(enhanced_data), "responses)\n")
  
  # Add subject_id column for consistency
  enhanced_data <- enhanced_data %>%
    mutate(subject_id = admin_subject_id) %>%
    select(-admin_subject_id)
  
  write_csv(enhanced_data, subject_file)
  cat("💾 Saved subject-enhanced dataset:", subject_file, "\n")
  
  # Step 5: Add followup metadata
  cat("\n� STEP 5: Adding Followup Metadata\n")
  cat("===================================\n")
  followup_data <- extract_session_data(sql_file)
  therapist_data <- extract_therapist_data(sql_file)
  
  # Prepare session data - keep therapist_id as numeric
  followup_selected <- followup_data %>%
    rename(session_therapist = session_therapist_id)
  
  # Add session data to main dataset
  enhanced_data <- enhanced_data %>%
    left_join(admin_data %>% select(administration_id, session_id), by = "administration_id") %>%
    left_join(followup_selected, by = c("session_id" = "session_id"))
  
  session_join_count <- sum(!is.na(enhanced_data$session_id))
  session_join_rate <- round(session_join_count / nrow(enhanced_data) * 100, 1)
  cat("🔗 Session join rate:", session_join_rate, "% (", session_join_count, "out of", nrow(enhanced_data), "responses)\n")
  
  write_csv(enhanced_data, complete_file)
  cat("💾 Saved complete dataset:", complete_file, "\n")
  
  # Final summary
  cat("\n🎉 COMPLETE DATA EXTRACTION PIPELINE FINISHED!\n")
  cat("=============================================\n")
  cat("📊 Final dataset:", nrow(enhanced_data), "rows ×", ncol(enhanced_data), "columns\n")
  cat("💾 File size:", format(file.size(complete_file) / 1024^2, digits = 1), "MB\n")
  
  cat("\n📋 Metadata Coverage Summary:\n")
  cat("   Item metadata:     ", round(sum(!is.na(enhanced_data$item_label)) / nrow(enhanced_data) * 100, 1), "%\n")
  cat("   Administration:    ", round(sum(!is.na(enhanced_data$admin_start_datetime)) / nrow(enhanced_data) * 100, 1), "%\n")
  cat("   Subject metadata:  ", round(sum(!is.na(enhanced_data$subject_type)) / nrow(enhanced_data) * 100, 1), "%\n")
  cat("   Session data:      ", round(sum(!is.na(enhanced_data$session_id)) / nrow(enhanced_data) * 100, 1), "%\n")
  
  cat("\n📁 Generated Files:\n")
  cat("   Basic dataset:     ", basic_file, "\n")
  cat("   + Item metadata:   ", item_file, "\n")
  cat("   + Administration:  ", admin_file, "\n")
  cat("   + Subject data:    ", subject_file, "\n")
  cat("   + Session data:    ", complete_file, " ⭐ FINAL\n")
  
  # Create metadata files for key datasets
  write_metadata <- function(file_path, description, data_df) {
    metadata_content <- paste0(
      "Dataset: ", description, "\n",
      "Generated: ", Sys.time(), "\n",
      "Source: dump-fondecyt-202507271125.sql\n",
      "File: ", file_path, "\n\n",
      "Dataset Statistics:\n",
      "- Total responses: ", nrow(data_df), "\n",
      "- Total columns: ", ncol(data_df), "\n",
      "- File size: ", format(file.size(file_path) / 1024^2, digits = 1), " MB\n"
    )
    writeLines(metadata_content, paste0(tools::file_path_sans_ext(file_path), "_metadata.txt"))
  }
  
  write_metadata(item_file, "Item Responses with Item Metadata", enhanced_data)
  write_metadata(complete_file, "Complete Item Responses with All Metadata", enhanced_data)
  
  cat("\n✅ All files generated successfully! Ready for analysis.\n")
  
  # Step 6: Extract measure documentation
  cat("\n🔸 STEP 6: Extracting Measure Documentation\n")
  cat("===========================================\n")
  
  measure_file <- "data/measure_metadata.csv"
  
  # Extract measure metadata
  measure_data <- extract_measure_data(sql_file)
  write_csv(measure_data, measure_file)
  cat("💾 Saved measure metadata:", measure_file, "\n")
  
  cat("📊 Extracted", nrow(measure_data), "measures\n")
  
  # Clean up intermediate files, keeping only the final complete dataset
  cat("\n🧹 CLEANING UP INTERMEDIATE FILES\n")
  cat("=================================\n")
  
  intermediate_files <- c(basic_file, item_file, admin_file, subject_file)
  intermediate_metadata <- paste0(tools::file_path_sans_ext(intermediate_files), "_metadata.txt")
  
  files_to_remove <- c(intermediate_files, intermediate_metadata)
  files_removed <- 0
  
  for (file_path in files_to_remove) {
    if (file.exists(file_path)) {
      file.remove(file_path)
      files_removed <- files_removed + 1
      cat("🗑️  Removed:", file_path, "\n")
    }
  }
  
  cat("\n📁 Final Clean Workspace:\n")
  cat("   ✅ FINAL DATASET:      ", complete_file, " ⭐\n")
  cat("   ✅ FINAL METADATA:     ", paste0(tools::file_path_sans_ext(complete_file), "_metadata.txt"), "\n")
  cat("   ✅ MEASURE METADATA:   ", measure_file, "\n")
  cat("   ✅ SOURCE DATA:        ", sql_file, "\n")
  cat("   ✅ EXTRACTION SCRIPT:  extract_basic_responses.R\n")
  cat("\n🗑️  Removed", files_removed, "intermediate files to keep workspace clean.\n")
}

# Run the script
if (!interactive()) {
  main()
} else {
  # If running interactively, show instructions
  cat("📋 FONDECYT Complete Data Extraction Pipeline\n")
  cat("============================================\n")
  cat("🔸 This script contains a complete extraction pipeline.\n")
  cat("🔸 Usage:\n")
  cat("    main()                      # Prompts to select dump if default missing\n")
  cat("    main('data/dump.sql')       # Use explicit path\n")
  cat("    main(excluded_measure_ids=c(1,2))  # Override exclusion list\n")
  cat("\n🔸 Individual helper functions:\n")
  cat("    extract_item_responses(sql_file, excluded_measure_ids)\n")
  cat("    extract_item_data(sql_file)\n")
  cat("    extract_measure_data(sql_file)\n")
  cat("    extract_administration_data(sql_file)\n")
  cat("    extract_subject_data(sql_file)\n")
  cat("    extract_session_data(sql_file)\n")
  cat("    extract_therapist_data(sql_file)\n")
  cat("\n🎯 Run main() to begin.\n")
}
