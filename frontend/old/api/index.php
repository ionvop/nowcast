<?php

require_once "common.php";
header("Content-Type: application/json");
$data = json_decode(file_get_contents("php://input"), true);
$db = new SQLite3("database.db");

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
        $response = fetch("https://weather.googleapis.com/v1/currentConditions:lookup?key={$GOOGLE_API_KEY}&location.latitude={$data["latitude"]}&location.longitude={$data["longitude"]}");
        $heatIndex = $response["json"]["heatIndex"]["degrees"] ?? null;

        executePreparedQuery($db, <<<SQL
            DELETE FROM `heat_locations`
            WHERE (`latitude` > :latitude - 0.001 AND `latitude` < :latitude + 0.001
            AND `longitude` > :longitude - 0.001 AND `longitude` < :longitude + 0.001)
            OR `time` < :time - 3600
            OR `heat_index` IS NULL;
        SQL, [
            ":latitude" => $data["latitude"],
            ":longitude" => $data["longitude"],
            ":time" => time()
        ]);

        executePreparedQuery($db, <<<SQL
            INSERT INTO `heat_locations` (`heat_index`, `latitude`, `longitude`)
            VALUES (:heat_index, :latitude, :longitude);
        SQL, [
            ":heat_index" => $heatIndex,
            ":latitude" => $data["latitude"],
            ":longitude" => $data["longitude"]
        ]);

        echo json_encode([
            "heatIndex" => $heatIndex,
            "latitude" => $data["latitude"],
            "longitude" => $data["longitude"],
            "time" => time()
        ]);

        return;
    case "get_heat_locations":
        executePreparedQuery($db, <<<SQL
            DELETE FROM `heat_locations`
            WHERE `time` < :time - 3600
            OR `heat_index` IS NULL;
        SQL, [
            ":time" => time()
        ]);

        $result = executePreparedQuery($db, <<<SQL
            SELECT * FROM `heat_locations`
        SQL);

        $heatLocations = [];

        while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
            $heatLocations[] = $row;
        }

        echo json_encode($heatLocations);
        return;
    case "profile":
        if (!isset($_COOKIE["session"])) {
            http_response_code(401);
            echo json_encode(false);
            return;
        }

        $user = executePreparedQuery($db, <<<SQL
            SELECT * FROM `users` WHERE `session` = :session;
        SQL, [
            ":session" => $_COOKIE["session"]
        ])->fetchArray(SQLITE3_ASSOC);

        echo json_encode($user);
        return;
    case "newPost":
        $user = executePreparedQuery($db, <<<SQL
            SELECT * FROM `users` WHERE `session` = :session;
        SQL, [
            ":session" => $_COOKIE["session"]
        ])->fetchArray(SQLITE3_ASSOC);

        if (!$user) {
            http_response_code(401);
            echo json_encode(["details" => "Unauthorized."]);
            return;
        }

        executePreparedQuery($db, <<<SQL
            INSERT INTO `posts` (`user_id`, `content`, `address`, `latitude`, `longitude`)
            VALUES (:user_id, :content, :address, :latitude, :longitude);
        SQL, [
            ":user_id" => $user["id"],
            ":content" => $data["content"],
            ":address" => $data["address"],
            ":latitude" => $data["latitude"],
            ":longitude" => $data["longitude"]
        ]);

        http_response_code(201);
        echo json_encode(["details" => "Post created."]);
        return;
    case "getPosts":
        executePreparedQuery($db, <<<SQL
            DELETE FROM `posts` WHERE `time` < :time;
        SQL, [
            ":time" => time() - 86400
        ]);

        $result = executePreparedQuery($db, <<<SQL
            SELECT * FROM `posts`
        SQL);

        $posts = [];

        while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
            $row["user"] = executePreparedQuery($db, <<<SQL
                SELECT * FROM `users` WHERE `id` = :id;
            SQL, [
                ":id" => $row["user_id"]
            ])->fetchArray(SQLITE3_ASSOC);

            $posts[] = $row;
        }

        echo json_encode($posts);
        return;
    case "getPost":
        $post = executePreparedQuery($db, <<<SQL
            SELECT * FROM `posts` WHERE `id` = :id;
        SQL, [
            ":id" => $data["id"]
        ])->fetchArray(SQLITE3_ASSOC);

        $post["user"] = executePreparedQuery($db, <<<SQL
            SELECT * FROM `users` WHERE `id` = :id;
        SQL, [
            ":id" => $post["user_id"]
        ])->fetchArray(SQLITE3_ASSOC);

        echo json_encode($post);
        return;
    case "deletePost":
        $user = executePreparedQuery($db, <<<SQL
            SELECT * FROM `users` WHERE `session` = :session;
        SQL, [
            ":session" => $_COOKIE["session"]
        ])->fetchArray(SQLITE3_ASSOC);

        if (!$user) {
            http_response_code(401);
            echo json_encode(["details" => "Unauthorized."]);
            return;
        }

        $post = executePreparedQuery($db, <<<SQL
            SELECT * FROM `posts` WHERE `id` = :id;
        SQL, [
            ":id" => $data["id"]
        ])->fetchArray(SQLITE3_ASSOC);

        if (!$post) {
            http_response_code(404);
            echo json_encode(["details" => "Post not found."]);
            return;
        }

        if ($post["user_id"] != $user["id"]) {
            http_response_code(401);
            echo json_encode(["details" => "Unauthorized."]);
            return;
        }

        executePreparedQuery($db, <<<SQL
            DELETE FROM `posts` WHERE `id` = :id;
        SQL, [
            ":id" => $data["id"]
        ]);

        http_response_code(200);
        echo json_encode(["details" => "Post deleted."]);
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