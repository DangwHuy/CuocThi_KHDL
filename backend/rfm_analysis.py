import pandas as pd
import json
from datetime import datetime
import os

def compute_rfm(df):
    df['Date'] = pd.to_datetime(df['Date'], format='%d-%m-%Y', errors='coerce')
    df = df.dropna(subset=['Date'])
    max_date = df['Date'].max()
    
    rfm = df.groupby('Member_number').agg({
        'Date': lambda x: (max_date - x.max()).days,
        'itemDescription': 'count' # Monetary proxy
    })
    
    # Frequency: count of unique dates
    freq = df.groupby('Member_number')['Date'].nunique()
    rfm['Frequency'] = freq
    
    rfm.rename(columns={'Date': 'Recency', 'itemDescription': 'Monetary'}, inplace=True)
    
    # Qcut scoring
    r_labels = range(5, 0, -1)
    f_labels = range(1, 6)
    m_labels = range(1, 6)
    
    try:
        rfm['R'] = pd.qcut(rfm['Recency'], q=5, labels=r_labels, duplicates='drop').astype(int)
    except:
        rfm['R'] = pd.qcut(rfm['Recency'].rank(method='first'), q=5, labels=r_labels).astype(int)
        
    try:
        rfm['F'] = pd.qcut(rfm['Frequency'], q=5, labels=f_labels, duplicates='drop').astype(int)
    except:
        rfm['F'] = pd.qcut(rfm['Frequency'].rank(method='first'), q=5, labels=f_labels).astype(int)
        
    try:
        rfm['M'] = pd.qcut(rfm['Monetary'], q=5, labels=m_labels, duplicates='drop').astype(int)
    except:
        rfm['M'] = pd.qcut(rfm['Monetary'].rank(method='first'), q=5, labels=m_labels).astype(int)
        
    def assign_segment(row):
        r, f, m = row['R'], row['F'], row['M']
        if r == 5 and f >= 4 and m >= 4:
            return 'Khách hàng tinh hoa' # Champions
        elif r >= 3 and f >= 3 and m >= 3:
            return 'Khách hàng thân thiết' # Loyal
        elif r >= 4 and f <= 2:
            return 'Khách hàng tiềm năng' # Potential
        elif r >= 4 and f == 1:
            return 'Khách hàng mới' # New
        elif r <= 3 and f >= 3 and m >= 3:
            return 'Khách hàng rủi ro' # At risk
        elif r <= 2 and f <= 2:
            return 'Khách hàng ngủ đông' # Hibernating
        else:
            return 'Khách hàng khác' # Others
            
    rfm['Segment'] = rfm.apply(assign_segment, axis=1)
    rfm['Score'] = rfm['R'].astype(str) + rfm['F'].astype(str) + rfm['M'].astype(str)
    rfm = rfm.reset_index()
    return rfm

def generate_json():
    csv_path = '../assets/data/Groceries_dataset.csv'
    if not os.path.exists(csv_path):
        csv_path = 'd:/Laptrinhmobile_tools/CT KHDL/assets/data/Groceries_dataset.csv'
        
    df = pd.read_csv(csv_path)
    rfm = compute_rfm(df)
    
    total_customers = len(rfm)
    segment_counts = rfm['Segment'].value_counts()
    
    segments = []
    for seg, count in segment_counts.items():
        segments.append({
            "name": seg,
            "count": int(count),
            "pct": round(count / total_customers * 100, 1)
        })
        
    # Names for segments (re-defined here to be sure)
    S_CHAMPIONS = 'Khách hàng tinh hoa'
    S_LOYAL = 'Khách hàng thân thiết'
    S_POTENTIAL = 'Khách hàng tiềm năng'
    S_NEW = 'Khách hàng mới'
    S_AT_RISK = 'Khách hàng rủi ro'
    S_HIBERNATING = 'Khách hàng ngủ đông'
    S_OTHERS = 'Khách hàng khác'

    # Ensure Segment column exists and is filled
    rfm['Segment'] = rfm['Segment'].fillna(S_OTHERS)
    
    # Top 10 overall
    top_overall = rfm.sort_values(by=['R', 'F', 'M'], ascending=[False, False, False]).head(10)
    
    # Get top 5 of each segment to ensure they show up in filters
    unique_segments = rfm['Segment'].unique()
    top_per_segment_list = []
    for s in unique_segments:
        seg_df = rfm[rfm['Segment'] == s].sort_values(by=['R', 'F', 'M'], ascending=[False, False, False]).head(5)
        top_per_segment_list.append(seg_df)
    
    top_per_segment = pd.concat(top_per_segment_list)
    combined_top = pd.concat([top_overall, top_per_segment]).drop_duplicates(subset='Member_number')
    
    top_list = []
    for _, row in combined_top.iterrows():
        top_list.append({
            "member_id": str(row['Member_number']),
            "r": int(row['R']),
            "f": int(row['F']),
            "m": int(row['M']),
            "score": str(row['Score']),
            "segment": str(row['Segment'])
        })
        
    stats = {
        "total_customers": total_customers,
        "champions_count": int(segment_counts.get(S_CHAMPIONS, 0)),
        "at_risk_count": int(segment_counts.get(S_AT_RISK, 0)),
        "avg_frequency": round(float(rfm['Frequency'].mean()), 1)
    }
    
    result = {
        "segments": segments,
        "top_customers": top_list,
        "stats": stats
    }
    
    out_dir = 'd:/Laptrinhmobile_tools/CT KHDL/assets/data/'
    with open(out_dir + 'rfm_data.json', 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
        
if __name__ == '__main__':
    generate_json()
    print("rfm_data.json generated successfully.")
