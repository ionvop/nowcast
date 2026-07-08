<?php

require_once "common.php";

switch ($_GET["method"]) {
    case "login":
        header("Location: https://accounts.google.com/o/oauth2/v2/auth?client_id={$CLIENT_ID}&redirect_uri={$REDIRECT_URI}&response_type=code&scope=email%20profile");
        break;
    case "callback":
        $db = new SQLite3("database.db");

        $response = fetch("https://oauth2.googleapis.com/token", [
            "method" => "POST",
            "headers" => [
                "Content-Type" => "application/x-www-form-urlencoded"
            ],
            "body" => http_build_query([
                "code" => $_GET["code"],
                "client_id" => $CLIENT_ID,
                "client_secret" => $CLIENT_SECRET,
                "redirect_uri" => $REDIRECT_URI,
                "grant_type" => "authorization_code"
            ])
        ]);

        $accessToken = $response["json"]["access_token"];
        $url = "https://www.googleapis.com/oauth2/v1/userinfo?access_token={$accessToken}";
        $response = fetch($url);
        $email = $response["json"]["email"];
        $name = $response["json"]["name"];
        $avatar = $response["json"]["picture"];

        $user = executePreparedQuery($db, <<<SQL
            SELECT * FROM `users` WHERE `email` = :email;
        SQL, [
            ":email" => $email
        ])->fetchArray(SQLITE3_ASSOC);

        if ($user == false) {
            executePreparedQuery($db, <<<SQL
                INSERT INTO `users` (`email`, `name`, `avatar`, `session`)
                VALUES (:email, :name, :avatar, :session);
            SQL, [
                ":email" => $email,
                ":name" => $name,
                ":avatar" => $avatar,
            ]);

            $user = executePreparedQuery($db, <<<SQL
                SELECT * FROM `users` WHERE `email` = :email;
            SQL, [
                ":email" => $email
            ])->fetchArray(SQLITE3_ASSOC);
        }

        $session = uniqid("session-");

        executePreparedQuery($db, <<<SQL
            UPDATE `users` SET `session` = :session WHERE `id` = :id;
        SQL, [
            ":session" => $session,
            ":id" => $user["id"]
        ]);

        setcookie("session", $session, time() + 86400);
        header("Location: ../app.php?page=profile");
        break;
    case "logout":
        setcookie("session", "", time() - 3600);
        header("Location: ../app.php?page=profile");
        break;
}