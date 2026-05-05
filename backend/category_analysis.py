import pandas as pd
import json

# ── Category mapping ──
CATEGORY_RULES = {
    'Dairy': [
        'whole milk', 'yogurt', 'whipped/sour cream', 'butter', 'cream cheese',
        'curd', 'butter milk', 'processed cheese', 'hard cheese', 'soft cheese',
        'sliced cheese', 'domestic eggs', 'UHT-milk', 'dessert', 'cream',
        'condensed milk', 'coffee creamer', 'white wine', 'specialty cheese',
    ],
    'Produce': [
        'other vegetables', 'root vegetables', 'tropical fruit', 'citrus fruit',
        'pip fruit', 'fruit/vegetable juice', 'frozen vegetables', 'herbs',
        'mushroom', 'onions', 'berries', 'grapes', 'packaged fruit/vegetables',
    ],
    'Bakery': [
        'rolls/buns', 'pastry', 'brown bread', 'white bread', 'specialty chocolate',
        'chocolate', 'candy', 'chewing gum', 'sugar', 'flour', 'waffles',
    ],
    'Beverages': [
        'soda', 'bottled water', 'bottled beer', 'canned beer', 'red/blush wine',
        'coffee', 'beverages', 'sparkling wine', 'liquor', 'liquor (appetizer)',
        'tea', 'instant coffee',
    ],
    'Meat': [
        'sausage', 'pork', 'beef', 'chicken', 'frankfurter', 'hamburger meat',
        'meat', 'ham', 'fish', 'canned fish', 'turkey',
    ],
}

ITEM_TO_CAT = {}
for cat, items in CATEGORY_RULES.items():
    for item in items:
        ITEM_TO_CAT[item.lower().strip()] = cat

COLORS = {
    'Dairy': '#378ADD', 'Produce': '#1D9E75', 'Bakery': '#D4A017',
    'Beverages': '#534AB7', 'Meat': '#D85A30', 'Other': '#5F5E5A',
}

CAT_VI = {
    'Dairy': 'Sữa & Trứng', 'Produce': 'Rau & Trái cây', 'Bakery': 'Bánh & Ngọt',
    'Beverages': 'Đồ uống', 'Meat': 'Thịt & Cá', 'Other': 'Khác',
}


def get_cat(item):
    return ITEM_TO_CAT.get(item.lower().strip(), 'Other')


def compute_category_analysis(df):
    df['Date'] = pd.to_datetime(df['Date'], format='%d-%m-%Y', errors='coerce')
    df = df.dropna(subset=['Date'])
    df['Category'] = df['itemDescription'].apply(get_cat)
    df['YearMonth'] = df['Date'].dt.to_period('M')

    total_all = len(df)

    # ── Per-category stats ──
    cat_counts = df['Category'].value_counts()
    sorted_months = sorted(df['YearMonth'].unique())

    categories = []
    for cat_name in ['Dairy', 'Produce', 'Bakery', 'Beverages', 'Meat', 'Other']:
        cat_df = df[df['Category'] == cat_name]
        total = int(cat_counts.get(cat_name, 0))
        pct = round(total / total_all * 100, 1)
        unique_products = int(cat_df['itemDescription'].nunique())

        # Top 3 products
        top3_raw = cat_df['itemDescription'].value_counts().head(3)
        top_3 = []
        for prod_name, prod_count in top3_raw.items():
            top_3.append({
                'name': prod_name,
                'count': int(prod_count),
                'pct_in_category': round(prod_count / total * 100, 1) if total > 0 else 0,
            })

        # Monthly trend (24 months)
        monthly = cat_df.groupby('YearMonth').size()
        monthly_trend = []
        for ym in sorted_months:
            monthly_trend.append(int(monthly.get(ym, 0)))

        categories.append({
            'name_en': cat_name,
            'name_vi': CAT_VI[cat_name],
            'total': total,
            'pct': pct,
            'unique_products': unique_products,
            'top_3': top_3,
            'monthly_trend': monthly_trend,
            'color': COLORS[cat_name],
        })

    # Sort descending by total
    categories.sort(key=lambda x: x['total'], reverse=True)

    # ── Top 20 products overall ──
    top20_raw = df['itemDescription'].value_counts().head(20)
    top_products = []
    for name, count in top20_raw.items():
        top_products.append({
            'name': name,
            'category_en': get_cat(name),
            'category_vi': CAT_VI.get(get_cat(name), get_cat(name)),
            'count': int(count),
            'pct': round(count / total_all * 100, 1),
        })

    # ── Stats ──
    most_popular = categories[0]

    # Fastest growing: compare H2/2015 vs H2/2014
    # H2 = Jul-Dec
    df['Year'] = df['Date'].dt.year
    df['Half'] = df['Date'].dt.month.apply(lambda m: 'H2' if m >= 7 else 'H1')

    h2_2014 = df[(df['Year'] == 2014) & (df['Half'] == 'H2')]
    h2_2015 = df[(df['Year'] == 2015) & (df['Half'] == 'H2')]

    growth_rates = {}
    for cat_name in ['Dairy', 'Produce', 'Bakery', 'Beverages', 'Meat', 'Other']:
        c14 = len(h2_2014[h2_2014['Category'] == cat_name])
        c15 = len(h2_2015[h2_2015['Category'] == cat_name])
        if c14 > 0:
            growth_rates[cat_name] = round((c15 - c14) / c14 * 100, 1)
        else:
            growth_rates[cat_name] = 0.0

    fastest = max(growth_rates, key=growth_rates.get)

    # Month labels
    month_labels_vi = [str(ym).replace('-', '/') for ym in sorted_months]
    month_labels_en = month_labels_vi  # Same format

    # Top product overall
    top1 = top_products[0] if top_products else {}

    result = {
        'categories': categories,
        'top_products_overall': top_products,
        'month_labels': month_labels_vi,
        'stats': {
            'total_transactions': total_all,
            'most_popular_en': most_popular['name_en'],
            'most_popular_vi': most_popular['name_vi'],
            'most_popular_count': most_popular['total'],
            'fastest_growing_en': fastest,
            'fastest_growing_vi': CAT_VI[fastest],
            'fastest_growth_pct': growth_rates[fastest],
            'top_product': top1.get('name', ''),
            'top_product_count': top1.get('count', 0),
        },
    }
    return result


if __name__ == '__main__':
    csv_path = 'd:/Laptrinhmobile_tools/CT KHDL/assets/data/Groceries_dataset.csv'
    df = pd.read_csv(csv_path)
    result = compute_category_analysis(df)

    out_path = 'd:/Laptrinhmobile_tools/CT KHDL/assets/data/category_data.json'
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print('category_data.json generated successfully.')
    for c in result['categories']:
        print(f"  {c['name_en']}: {c['total']} ({c['pct']}%)")
