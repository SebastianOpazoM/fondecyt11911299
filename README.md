# FONDECYT Research Project 11911299

This repository contains data analysis scripts and extracted data for the FONDECYT research project.

## 📁 **Project Structure:**

```
fondecyt11911299/
├── data/                          # Data extraction and raw data
│   ├── extract_local_data.R      # Main extraction script (SQL dump parsing)
│   ├── setup_local_db.sh         # Optional PostgreSQL setup (not required)
│   ├── item_responses.csv        # Extracted responses (621K rows)
│   ├── dump-fondecyt-*.sql       # Original database dump
│   └── README.md                 # Data documentation
├── analyze_data.Rmd              # Main analysis notebook (R Markdown)
├── analyze_data_backup.R         # Legacy R script (backup)
├── .gitignore                    # Git ignore rules
└── README.md                     # This file
```

## 🚀 **Quick Start:**

### **1. Analysis with R Markdown (Recommended):**
```r
# Open the analysis notebook in RStudio or VS Code
# File: analyze_data.Rmd
# Click "Knit" to generate HTML report with visualizations
```

### **2. Quick Data Loading:**
```r
# Load the extracted data
library(readr)
data <- read_csv("data/item_responses.csv")

# Basic exploration
str(data)
summary(data)
```

### **3. Re-extract Data (if needed):**
```r
# Extract from SQL dump (no database setup required)
source("data/extract_local_data.R")
main()
```

## 📊 **Data Overview:**

- **621,392 item responses** from research assessments
- **Date range:** 2020-2025
- **Response types:** Numeric and character responses
- **Source:** PostgreSQL database dump (197MB)

## 🔧 **Dependencies:**

### **R Packages:**
```r
install.packages(c("DBI", "RPostgreSQL", "dplyr", "readr", 
                   "ggplot2", "lubridate"))
```

### **System Requirements:**
- R (>= 4.0)
- PostgreSQL (for data extraction)
- 200MB+ disk space

## 📈 **Analysis Features:**

- Response completion rates
- Timeline analysis
- Data quality assessment
- Visualization generation
- Export capabilities

## 🗄️ **Database Schema:**

The original database contains 61 tables including:
- Research studies and subjects
- Measurement instruments and items
- Response data and administrations
- Expense tracking
- User management

## 📝 **Getting Started:**

1. **Clone the repository**
2. **Install R dependencies**
3. **Load data:** `read_csv("data/item_responses.csv")`
4. **Start analyzing!**

For detailed data extraction documentation, see `data/README.md`.

---

*FONDECYT Project #11911299 - Chilean National Fund for Scientific and Technological Development*
Data analysis repo for the study 
