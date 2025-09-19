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

# Focus on Chattanooga (TN), Dalton (GA), and Atlanta (GA)
cities = {
    "TN-CHA": {"city": "Chattanooga", "state": "TN", "coords": (35.0456, -85.3097)},
    "GA-DAL": {"city": "Dalton",      "state": "GA", "coords": (34.7698, -84.9702)},
    "GA-ATL": {"city": "Atlanta",      "state": "GA", "coords": (33.7490, -84.3880)},
}
jurisdictions = list(cities.keys())
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

# Crime categories and severity mapping
violent_crimes = [
    "homicide", "aggravated assault", "armed robbery", "kidnapping", "sexual assault"
]
property_crimes = [
    "burglary", "larceny", "fraud", "auto theft", "vandalism"
]
low_level_crimes = [
    "drug possession", "disorderly conduct", "trespassing", "public intoxication", "traffic violation"
]

def pick_crime():
    # Weighted distribution: High 20%, Medium 50%, Low 30%
    r = random.random()
    if r < 0.2:
        crime = random.choice(violent_crimes)
        severity = "High"
        priority = 5
        amount = round(random.uniform(10000.0, 100000.0), 2)
        category = "violent"
    elif r < 0.7:
        crime = random.choice(property_crimes)
        severity = "Medium"
        priority = 3
        amount = round(random.uniform(2000.0, 20000.0), 2)
        category = "property"
    else:
        crime = random.choice(low_level_crimes)
        severity = "Low"
        priority = 1
        amount = round(random.uniform(100.0, 2000.0), 2)
        category = "low-level"
    return crime, severity, priority, amount, category

now = datetime.utcnow()

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
    city_info = cities[j]
    base_lat, base_lon = city_info["coords"]
    # small jitter ~ up to ~3km
    jitter_lat = (random.random() - 0.5) * 0.06
    jitter_lon = (random.random() - 0.5) * 0.06
    lat = round(base_lat + jitter_lat, 6)
    lon = round(base_lon + jitter_lon, 6)

    crime, severity, pri, amount, category = pick_crime()

    # Issuing agency can be from TN or GA, intermix across cities
    issuers = [
        ("TN", "Chattanooga PD"),
        ("TN", "Tennessee Highway Patrol"),
        ("GA", "Atlanta PD"),
        ("GA", "Dalton PD"),
        ("GA", "Georgia State Patrol"),
    ]
    issuing_state, issuing_agency = random.choice(issuers)

    return {
        "warrant_id": str(uuid.uuid4()),
        "title": random.choice(titles),
        "description": "Auto-generated sample warrant for development/testing.",
        "status": status,
        "issue_date": issue,
        "expiry_date": expiry.isoformat() + "Z",
        "jurisdiction": j,
        "city": city_info["city"],
        "state": city_info["state"],
        "officer": random.choice(officers),
        "subject_name": random.choice(subjects),
        "subject_address": random.choice(streets),
        # Geo point usable in filters, distance queries, and Maps
        "subject_location": {"lat": lat, "lon": lon},
        "issuing_state": issuing_state,
        "issuing_agency": issuing_agency,
        "crime": crime,
        "severity": severity,
        "crime_category": category,
        "tags": random.sample(tags_pool, k=random.randint(1, 3)),
        "priority": pri,
        "amount": amount
    }

for _ in range(COUNT):
    doc = build_doc()
    meta = {"index": {"_index": INDEX, "_id": doc["warrant_id"]}}
    print(json.dumps(meta))
    print(json.dumps(doc))
