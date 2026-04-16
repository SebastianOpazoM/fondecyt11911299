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
#   1. study_sites.csv             — study_site_id, site_name, site_name_unified,
#                                     study_id
#   2. subject_site_map.csv        — subject_id, subject_type, study_site_id,
#                                     site_name, site_name_unified
#   3. therapist_patient_map.csv   — therapist_id, patient_id, source,
#                                     n_sessions, is_only_therapist
#                                     (long format: one row per dyad, patients
#                                      with multiple therapists appear multiple times)
#   4. session_therapist_map.csv   — session_id, patient_id, therapist_id,
#                                     session_number, session_modality,
#                                     modality_label, attendance_status
#
# Changes in this version (2026-04-16):
#   - Added site_name_unified to collapse Psicomédica Research Group and
#     Psicomédica Online into "Psicomédica" (they are the same organization;
#     modality is tracked at the session level)
#   - Therapist-patient mapping now combines BOTH sources:
#       (a) explicit links in measurement_researchsubject_patients
#       (b) session-level therapist_id in measurement_followup
#     Output is in long format (one row per dyad) so patients with multiple
#     therapists appear multiple times — the 'source' column indicates
#     whether the dyad comes from explicit links, sessions, or both.
#
# Usage:
#   source("shared_extract_metadata.R")
#   Or run from terminal: Rscript shared_extract_metadata.R
#
# Requirements: Base R only (no additional packages needed)
# =============================================================================

cat("=== NODAL: Extracting metadata from SQL backup ===\n\n")

# --- Configuration -----------------------------------------------------------

sql_files <- list.files("data", pattern = "^\\d{4}_\\d{2}_\\d{2}_dB_backup\\.sql$|^mindkey_backup.*\\.sql$",
                        full.names = TRUE)

if (length(sql_files) == 0) {
  sql_files <- list.files("data", pattern = "\\.sql$", full.names = TRUE)
}

if (length(sql_files) == 0) {
  stop("No SQL backup file found in data/ folder.\n",
       "  Please place the backup file (e.g., mindkey_backup_YYYYMMDD.sql) in the data/ directory.")
}

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
  
  copy_pattern <- paste0("COPY ", table_name, " ")
  
  found <- FALSE
  rows <- list()
  
  while (TRUE) {
    line <- readLines(con, n = 1, warn = FALSE)
    if (length(line) == 0) break
    
    if (!found && grepl(copy_pattern, line, fixed = TRUE)) {
      found <- TRUE
      next
    }
    
    if (found) {
      if (trimws(line) == "\\.") break
      
      fields <- strsplit(line, "\t", fixed = TRUE)[[1]]
      fields[fields == "\\N"] <- NA
      rows[[length(rows) + 1]] <- fields
    }
  }
  
  if (!found) {
    warning("Table '", table_name, "' not found in SQL file.")
    return(data.frame(matrix(ncol = length(col_names), nrow = 0,
                             dimnames = list(NULL, col_names))))
  }
  
  df <- do.call(rbind, lapply(rows, function(r) {
    length(r) <- length(col_names)
    r
  }))
  
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  names(df) <- col_names
  
  cat("  Extracted", nrow(df), "rows from", table_name, "\n")
  return(df)
}


# =============================================================================
# 1. STUDY SITES (with unified Psicomédica)
# =============================================================================
cat("--- Extracting study sites ---\n")

sites <- extract_copy_block(
  sql_file,
  "public.measurement_researchstudysite",
  c("study_site_id", "site_name", "description", "study_id")
)

sites$study_site_id <- as.integer(sites$study_site_id)
sites$study_id <- as.integer(sites$study_id)

# Add unified site name: collapse Psicomédica Research Group + Psicomédica Online
# into "Psicomédica" (same organization; modality is tracked at session level)
sites$site_name_unified <- ifelse(
  sites$site_name %in% c("Psicomédica Research Group", "Psicomédica Online"),
  "Psicomédica",
  sites$site_name
)

sites <- sites[, c("study_site_id", "site_name", "site_name_unified", "study_id")]

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

subjects_raw$subject_id <- as.integer(subjects_raw$subject_id)
subjects_raw$study_site_id <- as.integer(subjects_raw$study_site_id)
subjects_raw$subject_type <- as.integer(subjects_raw$subject_type)

# subject_type: 0 = Patient, 1 = Therapist
subjects_raw$subject_type_label <- ifelse(subjects_raw$subject_type == 0, "Patient", "Therapist")

subject_site <- merge(
  subjects_raw[, c("subject_id", "subject_type", "subject_type_label", "study_site_id")],
  sites[, c("study_site_id", "site_name", "site_name_unified")],
  by = "study_site_id",
  all.x = TRUE
)

subject_site <- subject_site[, c("subject_id", "subject_type", "subject_type_label",
                                  "study_site_id", "site_name", "site_name_unified")]
subject_site <- subject_site[order(subject_site$subject_id), ]

cat("\n  Subject distribution by unified site:\n")
print(table(subject_site$subject_type_label, subject_site$site_name_unified, useNA = "ifany"))

write.csv(subject_site, "data/subject_site_map.csv", row.names = FALSE)
cat("\n  Saved: data/subject_site_map.csv\n\n")


# =============================================================================
# 3. SESSION-LEVEL THERAPIST INFO (needed before dyad table)
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

session_therapist <- sessions[, c("session_id", "patient_id", "therapist_id",
                                   "session_number", "session_modality",
                                   "attendance_status")]

