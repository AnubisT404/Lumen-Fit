from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from database import get_db
from models import Meal, MealItem, FoodItem, Goals, MealTemplate, MealTemplateItem
from datetime import date, datetime
from pydantic import BaseModel, Field
from typing import Optional, List
from enum import Enum
import httpx
import ssl
import sqlite3
import os
import asyncio
import logging

logger = logging.getLogger(__name__)


def _convert_mfp_portions(portions: list, serving_grams: float) -> tuple:
    """Convert MFP portion gram_weights from multipliers (100 = 1 serving) to actual grams.
    
    MFP stores portion weights as multipliers where 100 = the food's base serving.
    We auto-correct serving_grams using any "N g"/"N gram" portion as reference:
    if portion says "1 g" with multiplier 7.14, then 1 serving = 100/7.14 ≈ 14g.
    
    Returns (converted_portions, corrected_serving_grams).
    """
    import re
    if not portions:
        return portions, serving_grams

    # Try to auto-correct serving_grams using a "N g" / "N gram(s)" portion
    corrected_sg = serving_grams
    for p in portions:
        m = re.match(r'^(\d+\.?\d*)\s*(g|gram|grams?)\s*$', p['description'], re.IGNORECASE)
        if m and p['gram_weight'] > 0:
            declared_g = float(m.group(1))
            candidate = declared_g * 100.0 / p['gram_weight']
            # Sanity check: corrected value must be a reasonable serving size
            if 2.0 <= candidate <= 2000.0:
                corrected_sg = candidate
            break

    # Max reasonable gram weights for common unit keywords
    _UNIT_MAX = {
        'tsp': 20, 'teaspoon': 20, 'tbsp': 50, 'tablespoon': 50,
        'pat': 20, 'slice': 200, 'piece': 500, 'stick': 250,
        'cup': 500, 'ml': 5, 'milliliter': 5, 'fl oz': 60,
        'fluid ounce': 60, 'oz': 200, 'ounce': 200,
    }

    # Convert all portions
    converted = []
    seen = set()
    for p in portions:
        actual_grams = round(p['gram_weight'] * corrected_sg / 100.0, 1)
        if actual_grams <= 0:
            continue
        desc = p['description']
        dl = desc.lower().strip()
        # Skip portions with unreasonable gram weights for their unit type
        skip = False
        for unit_key, max_g in _UNIT_MAX.items():
            if unit_key in dl and actual_grams > max_g * 10:
                skip = True
                break
        if skip:
            continue
        # Deduplicate by (description, rounded weight)
        key = (dl, round(actual_grams))
        if key in seen:
            continue
        seen.add(key)
        converted.append({
            "description": desc,
            "gram_weight": actual_grams,
            "amount": p.get('amount', 1.0),
        })
    return converted, round(corrected_sg, 1)

# Use OS-native cert store (fixes macOS Python SSL issues)
try:
    import truststore
    truststore.inject_into_ssl()
    _ssl_ctx = True  # use default (now backed by OS certs)
except ImportError:
    import certifi
    _ssl_ctx = ssl.create_default_context(cafile=certifi.where())

# Local USDA food database path
FOOD_DB_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'food_database.db')
_food_db_available = os.path.exists(FOOD_DB_PATH)
if _food_db_available:
    logger.info(f"Local food database found: {FOOD_DB_PATH}")
else:
    logger.warning(f"Local food database not found at {FOOD_DB_PATH} — will use API only")

from contextlib import contextmanager

@contextmanager
def _get_food_db(readonly: bool = True):
    """Reusable context manager for food_database.db connections."""
    uri = f"file:{FOOD_DB_PATH}?mode=ro" if readonly else FOOD_DB_PATH
    conn = sqlite3.connect(uri, uri=readonly)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


def _cache_to_food_db(name: str, brand: str, calories: float, protein: float, carbs: float, fat: float,
                       serving_size: float = 100.0, serving_unit: str = "g", serving_desc: str = "100g",
                       source: str = "user_cached"):
    """Cache a food item into the local USDA food DB + FTS index so it appears in future local searches."""
    if not _food_db_available:
        return
    try:
        # Normalize nutrients to per-100g (local DB convention)
        cal_100 = calories
        prot_100 = protein
        fat_100 = fat
        carb_100 = carbs
        if serving_size > 0 and serving_size != 100:
            factor = 100.0 / serving_size
            cal_100 = round(calories * factor, 1)
            prot_100 = round(protein * factor, 1)
            fat_100 = round(fat * factor, 1)
            carb_100 = round(carbs * factor, 1)

        conn = sqlite3.connect(FOOD_DB_PATH)
        cur = conn.cursor()
        # Use negative IDs for user-cached entries to avoid collision with USDA fdc_ids
        cur.execute("SELECT MIN(fdc_id) FROM food_items")
        min_id = cur.fetchone()[0] or 0
        new_id = min(min_id - 1, -1)
        cur.execute("""
            INSERT OR IGNORE INTO food_items (fdc_id, name, brand, category, data_type, trust_score,
                calories, protein_g, fat_g, carbs_g, fiber_g, sugar_g, sodium_mg,
                serving_size, serving_unit, serving_description)
            VALUES (?, ?, ?, '', ?, 80, ?, ?, ?, ?, 0, 0, 0, ?, ?, ?)
        """, (new_id, name, brand or '', source, cal_100, prot_100, fat_100, carb_100, serving_size, serving_unit, serving_desc))
        # Also insert into FTS index
        cur.execute("INSERT INTO food_items_fts(rowid, name, brand, category) VALUES (?, ?, ?, '')", (new_id, name, brand or ''))
        conn.commit()
        conn.close()
        logger.info(f"Cached food to local DB: {name}")
    except Exception as e:
        logger.warning(f"Failed to cache food: {e}")

router = APIRouter()

# ============ Enums ============

class MealTypeEnum(str, Enum):
    breakfast = "breakfast"
    lunch = "lunch"
    dinner = "dinner"
    snack = "snack"

# ============ Pydantic Schemas ============

class FoodItemCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    brand: Optional[str] = Field(None, max_length=200)
    barcode: Optional[str] = None
    serving_size: float = Field(..., gt=0, description="Must be positive")
    serving_unit: str = Field(..., min_length=1, max_length=20)
    serving_description: Optional[str] = None
    calories: float = Field(..., ge=0)
    protein_g: float = Field(..., ge=0)
    carbs_g: float = Field(..., ge=0)
    fats_g: float = Field(..., ge=0)
    fiber_g: Optional[float] = Field(None, ge=0)
    sugar_g: Optional[float] = Field(None, ge=0)
    sodium_mg: Optional[float] = Field(None, ge=0)
    source: Optional[str] = "manual"

class FoodItemResponse(BaseModel):
    id: int
    name: str
    brand: Optional[str]
    barcode: Optional[str]
    serving_size: float
    serving_unit: str
    serving_description: Optional[str]
    calories: float
    protein_g: float
    carbs_g: float
    fats_g: float
    fiber_g: Optional[float] = None
    sugar_g: Optional[float] = None
    sodium_mg: Optional[float] = None
    source: Optional[str] = None

    class Config:
        from_attributes = True

class MealItemCreate(BaseModel):
    food_id: int
    servings: float = Field(..., gt=0, description="Must be positive")

class MealCreate(BaseModel):
    meal_type: MealTypeEnum
    items: List[MealItemCreate] = []

class MealItemResponse(BaseModel):
    id: int
    food: FoodItemResponse
    servings: float

    class Config:
        from_attributes = True

class MealResponse(BaseModel):
    id: int
    date: date
    meal_type: str
    items: List[MealItemResponse]
    created_at: datetime

    class Config:
        from_attributes = True

