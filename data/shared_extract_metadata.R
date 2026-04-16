# =============================================================================
# shared_extract_metadata.R
# NODAL Dataset — Shared metadata extraction from MindKey SQL backup
# =============================================================================
# Purpose:
#   Extracts study site (clinic) and therapist lookup tables from the raw SQL
#   backup file. Generates CSV files that any researcher can join to the
#   patient_item_matrix_wide or to the long-format item_responses data.
#
# Outputs (saved to data/):
#   1. study_sites.csv          — study_site_id, site_name, study_id
#   2. subject_site_map.csv     — subject_id, subject_type, study_site_id, site_name
#   3. therapist_patient_map.csv — therapist_id, patient_id
#   4. session_therapist_map.csv — session_id, patient_id, therapist_id, session_number
#
# Usage:
#   source("shared_extract_metadata.R")
#   Or run from terminal: Rscript shared_extract_metadata.R
#
# Requirements: Base R only (no additional packages needed)
# =============================================================================

cat("=== NODAL: Extracting metadata from SQL backup ===\n\n")

# --- Configuration -----------------------------------------------------------

# Find the most recent SQL backup in the data/ folder
sql_files <- list.files("data", pattern = "^\\d{4}_\\d{2}_\\d{2}_dB_backup\\.sql$|^mindkey_backup.*\\.sql$",
                        full.names = TRUE)

if (length(sql_files) == 0) {
  # Also check for files with the alternate naming convention
  sql_files <- list.files("data", pattern = "\\.sql$", full.names = TRUE)
}

if (length(sql_files) == 0) {
  stop("No SQL backup file found in data/ folder.\n",
       "  Please place the backup file (e.g., mindkey_backup_YYYYMMDD.sql) in the data/ directory.")
}

# Use the most recent file (by name, which includes the date)
sql_file <- sort(sql_files, decreasing = TRUE)[1]
cat("Using SQL file:", sql_file, "\n\n")

# --- Helper: extract COPY block from SQL -------------------------------------
#' Reads a PostgreSQL COPY block from a SQL dump file.
#' Returns a data.frame with the extracted rows.
#'
#' @param filepath Path to the SQL file
#' @param table_name Full table name (e.g., "public.measurement_researchstudysite")
#' @param col_names Character vector of column names for the resulting data.frame
#' @return data.frame with extracted data, or empty data.frame if table not found

extract_copy_block <- function(filepath, table_name, col_names) {
  
  con <- file(filepath, "r", encoding = "UTF-8")
  on.exit(close(con))
  
  # Pattern to find the COPY statement for this table
  copy_pattern <- paste0("COPY ", table_name, " ")
  
  found <- FALSE
  rows <- list()
  
  while (TRUE) {
    line <- readLines(con, n = 1, warn = FALSE)
    if (length(line) == 0) break  # EOF
    
    if (!found && grepl(copy_pattern, line, fixed = TRUE)) {
      found <- TRUE
      next
    }
    
    if (found) {
      if (trimws(line) == "\\.") break  # End of COPY block
      
      fields <- strsplit(line, "\t", fixed = TRUE)[[1]]
      # Replace \N with NA
      fields[fields == "\\N"] <- NA
      rows[[length(rows) + 1]] <- fields
    }
  }
  
  if (!found) {
    warning("Table '", table_name, "' not found in SQL file.")
    return(data.frame(matrix(ncol = length(col_names), nrow = 0,
                             dimnames = list(NULL, col_names))))
  }
  
  # Build data.frame
  df <- do.call(rbind, lapply(rows, function(r) {
    # Pad or trim to match expected columns
    length(r) <- length(col_names)
    r
  }))
  
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  names(df) <- col_names
  
  cat("  Extracted", nrow(df), "rows from", table_name, "\n")
  return(df)
}


# =============================================================================
# 1. STUDY SITES
# =============================================================================
cat("--- Extracting study sites ---\n")

sites <- extract_copy_block(
  sql_file,
  "public.measurement_researchstudysite",
  c("study_site_id", "site_name", "description", "study_id")
)

sites$study_site_id <- as.integer(sites$study_site_id)
sites$study_id <- as.integer(sites$study_id)

# Keep relevant columns
sites <- sites[, c("study_site_id", "site_name", "study_id")]

cat("\n  Study sites found:\n")
print(sites, row.names = FALSE)

write.csv(sites, "data/study_sites.csv", row.names = FALSE)
cat("\n  Saved: data/study_sites.csv\n\n")


# =============================================================================
# 2. SUBJECT -> SITE MAPPING
# =============================================================================
cat("--- Extracting subject-site mapping ---\n")

subjects_raw <- extract_copy_block(
  sql_file,
  "public.measurement_researchsubject",
  c("subject_id", "identifier", "study_id", "auth_user_id", "study_site_id",
    "has_depression_suspicion", "is_interested_in_study", "subject_type",
    "is_active", "in_charge_id", "study_phase", "study_sub_phase",
    "ending_status", "appointment_day", "appointment_time",
    "study_therapist_sub_phase", "is_clinician", "clinical_phase",
    "clinical_record", "insurance_type", "has_research_consent",
    "discharge_state", "discharge_comments", "consent_file", "process_status")
)

# Convert key columns to appropriate types
subjects_raw$subject_id <- as.integer(subjects_raw$subject_id)
subjects_raw$study_site_id <- as.integer(subjects_raw$study_site_id)
subjects_raw$subject_type <- as.integer(subjects_raw$subject_type)

