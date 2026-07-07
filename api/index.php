<?php

require_once "common.php";
header("Content-Type: application/json");
$data = json_decode(file_get_contents("php://input"), true);

switch ($_GET["action"]) {
    case "weather":
        $response = fetch("https://weather.googleapis.com/v1/currentConditions:lookup?key={$GOOGLE_API_KEY}&location.latitude={$data["latitude"]}&location.longitude={$data["longitude"]}");
        echo json_encode($response["json"]);
        return;
    case "geocode":
        $response = fetch("https://geocode.googleapis.com/v4/geocode/location?location.latitude={$data["latitude"]}&location.longitude={$data["longitude"]}&key={$GOOGLE_API_KEY}");
        echo json_encode($response["json"]);
        return;
    case "forecast":
        $response = fetch("https://weather.googleapis.com/v1/forecast/hours:lookup?key={$GOOGLE_API_KEY}&location.latitude={$data["latitude"]}&location.longitude={$data["longitude"]}&hours=6");
        echo json_encode($response["json"]);
        return;
    case "analyze_heat_location":
        $db = new SQLite3("database.db");
        $response = fetch("https://weather.googleapis.com/v1/currentConditions:lookup?key={$GOOGLE_API_KEY}&location.latitude={$data["latitude"]}&location.longitude={$data["longitude"]}");
        $heatIndex = $response["json"]["heatIndex"]["degrees"];

        $query = <<<SQL
            DELETE FROM `heat_locations`
            WHERE (`latitude` > :latitude - 0.001 AND `latitude` < :latitude + 0.001
            AND `longitude` > :longitude - 0.001 AND `longitude` < :longitude + 0.001)
            OR `time` < :time - 3600;
        SQL;

        $stmt = $db->prepare($query);
        $stmt->bindValue(":latitude", $data["latitude"]);
        $stmt->bindValue(":longitude", $data["longitude"]);
        $stmt->bindValue(":time", time());
        $stmt->execute();
        
        $query = <<<SQL
            INSERT INTO `heat_locations` (`heat_index`, `latitude`, `longitude`)
            VALUES (:heat_index, :latitude, :longitude);
        SQL;

        $stmt = $db->prepare($query);
        $stmt->bindValue(":heat_index", $heatIndex);
        $stmt->bindValue(":latitude", $data["latitude"]);
        $stmt->bindValue(":longitude", $data["longitude"]);
        $stmt->execute();

        echo json_encode([
            "heatIndex" => $heatIndex,
            "latitude" => $data["latitude"],
            "longitude" => $data["longitude"],
            "time" => time()
        ]);

        return;
    case "get_heat_locations":
        $db = new SQLite3("database.db");

        $query = <<<SQL
            DELETE FROM `heat_locations`
            WHERE `time` < :time - 3600;
        SQL;

        $stmt = $db->prepare($query);
        $stmt->bindValue(":time", time());
        $stmt->execute();

        $query = <<<SQL
            SELECT * FROM `heat_locations`
        SQL;

        $stmt = $db->prepare($query);
        $result = $stmt->execute();
        $heatLocations = [];

        while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
            $heatLocations[] = $row;
        }

        echo json_encode($heatLocations);
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