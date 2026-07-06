<?php

require_once "common.php";
header("Content-Type: application/json");
$data = json_decode(file_get_contents("php://input"), true);

switch ($_GET["action"]) {
    case "weather":
        $response = fetch("https://weather.googleapis.com/v1/currentConditions:lookup?key={$GOOGLE_API_KEY}&location.latitude={$data["latitude"]}&location.longitude={$data["longitude"]}");
        echo json_encode($response);
        return;
    case "geocode":
        $response = fetch("https://geocode.googleapis.com/v4/geocode/location?location.latitude={$data["latitude"]}&location.longitude={$data["longitude"]}&key={$GOOGLE_API_KEY}");
        echo json_encode($response);
        return;
    case "forecast":
        $response = fetch("https://weather.googleapis.com/v1/forecast/hours:lookup?key={$GOOGLE_API_KEY}&location.latitude={$data["latitude"]}&location.longitude={$data["longitude"]}&hours=6");
        echo json_encode($response);
        return;
    default:
        http_response_code(404);
        echo json_encode(["details" => "Action not found."]);
        return;
}

function breakpoint(mixed $data) {
    echo json_encode($data);
    exit;
}