-- Gerivia: cria as tabelas próprias na inicialização, sem mexer nas migrations do Canary
-- (evita conflito de numeração quando o Canary oficial for atualizado).

local setup = GlobalEvent("GeriviaDatabaseSetup")

function setup.onStartup()
	local ok = db.query([[
CREATE TABLE IF NOT EXISTS `idle_hunts` (
    `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_id` int(11) NOT NULL,
    `account_id` int(11) UNSIGNED NOT NULL,
    `area_id` varchar(32) NOT NULL,
    `started_at` int(11) UNSIGNED NOT NULL,
    `max_seconds` int(11) UNSIGNED NOT NULL,
    `supplies_cost` bigint(20) UNSIGNED NOT NULL DEFAULT 0,
    `rng_seed` int(11) UNSIGNED NOT NULL,
    `ip` int(11) UNSIGNED NOT NULL DEFAULT 0,
    `snapshot` text NOT NULL,
    `status` enum('active','done','cancelled') NOT NULL DEFAULT 'active',
    `finished_at` int(11) UNSIGNED NOT NULL DEFAULT 0,
    `result` text NULL,
    CONSTRAINT `idle_hunts_pk` PRIMARY KEY (`id`),
    INDEX `idle_hunts_player_status` (`player_id`, `status`),
    INDEX `idle_hunts_account_status` (`account_id`, `status`),
    INDEX `idle_hunts_ip_status` (`ip`, `status`),
    CONSTRAINT `idle_hunts_players_fk` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
	if not ok then
		logger.error("[Gerivia] Falha ao criar a tabela idle_hunts")
	end
	ok = db.query([[
CREATE TABLE IF NOT EXISTS `gerivia_alerts` (
    `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_id` int(11) NOT NULL,
    `created_at` int(11) UNSIGNED NOT NULL,
    `kind` varchar(32) NOT NULL,
    `message` varchar(255) NOT NULL,
    `seen` tinyint(1) NOT NULL DEFAULT 0,
    CONSTRAINT `gerivia_alerts_pk` PRIMARY KEY (`id`),
    INDEX `gerivia_alerts_player_time` (`player_id`, `created_at`),
    CONSTRAINT `gerivia_alerts_players_fk` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
	if not ok then
		logger.error("[Gerivia] Falha ao criar a tabela gerivia_alerts")
	end
	ok = db.query([[
CREATE TABLE IF NOT EXISTS `gerivia_bot_sessions` (
    `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_id` int(11) NOT NULL,
    `started_at` int(11) UNSIGNED NOT NULL,
    `updated_at` int(11) UNSIGNED NOT NULL,
    `ended_at` int(11) UNSIGNED NOT NULL DEFAULT 0,
    `status` enum('running','stopped') NOT NULL DEFAULT 'running',
    `stop_reason` varchar(64) NULL,
    `xp` bigint(20) UNSIGNED NOT NULL DEFAULT 0,
    `potions_used` int(11) UNSIGNED NOT NULL DEFAULT 0,
    `kills` int(11) UNSIGNED NOT NULL DEFAULT 0,
    `loot_value` bigint(20) UNSIGNED NOT NULL DEFAULT 0,
    `supplies_spent` bigint(20) UNSIGNED NOT NULL DEFAULT 0,
    `private_room` tinyint(1) NOT NULL DEFAULT 0,
    `settings` text NULL,
    CONSTRAINT `gerivia_bot_sessions_pk` PRIMARY KEY (`id`),
    INDEX `gerivia_bot_sessions_player_status` (`player_id`, `status`),
    INDEX `gerivia_bot_sessions_player_started` (`player_id`, `started_at`),
    CONSTRAINT `gerivia_bot_sessions_players_fk` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
	if not ok then
		logger.error("[Gerivia] Falha ao criar a tabela gerivia_bot_sessions")
	end
	-- Sessões que ficaram abertas quando o servidor caiu ou reiniciou.
	db.query(string.format("UPDATE `gerivia_bot_sessions` SET `status` = 'stopped', `ended_at` = `updated_at`, `stop_reason` = 'restart' WHERE `status` = 'running' AND `updated_at` <= %d", os.time()))
	return true
end

setup:register()