@router.get("/search-food")
async def search_food(query: str, source: str = "all", db: Session = Depends(get_db)):
    """Search for foods. source='all' (default) searches local DB + APIs, source='off' searches OpenFoodFacts only."""
    
    results = []
    query_lower = query.lower().strip()
    
    if not query_lower or len(query_lower) < 2:
        return {"results": []}
    
    search_local = source != "off"
    
    # 1. Search local USDA food database (1.7M+ foods, instant, no network)
    if search_local and _food_db_available:
        try:
            with _get_food_db() as food_conn:
                cur = food_conn.cursor()
            
            # FTS5 search — split words with AND, use prefix matching (*)
            # "chicken breast" → "chicken"* AND "breast"* — handles plurals/suffixes
            # Falls back to OR if AND returns nothing (e.g. brand + food name)
            words = [w for w in query_lower.replace('"', '').split() if len(w) >= 2]
            if len(words) > 1:
                fts_query = ' AND '.join(f'{w}*' for w in words)
            elif words:
                fts_query = f'{words[0]}*'
            else:
                fts_query = query_lower
            
            cur.execute("""
                SELECT f.fdc_id, f.name, f.brand, f.category, f.data_type,
                       f.calories, f.protein_g, f.fat_g, f.carbs_g, 
                       f.fiber_g, f.sugar_g, f.sodium_mg,
                       f.saturated_fat_g, f.monounsaturated_fat_g, f.polyunsaturated_fat_g, f.trans_fat_g,
                       f.cholesterol_mg, f.potassium_mg, f.calcium_mg, f.iron_mg,
                       f.vitamin_a_mcg, f.vitamin_c_mg, f.vitamin_d_mcg,
                       f.serving_size, f.serving_unit, f.serving_description,
                       f.trust_score,
                       rank
                FROM food_items f
                JOIN food_items_fts ON food_items_fts.rowid = f.fdc_id
                WHERE food_items_fts MATCH ?
                ORDER BY 
                    f.trust_score DESC,
                    rank
                LIMIT 25
            """, (fts_query,))
            
            rows = cur.fetchall()
            
            # Fallback: if AND matched nothing and we had multiple words, try OR
            if not rows and len(words) > 1:
                fts_query_or = ' OR '.join(f'{w}*' for w in words)
                cur.execute("""
                    SELECT f.fdc_id, f.name, f.brand, f.category, f.data_type,
                           f.calories, f.protein_g, f.fat_g, f.carbs_g, 
                           f.fiber_g, f.sugar_g, f.sodium_mg,
                           f.saturated_fat_g, f.monounsaturated_fat_g, f.polyunsaturated_fat_g, f.trans_fat_g,
                           f.cholesterol_mg, f.potassium_mg, f.calcium_mg, f.iron_mg,
                           f.vitamin_a_mcg, f.vitamin_c_mg, f.vitamin_d_mcg,
                           f.serving_size, f.serving_unit, f.serving_description,
                           f.trust_score,
                           rank
                    FROM food_items f
                    JOIN food_items_fts ON food_items_fts.rowid = f.fdc_id
                    WHERE food_items_fts MATCH ?
                    ORDER BY 
                        f.trust_score DESC,
                        rank
                    LIMIT 25
                """, (fts_query_or,))
                rows = cur.fetchall()
            
            # Batch-load portions for all returned foods (USDA by fdc_id + MFP by food_name)
            portions_map = {}
            fdc_ids = [row['fdc_id'] for row in rows if row['fdc_id']]
            food_names = [row['name'] for row in rows if row['name']]
            if _food_db_available and (fdc_ids or food_names):
                try:
                    with _get_food_db() as p_conn:
                        p_cur = p_conn.cursor()
                        # Query USDA portions by fdc_id
                        if fdc_ids:
                            placeholders = ','.join('?' * len(fdc_ids))
                            p_cur.execute(f"""
                                SELECT fdc_id, food_name, portion_description, gram_weight, amount
                                FROM food_portions
                                WHERE fdc_id IN ({placeholders})
                                ORDER BY gram_weight
                            """, fdc_ids)
                            for p in p_cur.fetchall():
                                fid = p['fdc_id']
                                if fid not in portions_map:
                                    portions_map[fid] = []
                                portions_map[fid].append({
                                    "description": p['portion_description'],
                                    "gram_weight": round(p['gram_weight'], 1),
                                    "amount": p['amount'] or 1.0,
                                })
                        # Query MFP portions by food_name (for foods without USDA portions)
                        if food_names:
                            name_placeholders = ','.join('?' * len(food_names))
                            lower_names = [n.lower() for n in food_names]
                            p_cur.execute(f"""
                                SELECT fp.food_name, fp.portion_description, fp.gram_weight, fp.amount,
                                       mf.serving_grams
                                FROM food_portions fp
                                LEFT JOIN mfp_foods mf ON fp.mfp_id = mf.mfp_id
                                WHERE fp.source = 'mfp' AND LOWER(fp.food_name) IN ({name_placeholders})
                                ORDER BY fp.gram_weight
                            """, lower_names)
                            raw_name_portions = {}
                            name_serving_grams = {}
                            for p in p_cur.fetchall():
                                fn = p['food_name'].lower()
                                if fn not in raw_name_portions:
                                    raw_name_portions[fn] = []
                                    name_serving_grams[fn] = p['serving_grams'] or 100.0
                                raw_name_portions[fn].append({
                                    "description": p['portion_description'],
                                    "gram_weight": p['gram_weight'],
                                    "amount": p['amount'] or 1.0,
                                })
                            for row in rows:
                                fid = row['fdc_id']
                                fn = row['name'].lower()
                                if fid not in portions_map and fn in raw_name_portions:
                                    sg = name_serving_grams.get(fn, 100.0)
                                    portions_map[fid], _ = _convert_mfp_portions(raw_name_portions[fn], sg)
                except Exception:
                    pass

            for row in rows:
                # Determine source quality label
                data_type = row['data_type']
                if data_type == 'sr_legacy':
                    source_quality = 'lab-tested'
                elif data_type == 'foundation':
                    source_quality = 'lab-tested'
                else:
                    source_quality = 'manufacturer'
                
                fdc_id = row['fdc_id']
                portions = portions_map.get(fdc_id, [])

                results.append({
                    "name": row['name'],
                    "brand": row['brand'] or "",
                    "category": row['category'] or "",
                    "barcode": "",
                    "fdc_id": fdc_id,
                    "serving_size": row['serving_size'] or 100.0,
                    "serving_unit": row['serving_unit'] or "g",
                    "serving_description": row['serving_description'] or f"{row['serving_size'] or 100}g",
                    "portions": portions,
                    "calories": round(row['calories'], 1),
                    "protein_g": round(row['protein_g'], 1),
                    "carbs_g": round(row['carbs_g'], 1),
                    "fats_g": round(row['fat_g'], 1),
                    "fiber_g": round(row['fiber_g'] or 0, 1),
                    "sugar_g": round(row['sugar_g'] or 0, 1),
                    "sodium_mg": round(row['sodium_mg'] or 0, 1),
                    "saturated_fat_g": round(row['saturated_fat_g'] or 0, 1),
                    "monounsaturated_fat_g": round(row['monounsaturated_fat_g'] or 0, 1),
                    "polyunsaturated_fat_g": round(row['polyunsaturated_fat_g'] or 0, 1),
                    "trans_fat_g": round(row['trans_fat_g'] or 0, 1),
                    "cholesterol_mg": round(row['cholesterol_mg'] or 0, 1),
                    "potassium_mg": round(row['potassium_mg'] or 0, 1),
                    "calcium_mg": round(row['calcium_mg'] or 0, 1),
                    "iron_mg": round(row['iron_mg'] or 0, 1),
                    "vitamin_a_mcg": round(row['vitamin_a_mcg'] or 0, 1),
                    "vitamin_c_mg": round(row['vitamin_c_mg'] or 0, 1),
                    "vitamin_d_mcg": round(row['vitamin_d_mcg'] or 0, 1),
                    "source": "USDA_local",
                    "source_quality": source_quality,
                    "trust_score": row['trust_score'],
                })
            
            logger.info(f"Local DB returned {len(rows)} results for '{query}'")
        except Exception as e:
            logger.warning(f"Local food DB search error: {type(e).__name__}: {e}")
    
    # 1b. Search MFP foods (81K+ verified branded/restaurant items)
    if search_local and _food_db_available:
        try:
            with _get_food_db() as food_conn:
                cur = food_conn.cursor()
                
                # Build LIKE conditions for each word
                words = [w for w in query_lower.replace('"', '').split() if len(w) >= 2]
                if not words:
                    words = [query_lower]
                
                like_conditions = []
                like_params = []
                for w in words:
                    like_conditions.append("(LOWER(name) LIKE ? OR LOWER(brand) LIKE ?)")
                    like_params.extend([f"%{w}%", f"%{w}%"])
                
                where_clause = " AND ".join(like_conditions)
                # SAFETY: where_clause only contains static template patterns with ? placeholders
                # User input is in like_params, passed as parameterized values
                cur.execute(f"""
                    SELECT mfp_id, name, brand, calories, protein, carbs, fat,
                           fiber, sugar, sodium, serving_grams, verified, data_quality,
                           saturated_fat, monounsaturated_fat, polyunsaturated_fat, trans_fat,
                           cholesterol, potassium, calcium, iron,
                           vitamin_a, vitamin_c, vitamin_d
                    FROM mfp_foods
                    WHERE {where_clause} AND data_quality != 'bad'
                    ORDER BY 
                        CASE data_quality WHEN 'good' THEN 0 WHEN 'suspect' THEN 1 ELSE 2 END,
                        verified DESC,
                        CASE WHEN LOWER(name) LIKE ? THEN 0 ELSE 1 END,
                        calories DESC
                    LIMIT 25
                """, like_params + [f"%{query_lower}%"])
                
                mfp_rows = cur.fetchall()
                
                # Batch-load MFP portions by mfp_id
                mfp_portions_map = {}
                mfp_ids = [row['mfp_id'] for row in mfp_rows if row['mfp_id']]
                if mfp_ids:
                    placeholders = ','.join('?' * len(mfp_ids))
                    cur.execute(f"""
                        SELECT mfp_id, portion_description, gram_weight, amount
                        FROM food_portions
                        WHERE mfp_id IN ({placeholders})
                        ORDER BY gram_weight
                    """, mfp_ids)
                    for prow in cur.fetchall():
                        mid = prow['mfp_id']
                        if mid not in mfp_portions_map:
                            mfp_portions_map[mid] = []
                        desc = prow['portion_description']
                        if not any(p['description'] == desc for p in mfp_portions_map[mid]):
                            mfp_portions_map[mid].append({
                                "description": desc,
                                "gram_weight": prow['gram_weight'],
                                "amount": prow['amount'],
                            })
            
            for row in mfp_rows:
                is_verified = row['verified'] == 1
                raw_portions = mfp_portions_map.get(row['mfp_id'], [])
                sg = row['serving_grams'] or 100.0
                # Convert MFP multiplier-based portions to actual grams
                portions, corrected_sg = _convert_mfp_portions(raw_portions, sg)
                results.append({
                    "name": row['name'],
                    "brand": row['brand'] or "",
                    "category": "",
                    "barcode": "",
                    "fdc_id": None,
                    "mfp_id": row['mfp_id'],
                    "serving_size": corrected_sg,
                    "serving_unit": "g",
                    "serving_description": f"{corrected_sg}g",
                    "portions": portions,
                    "calories": round(row['calories'] or 0, 1),
                    "protein_g": round(row['protein'] or 0, 1),
                    "carbs_g": round(row['carbs'] or 0, 1),
                    "fats_g": round(row['fat'] or 0, 1),
                    "fiber_g": round(row['fiber'] or 0, 1),
                    "sugar_g": round(row['sugar'] or 0, 1),
                    "sodium_mg": round(row['sodium'] or 0, 1),
                    "saturated_fat_g": round(row['saturated_fat'] or 0, 1),
                    "monounsaturated_fat_g": round(row['monounsaturated_fat'] or 0, 1),
                    "polyunsaturated_fat_g": round(row['polyunsaturated_fat'] or 0, 1),
                    "trans_fat_g": round(row['trans_fat'] or 0, 1),
                    "cholesterol_mg": round(row['cholesterol'] or 0, 1),
                    "potassium_mg": round(row['potassium'] or 0, 1),
                    # DB stores absolute values (v3 scraper converted %DV→absolute at import)
                    "calcium_mg": round(row['calcium'] or 0, 1),
                    "iron_mg": round(row['iron'] or 0, 1),
                    "vitamin_a_mcg": round(row['vitamin_a'] or 0, 1),
                    "vitamin_c_mg": round(row['vitamin_c'] or 0, 1),
                    "vitamin_d_mcg": round(row['vitamin_d'] or 0, 1),
                    "source": "MFP",
                    "source_quality": "verified" if is_verified else "community",
                    "trust_score": 90 if is_verified else 40,
                })
            
            logger.info(f"MFP DB returned {len(mfp_rows)} results for '{query}'")
        except Exception as e:
            logger.warning(f"MFP food DB search error: {type(e).__name__}: {e}")
    
    # 2. Search user's own food entries (highest trust — manually verified)
    if search_local:
        local_foods = db.query(FoodItem).filter(
            FoodItem.name.ilike(f"%{query}%")
        ).limit(5).all()
        
        for food in local_foods:
            results.append({
                "id": food.id,
                "name": food.name,
                "brand": food.brand or "",
                "barcode": food.barcode or "",
                "serving_size": food.serving_size,
                "serving_unit": food.serving_unit or "g",
                "serving_description": food.serving_description,
                "suggested_unit": "g",
                "suggested_amount": 100.0,
                "calories": food.calories,
                "protein_g": food.protein_g,
                "carbs_g": food.carbs_g,
                "fats_g": food.fats_g,
                "source": "local",
                "source_quality": "verified",
                "trust_score": 100,
            })
    
    # 3. Hit external APIs if local results insufficient or OFF-only mode
    if len(results) < 5 or source == "off":
        logger.info(f"Only {len(results)} local results, querying external APIs in parallel...")
        
        async def _search_usda_api():
            """Search USDA FoodData Central API."""
            api_results = []
            try:
                async with httpx.AsyncClient(timeout=10.0, verify=_ssl_ctx) as client:
                    response = await client.get(
                        "https://api.nal.usda.gov/fdc/v1/foods/search",
                        params={
                            "query": query,
                            "pageSize": 15,
                            "dataType": ["SR Legacy", "Foundation", "Branded"],
                            "api_key": os.getenv("USDA_API_KEY", "DEMO_KEY")
                        }
                    )
                    response.raise_for_status()
                    data = response.json()
                    
                    for food in data.get("foods", []):
                        nutrients = {n["nutrientName"]: n["value"] for n in food.get("foodNutrients", [])}
                        calories = nutrients.get("Energy", 0)
                        if calories == 0:
                            continue
                        data_type = food.get("dataType", "")
                        food_desc = food.get("description", "")
                        if data_type in ("SR Legacy", "Foundation"):
                            trust, quality = 95, "lab-tested"
                        elif data_type == "Survey (FNDDS)":
                            trust, quality = 85, "survey"
                        else:
                            trust, quality = 60, "manufacturer"
                        api_results.append({
                            "name": food_desc.title(),
                            "brand": food.get("brandOwner", "") or "",
                            "barcode": food.get("gtinUpc", "") or "",
                            "serving_size": 100.0, "serving_unit": "g", "serving_description": "100g",
                            "suggested_unit": "g", "suggested_amount": 100.0,
                            "calories": round(calories, 1),
                            "protein_g": round(nutrients.get("Protein", 0), 1),
                            "carbs_g": round(nutrients.get("Carbohydrate, by difference", 0), 1),
                            "fats_g": round(nutrients.get("Total lipid (fat)", 0), 1),
                            "source": "USDA_api", "source_quality": quality,
                            "trust_score": min(trust, 100),
                        })
                    logger.info(f"USDA API returned {len(api_results)} results")
            except Exception as e:
                logger.warning(f"USDA API error: {type(e).__name__}: {e}")
            return api_results
        
        async def _search_openfoodfacts():
            """Search OpenFoodFacts — filter by data quality."""
            off_results = []
            try:
                async with httpx.AsyncClient(timeout=45.0, verify=_ssl_ctx, headers={"User-Agent": "FitnessTracker/1.0"}) as client:
                    response = await client.get(
                        "https://world.openfoodfacts.org/cgi/search.pl",
                        params={
                            "search_terms": query,
                            "search_simple": 1,
                            "json": 1,
                            "page_size": 25,
                            "tagtype_0": "countries",
                            "tag_contains_0": "contains",
                            "tag_0": "united-states",
                            "fields": "product_name,brands,code,nutriments,serving_size,completeness,nutriscore_grade,data_quality_errors_tags"
                        }
                    )
                    response.raise_for_status()
                    data = response.json()
                    
                    for product in data.get("products", []):
                        nutriments = product.get("nutriments", {})
                        product_name = product.get("product_name", "").strip()
                        if not product_name or len(product_name) < 2:
                            continue
                        if product.get("data_quality_errors_tags"):
                            continue
                        calories = nutriments.get("energy-kcal_100g") or nutriments.get("energy-kcal") or 0
                        if calories == 0:
                            continue
                        protein = nutriments.get("proteins_100g", 0) or 0
                        carbs = nutriments.get("carbohydrates_100g", 0) or 0
                        fat = nutriments.get("fat_100g", 0) or 0
                        macro_cals = (protein * 4) + (carbs * 4) + (fat * 9)
                        if macro_cals > 0 and abs(macro_cals - calories) / calories > 0.5:
                            continue
                        completeness = product.get("completeness", 0)
                        nutriscore = product.get("nutriscore_grade", "")
                        has_grade = nutriscore in ('a', 'b', 'c', 'd', 'e')
                        if completeness < 0.5 and not has_grade:
                            continue
                        trust = 30
                        if completeness >= 0.9: trust += 20
                        elif completeness >= 0.7: trust += 10
                        if has_grade: trust += 10
                        if all(v > 0 for v in [protein, carbs, fat]): trust += 10
                        off_results.append({
                            "name": product_name,
                            "brand": product.get("brands", "") or "",
                            "barcode": product.get("code", "") or "",
                            "serving_size": 100.0, "serving_unit": "g",
                            "serving_description": product.get("serving_size", "100g"),
                            "suggested_unit": "g", "suggested_amount": 100.0,
                            "calories": round(calories, 1),
                            "protein_g": round(protein, 1),
                            "carbs_g": round(carbs, 1),
                            "fats_g": round(fat, 1),
                            "fiber_g": round(nutriments.get("fiber_100g", 0) or 0, 1),
                            "sugar_g": round(nutriments.get("sugars_100g", 0) or 0, 1),
                            "sodium_mg": round((nutriments.get("sodium_100g", 0) or 0) * 1000, 1),
                            "saturated_fat_g": round(nutriments.get("saturated-fat_100g", 0) or 0, 1),
                            "monounsaturated_fat_g": round(nutriments.get("monounsaturated-fat_100g", 0) or 0, 1),
                            "polyunsaturated_fat_g": round(nutriments.get("polyunsaturated-fat_100g", 0) or 0, 1),
                            "trans_fat_g": round(nutriments.get("trans-fat_100g", 0) or 0, 1),
                            "cholesterol_mg": round((nutriments.get("cholesterol_100g", 0) or 0) * 1000, 1),
                            "potassium_mg": round((nutriments.get("potassium_100g", 0) or 0) * 1000, 1),
                            "calcium_mg": round((nutriments.get("calcium_100g", 0) or 0) * 1000, 1),
                            "iron_mg": round((nutriments.get("iron_100g", 0) or 0) * 1000, 1),
                            "vitamin_a_mcg": round((nutriments.get("vitamin-a_100g", 0) or 0) * 1_000_000, 1),
                            "vitamin_c_mg": round((nutriments.get("vitamin-c_100g", 0) or 0) * 1000, 1),
                            "vitamin_d_mcg": round((nutriments.get("vitamin-d_100g", 0) or 0) * 1_000_000, 1),
                            "source": "OpenFoodFacts", "source_quality": "community",
                            "trust_score": min(trust, 100),
                        })
                    logger.info(f"OpenFoodFacts returned {len(off_results)} results")
            except Exception as e:
                logger.warning(f"OpenFoodFacts error: {type(e).__name__}: {e}")
            return off_results
        
        # Run API searches — skip USDA in OFF-only mode
        if source == "off":
            off_results = await _search_openfoodfacts()
            results.extend(off_results)
        else:
            usda_results, off_results = await asyncio.gather(
                _search_usda_api(), _search_openfoodfacts()
            )
            results.extend(usda_results)
            results.extend(off_results)
    
    # 4. Sort by trust_score (highest first), deduplicate
    # Boost: exact name match gets +20, brand match gets +10
    # Penalize entries with impossible calorie density (macros > weight)
    for r in results:
        name_lower = r.get("name", "").lower()
        brand_lower = r.get("brand", "").lower()
        boost = 0
        if query_lower == name_lower or query_lower in name_lower.split(",")[0]:
            boost += 20
        elif query_lower in name_lower:
            boost += 10
        if query_lower in brand_lower:
            boost += 10
        # Sanity penalty: if cal/100g > 900 or macro grams exceed serving weight, deprioritize
        serving = r.get("serving_size", 100) or 100
        cal_per_100 = (r.get("calories", 0) / serving) * 100 if serving > 0 else 0
        macro_sum = (r.get("protein_g", 0) or 0) + (r.get("carbs_g", 0) or 0) + (r.get("fats_g", 0) or 0)
        if cal_per_100 > 900 or macro_sum > serving * 1.1:
            boost -= 50
        r["_sort_score"] = r.get("trust_score", 0) + boost
    
    results.sort(key=lambda r: r.get("_sort_score", 0), reverse=True)
    
    # Deduplicate by name+brand (keep first/best entry per food)
    seen = set()
    unique_results = []
    for r in results:
        r.pop("_sort_score", None)
        key = (r["name"].lower().strip(), (r.get("brand") or "").lower().strip())
        if key not in seen:
            seen.add(key)
            unique_results.append(r)
    
    return {"results": unique_results[:25]}


