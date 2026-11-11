<?php  // Moodle configuration, driven by Render environment variables
unset($CFG);
global $CFG;
$CFG = new stdClass();

// Database: Render provides DATABASE_URL (postgresql://user:pass@host[:port]/dbname)
$db = parse_url(getenv('DATABASE_URL'));
$CFG->dbtype    = 'pgsql';
$CFG->dblibrary = 'native';
$CFG->dbhost    = $db['host'];
$CFG->dbname    = ltrim($db['path'], '/');
$CFG->dbuser    = urldecode($db['user']);
$CFG->dbpass    = urldecode($db['pass'] ?? '');
$CFG->prefix    = 'mdl_';
$CFG->dboptions = [
    'dbpersist' => false,
    'dbport'    => (int)($db['port'] ?? 5432),
    'dbsocket'  => false,
];

// Site URL: MOODLE_WWWROOT if set (e.g. a custom domain), otherwise the
// https://<name>.onrender.com address Render provides automatically
$CFG->wwwroot  = rtrim(getenv('MOODLE_WWWROOT') ?: getenv('RENDER_EXTERNAL_URL'), '/');

// Persistent files live on the Render disk; local caches stay in the container for speed
$CFG->dataroot      = getenv('MOODLE_DATAROOT') ?: '/var/moodledata';
$CFG->localcachedir = '/var/cache/moodle';
$CFG->directorypermissions = 02770;
$CFG->admin = 'admin';

// Render terminates HTTPS at its proxy
$CFG->sslproxy = true;

// Moodle 5.1+ keeps lib/ under public/; older versions keep it in the root
$setup = file_exists(__DIR__ . '/lib/setup.php')
    ? __DIR__ . '/lib/setup.php'
    : __DIR__ . '/public/lib/setup.php';
require_once($setup);
