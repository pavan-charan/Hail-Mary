import pytest
from fastapi import status

def test_citizen_spatial_discovery_and_distance_calculation(client):
    # Reference user location (MG Road Metro Station: 12.9716, 77.5946)
    user_lat = 12.9716
    user_lon = 77.5946

    # 1. Create a close facility (~100m away)
    client.post("/api/v1/facilities", json={
        "name": "MG Road Station Gate 1 Toilet",
        "facility_type": "TOILET",
        "latitude": 12.9720,
        "longitude": 77.5950,
        "address": "Opposite Gate 1",
        "ward": "Ward-12",
        "gender_access": "MALE",
        "wheelchair_accessible": True,
        "water_availability": True,
        "opening_time": "06:00",
        "closing_time": "22:00"
    })

    # 2. Create a distant facility (~2km away)
    client.post("/api/v1/facilities", json={
        "name": "Lalbagh Botanical Garden Restroom",
        "facility_type": "TOILET",
        "latitude": 12.9507,
        "longitude": 77.5848,
        "address": "Near West Gate, Lalbagh",
        "ward": "Ward-144",
        "gender_access": "FEMALE",
        "wheelchair_accessible": False,
        "water_availability": True,
        "opening_time": "06:00",
        "closing_time": "19:00"
    })

    # 3. Create a Drinking Water Point (~400m away)
    client.post("/api/v1/facilities", json={
        "name": "Cubbon Park Filtered Drinking Water",
        "facility_type": "DRINKING_WATER",
        "latitude": 12.9745,
        "longitude": 77.5925,
        "address": "Cubbon Park Walkway 3",
        "ward": "Ward-12",
        "gender_access": "UNISEX",
        "wheelchair_accessible": True,
        "water_availability": True,
        "opening_time": "05:00",
        "closing_time": "21:00"
    })

    # 4. Query discovery with user coordinates
    resp = client.get(f"/api/v1/facilities?user_lat={user_lat}&user_lon={user_lon}")
    assert resp.status_code == status.HTTP_200_OK
    facilities = resp.json()
    assert len(facilities) >= 3

    # Closest facility must be first (sorted by distance)
    assert facilities[0]["distance_meters"] is not None
    assert facilities[0]["walking_time_minutes"] is not None
    assert facilities[0]["distance_meters"] <= facilities[1]["distance_meters"]

def test_citizen_multi_attribute_filtering(client):
    user_lat = 12.9716
    user_lon = 77.5946

    # Filter: Drinking Water only
    water_resp = client.get(f"/api/v1/facilities?user_lat={user_lat}&user_lon={user_lon}&facility_type=DRINKING_WATER")
    assert water_resp.status_code == status.HTTP_200_OK
    water_items = water_resp.json()
    for item in water_items:
        assert item["facility_type"] == "DRINKING_WATER"

    # Filter: Wheelchair Accessible only
    wheelchair_resp = client.get(f"/api/v1/facilities?user_lat={user_lat}&user_lon={user_lon}&wheelchair_only=true")
    assert wheelchair_resp.status_code == status.HTTP_200_OK
    wheelchair_items = wheelchair_resp.json()
    for item in wheelchair_items:
        assert item["wheelchair_accessible"] is True

    # Filter: Gender Access (Female only)
    female_resp = client.get(f"/api/v1/facilities?gender_access=FEMALE")
    assert female_resp.status_code == status.HTTP_200_OK
    female_items = female_resp.json()
    for item in female_items:
        assert item["gender_access"] == "FEMALE"

    # Filter: Distance Radius Threshold (< 500m)
    nearby_resp = client.get(f"/api/v1/facilities?user_lat={user_lat}&user_lon={user_lon}&max_distance_meters=500")
    assert nearby_resp.status_code == status.HTTP_200_OK
    nearby_items = nearby_resp.json()
    for item in nearby_items:
        assert item["distance_meters"] <= 500.0