@router.get("/barcode/{barcode}")
async def lookup_barcode(barcode: str, db: Session = Depends(get_db)):
    """Fast barcode lookup: checks local DB first, then OFF product API."""
    
    # 1. Check local DB for previously logged food with this barcode
    existing = db.query(FoodItem).filter(FoodItem.barcode == barcode).first()
    if existing:
        return {"found": True, "source": "local", "results": [{
            "name": existing.name,
            "brand": existing.brand or "",
            "barcode": existing.barcode or "",
            "calories": existing.calories,
            "protein_g": existing.protein_g,
            "carbs_g": existing.carbs_g,
            "fats_g": existing.fats_g,
            "fiber_g": existing.fiber_g or 0,
            "sugar_g": existing.sugar_g or 0,
            "sodium_mg": existing.sodium_mg or 0,
            "serving_size": existing.serving_size or 100.0,
            "serving_unit": existing.serving_unit or "g",
            "serving_description": existing.serving_description or "100g",
            "suggested_unit": existing.serving_unit or "g",
            "suggested_amount": existing.serving_size or 100.0,
            "source": "local",
            "trust_score": 90,
        }]}
    
    # 2. Direct OFF product API (instant lookup by barcode)
    try:
        async with httpx.AsyncClient(timeout=10.0, verify=_ssl_ctx, headers={"User-Agent": "FitnessTracker/1.0"}) as client:
            response = await client.get(f"https://world.openfoodfacts.org/api/v0/product/{barcode}.json")
            response.raise_for_status()
            data = response.json()
            
            if data.get("status") != 1:
                return {"found": False, "results": []}
            
            product = data.get("product", {})
            nutriments = product.get("nutriments", {})
            product_name = product.get("product_name", "").strip()
            if not product_name:
                return {"found": False, "results": []}
            
            calories = nutriments.get("energy-kcal_100g", 0) or 0
            protein = nutriments.get("proteins_100g", 0) or 0
            carbs = nutriments.get("carbohydrates_100g", 0) or 0
            fat = nutriments.get("fat_100g", 0) or 0
            
            return {"found": True, "source": "OFF", "results": [{
                "name": product_name,
                "brand": product.get("brands", "") or "",
                "barcode": barcode,
                "calories": round(calories, 1),
                "protein_g": round(protein, 1),
                "carbs_g": round(carbs, 1),
                "fats_g": round(fat, 1),
                "fiber_g": round(nutriments.get("fiber_100g", 0) or 0, 1),
                "sugar_g": round(nutriments.get("sugars_100g", 0) or 0, 1),
                "sodium_mg": round((nutriments.get("sodium_100g", 0) or 0) * 1000, 1),
                "serving_size": 100.0,
                "serving_unit": "g",
                "serving_description": product.get("serving_size", "100g"),
                "suggested_unit": "g",
                "suggested_amount": 100.0,
                "source": "OFF",
                "source_quality": "community",
                "trust_score": 70,
            }]}
    except Exception as e:
        logger.warning(f"Barcode lookup error: {type(e).__name__}: {e}")
        return {"found": False, "results": []}


