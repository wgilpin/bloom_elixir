#!/bin/bash

# Project Bloom startup script
# Starts PostgreSQL database and Phoenix server

set -e  # Exit on any error

echo "🌱 Starting Project Bloom..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if PostgreSQL container already exists
if docker ps -a --format 'table {{.Names}}' | grep -q "postgres-tutor"; then
    echo "📦 PostgreSQL container exists"
    
    # Start if stopped
    if ! docker ps --format 'table {{.Names}}' | grep -q "postgres-tutor"; then
        echo "🚀 Starting existing PostgreSQL container..."
        docker start postgres-tutor
    else
        echo "✅ PostgreSQL container already running"
    fi
else
    echo "📦 Creating and starting PostgreSQL container..."
    docker run --name postgres-tutor -e POSTGRES_PASSWORD=postgres -d -p 5432:5432 postgres
fi

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 5

# Check if we can connect to PostgreSQL
until docker exec postgres-tutor pg_isready -U postgres > /dev/null 2>&1; do
    echo "⏳ PostgreSQL is not ready yet, waiting..."
    sleep 2
done

echo "✅ PostgreSQL is ready!"

# Change to tutor directory
cd tutor

# Check if dependencies are installed
if [ ! -d "deps" ] || [ ! -d "assets/node_modules" ]; then
    echo "📥 Installing dependencies and setting up database..."
    mix setup
else
    echo "✅ Dependencies already installed"
    
    # Just run migrations in case there are new ones
    echo "🗄️  Running database migrations..."
    mix ecto.migrate
fi

# Start Phoenix server
echo "🚀 Starting Phoenix server on http://localhost:4000"
echo "Press Ctrl+C to stop the server"
echo ""

mix phx.server