#!/bin/bash

# FONDECYT Local Database Setup (OPTIONAL)
# This script sets up a local PostgreSQL database from your SQL dump
# NOTE: This is not required for the main extraction workflow!
# The project now uses direct SQL dump parsing via extract_local_data.R

echo "🐘 FONDECYT Local Database Setup (OPTIONAL)"
echo "==========================================="
echo "⚠️  This setup is NOT REQUIRED for the main workflow!"
echo "The project now uses direct dump parsing (extract_local_data.R)"
echo ""
echo "Continue only if you need PostgreSQL for complex queries."
echo "Press Ctrl+C to cancel, or Enter to continue..."
read -r

echo ""

# Check if PostgreSQL is installed
if ! command -v psql &> /dev/null; then
    echo "❌ PostgreSQL not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Installing PostgreSQL via Homebrew..."
        brew install postgresql
        brew services start postgresql
    else
        echo "Please install PostgreSQL manually for your system"
        exit 1
    fi
else
    echo "✅ PostgreSQL found"
fi

# Check if PostgreSQL service is running
if ! brew services list | grep postgresql | grep started &> /dev/null; then
    echo "Starting PostgreSQL service..."
    brew services start postgresql
fi

echo ""
echo "🗃️  Setting up database..."

# Create database
echo "Creating database 'fondecyt_local'..."
createdb fondecyt_local 2>/dev/null || echo "Database may already exist"

# Import the SQL dump
echo "Importing SQL dump (this may take several minutes)..."
echo "File size: $(ls -lh dump-fondecyt-202507271125.sql | awk '{print $5}')"

# Import with progress indication
psql fondecyt_local < dump-fondecyt-202507271125.sql

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Database setup complete!"
    echo ""
    echo "📊 Database info:"
    psql fondecyt_local -c "\dt" | head -20
    echo ""
    echo "🔍 Item responses table:"
    psql fondecyt_local -c "\d measurement_itemresponse"
    echo ""
    echo "📈 Sample data count:"
    psql fondecyt_local -c "SELECT COUNT(*) as total_item_responses FROM measurement_itemresponse;"
    echo ""
    echo "🚀 Database is ready for complex SQL queries:"
    echo "   psql fondecyt_local"
    echo ""
    echo "💡 For simple extraction, use extract_local_data.R instead!"
    echo "   (No database setup required)"
    echo "   password = ''  # Usually empty for local setup"
else
    echo "❌ Database import failed"
    exit 1
fi
