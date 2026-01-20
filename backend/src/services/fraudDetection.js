"use strict";

/**
 * Calculates the great-circle distance between two points on the Earth's surface.
 * Uses the Haversine formula.
 * @param {number} lat1 Latitude of point 1
 * @param {number} lon1 Longitude of point 1
 * @param {number} lat2 Latitude of point 2
 * @param {number} lon2 Longitude of point 2
 * @returns {number} Distance in kilometers
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Radius of the Earth in km
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) *
      Math.cos(lat2 * (Math.PI / 180)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Parses a location string "lat, long" into numbers.
 * @param {string} locString
 * @returns {{lat: number, lon: number} | null}
 */
function parseLocation(locString) {
  if (!locString || typeof locString !== "string") return null;
  const parts = locString.split(",").map((s) => parseFloat(s.trim()));
  if (parts.length !== 2 || isNaN(parts[0]) || isNaN(parts[1])) return null;
  return { lat: parts[0], lon: parts[1] };
}

/**
 * Detects anomalies based on the previous hop and the new hop attempt.
 * @param {object} previousHop The last recorded hop { location: "lat,lon", timestamp: number }
 * @param {string} newLocationStr The new location string "lat,lon"
 * @param {number} newTimestamp current timestamp in seconds
 * @returns {string[]} Array of flag strings (e.g. ["IMPOSSIBLE_TRAVEL"])
 */
function detectFraud(previousHop, newLocationStr, newTimestamp) {
  const flags = [];
  
  // 1. Basic Validation
  if (!previousHop || !previousHop.location) return flags; // First hop or missing data, can't check

  const prevLoc = parseLocation(previousHop.location);
  const newLoc = parseLocation(newLocationStr);

  if (!prevLoc || !newLoc) return flags; // Invalid format, skip check

  // 2. Calculate Distance (km)
  const distanceKm = calculateDistance(prevLoc.lat, prevLoc.lon, newLoc.lat, newLoc.lon);

  // 3. Calculate Time Difference (hours)
  // Timestamps are in seconds usually (from blockchain/block.timestamp)
  // Ensure we handle both ms (JS Date) and s (Solidity) carefully. 
  // We assume inputs are unified to Seconds.
  let timeDiffSeconds = newTimestamp - previousHop.timestamp;
  
  // Edge case: if timeDiff is negative or zero (concurrent scans), handle it
  if (timeDiffSeconds <= 0) timeDiffSeconds = 1; // avoid division by zero

  const timeDiffHours = timeDiffSeconds / 3600;

  // 4. Calculate Speed (km/h)
  const speed = distanceKm / timeDiffHours;

  // 5. Rules

  // Rule A: "Impossible Travel" (Supersonic speed)
  // Commercial planes fly ~900 km/h. Let's be generous and say 1200 km/h is max feasible 
  // (fast plane + airport processing, even though that takes longer).
  // If speed > 1500 km/h, it's definitely an anomaly (teleportation).
  // Exception: if distance is very small (< 1km) GPS drift might cause high calculated speed over tiny time bounds.
  if (distanceKm > 5 && speed > 1500) {
    flags.push("IMPOSSIBLE_TRAVEL");
    console.log(`[Fraud] IMPOSSIBLE_TRAVEL detected! Distance: ${distanceKm.toFixed(2)}km, Time: ${timeDiffHours.toFixed(4)}h, Speed: ${speed.toFixed(2)} km/h`);
  }

  // Rule B: "Simultaneous Scan"
  // If distance is significant (> 100km) but time diff is tiny (< 10 mins)
  if (distanceKm > 100 && timeDiffHours < (10/60)) {
     flags.push("SIMULTANEOUS_SCAN");
     console.log(`[Fraud] SIMULTANEOUS_SCAN detected! Distance: ${distanceKm.toFixed(2)}km in < 10 mins`);
  }

  return flags;
}

module.exports = {
  detectFraud,
  calculateDistance
};
