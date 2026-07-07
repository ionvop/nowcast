const panelTitle = document.getElementById("panelTitle");
const btnReload = document.getElementById("btnReload");
const pageLoader = document.getElementById("pageLoader");
const panelLoader = document.getElementById("panelLoader");
const pageHome = document.getElementById("pageHome");
const panelWeather = document.getElementById("panelWeather");
const imgWeather = document.getElementById("imgWeather");
const panelTemp = document.getElementById("panelTemp");
const panelCity = document.getElementById("panelCity");
const panelForecast = document.getElementById("panelForecast");
const pageHeat = document.getElementById("pageHeat");
const canvasGraph = document.getElementById("canvasGraph");
const pageMap = document.getElementById("pageMap");
const panelMap = document.getElementById("panelMap");
const tabHome = document.getElementById("tabHome");
const tabHeat = document.getElementById("tabHeat");
const tabMap = document.getElementById("tabMap");
const tabCommunity = document.getElementById("tabCommunity");
const tabProfile = document.getElementById("tabProfile");
let chartGraph;
let controller;
let currentPage = "home";

(async () => {
    openPage("home");

    const position = await new Promise((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(resolve, reject);
    });
})();

btnReload.onclick = () => {
    openPage(currentPage);
}

tabHome.onclick = () => {
    openPage("home");
}

tabHeat.onclick = () => {
    openPage("heat");
}

tabMap.onclick = () => {
    openPage("map");
}

tabCommunity.onclick = () => {
    openPage("community");
}

tabProfile.onclick = () => {
    openPage("profile");
}

