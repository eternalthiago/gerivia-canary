-- Gerivia: tabelas próprias. Rodar depois do schema.sql do Canary.

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Alertas do bot (vida baixa, supply, capacidade, jogador perto, morte, fim) para o site.
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Sessões do bot online (para o site mostrar o bot ligado e o histórico).
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Visão para o painel de GM: XP e ouro gerados pelo idle por dia.
CREATE OR REPLACE VIEW `idle_daily_economy` AS
SELECT
    DATE(FROM_UNIXTIME(`finished_at`)) AS `day`,
    COUNT(*) AS `hunts`,
    SUM(CAST(JSON_UNQUOTE(JSON_EXTRACT(`result`, '$.xp')) AS UNSIGNED)) AS `xp`,
    SUM(CAST(JSON_UNQUOTE(JSON_EXTRACT(`result`, '$.gold')) AS UNSIGNED)) AS `gold`,
    SUM(CAST(JSON_UNQUOTE(JSON_EXTRACT(`result`, '$.itemsValue')) AS UNSIGNED)) AS `items_value`
FROM `idle_hunts`
WHERE `status` = 'done'
GROUP BY `day`;