@router.post("/foods", response_model=FoodItemResponse)
def create_food_item(food: FoodItemCreate, db: Session = Depends(get_db)):
    """Add a new food to the database"""
    
    # Check if food with barcode already exists
    if food.barcode:
        existing = db.query(FoodItem).filter(FoodItem.barcode == food.barcode).first()
        if existing:
            return existing
    
    new_food = FoodItem(**food.model_dump())
    db.add(new_food)
    db.commit()
    db.refresh(new_food)
    
    # Cache to local food DB for fast future searches
    _cache_to_food_db(
        name=new_food.name, brand=new_food.brand or '',
        calories=new_food.calories, protein=new_food.protein_g,
        carbs=new_food.carbs_g, fat=new_food.fats_g,
        serving_size=new_food.serving_size, serving_unit=new_food.serving_unit or 'g',
        serving_desc=new_food.serving_description or f"{new_food.serving_size}g"
    )
    
    return new_food

@router.get("/foods", response_model=List[FoodItemResponse])
def get_foods(limit: int = 50, db: Session = Depends(get_db)):
    """Get all foods from local database"""
    foods = db.query(FoodItem).order_by(FoodItem.created_at.desc()).limit(limit).all()
    return foods

@router.post("/", response_model=MealResponse)
def create_meal(meal_data: MealCreate, db: Session = Depends(get_db)):
    """Create a new meal with food items"""
    
    # Create meal
    meal = Meal(
        date=date.today(),
        meal_type=meal_data.meal_type
    )
    db.add(meal)
    db.flush()  # Get ID without committing — rolls back if food validation fails
    
    # Add food items to meal
    for item in meal_data.items:
        # Verify food exists
        food = db.query(FoodItem).filter(FoodItem.id == item.food_id).first()
        if not food:
            raise HTTPException(status_code=404, detail=f"Food item {item.food_id} not found")
        
        meal_item = MealItem(
            meal_id=meal.id,
            food_id=item.food_id,
            servings=item.servings
        )
        db.add(meal_item)
    
    db.commit()
    db.refresh(meal)
    
    return meal

