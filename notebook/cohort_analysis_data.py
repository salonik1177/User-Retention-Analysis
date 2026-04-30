import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# Configuration
num_users = 5000
start_date = datetime(2024, 1, 1)

data = []
for i in range(num_users):
    u_id = f"USR-{10000 + i}"
    # Assign a random signup month (Cohort)
    cohort_offset = np.random.randint(0, 12)
    cohort_month = start_date + timedelta(days=31 * cohort_offset)
    cohort_str = cohort_month.strftime('%Y-%m')
    
    # Simulate retention: users stay for a random number of months (decaying probability)
    tenure = int(np.random.exponential(scale=5)) + 1
    tenure = min(tenure, 12) # Limit to 1 year of tracking
    
    for month_idx in range(tenure):
        activity_month = cohort_month + timedelta(days=31 * month_idx)
        # Add multiple transaction rows per user per month to hit the 50k row target
        num_transactions = np.random.randint(8, 15) 
        
        for _ in range(num_transactions):
            data.append({
                "User_ID": u_id,
                "Cohort_Month": cohort_str,
                "Activity_Month": activity_month.strftime('%Y-%m'),
                "Month_Distance": month_idx,
                "Transaction_Value": round(np.random.uniform(10.0, 100.0), 2),
                "Platform": np.random.choice(["iOS", "Android", "Web"])
            })

# Create DataFrame and Save
df = pd.DataFrame(data)
df = df.iloc[:55000] # Trim to a clean 55,000 rows
df.to_csv("user_retention_data.csv", index=False)
print(f"Dataset generated with {len(df)} rows.")