async function openPage(page) {
    controller?.abort();
    controller = new AbortController();
    const signal = controller.signal;
    panelLoader.textContent = "Loading...";

    for (const page of [pageLoader, pageHome, pageHeat, pageMap]) {
        page.style.display = "none";
    }
    
    for (const tab of [tabHome, tabHeat, tabMap, tabCommunity, tabProfile]) {
        tab.style.color = "#555";
    }

    switch (page) {
        case "home": {
            pageLoader.style.display = "flex";
            tabHome.style.color = "var(--theme)";
            panelTitle.textContent = "Home";
            currentPage = "home";

            const position = await new Promise((resolve, reject) => {
                navigator.geolocation.getCurrentPosition(resolve, reject);
            });

            const latitude = position.coords.latitude;
            const longitude = position.coords.longitude;

            {
                panelLoader.textContent = "Loading weather... (1/3)";

                const response = await fetch("api/?action=weather", {
                    method: "post",
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({
                        latitude,
                        longitude
                    }),
                    signal
                });

                const data = await response.json();
                console.log(data);
                panelWeather.textContent = data.weatherCondition.description.text;
                imgWeather.src = data.weatherCondition.iconBaseUri + ".svg";
                panelTemp.textContent = `${data.temperature.degrees}°C`;
            }

            {
                panelLoader.textContent = "Loading city... (2/3)";

                const response = await fetch("api/?action=geocode", {
                    method: "post",
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({
                        latitude,
                        longitude
                    }),
                    signal
                });

                const data = await response.json();
                console.log(data);
                panelCity.textContent = data.results[0].formattedAddress;
            }

            {
                panelLoader.textContent = "Loading forecast... (3/3)";

                const response = await fetch("api/?action=forecast", {
                    method: "post",
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({
                        latitude,
                        longitude
                    }),
                    signal
                });

                const data = await response.json();
                console.log(data);
                panelForecast.innerHTML = "";

                for (const forecast of data.forecastHours) {
                    panelForecast.innerHTML += /*html*/`
                        <div style="
                            padding: 1rem;
                            padding-left: 0rem;
                            padding-top: 0rem;">
                            <div style="
                                background-color: var(--theme);
                                border-radius: 1rem;">
                                <div style="
                                    padding: 1rem;
                                    text-align: center;">
                                    ${convertHour(forecast.displayDateTime.hours)}
                                </div>
                                <div style="
                                    padding: 1rem;
                                    padding-top: 0rem;
                                    text-align: center;">
                                    <img style="
                                        width: 3rem;
                                        height: 3rem;
                                        object-fit: contain;"
                                        src="${forecast.weatherCondition.iconBaseUri}_dark.svg">
                                </div>
                                <div style="
                                    padding: 1rem;
                                    padding-top: 0rem;
                                    text-align: center;">
                                    ${forecast.temperature.degrees}&deg;C
                                </div>
                            </div>
                        </div>
                    `;
                }
            }

            pageLoader.style.display = "none";
            pageHome.style.display = "block";
        } break;
        case "heat": {
            pageLoader.style.display = "flex";
            tabHeat.style.color = "var(--theme)";
            panelTitle.textContent = "Heat Data";
            currentPage = "heat";

            const position = await new Promise((resolve, reject) => {
                navigator.geolocation.getCurrentPosition(resolve, reject);
            });

            const latitude = position.coords.latitude;
            const longitude = position.coords.longitude;

            {
                panelLoader.textContent = "Loading data...";

                const response = await fetch("api/?action=forecast", {
                    method: "post",
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({
                        latitude,
                        longitude
                    }),
                    signal
                });

                const data = await response.json();
                console.log(data);

                const hours = data.forecastHours.map(hour =>
                    `${hour.displayDateTime.hours}:00`
                );

                const series = [
                    ["temperature", "Temperature", "#e53935"],
                    ["feelsLikeTemperature", "Feels Like", "#fb8c00"],
                    ["dewPoint", "Dew Point", "#1e88e5"],
                    ["heatIndex", "Heat Index", "#8e24aa"],
                    ["windChill", "Wind Chill", "#00897b"],
                    ["wetBulbTemperature", "Wet Bulb", "#3949ab"]
                ];

                const datasets = series.map(([key, label, color]) => ({
                    label,
                    data: data.forecastHours.map(h => h[key]?.degrees ?? null),
                    borderColor: color,
                    backgroundColor: color,
                    borderWidth: 2,
                    pointRadius: 3,
                    tension: 0.3,
                    fill: false
                }));

                if (chartGraph) chartGraph.destroy();

                chartGraph = new Chart(canvasGraph, {
                    type: "line",
                    data: {
                        labels: hours,
                        datasets
                    },
                    options: {
                        responsive: true,
                        interaction: {
                            mode: "index",
                            intersect: false
                        },
                        plugins: {
                            title: {
                                display: true,
                                text: "Hourly Temperature Forecast"
                            },
                            legend: {
                                position: "bottom"
                            },
                            tooltip: {
                                callbacks: {
                                    label: (context) => {
                                        return `${context.dataset.label}: ${context.parsed.y.toFixed(1)} °C`;
                                    }
                                }
                            }
                        },
                        scales: {
                            x: {
                                title: {
                                    display: true,
                                    text: "Hour"
                                }
                            },
                            y: {
                                title: {
                                    display: true,
                                    text: "Temperature (°C)"
                                }
                            }
                        }
                    }
                });

                pageLoader.style.display = "none";
                pageHeat.style.display = "block";
            }
        } break;
        case "map": {
            const {AdvancedMarkerElement} = await google.maps.importLibrary("marker");
            pageLoader.style.display = "flex";
            tabMap.style.color = "var(--theme)";
            panelTitle.textContent = "Map";
            currentPage = "map";

            const position = await new Promise((resolve, reject) => {
                navigator.geolocation.getCurrentPosition(resolve, reject);
            });

            const location = {
                lat: position.coords.latitude,
                lng: position.coords.longitude
            };

            const map = new google.maps.Map(pageMap, {
                zoom: 13,
                center: location,
                mapId: "DEMO_MAP_ID"
            });

            {
                panelLoader.textContent = "Loading map...";

                const response = await fetch("api/?action=get_heat_locations", {
                    method: "post",
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({}),
                    signal
                });

                const data = await response.json();
                console.log(data);

                for (const heatLocation of data) {
                    const circleMarker = document.createElement("div");
                    circleMarker.style.backgroundColor = getHeatIndexColor(heatLocation.heat_index);
                    circleMarker.style.border = "3px solid #FFFFFF";
                    circleMarker.style.borderRadius = "50%";
                    circleMarker.style.width = "20px";
                    circleMarker.style.height = "20px";
                    circleMarker.style.boxShadow = "0px 2px 4px rgba(0,0,0,0.3)";

                    const location = {
                        lat: heatLocation.latitude,
                        lng: heatLocation.longitude
                    }

                    const marker = new google.maps.marker.AdvancedMarkerElement({
                        map: map,
                        position: location,
                        content: circleMarker,
                        title: `Heat Index: ${heatLocation.heat_index} °C`
                    });

                    const dateString = new Date(heatLocation.time * 1000).toLocaleString();

                    const infoWindow = new google.maps.InfoWindow({
                        content: /*html*/`
                            <div style="
                                font-size: 1rem;
                                line-height: 1.5rem;">
                                ${marker.title}<br>
                                ${dateString}
                            </div>
                        `
                    });

                    marker.addListener("click", (event) => {
                        event.stop();

                        infoWindow.open({
                            anchor: marker,
                            map: map,
                        });
                    });
                }
            }

            map.addListener("click", async (event) => {
                const location = {
                    lat: event.latLng.lat(),
                    lng: event.latLng.lng()
                };

                console.log(location);
                map.panTo(location);

                const loader = document.createElement("div");
                loader.style.width = "20px";
                loader.style.height = "20px";
                loader.innerHTML = /*html*/`<svg stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g><circle cx="12" cy="12" r="9.5" fill="none" stroke-width="3" stroke-linecap="round"><animate attributeName="stroke-dasharray" dur="1.5s" calcMode="spline" values="0 150;42 150;42 150;42 150" keyTimes="0;0.475;0.95;1" keySplines="0.42,0,0.58,1;0.42,0,0.58,1;0.42,0,0.58,1" repeatCount="indefinite"/><animate attributeName="stroke-dashoffset" dur="1.5s" calcMode="spline" values="0;-16;-59;-59" keyTimes="0;0.475;0.95;1" keySplines="0.42,0,0.58,1;0.42,0,0.58,1;0.42,0,0.58,1" repeatCount="indefinite"/></circle><animateTransform attributeName="transform" type="rotate" dur="2s" values="0 12 12;360 12 12" repeatCount="indefinite"/></g></svg>`;
                
                const loaderMarker = new google.maps.marker.AdvancedMarkerElement({
                    map: map,
                    position: location,
                    content: loader,
                    title: "Loading..."
                });
                
                const response = await fetch("api/?action=analyze_heat_location", {
                    method: "post",
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({
                        latitude: location.lat,
                        longitude: location.lng
                    }),
                    signal
                });

                const data = await response.json();
                console.log(data);
                loaderMarker.map = null;
                const circleMarker = document.createElement("div");
                circleMarker.style.backgroundColor = getHeatIndexColor(data.heatIndex);
                circleMarker.style.border = "3px solid #FFFFFF";
                circleMarker.style.borderRadius = "50%";
                circleMarker.style.width = "20px";
                circleMarker.style.height = "20px";
                circleMarker.style.boxShadow = "0px 2px 4px rgba(0,0,0,0.3)";

                const marker = new google.maps.marker.AdvancedMarkerElement({
                    map: map,
                    position: location,
                    content: circleMarker,
                    title: `Heat Index: ${data.heatIndex} °C`
                });

                const dateString = new Date(data.time * 1000).toLocaleString();

                const infoWindow = new google.maps.InfoWindow({
                    content: /*html*/`
                        <div style="
                            font-size: 1rem;
                            line-height: 1.5rem;">
                            ${marker.title}<br>
                            ${dateString}
                        </div>
                    `
                });

                marker.addListener("click", (event) => {
                    event.stop();

                    infoWindow.open({
                        anchor: marker,
                        map: map,
                    });
                });

                infoWindow.open({
                    anchor: marker,
                    map: map,
                });
            });

            pageLoader.style.display = "none";
            pageMap.style.display = "block";
        } break;
    }
}

