"""Serving size unit conversion utilities."""

WEIGHT_UNITS = {
    "g": 1.0, "gram": 1.0, "grams": 1.0,
    "oz": 28.3495, "ounce": 28.3495, "ounces": 28.3495,
    "lb": 453.592, "lbs": 453.592, "pound": 453.592, "pounds": 453.592,
    "kg": 1000.0, "kilogram": 1000.0, "kilograms": 1000.0,
    "mg": 0.001,
}

VOLUME_UNITS = {
    "ml": 1.0, "milliliter": 1.0, "milliliters": 1.0,
    "l": 1000.0, "liter": 1000.0, "liters": 1000.0,
    "cup": 236.588, "cups": 236.588,
    "tbsp": 14.787, "tablespoon": 14.787, "tablespoons": 14.787,
    "tsp": 4.929, "teaspoon": 4.929, "teaspoons": 4.929,
    "fl oz": 29.5735, "fluid ounce": 29.5735, "fluid ounces": 29.5735,
}

COUNT_UNITS = [
    "piece", "pieces", "slice", "slices", "serving", "servings",
    "egg", "eggs", "strip", "strips", "patty", "patties",
    "bar", "bars", "scoop", "scoops", "packet", "packets",
    "container", "can", "bottle", "whole", "each",
]

FOOD_PRESETS = {
    "egg_large": {"weight_g": 50, "description": "1 large egg"},
    "bread_slice": {"weight_g": 28, "description": "1 slice bread"},
    "banana_medium": {"weight_g": 118, "description": "1 medium banana"},
    "apple_medium": {"weight_g": 182, "description": "1 medium apple"},
    "chicken_breast": {"weight_g": 174, "description": "1 chicken breast (6 oz)"},
    "rice_cup_cooked": {"weight_g": 186, "description": "1 cup cooked rice"},
}


def normalize_serving(size: float, unit: str) -> dict:
    """Normalize a serving to a standard unit for comparison."""
    unit_lower = (unit or "g").strip().lower()

    if unit_lower in WEIGHT_UNITS:
        return {
            "type": "weight",
            "normalized_grams": size * WEIGHT_UNITS[unit_lower],
            "original_size": size,
            "original_unit": unit,
        }
    if unit_lower in VOLUME_UNITS:
        return {
            "type": "volume",
            "normalized_ml": size * VOLUME_UNITS[unit_lower],
            "original_size": size,
            "original_unit": unit,
        }
    return {
        "type": "count",
        "count": size,
        "original_size": size,
        "original_unit": unit,
    }


def calculate_macro_for_servings(
    calories: float,
    protein_g: float,
    carbs_g: float,
    fats_g: float,
    base_serving_size: float,
    base_serving_unit: str,
    multiplier: float,
) -> dict:
    """Scale macros by a multiplier."""
    return {
        "calories": round(calories * multiplier, 1),
        "protein_g": round(protein_g * multiplier, 1),
        "carbs_g": round(carbs_g * multiplier, 1),
        "fats_g": round(fats_g * multiplier, 1),
    }
