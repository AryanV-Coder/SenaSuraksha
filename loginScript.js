const map = L.map("map").setView([28.6139, 77.209], 13); // New Delhi

L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
  attribution: "&copy; OpenStreetMap contributors",
}).addTo(map);

L.marker([34.0806, 74.0491]).addTo(map).bindPopup("Uri ").openPopup();
