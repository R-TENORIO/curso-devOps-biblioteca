<?php
header('Content-Type: application/json');
$health = [
    'status' => 'healthy',
    'timestamp' => date('c'),
    'service' => 'Biblioteca Universitária'
];
echo json_encode($health);
?>
