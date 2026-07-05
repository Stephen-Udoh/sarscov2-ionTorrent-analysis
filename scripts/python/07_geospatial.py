#!/usr/bin/env python3
"""
07_geospatial.py — Interactive geospatial map of sample collection sites
Produces: results/figures/geospatial_map.html (interactive)
"""

import folium
import pandas as pd
import os

# State capital coordinates (Nigeria)
STATE_COORDS = {
    "Bauchi":  (10.3158, 9.8442),
    "Kano":    (12.0022, 8.5920),
    "Kaduna":  (10.5264, 7.4384),
}

STATE_COLORS = {
    "Bauchi":  "#2C3E50",
    "Kano":    "#922B21",
    "Kaduna":  "#1E6B52",
}

meta = pd.read_csv("data/metadata/sample_metadata.csv")
qc   = pd.read_csv("results/qc/cohort_qc_summary.csv")
df = meta.merge(qc, left_on="sample_id", right_on="sample")

# Create map centered on Nigeria
m = folium.Map(
    location=[10.0, 8.5],
    zoom_start=6,
    tiles="CartoDB positron"
)

# Add one marker per sample, slightly jittered within state to avoid overlap
import random
random.seed(42)

for _, row in df.iterrows():
    state = row["state"]
    if state not in STATE_COORDS:
        continue
    lat, lon = STATE_COORDS[state]
    # Small jitter so same-state samples don't perfectly overlap
    lat += random.uniform(-0.15, 0.15)
    lon += random.uniform(-0.15, 0.15)

    color = STATE_COLORS.get(state, "#888888")
    popup_text = f"""
    <b>{row['sample_id']}</b><br>
    State: {state}<br>
    Lineage: {row['lineage']}<br>
    Clade: {row['clade']}<br>
    Collection: {row['collection_date']}<br>
    %N: {row['pct_n']}%<br>
    Reads mapped: {row['pct_mapped']}%
    """

    folium.CircleMarker(
        location=[lat, lon],
        radius=8,
        color="white",
        weight=1.5,
        fill=True,
        fill_color=color,
        fill_opacity=0.85,
        popup=folium.Popup(popup_text, max_width=220),
        tooltip=f"{row['sample_id']} — {row['lineage']}"
    ).add_to(m)

# Add state label markers
for state, (lat, lon) in STATE_COORDS.items():
    folium.Marker(
        location=[lat, lon],
        icon=folium.DivIcon(
            html=f'<div style="font-family:Liberation Serif;font-size:11px;font-weight:bold;color:{STATE_COLORS[state]};white-space:nowrap">{state}</div>',
            icon_size=(80, 20),
            icon_anchor=(40, 10)
        )
    ).add_to(m)

os.makedirs("results/figures", exist_ok=True)
m.save("results/figures/geospatial_map.html")
print("✅ Interactive map saved: results/figures/geospatial_map.html")
print("   Open in browser: xdg-open results/figures/geospatial_map.html")