class QuickAddCreate(BaseModel):
    meal_type: MealTypeEnum
    food_name: str = Field(..., min_length=1, max_length=200)
    brand: Optional[str] = None
    barcode: Optional[str] = None
    calories: float = Field(..., ge=0)
    protein_g: float = Field(..., ge=0)
    carbs_g: float = Field(..., ge=0)
    fats_g: float = Field(..., ge=0)
    fiber_g: Optional[float] = Field(None, ge=0)
    sugar_g: Optional[float] = Field(None, ge=0)
    sodium_mg: Optional[float] = Field(None, ge=0)
    saturated_fat_g: Optional[float] = Field(None, ge=0)
    polyunsaturated_fat_g: Optional[float] = Field(None, ge=0)
    monounsaturated_fat_g: Optional[float] = Field(None, ge=0)
    trans_fat_g: Optional[float] = Field(None, ge=0)
    cholesterol_mg: Optional[float] = Field(None, ge=0)
    potassium_mg: Optional[float] = Field(None, ge=0)
    calcium_mg: Optional[float] = Field(None, ge=0)
    iron_mg: Optional[float] = Field(None, ge=0)
    vitamin_a_pct: Optional[float] = Field(None, ge=0)
    vitamin_c_pct: Optional[float] = Field(None, ge=0)
    vitamin_a_mcg: Optional[float] = Field(None, ge=0)
    vitamin_c_mg: Optional[float] = Field(None, ge=0)
    vitamin_d_mcg: Optional[float] = Field(None, ge=0)
    serving_size: float = Field(1.0, gt=0)
    serving_unit: str = "serving"
    servings: float = Field(1.0, gt=0)
    source: Optional[str] = "manual"

@router.post("/quick-add")
def quick_add_meal(data: QuickAddCreate, db: Session = Depends(get_db)):
    """Quick add a meal without searching (manual entry)"""
    
    try:
        # Create food item
        food = FoodItem(
            name=data.food_name,
            brand=data.brand,
            barcode=data.barcode,
            serving_size=data.serving_size,
            serving_unit=data.serving_unit,
            serving_description=f"{data.serving_size} {data.serving_unit}",
            calories=data.calories,
            protein_g=data.protein_g,
            carbs_g=data.carbs_g,
            fats_g=data.fats_g,
            fiber_g=data.fiber_g,
            sugar_g=data.sugar_g,
            sodium_mg=data.sodium_mg,
            saturated_fat_g=data.saturated_fat_g,
            polyunsaturated_fat_g=data.polyunsaturated_fat_g,
            monounsaturated_fat_g=data.monounsaturated_fat_g,
            trans_fat_g=data.trans_fat_g,
            cholesterol_mg=data.cholesterol_mg,
            potassium_mg=data.potassium_mg,
            calcium_mg=data.calcium_mg,
            iron_mg=data.iron_mg,
            vitamin_a_pct=data.vitamin_a_pct or (round(data.vitamin_a_mcg / 9.0, 1) if data.vitamin_a_mcg else None),
            vitamin_c_pct=data.vitamin_c_pct or (round(data.vitamin_c_mg / 0.9, 1) if data.vitamin_c_mg else None),
            vitamin_d_mcg=data.vitamin_d_mcg,
            source=data.source or "manual"
        )
        db.add(food)
        db.flush()
        
        # Get or create meal for this date+type (prevents duplicates from concurrent requests)
        meal = db.query(Meal).filter(
            Meal.date == date.today(),
            Meal.meal_type == data.meal_type
        ).first()
        if not meal:
            meal = Meal(date=date.today(), meal_type=data.meal_type)
            db.add(meal)
            db.flush()
        
        # Add food to meal
        meal_item = MealItem(meal_id=meal.id, food_id=food.id, servings=data.servings)
        db.add(meal_item)
        db.commit()
    except Exception:
        db.rollback()
        raise
    
    # Cache to local food DB (outside transaction — non-critical)
    _cache_to_food_db(
        name=food.name, brand=food.brand or '',
        calories=food.calories, protein=food.protein_g,
        carbs=food.carbs_g, fat=food.fats_g,
        serving_size=food.serving_size, serving_unit=food.serving_unit or 'g',
        serving_desc=food.serving_description or f"{food.serving_size}g",
        source=data.source or "manual"
    )
    
    return {"message": "Meal added successfully", "meal_id": meal.id}

@router.get("/today")
def get_today_meals(db: Session = Depends(get_db)):
    """Get all meals for today with macro totals"""
    today = date.today()
    return _get_meals_for_date(today, db)


@router.get("/by-date")
def get_meals_by_date(date_str: str = Query(..., alias="date"), db: Session = Depends(get_db)):
    """Get all meals for a specific date"""
    target = date.fromisoformat(date_str)
    return _get_meals_for_date(target, db)


