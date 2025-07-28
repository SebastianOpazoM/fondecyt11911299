# NODAL data base

This repository contains data analysis scripts and extracted data for NODAL research projects.

Here is the full version of the **NODAL Data Use Agreement** formatted for direct use in **RMarkdown**. You can paste this into an `.Rmd` file without issues. I’ve used Markdown headers and indentation for clarity and compatibility:

# 🔒 Terms of Use and Research Agreement 

**Please read carefully before accessing or using any NODAL data.**

The NODAL database contains data from multiple research projects led by Paula Errázuriz, with funding provided by institutions such as ANID, MIDAP, and the mental health NGO PsiConecta. Numerous team members have contributed to the design, funding, collection, and preparation of these data under the supervision of Paula Errázuriz and Sebastián Opazo.

All data collection procedures have been approved by the Ethics Review Board of the Pontificia Universidad Católica de Chile, and participants provided informed consent. Because of this, strict ethical, legal, and academic standards must be upheld by anyone using these data.

By requesting or using data from NODAL, you agree to the following terms:

---

## 1. Prior Approval Required

Before accessing or analyzing any portion of the NODAL data, you must obtain written authorization from Paula Errázuriz. Please provide a brief outline of your research project, including:

- Research questions or hypotheses  
- Variables you intend to use  
- Planned outputs (e.g., thesis, article, conference presentation)

📧 Send your request to: paulae@uc.cl

---

## 2. Authorship and Acknowledgment

Any publication, thesis, conference presentation, report, or other product that uses NODAL data must include Paula Errázuriz as a co-author.

In some cases, other team members (e.g., Sebastián Opazo or other collaborators) may also need to be included as co-authors, depending on their contribution to the data. You must discuss and confirm authorship expectations with Paula before submitting or disseminating any work.

---

## 3. Acknowledgment of Funding Sources

All dissemination products must include proper acknowledgment of the institutions that supported the NODAL database, including:

- ANID  
- MIDAP  
- PsiConecta  
- Any other funding source relevant to the specific dataset used

The exact wording should be approved by Paula Errázuriz.

---

## 4. Special Conditions for Students and Assistants

If you are a student or research assistant working under the supervision of Errázuriz, you may be subject to additional guidelines regarding data use, authorship, or supervision. You must consult with her before using any NODAL data.

---

## 5. Confidentiality and Data Protection

All users must strictly adhere to ethical guidelines regarding participant confidentiality. No identifiable information may be disclosed under any circumstances. You are responsible for ensuring the secure storage and handling of the data at all times.

---

## 6. No Redistribution Without Permission

You may not share, copy, or distribute the dataset(s) or any portion thereof to third parties without explicit, written permission from Paula Errázuriz.

---

## 7. Reporting and Communication

You are expected to inform Paula Errázuriz of any publication, presentation, or project completion that uses NODAL data and to send her a copy of the final product. 

---

If you have any questions about these terms or your intended use, please contact paulae@uc.cl.


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
