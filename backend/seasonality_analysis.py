import pandas as pd
import json
import os

def compute_seasonality(df):
    df['Date'] = pd.to_datetime(df['Date'], format='%d-%m-%Y', errors='coerce')
    df = df.dropna(subset=['Date'])
    
    df['Year'] = df['Date'].dt.year
    df['Month'] = df['Date'].dt.month
    df['DayOfWeek'] = df['Date'].dt.dayofweek  # 0=Monday, 6=Sunday
    
    # ── 1. Yearly totals ──
    yearly = df.groupby('Year').size().to_dict()
    total_2014 = int(yearly.get(2014, 0))
    total_2015 = int(yearly.get(2015, 0))
    yoy_growth = round((total_2015 - total_2014) / total_2014 * 100, 1) if total_2014 > 0 else 0
    
    # ── 2. Monthly trend per year (for line chart: 2014 vs 2015) ──
    monthly_by_year = df.groupby(['Year', 'Month']).size().reset_index(name='count')
    
    trend_2014 = [0] * 12
    trend_2015 = [0] * 12
    for _, row in monthly_by_year.iterrows():
        m = int(row['Month']) - 1  # 0-indexed
        if row['Year'] == 2014:
            trend_2014[m] = int(row['count'])
        elif row['Year'] == 2015:
            trend_2015[m] = int(row['count'])
    
    # ── 3. Average monthly (Jan–Dec combined) ──
    monthly_avg = df.groupby('Month').size().reset_index(name='count')
    avg_monthly = []
    peak_month = 0
    peak_count = 0
    for _, row in monthly_avg.iterrows():
        m = int(row['Month'])
        c = int(row['count'])
        avg_monthly.append({"month": m, "count": c})
        if c > peak_count:
            peak_count = c
            peak_month = m
    
    # ── 4. Day of week ──
    day_names_vi = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN']
    day_names_en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
    dow = df.groupby('DayOfWeek').size().reset_index(name='count')
    day_of_week = []
    for _, row in dow.iterrows():
        d = int(row['DayOfWeek'])
        day_of_week.append({
            "day_index": d,
            "name_vi": day_names_vi[d],
            "name_en": day_names_en[d],
            "count": int(row['count'])
        })
    
    # ── 5. YoY growth per month ──
    yoy_monthly = []
    for m in range(12):
        v2014 = trend_2014[m]
        v2015 = trend_2015[m]
        if v2014 > 0:
            pct = round((v2015 - v2014) / v2014 * 100, 1)
        else:
            pct = 0.0
        yoy_monthly.append({"month": m + 1, "pct": pct})
    
    # ── 6. Top 5 products per season ──
    def get_season(month):
        if month in [3, 4, 5]:
            return 'spring'
        elif month in [6, 7, 8]:
            return 'summer'
        elif month in [9, 10, 11]:
            return 'autumn'
        else:
            return 'winter'
    
    df['Season'] = df['Month'].apply(get_season)
    
    season_names_vi = {
        'spring': 'Mùa xuân',
        'summer': 'Mùa hè',
        'autumn': 'Mùa thu',
        'winter': 'Mùa đông'
    }
    
    seasonal_products = {}
    for season in ['spring', 'summer', 'autumn', 'winter']:
        season_df = df[df['Season'] == season]
        top5 = season_df['itemDescription'].value_counts().head(5)
        seasonal_products[season] = {
            "name_vi": season_names_vi[season],
            "name_en": season.capitalize(),
            "products": [
                {"name": name, "count": int(count)} 
                for name, count in top5.items()
            ]
        }
    
    # ── Month names for convenience ──
    month_names_vi = ['Th1', 'Th2', 'Th3', 'Th4', 'Th5', 'Th6', 'Th7', 'Th8', 'Th9', 'Th10', 'Th11', 'Th12']
    month_names_en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    
    result = {
        "stats": {
            "total_2014": total_2014,
            "total_2015": total_2015,
            "yoy_growth": yoy_growth,
            "peak_month": peak_month,
            "peak_month_name_vi": month_names_vi[peak_month - 1],
            "peak_month_name_en": month_names_en[peak_month - 1],
            "peak_count": peak_count
        },
        "trend_2014": trend_2014,
        "trend_2015": trend_2015,
        "avg_monthly": avg_monthly,
        "day_of_week": day_of_week,
        "yoy_monthly": yoy_monthly,
        "seasonal_products": seasonal_products,
        "month_names_vi": month_names_vi,
        "month_names_en": month_names_en
    }
    
    return result


def generate_json():
    csv_path = '../assets/data/Groceries_dataset.csv'
    if not os.path.exists(csv_path):
        csv_path = 'd:/Laptrinhmobile_tools/CT KHDL/assets/data/Groceries_dataset.csv'
    
    df = pd.read_csv(csv_path)
    result = compute_seasonality(df)
    
    out_dir = 'd:/Laptrinhmobile_tools/CT KHDL/assets/data/'
    with open(out_dir + 'seasonality_data.json', 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)


if __name__ == '__main__':
    generate_json()
    print("seasonality_data.json generated successfully.")