def _get_meals_for_date(target_date, db: Session):
    meals = db.query(Meal).filter(Meal.date == target_date).order_by(Meal.created_at).all()
    
    meals_list = []
    
    for meal in meals:
        for item in meal.items:
            servings = item.servings
            food = item.food
            
            meals_list.append({
                "id": item.id,
                "meal_id": meal.id,
                "food_id": food.id,
                "meal_type": meal.meal_type,
                "food_name": food.name,
                "brand": food.brand,
                "servings": servings,
                "serving_size": item.effective_serving_size,
                "serving_unit": item.effective_serving_unit,
                "calories": round(item.effective_calories * servings, 1),
                "protein": round(item.effective_protein_g * servings, 1),
                "carbs": round(item.effective_carbs_g * servings, 1),
                "fat": round(item.effective_fats_g * servings, 1),
                "base_calories": item.effective_calories,
                "base_protein": item.effective_protein_g,
                "base_carbs": item.effective_carbs_g,
                "base_fat": item.effective_fats_g,
                "created_at": meal.created_at.isoformat()
            })
    
    goals = db.query(Goals).first()
    
    return {
        "date": target_date,
        "meals": meals_list,
        "goals": {
            "calories": goals.daily_calories if goals else 2000,
            "protein_g": goals.protein_g if goals else 150,
            "carbs_g": goals.carbs_g if goals else 200,
            "fats_g": goals.fats_g if goals else 65
        }
    }

@router.get("/nutrition-detail")
def get_nutrition_detail(
    start_date: str = None,
    end_date: str = None,
    db: Session = Depends(get_db)
):
    """Get detailed nutrition breakdown (all micro/macronutrients) for a date range"""
    from datetime import timedelta
    
    if not start_date:
        start = date.today()
    else:
        start = date.fromisoformat(start_date)
    
    if not end_date:
        end = start
    else:
        end = date.fromisoformat(end_date)
    
    meals = db.query(Meal).filter(Meal.date >= start, Meal.date <= end).all()
    
    _micro_fields = [
        "fiber", "sugar", "sodium", "saturated_fat", "polyunsaturated_fat",
        "monounsaturated_fat", "trans_fat", "cholesterol", "potassium",
        "calcium", "iron", "vitamin_a", "vitamin_c", "vitamin_d"
    ]
    
    # Aggregate per day
    days = {}
    current = start
    while current <= end:
        day = {
            "date": current.isoformat(),
            "calories": 0, "protein": 0, "carbs": 0, "fat": 0,
            "items_count": 0,
            "meal_calories": {"breakfast": 0, "lunch": 0, "dinner": 0, "snack": 0}
        }
        for f in _micro_fields:
            day[f] = 0
        days[current.isoformat()] = day
        current += timedelta(days=1)
    
    # Field mapping from FoodItem model attrs to response keys
    _field_map = {
        "fiber": "fiber_g", "sugar": "sugar_g", "sodium": "sodium_mg",
        "saturated_fat": "saturated_fat_g", "polyunsaturated_fat": "polyunsaturated_fat_g",
        "monounsaturated_fat": "monounsaturated_fat_g", "trans_fat": "trans_fat_g",
        "cholesterol": "cholesterol_mg", "potassium": "potassium_mg",
        "calcium": "calcium_mg", "iron": "iron_mg",
        "vitamin_a": "vitamin_a_pct", "vitamin_c": "vitamin_c_pct",
        "vitamin_d": "vitamin_d_mcg",
    }
    
    for meal in meals:
        day_key = meal.date.isoformat()
        if day_key not in days:
            continue
        meal_type = (meal.meal_type or "snack").lower()
        if meal_type not in ("breakfast", "lunch", "dinner", "snack"):
            meal_type = "snack"
        for item in meal.items:
            s = item.servings
            food = item.food
            if not food:
                continue
            item_cal = item.effective_calories * s
            days[day_key]["calories"] += item_cal
            days[day_key]["meal_calories"][meal_type] += item_cal
            days[day_key]["protein"] += item.effective_protein_g * s
            days[day_key]["carbs"] += item.effective_carbs_g * s
            days[day_key]["fat"] += item.effective_fats_g * s
            for resp_key, attr in _field_map.items():
                val = getattr(food, attr, None) or 0
                days[day_key][resp_key] += val * s
            days[day_key]["items_count"] += 1
    
    # Round all totals
    all_keys = ["calories", "protein", "carbs", "fat"] + _micro_fields
    for d in days.values():
        for k in all_keys:
            d[k] = round(d[k], 1)
        for mt in d["meal_calories"]:
            d["meal_calories"][mt] = round(d["meal_calories"][mt], 1)
    
    # Get goals
    goals = db.query(Goals).first()
    
    return {
        "days": list(days.values()),
        "goals": {
            "calories": goals.daily_calories if goals else 2000,
            "protein_g": goals.protein_g if goals else 150,
            "carbs_g": goals.carbs_g if goals else 200,
            "fats_g": goals.fats_g if goals else 65
        },
        "rdi": {
            "saturated_fat_g": 20,
            "polyunsaturated_fat_g": 22,
            "monounsaturated_fat_g": 22,
            "trans_fat_g": 2,
            "cholesterol_mg": 300,
            "sodium_mg": 2300,
            "potassium_mg": 4700,
            "fiber_g": 28,
            "sugar_g": 50,
            "vitamin_a_pct": 100,
            "vitamin_c_pct": 100,
            "calcium_mg": 1300,
            "iron_mg": 18,
            "vitamin_d_mcg": 20
        }
    }

@router.delete("/{meal_id}")
def delete_meal(meal_id: int, db: Session = Depends(get_db)):
    """Delete a meal and all its items"""
    meal = db.query(Meal).filter(Meal.id == meal_id).first()
    
    if not meal:
        raise HTTPException(status_code=404, detail="Meal not found")
    
    db.delete(meal)
    db.commit()
    
    return {"message": "Meal deleted successfully"}

@router.delete("/items/{item_id}")
def delete_meal_item(item_id: int, db: Session = Depends(get_db)):
    """Delete a single food item from a meal"""
    item = db.query(MealItem).filter(MealItem.id == item_id).first()
    
    if not item:
        raise HTTPException(status_code=404, detail="Meal item not found")
    
    db.delete(item)
    db.commit()
    
    return {"message": "Item removed from meal"}

class UpdateMealItemRequest(BaseModel):
    serving_size: Optional[float] = Field(None, gt=0)
    serving_unit: Optional[str] = None
    servings: Optional[float] = Field(None, gt=0)
    calories: Optional[float] = Field(None, ge=0)
    protein_g: Optional[float] = Field(None, ge=0)
    carbs_g: Optional[float] = Field(None, ge=0)
    fats_g: Optional[float] = Field(None, ge=0)
    meal_type: Optional[MealTypeEnum] = None

