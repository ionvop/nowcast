<?php

require_once "api/config.php";

?>

<html>
    <head>
        <link rel="stylesheet" href="style.css?v=<?= time() ?>">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta charset="UTF-8">
    </head>
    <body>
        <div style="
            display: grid;
            grid-template-rows: max-content 1fr max-content;
            height: 100%;
            box-sizing: border-box;
            overflow: hidden;">
            <div style="
                display: grid;
                grid-template-columns: max-content 1fr max-content;
                background-color: var(--theme);">
                <div style="
                    display: flex;
                    align-items: center;
                    padding: 1rem;">
                    <svg xmlns="http://www.w3.org/2000/svg" height="30px" viewBox="0 -960 960 960" width="30px" fill="#e3e3e3"><path d="M380-320q-109 0-184.5-75.5T120-580q0-109 75.5-184.5T380-840q109 0 184.5 75.5T640-580q0 44-14 83t-38 69l224 224q11 11 11 28t-11 28q-11 11-28 11t-28-11L532-372q-30 24-69 38t-83 14Zm0-80q75 0 127.5-52.5T560-580q0-75-52.5-127.5T380-760q-75 0-127.5 52.5T200-580q0 75 52.5 127.5T380-400Z"/></svg>
                </div>
                <div style="
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    padding: 1rem;
                    font-size: 1.5rem;
                    color: #fff;
                    font-weight: bold;"
                    id="panelTitle">
                    
                </div>
                <div style="
                    display: flex;
                    align-items: center;
                    padding: 1rem;"
                    id="btnReload">
                    <svg xmlns="http://www.w3.org/2000/svg" height="30px" viewBox="0 -960 960 960" width="30px" fill="#e3e3e3"><path d="M480-160q-134 0-227-93t-93-227q0-134 93-227t227-93q69 0 132 28.5T720-690v-70q0-17 11.5-28.5T760-800q17 0 28.5 11.5T800-760v200q0 17-11.5 28.5T760-520H560q-17 0-28.5-11.5T520-560q0-17 11.5-28.5T560-600h128q-32-56-87.5-88T480-720q-100 0-170 70t-70 170q0 100 70 170t170 70q68 0 124.5-34.5T692-367q8-14 22.5-19.5t29.5-.5q16 5 23 21t-1 30q-41 80-117 128t-169 48Z"/></svg>
                </div>
            </div>
            <div style="
                overflow: hidden;
                background-color: #eef;">
                <div style="
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    height: 100%;
                    box-sizing: border-box;
                    color: #555;"
                    id="pageLoader">
                    <div>
                        <div style="
                            display: flex;
                            align-items: center;
                            justify-content: center;">
                            <div style="
                                width: 5rem;
                                height: 5rem;">
                                <svg stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g><circle cx="12" cy="12" r="9.5" fill="none" stroke-width="3" stroke-linecap="round"><animate attributeName="stroke-dasharray" dur="1.5s" calcMode="spline" values="0 150;42 150;42 150;42 150" keyTimes="0;0.475;0.95;1" keySplines="0.42,0,0.58,1;0.42,0,0.58,1;0.42,0,0.58,1" repeatCount="indefinite"/><animate attributeName="stroke-dashoffset" dur="1.5s" calcMode="spline" values="0;-16;-59;-59" keyTimes="0;0.475;0.95;1" keySplines="0.42,0,0.58,1;0.42,0,0.58,1;0.42,0,0.58,1" repeatCount="indefinite"/></circle><animateTransform attributeName="transform" type="rotate" dur="2s" values="0 12 12;360 12 12" repeatCount="indefinite"/></g></svg>
                            </div>
                        </div>
                        <div style="
                            padding: 1rem;
                            text-align: center;
                            color: #555;"
                            id="panelLoader">
                            Loading app...
                        </div>
                    </div>
                </div>
                <div style="
                    display: none;
                    height: 100%;
                    box-sizing: border-box;
                    overflow: auto;"
                    id="pageHome">
                    <div style="
                        padding: 1rem;
                        padding-top: 3rem;
                        color: #555;
                        text-align: center;
                        font-size: 1.5rem;"
                        id="panelWeather">
                        
                    </div>
                    <div style="
                        padding: 1rem;
                        text-align: center;">
                        <img style="
                            width: 10rem;
                            height: 10rem;
                            object-fit: contain;"
                            src=""
                            id="imgWeather">
                    </div>
                    <div style="
                        padding: 1rem;
                        text-align: center;
                        font-size: 2rem;
                        color: #000;"
                        id="panelTemp">
                        
                    </div>
                    <div style="
                        padding: 1rem;
                        padding-top: 0rem;
                        text-align: center;
                        color: #555;"
                        id="panelCity">
                        
                    </div>
                    <div style="
                        padding: 1rem;
                        font-weight: bold;">
                        Hourly Forecasts
                    </div>
                    <div style="
                        display: flex;
                        flex-wrap: nowrap;
                        overflow: auto;
                        padding-left: 1rem;"
                        id="panelForecast">

                    </div>
                </div>
                <div style="
                    display: none;
                    height: 100%;
                    box-sizing: border-box;
                    overflow: auto;"
                    id="pageHeat">
                    <div style="
                        padding: 1rem;">
                        <canvas style="
                            width: 100%;"
                            width="300"
                            height="400"
                            id="canvasGraph">

                        </canvas>
                    </div>
                </div>
                <div style="
                    display: none;
                    position: relative;
                    height: 100%;
                    box-sizing: border-box;"
                    id="pageMap">
                    <div style="
                        position: absolute;
                        top: 0;
                        left: 0;
                        width: 100%;
                        height: 100%;
                        box-sizing: border-box;"
                        id="panelMap">

                    </div>
                    <div style="
                        display: none;
                        align-items: center;
                        justify-content: center;
                        position: absolute;
                        top: 0rem;
                        left: 0rem;
                        width: 100%;
                        height: 100%;
                        box-sizing: border-box;
                        background-color: #0005;
                        padding: 1rem;"
                        id="panelAlert">
                        <div style="
                            background-color: #fff;
                            border-radius: 1rem;">
                            <div style="
                                display: grid;
                                grid-template-columns: 1fr max-content;">
                                <div style="
                                    display: flex;
                                    align-items: center;
                                    padding: 1rem;
                                    font-weight: bold;"
                                    id="panelAlertTitle">

                                </div>
                                <div style="
                                    display: flex;
                                    align-items: center;
                                    padding: 1rem;"
                                    id="btnAlertClose">
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#1f1f1f"><path d="M480-424 284-228q-11 11-28 11t-28-11q-11-11-11-28t11-28l196-196-196-196q-11-11-11-28t11-28q11-11 28-11t28 11l196 196 196-196q11-11 28-11t28 11q11 11 11 28t-11 28L536-480l196 196q11 11 11 28t-11 28q-11 11-28 11t-28-11L480-424Z"/></svg>
                                </div>
                            </div>
                            <div style="
                                padding: 1rem;
                                padding-top: 0rem;
                                color: #555;
                                line-height: 1.5rem;
                                white-space: pre-line;"
                                id="panelAlertContent">

                            </div>
                        </div>
                    </div>
                </div>
                <div style="
                    display: none;
                    position: relative;
                    height: 100%;
                    box-sizing: border-box;
                    overflow: auto;"
                    id="pageCommunity">
                    <div style="
                        position: absolute;
                        top: 0rem;
                        left: 0rem;
                        width: 100%;
                        height: 100%;
                        padding-top: 1rem;
                        box-sizing: border-box;"
                        id="panelPosts">

                    </div>
                    <div style="
                        display: none;
                        position: absolute;
                        bottom: 0rem;
                        right: 0rem;
                        padding: 1rem;"
                        id="panelNewPost">
                        <button id="btnNewPost">
                            <div style="
                                display: grid;
                                grid-template-columns: max-content 1fr;">
                                <div style="
                                    display: flex;
                                    align-items: center;">
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#e3e3e3"><path d="M160-120q-17 0-28.5-11.5T120-160v-97q0-16 6-30.5t17-25.5l505-504q12-11 26.5-17t30.5-6q16 0 31 6t26 18l55 56q12 11 17.5 26t5.5 30q0 16-5.5 30.5T817-647L313-143q-11 11-25.5 17t-30.5 6h-97Zm544-528 56-56-56-56-56 56 56 56Z"/></svg>
                                </div>
                                <div style="
                                    display: flex;
                                    align-items: center;
                                    padding-left: 0.5rem;">
                                    New Post
                                </div>
                            </div>
                        </button>
                    </div>
                </div>
                <div style="
                    display: none;
                    height: 100%;
                    box-sizing: border-box;
                    overflow: auto;"
                    id="pageNewPost">
                    <div style="
                        display: grid;
                        grid-template-rows: 1fr max-content;
                        height: 100%;
                        box-sizing: border-box;">
                        <div style="
                            padding: 1rem;">
                            <textarea id="inputPost"
                                placeholder="What's on your mind?"></textarea>
                        </div>
                        <div style="
                            display: grid;
                            grid-template-columns: max-content 1fr max-content;">
                            <div style="
                                display: flex;
                                align-items: center;
                                padding: 1rem;
                                padding-top: 0rem;">
                                <label class="switch">
                                    <input type="checkbox"
                                        id="chkLocation">
                                    <span class="slider round"></span>
                                </label>
                            </div>
                            <div style="
                                display: flex;
                                align-items: center;
                                padding: 1rem;
                                padding-top: 0rem;
                                padding-left: 0rem;">
                                Include my current location
                            </div>
                            <div style="
                                padding: 1rem;
                                padding-top: 0rem;">
                                <button id="btnPost">
                                    <div style="
                                        display: grid;
                                        grid-template-columns: max-content 1fr;">
                                        <div style="
                                            display: flex;
                                            align-items: center;">
                                            <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#e3e3e3"><path d="M176-183q-20 8-38-3.5T120-220v-180l320-80-320-80v-180q0-22 18-33.5t38-3.5l616 260q25 11 25 37t-25 37L176-183Z"/></svg>
                                        </div>
                                        <div style="
                                            display: flex;
                                            align-items: center;
                                            padding-left: 0.5rem;">
                                            Post
                                        </div>
                                    </div>
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
                <div style="
                    display: none;
                    height: 100%;
                    box-sizing: border-box;
                    overflow: auto;"
                    id="pagePost">
                    <div style="
                        padding: 1rem;">
                        <div style="
                            background-color: #fff;
                            border-radius: 1rem;
                            border: 1px solid var(--theme);
                            overflow: hidden;">
                            <div style="
                                display: grid;
                                grid-template-columns: max-content 1fr max-content;
                                border-bottom: 1px solid #555;">
                                <div style="
                                    display: flex;
                                    align-items: center;
                                    padding: 1rem;">
                                    <img style="
                                        width: 2rem;
                                        height: 2rem;
                                        object-fit: cover;
                                        border-radius: 50%;"
                                        src=""
                                        id="imgPostAvatar">
                                </div>
                                <div style="
                                    display: flex;
                                    align-items: center;
                                    padding: 1rem;
                                    padding-left: 0rem;"
                                    id="panelPostName">

                                </div>
                                <div style="
                                    display: flex;
                                    align-items: center;
                                    padding: 1rem;
                                    font-size: 0.7rem;
                                    color: #555;"
                                    id="panelPostTime">

                                </div>
                            </div>
                            <div style="
                                padding: 1rem;
                                white-space: pre-line"
                                id="panelPostContent">
                            
                            </div>
                            <div style="
                                display: grid;
                                grid-template-columns: 1fr max-content;">
                                <div style="
                                    padding: 1rem;
                                    color: #555;
                                    font-size: 0.7rem;"
                                    id="panelPostLocation">

                                </div>
                                <div style="
                                    display: none;
                                    padding: 1rem;"
                                    id="btnDelete"
                                    data-id="">
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#e31f1f"><path d="M280-120q-33 0-56.5-23.5T200-200v-520q-17 0-28.5-11.5T160-760q0-17 11.5-28.5T200-800h160q0-17 11.5-28.5T400-840h160q17 0 28.5 11.5T600-800h160q17 0 28.5 11.5T800-760q0 17-11.5 28.5T760-720v520q0 33-23.5 56.5T680-120H280Zm148.5-171.5Q440-303 440-320v-280q0-17-11.5-28.5T400-640q-17 0-28.5 11.5T360-600v280q0 17 11.5 28.5T400-280q17 0 28.5-11.5Zm160 0Q600-303 600-320v-280q0-17-11.5-28.5T560-640q-17 0-28.5 11.5T520-600v280q0 17 11.5 28.5T560-280q17 0 28.5-11.5Z"/></svg>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div style="
                    display: none;
                    height: 100%;
                    box-sizing: border-box;
                    overflow: auto;"
                    id="pageLogin">
                    <div style="
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        height: 100%;
                        box-sizing: border-box;">
                        <div>
                            <button class="gsi-material-button" id="btnLogin">
                                <div class="gsi-material-button-state"></div>
                                <div class="gsi-material-button-content-wrapper">
                                    <div class="gsi-material-button-icon">
                                        <svg version="1.1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" xmlns:xlink="http://www.w3.org/1999/xlink" style="display: block;">
                                            <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"></path>
                                            <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"></path>
                                            <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"></path>
                                            <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"></path>
                                            <path fill="none" d="M0 0h48v48H0z"></path>
                                        </svg>
                                    </div>
                                    <span class="gsi-material-button-contents">Sign in with Google</span>
                                    <span style="display: none;">Sign in with Google</span>
                                </div>
                            </button>
                        </div>
                    </div>
                </div>
                <div style="
                    display: none;
                    height: 100%;
                    box-sizing: border-box;
                    overflow: auto;"
                    id="pageProfile">
                    <div style="
                        padding: 1rem;
                        text-align: center;">
                        <img style="
                            width: 10rem;
                            height: 10rem;
                            object-fit: cover;
                            border-radius: 50%;"
                            src=""
                            id="imgAvatar">
                    </div>
                    <div style="
                        padding: 1rem;
                        padding-top: 0rem;
                        text-align: center;
                        font-size: 1.5rem;
                        font-weight: bold;"
                        id="panelName">

                    </div>
                    <div style="
                        padding: 1rem;
                        text-align: center;">
                        <button id="btnLogout">
                            <div style="
                                display: grid;
                                grid-template-columns: max-content 1fr;">
                                <div style="
                                    display: flex;
                                    align-items: center;">
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#e3e3e3"><path d="M200-120q-33 0-56.5-23.5T120-200v-560q0-33 23.5-56.5T200-840h240q17 0 28.5 11.5T480-800q0 17-11.5 28.5T440-760H200v560h240q17 0 28.5 11.5T480-160q0 17-11.5 28.5T440-120H200Zm487-320H400q-17 0-28.5-11.5T360-480q0-17 11.5-28.5T400-520h287l-75-75q-11-11-11-27t11-28q11-12 28-12.5t29 11.5l143 143q12 12 12 28t-12 28L669-309q-12 12-28.5 11.5T612-310q-11-12-10.5-28.5T613-366l74-74Z"/></svg>
                                </div>
                                <div style="
                                    display: flex;
                                    align-items: center;
                                    padding-left: 0.5rem;">
                                    Logout
                                </div>
                            </div>
                        </button>
                    </div>
                </div>
            </div>
            <div style="
                display: grid;
                grid-template-columns: repeat(5, 1fr);
                background-color: #fff;">
                <div style="
                    color: #555;"
                    id="tabHome">
                    <div style="
                        padding: 1rem;
                        padding-bottom: 0.5rem;
                        text-align: center;">
                        <svg xmlns="http://www.w3.org/2000/svg" height="30px" viewBox="0 -960 960 960" width="30px" fill="currentColor"><path d="M160-200v-360q0-19 8.5-36t23.5-28l240-180q21-16 48-16t48 16l240 180q15 11 23.5 28t8.5 36v360q0 33-23.5 56.5T720-120H600q-17 0-28.5-11.5T560-160v-200q0-17-11.5-28.5T520-400h-80q-17 0-28.5 11.5T400-360v200q0 17-11.5 28.5T360-120H240q-33 0-56.5-23.5T160-200Z"/></svg>
                    </div>
                    <div style="
                        padding-bottom: 1rem;
                        text-align: center;
                        font-size: 0.7rem;">
                        Home
                    </div>
                </div>
                <div style="
                    color: #555;"
                    id="tabHeat">
                    <div style="
                        padding: 1rem;
                        padding-bottom: 0.5rem;
                        text-align: center;">
                        <svg xmlns="http://www.w3.org/2000/svg" height="30px" viewBox="0 -960 960 960" width="30px" fill="currentColor"><path d="M680-160q-17 0-28.5-11.5T640-200v-200q0-17 11.5-28.5T680-440h80q17 0 28.5 11.5T800-400v200q0 17-11.5 28.5T760-160h-80Zm-240 0q-17 0-28.5-11.5T400-200v-560q0-17 11.5-28.5T440-800h80q17 0 28.5 11.5T560-760v560q0 17-11.5 28.5T520-160h-80Zm-240 0q-17 0-28.5-11.5T160-200v-360q0-17 11.5-28.5T200-600h80q17 0 28.5 11.5T320-560v360q0 17-11.5 28.5T280-160h-80Z"/></svg>
                    </div>
                    <div style="
                        padding-bottom: 1rem;
                        text-align: center;
                        font-size: 0.7rem;">
                        Heat Data
                    </div>
                </div>
                <div style="
                    color: #555;"
                    id="tabMap">
                    <div style="
                        padding: 1rem;
                        padding-bottom: 0.5rem;
                        text-align: center;">
                        <svg xmlns="http://www.w3.org/2000/svg" height="30px" viewBox="0 -960 960 960" width="30px" fill="currentColor"><path d="m574-129-214-75-186 72q-10 4-19.5 2.5T137-136q-8-5-12.5-13.5T120-169v-561q0-13 7.5-23t20.5-15l186-63q6-2 12.5-3t13.5-1q7 0 13.5 1t12.5 3l214 75 186-72q10-4 19.5-2.5T823-824q8 5 12.5 13.5T840-791v561q0 13-7.5 23T812-192l-186 63q-6 2-12.5 3t-13.5 1q-7 0-13.5-1t-12.5-3Zm-14-89v-468l-160-56v468l160 56Z"/></svg>
                    </div>
                    <div style="
                        padding-bottom: 1rem;
                        text-align: center;
                        font-size: 0.7rem;">
                        Map
                    </div>
                </div>
                <div style="
                    color: #555;"
                    id="tabCommunity">
                    <div style="
                        padding: 1rem;
                        padding-bottom: 0.5rem;
                        text-align: center;">
                        <svg xmlns="http://www.w3.org/2000/svg" height="30px" viewBox="0 -960 960 960" width="30px" fill="currentColor"><path d="M40-272q0-34 17.5-62.5T104-378q62-31 126-46.5T360-440q66 0 130 15.5T616-378q29 15 46.5 43.5T680-272v32q0 33-23.5 56.5T600-160H120q-33 0-56.5-23.5T40-240v-32Zm698 112q11-18 16.5-38.5T760-240v-40q0-44-24.5-84.5T666-434q51 6 96 20.5t84 35.5q36 20 55 44.5t19 53.5v40q0 33-23.5 56.5T840-160H738ZM247-527q-47-47-47-113t47-113q47-47 113-47t113 47q47 47 47 113t-47 113q-47 47-113 47t-113-47Zm466 0q-47 47-113 47-11 0-28-2.5t-28-5.5q27-32 41.5-71t14.5-81q0-42-14.5-81T544-792q14-5 28-6.5t28-1.5q66 0 113 47t47 113q0 66-47 113Z"/></svg>
                    </div>
                    <div style="
                        padding-bottom: 1rem;
                        text-align: center;
                        font-size: 0.7rem;">
                        Community
                    </div>
                </div>
                <div style="
                    color: #555;"
                    id="tabProfile">
                    <div style="
                        padding: 1rem;
                        padding-bottom: 0.5rem;
                        text-align: center;">
                        <svg xmlns="http://www.w3.org/2000/svg" height="30px" viewBox="0 -960 960 960" width="30px" fill="currentColor"><path d="M160-240q-17 0-28.5-11.5T120-280q0-17 11.5-28.5T160-320h640q17 0 28.5 11.5T840-280q0 17-11.5 28.5T800-240H160Zm0-200q-17 0-28.5-11.5T120-480q0-17 11.5-28.5T160-520h640q17 0 28.5 11.5T840-480q0 17-11.5 28.5T800-440H160Zm0-200q-17 0-28.5-11.5T120-680q0-17 11.5-28.5T160-720h640q17 0 28.5 11.5T840-680q0 17-11.5 28.5T800-640H160Z"/></svg>
                    </div>
                    <div style="
                        padding-bottom: 1rem;
                        text-align: center;
                        font-size: 0.7rem;">
                        Profile
                    </div>
                </div>
            </div>
        </div>
        <script async src="https://maps.googleapis.com/maps/api/js?key=<?= $GOOGLE_MAPS_KEY ?>&loading=async&callback=initMap"></script>
        <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
        <script src="script.js?v=<?= time() ?>"></script>
    </body>
</html>