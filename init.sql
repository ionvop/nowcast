CREATE TABLE `heat_locations` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `heat_index` REAL, "latitude" REAL, "longitude" REAL, `time` INTEGER DEFAULT (unixepoch()));
