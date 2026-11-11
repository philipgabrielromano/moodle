<?php
// Exit codes: 0 = Moodle installed, 1 = database empty (needs install), 2 = cannot connect.
$db = parse_url(getenv('DATABASE_URL'));
$conn = sprintf(
    "host=%s port=%d dbname=%s user=%s password=%s connect_timeout=5",
    $db['host'], $db['port'] ?? 5432, ltrim($db['path'], '/'),
    urldecode($db['user']), urldecode($db['pass'] ?? '')
);
$link = @pg_connect($conn);
if (!$link) { exit(2); }
$res = pg_query($link, "SELECT to_regclass('public.mdl_config') IS NOT NULL AS installed");
$row = $res ? pg_fetch_assoc($res) : null;
exit(($row && $row['installed'] === 't') ? 0 : 1);