function convertHour(hour24) {
    const ampm = hour24 >= 12 ? 'PM' : 'AM';
    const hour12 = (hour24 % 12) || 12;
    return `${hour12}${ampm}`;
}

/**
 * Returns a color representing the heat index.
 * @param {number} heatIndex - Heat index in Celsius.
 * @returns {string} CSS rgb() color.
 */
function getHeatIndexColor(heatIndex) {
    const stops = [
        { value: 27, color: [255, 235, 59] },   // Yellow
        { value: 32, color: [255, 193, 7] },    // Amber
        { value: 41, color: [255, 87, 34] },    // Deep Orange
        { value: 54, color: [183, 28, 28] }     // Dark Red
    ];

    // Clamp below minimum
    if (heatIndex <= stops[0].value) {
        return `rgb(${stops[0].color.join(",")})`;
    }

    // Clamp above maximum
    if (heatIndex >= stops[stops.length - 1].value) {
        return `rgb(${stops[stops.length - 1].color.join(",")})`;
    }

    // Find the interval
    for (let i = 0; i < stops.length - 1; i++) {
        const a = stops[i];
        const b = stops[i + 1];

        if (heatIndex >= a.value && heatIndex <= b.value) {
            const t = (heatIndex - a.value) / (b.value - a.value);

            const r = Math.round(a.color[0] + (b.color[0] - a.color[0]) * t);
            const g = Math.round(a.color[1] + (b.color[1] - a.color[1]) * t);
            const bColor = Math.round(a.color[2] + (b.color[2] - a.color[2]) * t);

            return `rgb(${r}, ${g}, ${bColor})`;
        }
    }
}