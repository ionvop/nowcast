const panelTitle = document.getElementById("panelTitle");
const btnReload = document.getElementById("btnReload");
const pageLoader = document.getElementById("pageLoader");
const pageHome = document.getElementById("pageHome");
const panelWeather = document.getElementById("panelWeather");
const imgWeather = document.getElementById("imgWeather");
const panelTemp = document.getElementById("panelTemp");
const panelCity = document.getElementById("panelCity");
const panelForecast = document.getElementById("panelForecast");
const tabHome = document.getElementById("tabHome");
const tabHeat = document.getElementById("tabHeat");
const tabMap = document.getElementById("tabMap");
const tabCommunity = document.getElementById("tabCommunity");
const tabProfile = document.getElementById("tabProfile");
let currentPage = "home";

(() => {
    openPage("home");
})()

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
    for (const page of [pageLoader, pageHome]) {
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

            await (async () => {
                const response = await fetch("api/?action=weather", {
                    method: "post",
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({
                        latitude,
                        longitude
                    })
                });

                const data = await response.json();
                panelWeather.textContent = data.json.weatherCondition.description.text;
                imgWeather.src = data.json.weatherCondition.iconBaseUri + ".svg";
                panelTemp.innerHTML = `${data.json.temperature.degrees}&deg;C`;
            })();

            await (async () => {
                const response = await fetch("api/?action=geocode", {
                    method: "post",
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({
                        latitude,
                        longitude
                    })
                });

                const data = await response.json();
                panelCity.textContent = data.json.results[0].formattedAddress;
            })();

            await (async () => {
                const reposne = await fetch("api/?action=forecast", {
                    method: "post",
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({
                        latitude,
                        longitude
                    })
                });

                const data = await reposne.json();
                console.log(data);
                panelForecast.innerHTML = "";

                for (const forecast of data.json.forecastHours) {
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
            })();

            pageLoader.style.display = "none";
            pageHome.style.display = "block";
        } break;
    }
}

function convertHour(hour24) {
    const ampm = hour24 >= 12 ? 'PM' : 'AM';
    const hour12 = (hour24 % 12) || 12;
    return `${hour12}${ampm}`;
}