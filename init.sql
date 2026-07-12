CREATE TABLE `heat_locations` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `heat_index` REAL, "latitude" REAL, "longitude" REAL, `time` INTEGER DEFAULT (unixepoch()));
CREATE TABLE "users" (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `name` TEXT, `email` TEXT UNIQUE, `avatar` TEXT, `session` TEXT, `time` INTEGER DEFAULT (unixepoch()));
CREATE TABLE `posts` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `user_id` INTEGER REFERENCES `users`(`id`), `content` TEXT, `time` INTEGER DEFAULT (unixepoch()));
