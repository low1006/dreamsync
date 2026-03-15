from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import joblib
import numpy as np
import pandas as pd

app = FastAPI(title="DreamSync ML API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

pipeline = joblib.load("best_sleep_model.pkl")

TARGET_MINUTES   = 480
IDEAL_DEEP_RATIO = 0.18
IDEAL_REM_RATIO  = 0.22
EPS              = 1e-6
MOOD_MAP         = {"sad": 30.0, "neutral": 60.0, "happy": 90.0}


# ── Request models ────────────────────────────────────────────────────────────

class SleepNight(BaseModel):
    """One night from sleep_record JOIN daily_activity."""
    date                : str
    total_minutes       : int
    deep_minutes        : int
    light_minutes       : int
    rem_minutes         : int
    awake_minutes       : int
    sleep_score         : int
    mood_feedback       : Optional[str]   = None   # "sad" | "neutral" | "happy"
    exercise_minutes    : Optional[int]   = 0
    food_calories       : Optional[int]   = 0
    screen_time_minutes : Optional[int]   = 0
    bedtime_hours       : Optional[float] = 23.0


class RecommendRequest(BaseModel):
    """Past 7 nights (oldest first) + today's lifestyle data."""
    history             : List[SleepNight]
    exercise_minutes    : Optional[int]   = 0       # today
    food_calories       : Optional[int]   = 0       # today
    screen_time_minutes : Optional[int]   = 0       # today
    bedtime_hours       : Optional[float] = 23.0    # planned bedtime tonight


# ── Convert one SleepNight to raw feature dict ────────────────────────────────

def night_to_dict(n: SleepNight) -> dict:
    total_h = n.total_minutes / 60.0
    deep_h  = n.deep_minutes  / 60.0
    rem_h   = n.rem_minutes   / 60.0
    light_h = n.light_minutes / 60.0
    awake_h = n.awake_minutes / 60.0
    tib     = total_h + awake_h

    deep_r  = np.clip(deep_h  / (total_h + EPS), 0, 1)
    rem_r   = np.clip(rem_h   / (total_h + EPS), 0, 1)
    light_r = np.clip(light_h / (total_h + EPS), 0, 1)
    awake_r = np.clip(awake_h / (total_h + EPS), 0, 1)
    eff     = np.clip(total_h / (tib     + EPS), 0, 1)

    mood_score = MOOD_MAP.get(n.mood_feedback or "", None)
    blended    = (0.6 * n.sleep_score + 0.4 * mood_score) if mood_score else float(n.sleep_score)

    exercise_h = (n.exercise_minutes    or 0) / 60.0
    screen_h   = (n.screen_time_minutes or 0) / 60.0
    calories   = float(n.food_calories  or 0)

    return {
        "total_sleep_hours"   : total_h,
        "deep_sleep_hours"    : deep_h,
        "light_sleep_hours"   : light_h,
        "rem_hours"           : rem_h,
        "awake_hours"         : awake_h,
        "total_sleep_minutes" : float(n.total_minutes),
        "awake_minutes_f"     : float(n.awake_minutes),
        "time_in_bed_hours"   : tib,
        "sleep_score"         : float(n.sleep_score),
        "blended_score"       : blended,
        "duration_ratio"      : np.clip(n.total_minutes / TARGET_MINUTES, 0, 1),
        "deep_ratio"          : deep_r,
        "rem_ratio"           : rem_r,
        "light_ratio"         : light_r,
        "awake_ratio"         : awake_r,
        "sleep_efficiency"    : eff,
        "deep_ratio_dev"      : np.clip(abs(deep_r - IDEAL_DEEP_RATIO) / IDEAL_DEEP_RATIO, 0, 2),
        "rem_ratio_dev"       : np.clip(abs(rem_r  - IDEAL_REM_RATIO)  / IDEAL_REM_RATIO,  0, 2),
        "exercise_time"       : exercise_h,
        "calories_intake"     : calories,
        "screentime"          : screen_h,
    }


# ── Build feature row for one candidate duration ──────────────────────────────

def build_row(
    history: List[SleepNight],
    hrs: float,
    sim_deep_r: float, sim_rem_r: float,
    sim_light_r: float, sim_awake_r: float,
    today_exercise_h: float, today_calories: float,
    today_screen_h: float, tonight_bedtime: float,
) -> pd.DataFrame:

    # History dataframe (oldest → newest)
    hist_df = pd.DataFrame([night_to_dict(n) for n in history])

    lag1 = hist_df.iloc[-1]
    lag2 = hist_df.iloc[-2] if len(hist_df) >= 2 else hist_df.iloc[-1]
    roll3 = hist_df.tail(3).mean()
    roll7 = hist_df.tail(7).mean()

    total_min   = hrs * 60
    sim_awake_h = hrs * sim_awake_r
    tib         = hrs + sim_awake_h
    eff         = np.clip(hrs / (tib + EPS), 0, 1)
    bedtime_n   = tonight_bedtime % 24

    f = {
        # Tonight candidate
        "total_sleep_hours"   : hrs,
        "deep_sleep_hours"    : hrs * sim_deep_r,
        "light_sleep_hours"   : hrs * sim_light_r,
        "rem_hours"           : hrs * sim_rem_r,
        "awake_hours"         : sim_awake_h,
        "total_sleep_minutes" : total_min,
        "awake_minutes_f"     : sim_awake_h * 60,
        "time_in_bed_hours"   : tib,
        "duration_ratio"      : np.clip(total_min / TARGET_MINUTES, 0, 1),
        "deep_ratio"          : sim_deep_r,
        "rem_ratio"           : sim_rem_r,
        "light_ratio"         : sim_light_r,
        "awake_ratio"         : sim_awake_r,
        "sleep_efficiency"    : eff,
        "deep_ratio_dev"      : np.clip(abs(sim_deep_r - IDEAL_DEEP_RATIO) / IDEAL_DEEP_RATIO, 0, 2),
        "rem_ratio_dev"       : np.clip(abs(sim_rem_r  - IDEAL_REM_RATIO)  / IDEAL_REM_RATIO,  0, 2),
        # Today's lifestyle
        "exercise_time"       : today_exercise_h,
        "calories_intake"     : today_calories,
        "screentime"          : today_screen_h,
        "exercise_benefit"    : np.clip(today_exercise_h, 0, 2),
        "late_screen"         : today_screen_h * float(tonight_bedtime > 23),
        # Bedtime cyclical
        "bedtime_hours"       : tonight_bedtime,
        "bedtime_sin"         : np.sin(2 * np.pi * bedtime_n / 24),
        "bedtime_cos"         : np.cos(2 * np.pi * bedtime_n / 24),
        # Day of week (unknown tonight → neutral)
        "day_of_week"         : 0,
        "day_of_week_sin"     : 0.0,
        "day_of_week_cos"     : 1.0,
        "is_weekend"          : 0,
    }

    # Lag features — from REAL past nights (personalised!)
    lag_cols = [
        "total_sleep_hours", "sleep_score", "blended_score",
        "deep_ratio", "rem_ratio", "awake_ratio",
        "duration_ratio", "deep_ratio_dev", "rem_ratio_dev",
        "rem_hours", "deep_sleep_hours", "awake_hours",
        "screentime", "exercise_time", "calories_intake", "sleep_efficiency",
    ]
    for col in lag_cols:
        f[f"{col}_lag1"] = float(lag1.get(col, 0))
        f[f"{col}_lag2"] = float(lag2.get(col, 0))

    # Rolling averages — from REAL past nights (personalised!)
    roll_cols = [
        "total_sleep_hours", "sleep_score", "blended_score",
        "deep_ratio", "rem_ratio", "duration_ratio", "sleep_efficiency",
    ]
    for col in roll_cols:
        f[f"{col}_roll3"] = float(roll3.get(col, 0))
        f[f"{col}_roll7"] = float(roll7.get(col, 0))

    # Sleep debt: personal 7-night average vs last night
    f["sleep_debt"] = float(
        roll7.get("total_sleep_hours", hrs) - lag1.get("total_sleep_hours", hrs)
    )

    return pd.DataFrame([f])


# ── Recommend endpoint ────────────────────────────────────────────────────────

@app.post("/recommend")
def recommend(req: RecommendRequest):
    if not req.history:
        return {"error": "history list is empty"}

    history = sorted(req.history, key=lambda n: n.date)  # oldest → newest
    latest  = history[-1]

    base_h  = latest.total_minutes / 60.0
    deep_r  = (latest.deep_minutes  / 60.0) / max(base_h, EPS)
    rem_r   = (latest.rem_minutes   / 60.0) / max(base_h, EPS)
    awake_r = (latest.awake_minutes / 60.0) / max(base_h, EPS)

    today_exercise_h = (req.exercise_minutes    or 0) / 60.0
    today_calories   = float(req.food_calories  or 0)
    today_screen_h   = (req.screen_time_minutes or 0) / 60.0
    tonight_bedtime  = req.bedtime_hours or 23.0

    model_features = pipeline.named_steps["pre"].transformers_[0][2]

    hour_range = [round(x / 4, 2) for x in range(16, 41)]  # 4h–10h
    best_score, best_hrs = -1.0, 8.0
    candidates = []

    for hrs in hour_range:
        delta = float(np.clip((hrs - base_h) / max(base_h, 1), -0.3, 0.3))
        nudge = 0.4 * delta

        sim_deep_r  = float(np.clip(deep_r  + nudge * (IDEAL_DEEP_RATIO - deep_r),  0.05, 0.40))
        sim_rem_r   = float(np.clip(rem_r   + nudge * (IDEAL_REM_RATIO  - rem_r),   0.05, 0.40))
        sim_light_r = float(np.clip(1.0 - sim_deep_r - sim_rem_r, 0.10, 0.80))
        sim_awake_r = float(np.clip(awake_r * (1 - 0.08 * delta), 0.0, 0.30))

        X = build_row(
            history=history, hrs=hrs,
            sim_deep_r=sim_deep_r, sim_rem_r=sim_rem_r,
            sim_light_r=sim_light_r, sim_awake_r=sim_awake_r,
            today_exercise_h=today_exercise_h, today_calories=today_calories,
            today_screen_h=today_screen_h, tonight_bedtime=tonight_bedtime,
        )

        for col in model_features:
            if col not in X.columns:
                X[col] = 0.0
        X = X[model_features]

        score = float(np.clip(pipeline.predict(X)[0], 0, 100))

        candidates.append({
            "hours"        : hrs,
            "score"        : round(score, 1),
            "sim_deep_h"   : round(hrs * sim_deep_r,  2),
            "sim_rem_h"    : round(hrs * sim_rem_r,   2),
            "sim_deep_pct" : round(sim_deep_r * 100,  1),
            "sim_rem_pct"  : round(sim_rem_r  * 100,  1),
        })

        if score > best_score:
            best_score, best_hrs = score, hrs

    h    = int(best_hrs)
    m    = int((best_hrs % 1) * 60)
    best = next(c for c in candidates if c["hours"] == best_hrs)

    return {
        "recommended_hours" : best_hrs,
        "recommended_label" : f"{h}h {m}min",
        "expected_score"    : round(best_score, 1),
        "sim_deep_h"        : best["sim_deep_h"],
        "sim_rem_h"         : best["sim_rem_h"],
        "sim_deep_pct"      : best["sim_deep_pct"],
        "sim_rem_pct"       : best["sim_rem_pct"],
        "candidates"        : candidates,
    }


@app.get("/health")
def health():
    return {"status": "ok"}