@router.put("/items/{item_id}")
def update_meal_item(item_id: int, data: UpdateMealItemRequest, db: Session = Depends(get_db)):
    """Update a meal item (serving size, macros, or meal type).
    Stores overrides on MealItem, never mutates the shared FoodItem."""
    item = db.query(MealItem).filter(MealItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Meal item not found")
    
    meal = item.meal

    # Store overrides on the MealItem (not the shared FoodItem)
    if data.calories is not None:
        item.override_calories = data.calories
    if data.protein_g is not None:
        item.override_protein_g = data.protein_g
    if data.carbs_g is not None:
        item.override_carbs_g = data.carbs_g
    if data.fats_g is not None:
        item.override_fats_g = data.fats_g
    if data.serving_size is not None:
        item.override_serving_size = data.serving_size
    if data.serving_unit is not None:
        item.override_serving_unit = data.serving_unit
    if data.servings is not None:
        item.servings = data.servings

    # Move to different meal type if requested
    if data.meal_type is not None and data.meal_type.value != meal.meal_type:
        target_meal = db.query(Meal).filter(
            Meal.date == meal.date,
            Meal.meal_type == data.meal_type.value
        ).first()
        if not target_meal:
            target_meal = Meal(date=meal.date, meal_type=data.meal_type.value)
            db.add(target_meal)
            db.commit()
            db.refresh(target_meal)
        item.meal_id = target_meal.id

    db.commit()
    
    return {
        "message": "Item updated",
        "item": {
            "id": item.id,
            "meal_type": item.meal.meal_type,
            "food_name": item.food.name,
            "servings": item.servings,
            "serving_size": item.effective_serving_size,
            "serving_unit": item.effective_serving_unit,
            "calories": round(item.effective_calories * item.servings, 1),
            "protein": round(item.effective_protein_g * item.servings, 1),
            "carbs": round(item.effective_carbs_g * item.servings, 1),
            "fat": round(item.effective_fats_g * item.servings, 1),
        }
    }

@router.get("/serving-units")
def get_serving_units():
    """Get list of supported serving units"""
    from serving_utils import WEIGHT_UNITS, VOLUME_UNITS, COUNT_UNITS, FOOD_PRESETS
    
    return {
        "weight_units": WEIGHT_UNITS,
        "volume_units": VOLUME_UNITS,
        "count_units": COUNT_UNITS,
        "examples": {
            "weight": ["100g", "5oz", "0.5lb"],
            "volume": ["1cup", "2tbsp", "240ml"],
            "count": ["2eggs", "1slice", "3pieces"]
        },
        "common_presets": list(FOOD_PRESETS.keys())
    }

@router.get("/recent-foods")
def get_recent_foods(db: Session = Depends(get_db)):
    """Get recently and frequently logged foods for quick-add."""
    from sqlalchemy import func, desc
    
    # Recent: last 20 unique foods logged
    recent_items = (
        db.query(FoodItem)
        .join(MealItem, MealItem.food_id == FoodItem.id)
        .join(Meal, Meal.id == MealItem.meal_id)
        .order_by(desc(Meal.created_at))
        .limit(50)
        .all()
    )
    
    seen = set()
    recent = []
    for food in recent_items:
        if food.name not in seen and len(recent) < 15:
            seen.add(food.name)
            recent.append(food)
    
    # Frequent: most logged foods (all time)
    freq_query = (
        db.query(FoodItem, func.count(MealItem.id).label("log_count"))
        .join(MealItem, MealItem.food_id == FoodItem.id)
        .group_by(FoodItem.id)
        .order_by(desc("log_count"))
        .limit(10)
        .all()
    )
    
    frequent_foods = [(food, count) for food, count in freq_query]
    
    # Batch-load portions for all foods
    all_foods = recent + [f for f, _ in frequent_foods]
    portions_map = _load_portions_for_foods(all_foods)
    
    recent_out = []
    for food in recent:
        recent_out.append({
            "id": food.id,
            "name": food.name,
            "brand": food.brand or "",
            "calories": food.calories,
            "protein_g": food.protein_g,
            "carbs_g": food.carbs_g,
            "fats_g": food.fats_g,
            "fiber_g": food.fiber_g or 0,
            "sugar_g": food.sugar_g or 0,
            "sodium_mg": food.sodium_mg or 0,
            "serving_size": food.serving_size,
            "serving_unit": food.serving_unit or "g",
            "serving_description": food.serving_description or f"{food.serving_size}g",
            "portions": portions_map.get(food.name.lower(), []),
            "source": food.source or "local",
            "source_quality": "verified" if food.source in ("USDA_local", "manual") else "community",
        })
    
    frequent_out = []
    for food, count in frequent_foods:
        frequent_out.append({
            "id": food.id,
            "name": food.name,
            "brand": food.brand or "",
            "calories": food.calories,
            "protein_g": food.protein_g,
            "carbs_g": food.carbs_g,
            "fats_g": food.fats_g,
            "fiber_g": food.fiber_g or 0,
            "sugar_g": food.sugar_g or 0,
            "sodium_mg": food.sodium_mg or 0,
            "serving_size": food.serving_size,
            "serving_unit": food.serving_unit or "g",
            "serving_description": food.serving_description or f"{food.serving_size}g",
            "portions": portions_map.get(food.name.lower(), []),
            "source": food.source or "local",
            "source_quality": "verified" if food.source in ("USDA_local", "manual") else "community",
            "log_count": count,
        })
    
    return {"recent": recent_out, "frequent": frequent_out}


_KNOWN_UNIT_GRAMS = {
    'oz': 28.35, 'ounce': 28.35,
    'lb': 453.6, 'pound': 453.6,
    'kg': 1000.0, 'kilogram': 1000.0,
    'g': 1.0, 'gram': 1.0,
    'mg': 0.001, 'milligram': 0.001,
    'cup': 240.0,
    'tbsp': 15.0, 'tablespoon': 15.0,
    'tsp': 5.0, 'teaspoon': 5.0,
    'ml': 1.0, 'milliliter': 1.0,
    'fl oz': 29.57, 'fluid ounce': 29.57,
}

def _fix_portion_weights(portions: list) -> list:
    """Fix portions with known units whose gram_weight is clearly wrong (MFP multiplier artifacts).
    
    For descriptions like '1 oz', '4 oz', '1 lb' etc., we know the correct gram weight.
    Also handles 'container (N unit)' patterns with embedded quantities.
    If the stored value is way off, replace with the computed correct value.
    """
    import re
    fixed = []
    for p in portions:
        desc = p['description'].strip()
        corrected = False
        
        # Pattern 1: "N unit(s)" — direct unit match
        m = re.match(r'^(\d+\.?\d*)\s+(.+)$', desc)
        if m:
            qty = float(m.group(1))
            raw_unit = m.group(2).lower().rstrip('s').strip('()').strip()
            unit = raw_unit
            if unit == 'onz': unit = 'oz'
            if unit == 'grm': unit = 'g'
            if unit.startswith('lb'): unit = 'lb'
            if unit.startswith('kg'): unit = 'kg'
            
            if unit in _KNOWN_UNIT_GRAMS:
                expected = qty * _KNOWN_UNIT_GRAMS[unit]
                current = p['gram_weight']
                if expected > 0 and (current < expected * 0.4 or current > expected * 2.5):
                    p = dict(p)
                    p['gram_weight'] = round(expected, 1)
                    corrected = True
        
        # Pattern 2: "container (N unit)" — embedded unit in parentheses
        if not corrected:
            m2 = re.search(r'\((\d+\.?\d*)\s*(oz|ounce|gram|g|ml|milliliter)\b', desc, re.IGNORECASE)
            if m2:
                qty2 = float(m2.group(1))
                raw_u2 = m2.group(2).lower().rstrip('s')
                if raw_u2 in _KNOWN_UNIT_GRAMS:
                    expected2 = qty2 * _KNOWN_UNIT_GRAMS[raw_u2]
                    if expected2 > 0 and p['gram_weight'] < expected2 * 0.4:
                        p = dict(p)
                        p['gram_weight'] = round(expected2, 1)
        
        fixed.append(p)
    return fixed

def _load_portions_for_foods(foods: list) -> dict:
    """Load portions from food_database.db for a list of FoodItem objects. Returns {lowercase_name: [portions]}."""
    if not _food_db_available or not foods:
        return {}
    portions_map = {}
    try:
        with _get_food_db() as p_conn:
            p_cur = p_conn.cursor()
            names = list({f.name.lower() for f in foods if f.name})
            if names:
                placeholders = ','.join('?' * len(names))
                p_cur.execute(f"""
                    SELECT LOWER(food_name) as fn, portion_description,
                           MAX(gram_weight) as gram_weight, MAX(amount) as amount
                    FROM food_portions
                    WHERE LOWER(food_name) IN ({placeholders})
                    GROUP BY LOWER(food_name), portion_description
                    ORDER BY gram_weight
                """, names)
                for p in p_cur.fetchall():
                    fn = p['fn']
                    if fn not in portions_map:
                        portions_map[fn] = []
                    portions_map[fn].append({
                        "description": p['portion_description'],
                        "gram_weight": round(p['gram_weight'], 1),
                        "amount": p['amount'] or 1.0,
                    })
                for fn in portions_map:
                    portions_map[fn] = _fix_portion_weights(portions_map[fn])
    except Exception:
        pass
    return portions_map

@router.post("/convert-serving")
def convert_serving(
    food_id: int,
    from_servings: float,
    to_serving_size: float,
    to_serving_unit: str,
    db: Session = Depends(get_db)
):
    """
    Convert macros between different serving sizes
    
    Example: Food is "per 100g", user wants to know macros for "150g"
    """
    food = db.query(FoodItem).filter(FoodItem.id == food_id).first()
    if not food:
        raise HTTPException(status_code=404, detail="Food not found")
    
    from serving_utils import calculate_macro_for_servings, normalize_serving
    
    # Normalize both servings to same unit for comparison
    base_normalized = normalize_serving(food.serving_size, food.serving_unit)
    target_normalized = normalize_serving(to_serving_size, to_serving_unit)
    
    # Calculate multiplier
    if base_normalized["type"] == target_normalized["type"] == "weight":
        multiplier = target_normalized["normalized_grams"] / base_normalized["normalized_grams"]
    elif base_normalized["type"] == target_normalized["type"] == "volume":
        multiplier = target_normalized["normalized_ml"] / base_normalized["normalized_ml"]
    else:
        # Different types or count-based, use simple multiplier
        multiplier = to_serving_size / food.serving_size
    
    macros = calculate_macro_for_servings(
        food.calories, food.protein_g, food.carbs_g, food.fats_g,
        food.serving_size, food.serving_unit,
        multiplier
    )
    
    return {
        "food_name": food.name,
        "original_serving": f"{food.serving_size}{food.serving_unit}",
        "converted_to": f"{to_serving_size}{to_serving_unit}",
        "multiplier": round(multiplier, 2),
        "macros": macros
    }


# ──────────────────────────── Meal Templates ────────────────────────────

class MealTemplateItemCreate(BaseModel):
    food_id: int = 0
    servings: float = 1.0
    serving_size: Optional[float] = None
    serving_unit: Optional[str] = None
    # Optional food data — used to create FoodItem when food_id is 0
    food_name: Optional[str] = None
    brand: Optional[str] = None
    calories: Optional[float] = None
    protein_g: Optional[float] = None
    carbs_g: Optional[float] = None
    fats_g: Optional[float] = None

class MealTemplateCreate(BaseModel):
    name: str
    items: List[MealTemplateItemCreate]

class MealTemplateLogRequest(BaseModel):
    meal_type: str
    date: str  # YYYY-MM-DD

@router.get("/templates")
def list_templates(db: Session = Depends(get_db)):
    templates = db.query(MealTemplate).order_by(MealTemplate.updated_at.desc()).all()
    result = []
    for t in templates:
        items = []
        total_cal = 0
        total_p = 0
        total_c = 0
        total_f = 0
        for item in t.items:
            food = item.food
            if not food:
                continue
            s = item.servings or 1.0
            cal = round((food.calories or 0) * s)
            p = round((food.protein_g or 0) * s, 1)
            c = round((food.carbs_g or 0) * s, 1)
            f = round((food.fats_g or 0) * s, 1)
            total_cal += cal
            total_p += p
            total_c += c
            total_f += f
            items.append({
                "id": item.id,
                "food_id": food.id,
                "food_name": food.name,
                "brand": food.brand,
                "servings": s,
                "serving_size": item.serving_size,
                "serving_unit": item.serving_unit,
                "calories": cal,
                "protein_g": p,
                "carbs_g": c,
                "fats_g": f,
            })
        result.append({
            "id": t.id,
            "name": t.name,
            "created_at": t.created_at.isoformat() if t.created_at else None,
            "updated_at": t.updated_at.isoformat() if t.updated_at else None,
            "items": items,
            "total_calories": total_cal,
            "total_protein_g": round(total_p, 1),
            "total_carbs_g": round(total_c, 1),
            "total_fats_g": round(total_f, 1),
            "item_count": len(items),
        })
    return result

def _resolve_food_id(item_data: MealTemplateItemCreate, db: Session) -> int:
    """Resolve a food_id, creating a FoodItem if needed."""
    if item_data.food_id and item_data.food_id > 0:
        food = db.query(FoodItem).filter(FoodItem.id == item_data.food_id).first()
        if food:
            return food.id
    # Create a new FoodItem from the provided data
    if not item_data.food_name:
        raise HTTPException(400, "food_id not found and no food_name provided")
    food = FoodItem(
        name=item_data.food_name,
        brand=item_data.brand or "",
        calories=item_data.calories or 0,
        protein_g=item_data.protein_g or 0,
        carbs_g=item_data.carbs_g or 0,
        fats_g=item_data.fats_g or 0,
        serving_size=100.0,
        serving_unit="g",
        source="template",
    )
    db.add(food)
    db.flush()
    return food.id

@router.post("/templates")
def create_template(data: MealTemplateCreate, db: Session = Depends(get_db)):
    if not data.name or not data.items:
        raise HTTPException(400, "Template needs a name and at least one item")
    template = MealTemplate(name=data.name.strip())
    db.add(template)
    db.flush()
    for item_data in data.items:
        food_id = _resolve_food_id(item_data, db)
        db.add(MealTemplateItem(
            template_id=template.id,
            food_id=food_id,
            servings=item_data.servings,
            serving_size=item_data.serving_size,
            serving_unit=item_data.serving_unit,
        ))
    db.commit()
    db.refresh(template)
    return {"id": template.id, "name": template.name, "item_count": len(data.items)}

class SaveFromMealRequest(BaseModel):
    name: str
    meal_id: int

@router.post("/templates/from-meal")
def create_template_from_meal(data: SaveFromMealRequest, db: Session = Depends(get_db)):
    """Create a template from an existing logged meal's items."""
    meal = db.query(Meal).filter(Meal.id == data.meal_id).first()
    if not meal:
        raise HTTPException(404, "Meal not found")
    if not meal.items:
        raise HTTPException(400, "Meal has no items")

    template = MealTemplate(name=data.name.strip())
    db.add(template)
    db.flush()
    for item in meal.items:
        db.add(MealTemplateItem(
            template_id=template.id,
            food_id=item.food_id,
            servings=item.servings,
        ))
    db.commit()
    return {"id": template.id, "name": template.name, "item_count": len(meal.items)}

@router.post("/templates/{template_id}/log")
def log_template(template_id: int, data: MealTemplateLogRequest, db: Session = Depends(get_db)):
    template = db.query(MealTemplate).filter(MealTemplate.id == template_id).first()
    if not template:
        raise HTTPException(404, "Template not found")
    if not template.items:
        raise HTTPException(400, "Template has no items")

    meal_date = datetime.strptime(data.date, "%Y-%m-%d").date()
    meal = db.query(Meal).filter(Meal.date == meal_date, Meal.meal_type == data.meal_type).first()
    if not meal:
        meal = Meal(date=meal_date, meal_type=data.meal_type)
        db.add(meal)
        db.flush()

    added = 0
    for t_item in template.items:
        if not t_item.food:
            continue
        db.add(MealItem(
            meal_id=meal.id,
            food_id=t_item.food_id,
            servings=t_item.servings or 1.0,
        ))
        added += 1
    db.commit()

    # Touch updated_at so recently used templates float to top
    template.updated_at = datetime.now()
    db.commit()

    return {"message": f"Added {added} items to {data.meal_type}", "meal_id": meal.id}

@router.put("/templates/{template_id}")
def update_template(template_id: int, data: MealTemplateCreate, db: Session = Depends(get_db)):
    template = db.query(MealTemplate).filter(MealTemplate.id == template_id).first()
    if not template:
        raise HTTPException(404, "Template not found")
    if not data.name or not data.items:
        raise HTTPException(400, "Template needs a name and at least one item")

    template.name = data.name.strip()
    template.updated_at = datetime.now()

    # Remove old items
    for old_item in template.items:
        db.delete(old_item)
    db.flush()

    # Add new items
    for item_data in data.items:
        food_id = _resolve_food_id(item_data, db)
        db.add(MealTemplateItem(
            template_id=template.id,
            food_id=food_id,
            servings=item_data.servings,
            serving_size=item_data.serving_size,
            serving_unit=item_data.serving_unit,
        ))
    db.commit()
    return {"id": template.id, "name": template.name, "item_count": len(data.items)}

@router.delete("/templates/{template_id}")
def delete_template(template_id: int, db: Session = Depends(get_db)):
    template = db.query(MealTemplate).filter(MealTemplate.id == template_id).first()
    if not template:
        raise HTTPException(404, "Template not found")
    db.delete(template)
    db.commit()
    return {"message": "Template deleted"}
