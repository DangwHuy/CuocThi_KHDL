import pandas as pd
import json
from mlxtend.preprocessing import TransactionEncoder
from mlxtend.frequent_patterns import fpgrowth
from mlxtend.frequent_patterns import association_rules

def main():
    print("1. Đang tải dữ liệu...")
    df = pd.read_csv('../assets/data/Groceries_dataset.csv')
    print(f"Đã tải xong: {df.shape[0]} dòng dữ liệu.")

    print("\n2. Tiền xử lý dữ liệu (Cleaning & Transformation)...")
    df.dropna(subset=['itemDescription'], inplace=True)
    df['itemDescription'] = df['itemDescription'].str.strip().str.lower()
    df['Date'] = pd.to_datetime(df['Date'], format='%d-%m-%Y', errors='coerce')
    
    print("\n3. Thực hiện EDA & Trích chọn đặc trưng (Feature Engineering)...")
    
    # --- EDA SECTION ---
    eda_data = {}
    # All Items Count (for Data Explorer)
    eda_data['all_items'] = df['itemDescription'].value_counts().to_dict()
    # Top 10 (for Dashboard)
    eda_data['top_items'] = df['itemDescription'].value_counts().head(10).to_dict()
    
    # Monthly Trend
    df['MonthYear'] = df['Date'].dt.strftime('%Y-%m')
    eda_data['monthly_trend'] = df.groupby('MonthYear')['itemDescription'].count().to_dict()
    
    # Basket Sizes
    basket_sizes = df.groupby(['Member_number', 'Date'])['itemDescription'].count()
    size_counts = basket_sizes.value_counts().to_dict()
    grouped_sizes = {"1": 0, "2": 0, "3": 0, "4": 0, "5+": 0}
    for size, count in size_counts.items():
        if size == 1: grouped_sizes["1"] += count
        elif size == 2: grouped_sizes["2"] += count
        elif size == 3: grouped_sizes["3"] += count
        elif size == 4: grouped_sizes["4"] += count
        else: grouped_sizes["5+"] += count
    eda_data['basket_sizes'] = grouped_sizes

    with open('../assets/data/eda_results.json', 'w', encoding='utf-8') as f:
        json.dump(eda_data, f, ensure_ascii=False, indent=2)
    print("Đã xuất dữ liệu EDA ra file eda_results.json")
    # --- END EDA ---

    df_unique = df.drop_duplicates(subset=['Member_number', 'Date', 'itemDescription'])
    basket = df_unique.groupby(['Member_number', 'Date'])['itemDescription'] \
               .apply(list) \
               .tolist()
    
    print("Đang mã hóa giỏ hàng (TransactionEncoder)...")
    te = TransactionEncoder()
    te_ary = te.fit(basket).transform(basket)
    basket_ohe = pd.DataFrame(te_ary, columns=te.columns_)

    print(f"Kích thước ma trận giỏ hàng: {basket_ohe.shape}")

    print("\n4. Huấn luyện mô hình AI/ML (FP-Growth)...")
    frequent_itemsets = fpgrowth(basket_ohe, min_support=0.001, use_colnames=True)
    print(f"Tìm thấy {len(frequent_itemsets)} tập phổ biến.")

    print("Đang tạo các Luật kết hợp (Association Rules)...")
    rules = association_rules(frequent_itemsets, metric="lift", min_threshold=1.0)
    rules = rules.sort_values(['lift', 'confidence'], ascending=[False, False])
    print(f"Tạo thành công {len(rules)} quy luật mua sắm.")

    print("\n5. Phân tích Insight & Lưu kết quả...")
    recommendations = {}
    for _, row in rules.iterrows():
        antecedents = list(row['antecedents'])
        consequents = list(row['consequents'])
        
        # Chỉ lấy luật 1-đổi-1 cho đơn giản trong demo
        if len(antecedents) == 1 and len(consequents) == 1:
            item_a = antecedents[0]
            item_b = consequents[0]
            if item_a not in recommendations:
                recommendations[item_a] = []
            
            rec = {
                "recommend": item_b,
                "confidence": round(row['confidence'], 3),
                "lift": round(row['lift'], 3)
            }
            if len(recommendations[item_a]) < 5:
                recommendations[item_a].append(rec)

    output_path = '../assets/data/recommendations.json'
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(recommendations, f, ensure_ascii=False, indent=2)
    
    print(f"Đã lưu bộ máy gợi ý vào: {output_path}")
    print("Quy trình Data Science hoàn tất xuất sắc!")

if __name__ == '__main__':
    main()
