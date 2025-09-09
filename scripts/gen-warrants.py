#!/usr/bin/env python3
import json, random, uuid, sys
from datetime import datetime, timedelta

INDEX = sys.argv[1] if len(sys.argv) > 1 else "warrants"
COUNT = int(sys.argv[2]) if len(sys.argv) > 2 else 20

random.seed(42)

titles = [
    "Search Warrant",
    "Arrest Warrant",
    "Bench Warrant",
    "Extradition Warrant",
    "No-Knock Warrant",
    "Wiretap Warrant",
    "Seizure Warrant",
    "Inspection Warrant",
]

jurisdictions = ["CA-LA", "CA-SF", "NY-NYC", "TX-AUS", "WA-SEA", "IL-CHI", "FL-MIA", "MA-BOS"]
statuses = ["pending", "active", "executed", "revoked", "expired"]
officers = [
    "Det. Sarah Collins",
    "Sgt. Mark Rivera",
    "Ofc. Priya Patel",
    "Det. Liam O'Connor",
    "Sgt. Mei Chen",
    "Det. Carlos Alvarez",
]
subjects = [
    "John Doe", "Jane Smith", "Alex Johnson", "Maria Garcia",
    "David Lee", "Emily Davis", "Michael Brown", "Sophia Wilson",
]
streets = [
    "123 Elm St", "456 Oak Ave", "789 Pine Rd", "321 Maple Blvd",
    "654 Cedar Ln", "987 Birch Way", "741 Spruce Ct", "852 Walnut Dr",
]
tags_pool = ["narcotics", "fraud", "theft", "homicide", "cyber", "financial", "fugitives", "wiretap"]

now = datetime.utcnow()

# Base coordinates for each jurisdiction (approx city centers)
jurisdiction_coords = {
    "CA-LA": (34.0522, -118.2437),   # Los Angeles
    "CA-SF": (37.7749, -122.4194),   # San Francisco
    "NY-NYC": (40.7128, -74.0060),   # New York
    "TX-AUS": (30.2672, -97.7431),   # Austin
    "WA-SEA": (47.6062, -122.3321),  # Seattle
    "IL-CHI": (41.8781, -87.6298),   # Chicago
    "FL-MIA": (25.7617, -80.1918),   # Miami
    "MA-BOS": (42.3601, -71.0589),   # Boston
}

def rand_date(start_days_ago=120, span_days=180):
    start = now - timedelta(days=start_days_ago)
    dt = start + timedelta(days=random.randint(0, span_days), hours=random.randint(0,23), minutes=random.randint(0,59))
    return dt.replace(microsecond=0).isoformat() + "Z"

def build_doc():
    issue = rand_date()
    expiry = datetime.fromisoformat(issue.replace("Z", "")) + timedelta(days=random.randint(7, 90))
    status = random.choice(statuses)
    pri = random.randint(1, 5)
    amount = round(random.uniform(500.0, 50000.0), 2)

    j = random.choice(jurisdictions)
    base_lat, base_lon = jurisdiction_coords[j]
    # small jitter ~ up to ~1.5km
    jitter_lat = (random.random() - 0.5) * 0.03
    jitter_lon = (random.random() - 0.5) * 0.03
    lat = round(base_lat + jitter_lat, 6)
    lon = round(base_lon + jitter_lon, 6)

    return {
        "warrant_id": str(uuid.uuid4()),
        "title": random.choice(titles),
        "description": "Auto-generated sample warrant for development/testing.",
        "status": status,
        "issue_date": issue,
        "expiry_date": expiry.isoformat() + "Z",
        "jurisdiction": j,
        "officer": random.choice(officers),
        "subject_name": random.choice(subjects),
        "subject_address": random.choice(streets),
        # Geo point usable in filters, distance queries, and Maps
        "subject_location": {"lat": lat, "lon": lon},
        "tags": random.sample(tags_pool, k=random.randint(1, 3)),
        "priority": pri,
        "amount": amount
    }

for _ in range(COUNT):
    doc = build_doc()
    meta = {"index": {"_index": INDEX, "_id": doc["warrant_id"]}}
    print(json.dumps(meta))
    print(json.dumps(doc))