session_therapist$session_id <- as.integer(session_therapist$session_id)
session_therapist$patient_id <- as.integer(session_therapist$patient_id)
session_therapist$therapist_id <- as.integer(session_therapist$therapist_id)
session_therapist$session_number <- as.integer(session_therapist$session_number)
session_therapist$session_modality <- as.integer(session_therapist$session_modality)

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
# 4. THERAPIST-PATIENT MAPPING (long format, combines both sources)
# =============================================================================
cat("--- Extracting therapist-patient dyads (combined sources) ---\n")

# Source A: explicit links from measurement_researchsubject_patients
explicit_links <- extract_copy_block(
  sql_file,
  "public.measurement_researchsubject_patients",
  c("id", "therapist_id", "patient_id")
)
explicit_links$therapist_id <- as.integer(explicit_links$therapist_id)
explicit_links$patient_id <- as.integer(explicit_links$patient_id)
explicit_dyads <- unique(explicit_links[, c("therapist_id", "patient_id")])

# Source B: session-level dyads (count sessions per dyad)
session_dyads <- session_therapist[!is.na(session_therapist$therapist_id),
                                    c("therapist_id", "patient_id")]
# Aggregate: count sessions per therapist-patient dyad
session_dyad_counts <- aggregate(
  rep(1, nrow(session_dyads)),
  by = list(therapist_id = session_dyads$therapist_id,
            patient_id = session_dyads$patient_id),
  FUN = sum
)
names(session_dyad_counts)[3] <- "n_sessions"

# Combine sources: full outer join
all_dyads <- merge(
  explicit_dyads,
  session_dyad_counts,
  by = c("therapist_id", "patient_id"),
  all = TRUE
)

# Source indicator: where does this dyad come from?
all_dyads$in_explicit <- !is.na(match(
  paste(all_dyads$therapist_id, all_dyads$patient_id),
  paste(explicit_dyads$therapist_id, explicit_dyads$patient_id)
))
all_dyads$in_sessions <- !is.na(all_dyads$n_sessions)
all_dyads$n_sessions[is.na(all_dyads$n_sessions)] <- 0

all_dyads$source <- with(all_dyads, ifelse(
  in_explicit & in_sessions, "both",
  ifelse(in_explicit, "explicit_only", "sessions_only")
))

# Flag: is this the only therapist for this patient?
therapist_count_per_patient <- aggregate(
  all_dyads$therapist_id,
  by = list(patient_id = all_dyads$patient_id),
  FUN = function(x) length(unique(x))
)
names(therapist_count_per_patient)[2] <- "n_therapists"

all_dyads <- merge(all_dyads, therapist_count_per_patient, by = "patient_id", all.x = TRUE)
all_dyads$is_only_therapist <- all_dyads$n_therapists == 1

# Final ordering and columns
therapist_patient_map <- all_dyads[, c("therapist_id", "patient_id", "source",
                                        "n_sessions", "is_only_therapist",
                                        "n_therapists")]
therapist_patient_map <- therapist_patient_map[order(therapist_patient_map$patient_id,
                                                      -therapist_patient_map$n_sessions), ]

cat("\n  Total therapist-patient dyads:", nrow(therapist_patient_map), "\n")
cat("  Unique therapists:", length(unique(therapist_patient_map$therapist_id)), "\n")
cat("  Unique patients with at least one therapist:",
    length(unique(therapist_patient_map$patient_id)), "\n")
cat("\n  Dyad source distribution:\n")
print(table(therapist_patient_map$source))

# Patients with multiple therapists
multi <- therapist_patient_map[therapist_patient_map$n_therapists > 1, ]
n_multi_patients <- length(unique(multi$patient_id))
if (n_multi_patients > 0) {
  cat("\n  Patients with multiple therapists:", n_multi_patients, "\n")
  cat("  IDs:", paste(unique(multi$patient_id), collapse = ", "), "\n")
}

write.csv(therapist_patient_map, "data/therapist_patient_map.csv", row.names = FALSE)
cat("\n  Saved: data/therapist_patient_map.csv\n\n")


# =============================================================================
# SUMMARY
# =============================================================================
cat("=== Extraction complete ===\n\n")
cat("Files generated in data/:\n")
cat("  1. study_sites.csv           — Site/clinic lookup (", nrow(sites), " sites)\n")
cat("  2. subject_site_map.csv      — Subject-to-site mapping (", nrow(subject_site), " subjects)\n")
cat("  3. session_therapist_map.csv — Session-level therapist info (", nrow(session_therapist), " sessions)\n")
cat("  4. therapist_patient_map.csv — Therapist-patient dyads (", nrow(therapist_patient_map), " dyads)\n")

cat("\nNote on therapist_patient_map.csv:\n")
cat("  - Long format: patients with multiple therapists appear in multiple rows\n")
cat("  - 'source' indicates origin: explicit_only, sessions_only, or both\n")
cat("  - 'n_sessions' is the count of sessions for that dyad (0 if only explicit)\n")
cat("  - 'is_only_therapist' is TRUE when the patient has just one therapist\n")
cat("  - 'n_therapists' is the total number of therapists for that patient\n")

cat("\nUsage example (patients with single therapist):\n")
cat('  map <- read.csv("data/therapist_patient_map.csv")\n')
cat('  single_tp <- map[map$is_only_therapist, c("patient_id", "therapist_id")]\n')

cat("\nUsage example (with unified site name):\n")
cat('  sites <- read.csv("data/subject_site_map.csv")\n')
cat('  sites <- sites[sites$subject_type == 0, c("subject_id", "site_name_unified")]\n')
cat('  wide <- merge(wide, sites, by = "subject_id")\n')
