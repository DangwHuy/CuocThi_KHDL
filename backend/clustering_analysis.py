import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from sklearn.decomposition import PCA
from sklearn.metrics import silhouette_score
import json
import os

# Category mapping
CATEGORY_MAP = {
    'whole milk': 'Dairy', 'yogurt': 'Dairy', 'cream cheese': 'Dairy',
    'curd': 'Dairy', 'butter': 'Dairy', 'whipped/sour cream': 'Dairy',
    'butter milk': 'Dairy', 'processed cheese': 'Dairy', 'hard cheese': 'Dairy',
    'soft cheese': 'Dairy', 'sliced cheese': 'Dairy', 'domestic eggs': 'Dairy',
    'UHT-milk': 'Dairy', 'dessert': 'Dairy', 'cream': 'Dairy',

    'other vegetables': 'Produce', 'root vegetables': 'Produce',
    'tropical fruit': 'Produce', 'citrus fruit': 'Produce', 'pip fruit': 'Produce',
    'onions': 'Produce', 'berries': 'Produce', 'grapes': 'Produce',
    'herbs': 'Produce', 'mushroom': 'Produce', 'frozen vegetables': 'Produce',
    'packaged fruit/vegetables': 'Produce', 'fruit/vegetable juice': 'Produce',

    'rolls/buns': 'Bakery', 'pastry': 'Bakery', 'brown bread': 'Bakery',
    'white bread': 'Bakery', 'specialty chocolate': 'Bakery',
    'chocolate': 'Bakery', 'candy': 'Bakery', 'chewing gum': 'Bakery',
    'sugar': 'Bakery', 'flour': 'Bakery',

    'soda': 'Beverages', 'bottled water': 'Beverages', 'bottled beer': 'Beverages',
    'canned beer': 'Beverages', 'red/blush wine': 'Beverages', 'coffee': 'Beverages',
    'beverages': 'Beverages', 'white wine': 'Beverages', 'sparkling wine': 'Beverages',

    'sausage': 'Meat', 'pork': 'Meat', 'beef': 'Meat', 'chicken': 'Meat',
    'frankfurter': 'Meat', 'hamburger meat': 'Meat', 'meat': 'Meat',
}

CATEGORY_VI = {
    'Dairy': 'Sữa & Trứng', 'Produce': 'Rau & Trái cây', 'Bakery': 'Bánh & Ngọt',
    'Beverages': 'Đồ uống', 'Meat': 'Thịt & Cá', 'Other': 'Khác',
}


def get_category(item):
    return CATEGORY_MAP.get(item.strip(), 'Other')