# subject_type: 0 = Patient, 1 = Therapist
subjects_raw$subject_type_label <- ifelse(subjects_raw$subject_type == 0, "Patient", "Therapist")

# Join with site names
subject_site <- merge(
  subjects_raw[, c("subject_id", "subject_type", "subject_type_label", "study_site_id")],
  sites[, c("study_site_id", "site_name")],
  by = "study_site_id",
  all.x = TRUE
)

# Reorder columns
subject_site <- subject_site[, c("subject_id", "subject_type", "subject_type_label",
                                  "study_site_id", "site_name")]
subject_site <- subject_site[order(subject_site$subject_id), ]

cat("\n  Subject distribution by type and site:\n")
print(table(subject_site$subject_type_label, subject_site$site_name, useNA = "ifany"))

write.csv(subject_site, "data/subject_site_map.csv", row.names = FALSE)
cat("\n  Saved: data/subject_site_map.csv\n\n")


# =============================================================================
# 3. THERAPIST-PATIENT MAPPING
# =============================================================================
cat("--- Extracting therapist-patient links ---\n")

tp_links <- extract_copy_block(
  sql_file,
  "public.measurement_researchsubject_patients",
  c("id", "therapist_id", "patient_id")
)

tp_links$therapist_id <- as.integer(tp_links$therapist_id)
tp_links$patient_id <- as.integer(tp_links$patient_id)
tp_links <- tp_links[, c("therapist_id", "patient_id")]

cat("\n  Unique therapists:", length(unique(tp_links$therapist_id)), "\n")
cat("  Unique patients with assigned therapist:", length(unique(tp_links$patient_id)), "\n")

# Flag patients with multiple therapists
therapist_count <- as.data.frame(table(tp_links$patient_id))
names(therapist_count) <- c("patient_id", "n_therapists")
multi_therapist <- therapist_count[therapist_count$n_therapists > 1, ]
if (nrow(multi_therapist) > 0) {
  cat("  Patients with >1 therapist:", nrow(multi_therapist),
      "(IDs:", paste(multi_therapist$patient_id, collapse = ", "), ")\n")
}

write.csv(tp_links, "data/therapist_patient_map.csv", row.names = FALSE)
cat("\n  Saved: data/therapist_patient_map.csv\n\n")


# =============================================================================
# 4. SESSION-LEVEL THERAPIST INFO (from followup/sessions table)
# =============================================================================
cat("--- Extracting session-therapist data ---\n")

sessions <- extract_copy_block(
  sql_file,
  "public.measurement_followup",
  c("session_id", "session_number", "patient_id", "therapist_id",
    "session_modality", "comments", "f_type_id", "attendance_status",
    "attendance_status_reason", "attendance_status_reason_known",
    "post_session_expiration_datetime", "post_session_scheduled_start_datetime",
    "pre_session_expiration_datetime", "pre_session_scheduled_start_datetime",
    "session_modality_known", "created_by_id", "created_datetime",
    "digital_send", "last_edit_by_id", "last_edit_datetime",
    "created_by_clinical_id", "last_edit_by_clinical_id",
    "clinical_commitments", "clinical_quote", "clinical_risk_eval",
    "f_clinical_type", "scheduled_datetime")
)

# Keep relevant columns for the session-therapist lookup
session_therapist <- sessions[, c("session_id", "patient_id", "therapist_id",
                                   "session_number", "session_modality",
                                   "attendance_status")]

session_therapist$session_id <- as.integer(session_therapist$session_id)
session_therapist$patient_id <- as.integer(session_therapist$patient_id)
session_therapist$therapist_id <- as.integer(session_therapist$therapist_id)
session_therapist$session_number <- as.integer(session_therapist$session_number)
session_therapist$session_modality <- as.integer(session_therapist$session_modality)

# Decode modality
session_therapist$modality_label <- factor(
  session_therapist$session_modality,
  levels = c(0, 1, 2),
  labels = c("In Person", "Remote/Videocall", "Other")
)

session_therapist <- session_therapist[order(session_therapist$patient_id,
                                             session_therapist$session_number), ]

cat("\n  Total session records:", nrow(session_therapist), "\n")
cat("  Unique patients with sessions:", length(unique(session_therapist$patient_id)), "\n")
cat("  Unique therapists in sessions:", length(unique(na.omit(session_therapist$therapist_id))), "\n")
cat("\n  Session modality distribution:\n")
print(table(session_therapist$modality_label, useNA = "ifany"))

write.csv(session_therapist, "data/session_therapist_map.csv", row.names = FALSE)
cat("\n  Saved: data/session_therapist_map.csv\n\n")


# =============================================================================
# SUMMARY
# =============================================================================
cat("=== Extraction complete ===\n\n")
cat("Files generated in data/:\n")
cat("  1. study_sites.csv           — Site/clinic lookup (", nrow(sites), " sites)\n")
cat("  2. subject_site_map.csv      — Subject-to-site mapping (", nrow(subject_site), " subjects)\n")
cat("  3. therapist_patient_map.csv — Therapist-patient links (", nrow(tp_links), " dyads)\n")
cat("  4. session_therapist_map.csv — Session-level therapist info (", nrow(session_therapist), " sessions)\n")
cat("\nUsage example:\n")
cat('  site_map <- read.csv("data/subject_site_map.csv")\n')
cat('  wide_data <- read.csv("data/patient_item_matrix_wide_TIMESTAMP.csv")\n')
cat('  wide_data <- merge(wide_data, site_map[site_map$subject_type == 0,\n')
cat('                     c("subject_id", "site_name")], by = "subject_id")\n')
