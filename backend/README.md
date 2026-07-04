# Fitness Tracker Backend

## Setup

1. Create virtual environment:
```bash
python3 -m venv .venv
source venv/bin/activate  # Mac/Linux
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Run the server:
```bash
uvicorn main:app --reload
```

The API will be available at `http://localhost:8000`

## API Documentation

Visit `http://localhost:8000/docs` for interactive API documentation (Swagger UI)

## Database

Using SQLite for simplicity. Database file: `fitness.db` (created automatically)

## API Endpoints

### Profile & Goals
- `POST /api/profile/setup` - Initial profile setup (calculates TDEE and macros)
- `GET /api/profile` - Get profile and goals
- `GET /api/profile/goals` - Get current goals
- `PUT /api/profile/goals` - Update goals

### Body Measurements
- `POST /api/measurements` - Log body measurements
- `GET /api/measurements` - Get measurement history
- `GET /api/measurements/latest` - Get latest measurement
- `GET /api/measurements/stats` - Get weight statistics

### Meals & Nutrition
- `GET /api/meals/search-food?query=chicken` - Search foods (OpenFoodFacts + local DB)
- `POST /api/meals/foods` - Add food to database
- `POST /api/meals` - Create meal with items
- `POST /api/meals/quick-add` - Quick add meal (manual entry)
- `GET /api/meals/today` - Get today's meals with totals
- `DELETE /api/meals/{meal_id}` - Delete meal

### Water Tracking
- `POST /api/water` - Log water intake
- `GET /api/water/today` - Get today's water total
- `GET /api/water/history?days=7` - Get water history

### Workouts
- `POST /api/workouts` - Log workout
- `GET /api/workouts` - Get workout history
- `GET /api/workouts/today` - Get today's workouts
- `GET /api/workouts/stats` - Get workout statistics

### Dashboard
- `GET /api/dashboard/today` - Complete overview (nutrition, water, workouts, weight)

## Next Steps

1. Test all endpoints using Swagger UI at `/docs`
2. Build frontend (Next.js/React)
3. Add more features (streaks, reminders, charts)
