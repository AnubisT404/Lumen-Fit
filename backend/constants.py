"""Application-wide constants. Avoids magic numbers scattered across modules."""

# AI Coach
AI_MAX_TOKENS = 2048
AI_TEMPERATURE = 0.7
AI_CHAT_HISTORY_LIMIT = 10

# Water tracking
WATER_GLASS_ML = 250
WATER_DEFAULT_GOAL_ML = 2000

# Nutrition
DEFAULT_CALORIE_GOAL = 2000
DEFAULT_PROTEIN_G = 150
DEFAULT_CARBS_G = 250
DEFAULT_FATS_G = 65

# Search
FOOD_SEARCH_LIMIT = 25
MFP_SEARCH_LIMIT = 25
RECENT_FOODS_LIMIT = 15
FREQUENT_FOODS_LIMIT = 10

# Trends
TREND_DAYS = 7
WEIGHT_TREND_THRESHOLD_KG = 0.5

# File uploads
MAX_UPLOAD_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB
ALLOWED_UPLOAD_EXTENSIONS = {".pdf", ".txt", ".md", ".csv", ".json", ".docx"}

# Cache TTLs (seconds)
SETTINGS_CACHE_TTL = 300  # 5 minutes
