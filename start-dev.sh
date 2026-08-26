#!/bin/bash
# Quick Start Script for Backhaul Logistics Development

set -e

echo "🚀 Backhaul Logistics - Quick Start"
echo "===================================="
echo ""

# Check Docker
echo "📦 Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker Desktop:"
    echo "   https://www.docker.com/products/docker-desktop/"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

echo "✅ Docker is running"
echo ""

# Start database services
echo "🗄️  Starting PostgreSQL + Redis..."
cd docker
if [ ! -f .env ]; then
    echo "⚠️  docker/.env not found, copying from example..."
    cp .env.example .env
    echo "⚠️  Please edit docker/.env and set POSTGRES_PASSWORD"
    exit 1
fi

docker compose up -d

echo "✅ Database services started"
echo ""

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 5

until docker exec backhaul-postgres pg_isready -U backhaul -d backhaul &> /dev/null; do
    echo "   Still waiting..."
    sleep 2
done

echo "✅ PostgreSQL is ready"
echo ""

# Check backend
cd ../backend
echo "🔧 Checking backend..."

if [ ! -d node_modules ]; then
    echo "📦 Installing backend dependencies..."
    npm install --legacy-peer-deps
fi

echo "🏗️  Building backend..."
npm run build

echo "🚀 Starting backend in development mode..."
npm run start:dev &
BACKEND_PID=$!

echo "✅ Backend started (PID: $BACKEND_PID)"
echo ""

# Check mobile
cd ../mobile
echo "📱 Checking Flutter..."

if ! command -v flutter &> /dev/null; then
    echo "⚠️  Flutter not found. Please install Flutter SDK:"
    echo "   https://docs.flutter.dev/get-started/install"
else
    echo "✅ Flutter is ready"
    echo ""
    echo "📱 To run the mobile app:"
    echo "   cd mobile"
    echo "   flutter run"
fi

echo ""
echo "✅ Development environment is ready!"
echo ""
echo "🌐 Services:"
echo "   - Backend API:        http://localhost:3000"
echo "   - API Documentation:  http://localhost:3000/api"
echo "   - Health Check:       http://localhost:3000/health"
echo "   - PostgreSQL:         localhost:5432"
echo "   - Redis:              localhost:6379"
echo ""
echo "📝 Useful commands:"
echo "   - Stop backend:       kill $BACKEND_PID"
echo "   - Stop database:      cd docker && docker compose down"
echo "   - View logs:          docker logs backhaul-postgres"
echo "   - Database shell:     docker exec -it backhaul-postgres psql -U backhaul -d backhaul"
echo ""
