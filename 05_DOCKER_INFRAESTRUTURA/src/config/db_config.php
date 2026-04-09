<?php
return [
    'host' => getenv('DB_HOST') ?: 'db',
    'database' => getenv('DB_NAME') ?: 'biblioteca_universitaria',
    'username' => getenv('DB_USER') ?: 'biblioteca_user',
    'password' => getenv('DB_PASS') ?: 'biblioteca_pass_secure_2026',
    'charset' => 'utf8mb4'
];
?>
