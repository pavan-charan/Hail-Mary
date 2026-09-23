import requests
import json

def fetch_kochi_osm_facilities():
    # Bounding box for Kochi Municipal Area: [south, west, north, east]
    # approx (9.88, 76.20, 10.08, 76.40)
    endpoints = [
        "https://overpass.kumi.systems/api/interpreter",
        "https://overpass-api.de/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    ]
    
    headers = {
        "User-Agent": "KochiCivicSanitationApp/1.0 (contact: info@kmc.gov.in)"
    }
    
    query = """
    [out:json][timeout:25];
    (
      node["amenity"="toilets"](9.88,76.20,10.08,76.40);
      way["amenity"="toilets"](9.88,76.20,10.08,76.40);
      node["amenity"="drinking_water"](9.88,76.20,10.08,76.40);
      way["amenity"="drinking_water"](9.88,76.20,10.08,76.40);
    );
    out center;
    """
    
    for endpoint in endpoints:
        try:
            response = requests.post(endpoint, data={"data": query}, headers=headers, timeout=25)
            if response.status_code == 200:
                data = response.json()
                elements = data.get("elements", [])
                print(f"Successfully fetched {len(elements)} real facilities from {endpoint}!")
                return elements
            else:
                print(f"Endpoint {endpoint} returned status {response.status_code}")
        except Exception as e:
            print(f"Failed on {endpoint}: {e}")
    return []

if __name__ == "__main__":
    elements = fetch_kochi_osm_facilities()
    for i, el in enumerate(elements[:15]):
        lat = el.get("lat") or el.get("center", {}).get("lat")
        lon = el.get("lon") or el.get("center", {}).get("lon")
        tags = el.get("tags", {})
        print(f"{i+1}. {tags.get('name', 'Public Facility')} | Type: {tags.get('amenity', tags.get('man_made'))} | Lat: {lat}, Lon: {lon} | Tags: {tags}")
