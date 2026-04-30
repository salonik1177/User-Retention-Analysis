import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.linear_model import LinearRegression

# 1. SETUP: We'll use the data you found in SQL (Averages across cohorts)
data = {
    'month_distance': [0, 1, 2, 3, 4, 5],
    'retention_rate': [1.0, 0.82, 0.75, 0.68, 0.62, 0.58], # Example rates from your SQL
    'cumulative_clv': [52.10, 98.45, 142.10, 185.30, 224.90, 260.15] # Your SQL Running Total
}
df = pd.DataFrame(data)

# --- STEP 1: RETENTION CURVE ---
plt.figure(figsize=(10, 5))
plt.plot(df['month_distance'], df['retention_rate'] * 100, marker='o', color='blue', linewidth=2)
plt.title('Customer Retention Curve (The "Line of Life")')
plt.xlabel('Months Since Sign-up')
plt.ylabel('Percentage of Users Remaining (%)')
plt.grid(True, linestyle='--', alpha=0.7)
plt.show()

# --- STEP 3: CLV FORECASTING (12 MONTHS) ---
# Prepare the model
X = df[['month_distance']] # Input: Month number
y = df['cumulative_clv']    # Output: $ Spent

model = LinearRegression()
model.fit(X, y)

# Predict for future months (6 to 12)
future_months = np.array(range(0, 13)).reshape(-1, 1)
predictions = model.predict(future_months)

# Visualize the Forecast
plt.figure(figsize=(10, 5))
plt.scatter(df['month_distance'], y, color='black', label='Actual Data')
plt.plot(future_months, predictions, color='red', linestyle='--', label='12-Month Forecast')
plt.title('12-Month Customer Lifetime Value Projection')
plt.xlabel('Month')
plt.ylabel('Cumulative Revenue per User ($)')
plt.legend()
plt.show()

print(f"Predicted CLV at 12 Months: ${predictions[12]:.2f}")