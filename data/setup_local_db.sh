#!/bin/bash

# FONDECYT Local Database Setup
# This script sets up a local PostgreSQL database from your SQL dump

echo "🐘 FONDECYT Local Database Setup"
echo "================================"
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
    echo "🚀 Now you can use extract_data.R with these local credentials:"
    echo "   host = 'localhost'"
    echo "   dbname = 'fondecyt_local'"
    echo "   user = '$(whoami)'"
    echo "   password = ''  # Usually empty for local setup"
else
    echo "❌ Database import failed"
    exit 1
fi
