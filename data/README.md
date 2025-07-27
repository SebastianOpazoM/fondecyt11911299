# Data Extraction for FONDECYT Project

This folder contains all data extraction scripts and raw data files for the FONDECYT research project.

## 📁 **Folder Contents:**

### **Scripts:**
- `extract_local_data.R` - Main data extraction script (parses SQL dumps directly)
- `run_extraction.R` - Automated runner script (legacy, uses PostgreSQL)
- `setup_local_db.sh` - Optional PostgreSQL setup (not required for main workflow)

### **Data Files:**
- `dump-fondecyt-202507271125.sql` - Original PostgreSQL database dump (197MB)
- `item_responses.csv` - Extracted item responses data (198MB, 621,392 rows)

## 🚀 **Quick Start:**

### **Option 1: Use existing extracted data**
```r
# Load the pre-extracted data
library(readr)
data <- read_csv("data/item_responses.csv")
```

### **Option 2: Re-extract data from database**
```bash
# Set up local database (one-time setup)
cd data
./setup_local_db.sh

# Extract data
Rscript run_extraction.R
```

### **Extract Data Using R**
```r
# From the data folder
source("extract_local_data.R")

# Auto-extract from latest dump
data <- extract_item_responses_from_dump()

# Or run complete workflow with file discovery
main()
```

## 📊 **Data Structure:**

The `item_responses.csv` file contains:
- **621,392 rows** - one per item response
- **12 columns** - response data, IDs, timestamps
- **Response types** - numeric and character responses
- **Date range** - 2020-2025 research data

### **Key Columns:**
- `response_id` - Unique response identifier
- `item_id` - Question/item identifier  
- `administration_id` - Assessment session identifier
- `response_value` - Unified response value
- `response_type` - Type of response (numeric/character)
- `response_date` - When response was created

## 🔗 **Related Tables Available:**

The PostgreSQL database contains 61 tables including:
- `measurement_item` - Question/item details
- `measurement_measure` - Assessment instruments
- `measurement_measureadministration` - Assessment sessions
- `measurement_researchstudy` - Research studies
- `measurement_researchsubject` - Study participants

## � **For Complex Queries (Optional):**

If you need to run complex SQL queries across multiple tables, you can still set up PostgreSQL:

```bash
# Set up local database (optional)
./setup_local_db.sh

# Then use psql for complex queries
psql fondecyt -c "SELECT * FROM measurement_itemresponse LIMIT 5;"
```

To extend the current dataset with related information, you would need to modify the parsing logic in `extract_local_data.R` or use the PostgreSQL approach for complex joins.

## ⚠️ **Important Notes:**

- Large files (`.csv`, `.sql`) are gitignored by default
- Keep the SQL dump for reproducibility
- The local PostgreSQL database is named `fondecyt`
- All timestamps are in UTC

## 🔍 **Database Schema:**

To explore the database structure:
```bash
psql fondecyt -c "\dt"  # List all tables
psql fondecyt -c "\d measurement_itemresponse"  # Table structure
```
