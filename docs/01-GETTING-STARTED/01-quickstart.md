# Interspace Quick Start Guide

## 1. Start Full Backend Stack (Database + API)
```bash
cd ~/Documents/GitHub/interspace-backend

# First, ensure package-lock.json is up to date
npm install

# Then start the full stack with Docker Compose
docker-compose --profile local up --build
```

## 2. Alternative: Run Backend Locally (if Docker build fails)
```bash
# Start just the database
docker run -d \
  --name interspace-postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=interspace \
  -p 5432:5432 \
  postgres:15

# Run backend locally
cd ~/Documents/GitHub/interspace-backend
npm install
npx prisma generate
npx prisma migrate dev
npm run dev
```

## 3. Start iOS App
```bash
cd ~/Documents/GitHub/interspace-ios
pod install
open Interspace.xcworkspace
```
Then press `Cmd + R` in Xcode

## Common Commands

### Reset Database
```bash
cd ~/Documents/GitHub/interspace-backend
npx prisma migrate reset --force
```

### View Logs
```bash
# Backend logs
cd ~/Documents/GitHub/interspace-backend
tail -f logs/backend.log

# Database logs
docker logs interspace-postgres -f
```

### Stop Everything
```bash
cd ~/Documents/GitHub/interspace-backend
# Stop database
docker stop interspace-postgres
docker rm interspace-postgres

# Press Ctrl+C in backend terminal
# Press Stop in Xcode
```

## Environment Check
- Backend: http://localhost:3000
- Database: postgresql://localhost:5432/interspace
- iOS: Run on iPhone 15 Pro simulator

## Testing Email Authentication
```bash
# 1. Request verification code
curl -X POST http://localhost:3000/api/v1/auth/email/request-code \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'

# 2. Get verification code from logs (codes are now hashed in database)
docker logs interspace-backend --tail 50 | grep -E "DEV MODE.*Code:"

# The verification code will be shown in logs like:
# [INFO] 📧 [DEV MODE] Email: test@example.com
# [INFO] 📧 [DEV MODE] Code: 123456

# Note: Codes are now stored as bcrypt hashes in the database for security

# 3. Verify code (this creates/updates the user)
curl -X POST http://localhost:3000/api/v1/auth/email/verify-code \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "code": "CODE_FROM_ABOVE"}'

# 4. Authenticate after verification (just pass email, no code needed)
curl -X POST http://localhost:3000/api/v1/auth/authenticate \
  -H "Content-Type: application/json" \
  -d '{"authToken": "test@example.com", "authStrategy": "email", "email": "test@example.com"}'
```

## Troubleshooting
- Clean Xcode: `Cmd + Shift + K`
- Reset Simulator: Device → Erase All Content and Settings
- Rebuild Backend: `rm -rf node_modules && npm install`