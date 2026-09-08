CREATE TABLE "tasks" (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `task` TEXT NOT NULL, `is_completed` INTEGER DEFAULT 0, `created_at` TEXT DEFAULT (datetime()));
