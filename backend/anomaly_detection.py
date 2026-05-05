import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest
import json

def compute_anomalies(df):
    df['Date'] = pd.to_datetime(df['Date'], format='%d-%m-%Y', errors='coerce')
    df = df.dropna(subset=['Date'])

    # ════════════════ A. DAILY ANOMALIES (IQR) ════════════════
    daily = df.groupby('Date').agg(
        count=('itemDescription', 'count'),
    ).reset_index().sort_values('Date')

    Q1 = daily['count'].quantile(0.25)
    Q3 = daily['count'].quantile(0.75)
    IQR = Q3 - Q1
    lower = Q1 - 1.5 * IQR
    upper = Q3 + 1.5 * IQR

    # Full daily series
    daily_series = []
    for _, row in daily.iterrows():
        is_anom = row['count'] < lower or row['count'] > upper
        daily_series.append({
            'date': row['Date'].strftime('%Y-%m-%d'),
            'count': int(row['count']),
            'is_anomaly': bool(is_anom),
        })

    # Anomaly details
    anom_days = daily[(daily['count'] < lower) | (daily['count'] > upper)].copy()
    daily_anomalies = []
    for _, row in anom_days.iterrows():
        date = row['Date']
        count = int(row['count'])
        atype = 'spike' if count > upper else 'drop'
        expected_mid = (Q1 + Q3) / 2
        dev_pct = round(abs(count - expected_mid) / expected_mid * 100, 1)

        # Top 3 items on that day
        day_df = df[df['Date'] == date]
        top3 = day_df['itemDescription'].value_counts().head(3).index.tolist()

        daily_anomalies.append({
            'date': date.strftime('%Y-%m-%d'),
            'count': count,
            'expected_min': round(float(lower), 1),
            'expected_max': round(float(upper), 1),
            'deviation_pct': dev_pct,
            'type': atype,
            'top_items': top3,
        })

    # Sort by deviation descending
    daily_anomalies.sort(key=lambda x: x['deviation_pct'], reverse=True)

    spike_count = sum(1 for a in daily_anomalies if a['type'] == 'spike')
    drop_count = sum(1 for a in daily_anomalies if a['type'] == 'drop')

    # ════════════════ B. CUSTOMER ANOMALIES (Isolation Forest) ════════════════
    cust = df.groupby('Member_number').agg(
        total_transactions=('Date', 'nunique'),
        total_items=('itemDescription', 'count'),
        unique_items=('itemDescription', 'nunique'),
        first_buy=('Date', 'min'),
        last_buy=('Date', 'max'),
    ).reset_index()

    cust['avg_basket'] = round(cust['total_items'] / cust['total_transactions'], 2)
    cust['span_days'] = (cust['last_buy'] - cust['first_buy']).dt.days.clip(lower=1)
    cust['txn_per_day'] = round(cust['total_transactions'] / cust['span_days'], 4)

    features = cust[['total_transactions', 'avg_basket', 'unique_items', 'txn_per_day']].fillna(0)

    iso = IsolationForest(contamination=0.05, random_state=42, n_estimators=100)
    cust['anomaly_label'] = iso.fit_predict(features)
    cust['anomaly_score'] = iso.decision_function(features)

    anomaly_customers = cust[cust['anomaly_label'] == -1].copy()
    anomaly_customers = anomaly_customers.sort_values('anomaly_score')

    # Generate reason
    med_txn = cust['total_transactions'].median()
    med_basket = cust['avg_basket'].median()
    med_unique = cust['unique_items'].median()

    customer_anomalies = []
    for _, row in anomaly_customers.iterrows():
        reasons = []
        if row['total_transactions'] > med_txn * 2:
            reasons.append('Mua quá nhiều lần')
        if row['avg_basket'] > med_basket * 2:
            reasons.append('Giỏ hàng bất thường lớn')
        if row['unique_items'] > med_unique * 2:
            reasons.append('Đa dạng SP bất thường')
        if row['total_transactions'] <= 1:
            reasons.append('Chỉ mua 1 lần')
        if not reasons:
            reasons.append('Hành vi mua sắm khác biệt')

        customer_anomalies.append({
            'member_id': str(row['Member_number']),
            'anomaly_score': round(float(row['anomaly_score']), 3),
            'total_transactions': int(row['total_transactions']),
            'avg_basket': float(row['avg_basket']),
            'unique_items': int(row['unique_items']),
            'reason_vi': reasons[0],
            'reason_en': {
                'Mua quá nhiều lần': 'Too many purchases',
                'Giỏ hàng bất thường lớn': 'Abnormally large basket',
                'Đa dạng SP bất thường': 'Abnormal product diversity',
                'Chỉ mua 1 lần': 'Single purchase only',
                'Hành vi mua sắm khác biệt': 'Unusual shopping behavior',
            }.get(reasons[0], 'Unusual behavior'),
        })

    # Limit to top 30 most anomalous
    customer_anomalies = customer_anomalies[:30]

    stats = {
        'total_days': int(len(daily)),
        'anomaly_days': int(len(daily_anomalies)),
        'spike_days': spike_count,
        'drop_days': drop_count,
        'anomaly_customers': int(len(anomaly_customers)),
        'pct_anomaly_customers': round(len(anomaly_customers) / len(cust) * 100, 1),
        'iqr_lower': round(float(lower), 1),
        'iqr_upper': round(float(upper), 1),
    }

    return {
        'daily_anomalies': daily_anomalies,
        'customer_anomalies': customer_anomalies,
        'daily_series': daily_series,
        'stats': stats,
    }


if __name__ == '__main__':
    csv_path = 'd:/Laptrinhmobile_tools/CT KHDL/assets/data/Groceries_dataset.csv'
    df = pd.read_csv(csv_path)
    result = compute_anomalies(df)

    out_path = 'd:/Laptrinhmobile_tools/CT KHDL/assets/data/anomaly_data.json'
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print('anomaly_data.json generated successfully.')
    s = result['stats']
    print(f"  Days: {s['total_days']} | Anomaly days: {s['anomaly_days']} (Spike: {s['spike_days']}, Drop: {s['drop_days']})")
    print(f"  Anomaly customers: {s['anomaly_customers']} ({s['pct_anomaly_customers']}%)")
