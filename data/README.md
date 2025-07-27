# Data Extraction for FONDECYT Project

This folder contains all data extraction scripts and raw data files for the FONDECYT research project.

## 📁 **Folder Contents:**

### **Scripts:**
- `extract_data.R` - Main data extraction script (connects to PostgreSQL)
- `extract_local_data.R` - Alternative extraction methods (direct from dump)
- `run_extraction.R` - Automated runner script
- `setup_local_db.sh` - Sets up local PostgreSQL database from dump

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

### **Option 3: Extract from R**
```r
# From the data folder
source("extract_data.R")
data <- extract_item_responses("new_responses.csv")
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

## 💡 **Adding Related Data:**

To extend the current dataset with related information, modify the query in `extract_data.R`:

```sql
-- Example: Add item text and measure names
SELECT 
  ir.*,
  i.text as item_text,
  m.name as measure_name
FROM measurement_itemresponse ir
LEFT JOIN measurement_item i ON ir.item_id = i.id
LEFT JOIN measurement_measureadministration ma ON ir.administration_id = ma.id
LEFT JOIN measurement_measure m ON ma.measure_id = m.id
```

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
