from __future__ import annotations

import json
import math
from dataclasses import dataclass
from typing import Any
from urllib import error, parse, request


@dataclass(frozen=True)
class NearestPlace:
    name: str
    address: str
    latitude: float
    longitude: float
    distance_meters: int
    maps_url: str
    maps_fallback_url: str


class GooglePlacesClient:
    """Simple Google Places nearby search client."""

    def __init__(self, api_key: str, radius_meters: int = 3000, timeout_seconds: int = 15) -> None:
        self._api_key = api_key
        self._radius_meters = radius_meters
        self._timeout_seconds = timeout_seconds

    def find_nearest(self, latitude: float, longitude: float, place_type: str) -> NearestPlace | None:
        if not self._api_key:
            raise RuntimeError("GOOGLE_PLACES_API_KEY is not configured.")

        payload = {
            "includedTypes": [place_type],
            "maxResultCount": 20,
            "rankPreference": "DISTANCE",
            "locationRestriction": {
                "circle": {
                    "center": {
                        "latitude": latitude,
                        "longitude": longitude,
                    },
                    "radius": float(self._radius_meters),
                }
            },
        }
        url = "https://places.googleapis.com/v1/places:searchNearby"

        req = request.Request(
            url=url,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "X-Goog-Api-Key": self._api_key,
                "X-Goog-FieldMask": "places.id,places.displayName,places.formattedAddress,places.location",
            },
            method="POST",
        )
        try:
            with request.urlopen(req, timeout=self._timeout_seconds) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"Google Places request failed with HTTP {exc.code}: {detail}"
            ) from exc
        except error.URLError as exc:
            raise RuntimeError(f"Could not reach Google Places API: {exc}") from exc

        results = payload.get("places", [])
        candidates: list[NearestPlace] = []
        for item in results:
            candidate = self._to_place(item, latitude, longitude)
            if candidate is not None:
                candidates.append(candidate)

        if not candidates:
            return None

        return min(candidates, key=lambda p: p.distance_meters)

    @staticmethod
    def _to_place(item: dict[str, Any], user_lat: float, user_lng: float) -> NearestPlace | None:
        location = item.get("location", {})
        lat = location.get("latitude")
        lng = location.get("longitude")
        if not isinstance(lat, (float, int)) or not isinstance(lng, (float, int)):
            return None

        display_name = item.get("displayName")
        if isinstance(display_name, dict):
            name = str(display_name.get("text", "Unknown place"))
        else:
            name = "Unknown place"

        address = str(item.get("formattedAddress") or "Address unavailable")
        place_id = str(item.get("id", "")).strip()
        distance = _haversine_meters(user_lat, user_lng, float(lat), float(lng))
        query = f"{float(lat)},{float(lng)}"
        if place_id:
            maps_url = (
                "https://www.google.com/maps/search/?api=1"
                f"&query={parse.quote_plus(query)}"
                f"&query_place_id={parse.quote_plus(place_id)}"
            )
        else:
            maps_url = (
                "https://www.google.com/maps/search/?api=1"
                f"&query={parse.quote_plus(query)}"
            )

        maps_fallback_url = f"https://maps.google.com/?q={parse.quote_plus(query)}"

        return NearestPlace(
            name=name,
            address=address,
            latitude=float(lat),
            longitude=float(lng),
            distance_meters=int(distance),
            maps_url=maps_url,
            maps_fallback_url=maps_fallback_url,
        )


def _haversine_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius = 6_371_000.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lon2 - lon1)

    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return radius * c