def compute_clustering(df):
    df['Date'] = pd.to_datetime(df['Date'], format='%d-%m-%Y', errors='coerce')
    df = df.dropna(subset=['Date'])
    df['Category'] = df['itemDescription'].apply(get_category)

    # ── Feature engineering per customer ──
    customers = df.groupby('Member_number').agg(
        total_transactions=('Date', 'nunique'),
        unique_items=('itemDescription', 'nunique'),
        total_items=('itemDescription', 'count'),
        first_buy=('Date', 'min'),
        last_buy=('Date', 'max'),
    ).reset_index()

    customers['avg_basket_size'] = round(customers['total_items'] / customers['total_transactions'], 2)
    customers['shopping_span_days'] = (customers['last_buy'] - customers['first_buy']).dt.days

    # Favourite category
    fav_cat = df.groupby(['Member_number', 'Category']).size().reset_index(name='cnt')
    fav_cat = fav_cat.sort_values('cnt', ascending=False).drop_duplicates('Member_number')
    fav_cat = fav_cat[['Member_number', 'Category']].rename(columns={'Category': 'favourite_category'})
    customers = customers.merge(fav_cat, on='Member_number', how='left')
    customers['favourite_category'] = customers['favourite_category'].fillna('Other')

    # ── Clustering features ──
    feature_cols = ['total_transactions', 'unique_items', 'avg_basket_size', 'shopping_span_days']
    X = customers[feature_cols].fillna(0)

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    # K-Means with K=4
    K = 4
    kmeans = KMeans(n_clusters=K, random_state=42, n_init=10)
    customers['cluster'] = kmeans.fit_predict(X_scaled)

    sil = round(float(silhouette_score(X_scaled, customers['cluster'])), 3)

    # ── PCA for scatter plot ──
    pca = PCA(n_components=2, random_state=42)
    X_pca = pca.fit_transform(X_scaled)
    customers['pca_x'] = X_pca[:, 0]
    customers['pca_y'] = X_pca[:, 1]

    # ── Name clusters based on characteristics ──
    cluster_profiles = customers.groupby('cluster').agg(
        avg_trans=('total_transactions', 'mean'),
        avg_basket=('avg_basket_size', 'mean'),
        avg_unique=('unique_items', 'mean'),
        count=('Member_number', 'count'),
    ).reset_index()

    # Sort by avg_trans descending to assign names
    sorted_profiles = cluster_profiles.sort_values('avg_trans', ascending=False).reset_index(drop=True)

    name_map = {}
    colors = ['#534AB7', '#1D9E75', '#D85A30', '#185FA5']

    # Assign names based on actual characteristics
    median_trans = cluster_profiles['avg_trans'].median()
    median_basket = cluster_profiles['avg_basket'].median()

    used_names = set()
    for _, row in cluster_profiles.iterrows():
        cid = int(row['cluster'])
        high_trans = row['avg_trans'] >= median_trans
        high_basket = row['avg_basket'] >= median_basket

        if high_trans and high_basket and 'Heavy Shoppers' not in used_names:
            name_map[cid] = {'en': 'Heavy Shoppers', 'vi': 'Mua sắm nhiều'}
            used_names.add('Heavy Shoppers')
        elif high_trans and not high_basket and 'Regular Light' not in used_names:
            name_map[cid] = {'en': 'Regular Light', 'vi': 'Thường xuyên (nhỏ)'}
            used_names.add('Regular Light')
        elif not high_trans and high_basket and 'Regular Heavy' not in used_names:
            name_map[cid] = {'en': 'Regular Heavy', 'vi': 'Giỏ hàng lớn'}
            used_names.add('Regular Heavy')
        elif not high_trans and not high_basket and 'Occasional Buyers' not in used_names:
            name_map[cid] = {'en': 'Occasional Buyers', 'vi': 'Mua thỉnh thoảng'}
            used_names.add('Occasional Buyers')
        else:
            # Fallback for edge cases
            remaining = {'Heavy Shoppers', 'Regular Light', 'Regular Heavy', 'Occasional Buyers'} - used_names
            if remaining:
                pick = remaining.pop()
                vi_map = {'Heavy Shoppers': 'Mua sắm nhiều', 'Regular Light': 'Thường xuyên (nhỏ)',
                          'Regular Heavy': 'Giỏ hàng lớn', 'Occasional Buyers': 'Mua thỉnh thoảng'}
                name_map[cid] = {'en': pick, 'vi': vi_map[pick]}
                used_names.add(pick)

    # Assign colors
    for i, cid in enumerate(sorted(name_map.keys())):
        name_map[cid]['color'] = colors[i % len(colors)]

    # ── Build cluster_summary ──
    total_customers = int(len(customers))
    cluster_summary = []
    for _, row in cluster_profiles.iterrows():
        cid = int(row['cluster'])
        info = name_map[cid]
        # Top category for this cluster
        cluster_members = customers[customers['cluster'] == cid]
        top_cat = cluster_members['favourite_category'].value_counts().index[0]
        cluster_summary.append({
            'cluster_id': cid,
            'name_en': info['en'],
            'name_vi': info['vi'],
            'count': int(row['count']),
            'pct': round(float(row['count']) / total_customers * 100, 1),
            'avg_transactions': round(float(row['avg_trans']), 1),
            'avg_basket': round(float(row['avg_basket']), 2),
            'avg_unique_items': round(float(row['avg_unique']), 1),
            'top_category_en': top_cat,
            'top_category_vi': CATEGORY_VI.get(top_cat, top_cat),
            'color': info['color'],
        })

    # Sort by cluster_id for consistency
    cluster_summary.sort(key=lambda x: x['cluster_id'])

    # ── Scatter sample (max 500 points) ──
    sample = customers.sample(n=min(500, len(customers)), random_state=42)
    scatter_sample = []
    for _, row in sample.iterrows():
        scatter_sample.append({
            'x': round(float(row['pca_x']), 3),
            'y': round(float(row['pca_y']), 3),
            'cluster': int(row['cluster']),
        })

    # Biggest & smallest cluster
    biggest = max(cluster_summary, key=lambda x: x['count'])
    smallest = min(cluster_summary, key=lambda x: x['count'])

    result = {
        'cluster_summary': cluster_summary,
        'scatter_sample': scatter_sample,
        'stats': {
            'total_customers': total_customers,
            'silhouette_score': sil,
            'best_k': K,
            'biggest_cluster_en': biggest['name_en'],
            'biggest_cluster_vi': biggest['name_vi'],
            'biggest_count': biggest['count'],
            'smallest_cluster_en': smallest['name_en'],
            'smallest_cluster_vi': smallest['name_vi'],
            'smallest_count': smallest['count'],
        }
    }
    return result


if __name__ == '__main__':
    csv_path = 'd:/Laptrinhmobile_tools/CT KHDL/assets/data/Groceries_dataset.csv'
    df = pd.read_csv(csv_path)
    result = compute_clustering(df)

    out_path = 'd:/Laptrinhmobile_tools/CT KHDL/assets/data/clustering_data.json'
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print('clustering_data.json generated successfully.')
    print(f"Silhouette Score: {result['stats']['silhouette_score']}")
    for c in result['cluster_summary']:
        print(f"  Cluster {c['cluster_id']}: {c['name_en']} — {c['count']} customers ({c['pct']}%)")
