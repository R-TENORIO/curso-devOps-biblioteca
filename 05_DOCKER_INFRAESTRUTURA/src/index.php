<?php
/**
 * ============================================================
 * Sistema de Biblioteca Universitária Digital
 * Página Principal — Teste de Funcionamento
 * ============================================================
 * Projeto Integrado DevOps — Anhanguera 2026
 * Aluno: Rodrigo Tenorio Cavalcanti da Silva
 * Data: Março 2026
 * ============================================================
 */

// Configurações iniciais
date_default_timezone_set('America/Sao_Paulo');
header('Content-Type: text/html; charset=utf-8');

// Variáveis de ambiente do Docker
$db_host = getenv('DB_HOST') ?: 'db';
$db_name = getenv('DB_NAME') ?: 'biblioteca_universitaria';
$db_user = getenv('DB_USER') ?: 'biblioteca_user';
$db_pass = getenv('DB_PASS') ?: 'biblioteca_pass_secure_2026';

// Tentar conexão com banco de dados
$db_connected = false;
$db_error = null;
$stats = null;

try {
    $pdo = new PDO(
        "mysql:host=$db_host;dbname=$db_name;charset=utf8mb4",
        $db_user,
        $db_pass,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false
        ]
    );
    $db_connected = true;
    
    // Buscar estatísticas do banco
    $stats = $pdo->query("
        SELECT 
            (SELECT COUNT(*) FROM livro) AS total_livros,
            (SELECT COUNT(*) FROM exemplar) AS total_exemplares,
            (SELECT COUNT(*) FROM exemplar WHERE status='disponivel') AS disponiveis,
            (SELECT COUNT(*) FROM usuario WHERE ativo=1) AS usuarios_ativos,
            (SELECT COUNT(*) FROM emprestimo WHERE status IN ('ativo', 'atrasado')) AS emprestimos_ativos
    ")->fetch();
} catch (PDOException $e) {
    $db_error = "Erro de conexão: " . $e->getMessage();
    $db_connected = false;
}

// Informações do servidor
$server_info = [
    'php_version' => phpversion(),
    'server_software' => $_SERVER['SERVER_SOFTWARE'] ?? 'Apache',
    'server_time' => date('d/m/Y H:i:s'),
    'timezone' => date_default_timezone_get(),
    'container_hostname' => gethostname()
];
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sistema de Biblioteca Universitária Digital</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 40px;
            max-width: 900px;
            width: 100%;
        }
        h1 {
            color: #667eea;
            text-align: center;
            margin-bottom: 10px;
            font-size: 2.2em;
        }
        .subtitle {
            text-align: center;
            color: #666;
            margin-bottom: 30px;
            font-size: 1.1em;
        }
        .status {
            text-align: center;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 30px;
            font-weight: bold;
        }
        .status.success {
            background: #d4edda;
            color: #155724;
            border: 2px solid #c3e6cb;
        }
        .status.error {
            background: #f8d7da;
            color: #721c24;
            border: 2px solid #f5c6cb;
        }
        .datetime {
            text-align: center;
            background: #f7fafc;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 30px;
            font-size: 1.1em;
            color: #333;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
        }
        .stat-number {
            font-size: 2.2em;
            font-weight: bold;
            display: block;
        }
        .stat-label {
            font-size: 0.85em;
            opacity: 0.95;
            margin-top: 5px;
        }
        .info {
            background: #edf2f7;
            padding: 20px;
            border-radius: 10px;
            margin-top: 20px;
        }
        .info h3 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.2em;
        }
        .info ul {
            list-style: none;
            padding-left: 0;
        }
        .info li {
            padding: 8px 0;
            padding-left: 25px;
            position: relative;
            border-bottom: 1px solid #e2e8f0;
        }
        .info li:before {
            content: "✓";
            color: #48bb78;
            position: absolute;
            left: 0;
            font-weight: bold;
            font-size: 1.2em;
        }
        .server-info {
            background: #fff3cd;
            padding: 15px;
            border-radius: 10px;
            margin-top: 20px;
            font-size: 0.9em;
        }
        .server-info h4 {
            color: #856404;
            margin-bottom: 10px;
        }
        .server-info table {
            width: 100%;
            border-collapse: collapse;
        }
        .server-info td {
            padding: 5px 10px;
            border-bottom: 1px solid #ffeaa7;
        }
        .server-info td:first-child {
            font-weight: bold;
            color: #856404;
            width: 40%;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            color: #666;
            font-size: 0.85em;
            padding-top: 20px;
            border-top: 2px solid #e2e8f0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📚 Sistema de Biblioteca Universitária</h1>
        <p class="subtitle">Gerenciamento Integrado de Acervo Digital</p>
        
        <?php if ($db_connected): ?>
        <div class="status success">
            ✅ Banco de Dados: Conectado com Sucesso
        </div>
        <?php else: ?>
        <div class="status error">
            ⚠️ Banco de Dados: <?php echo htmlspecialchars($db_error); ?>
        </div>
        <?php endif; ?>

        <div class="datetime">
            <strong>🕐 Data/Hora do Servidor:</strong><br>
            <?php echo $server_info['server_time']; ?> 
            (<?php echo $server_info['timezone']; ?>)
        </div>

        <?php if ($db_connected && $stats): ?>
        <div class="stats">
            <div class="stat-card">
                <span class="stat-number"><?php echo $stats['total_livros']; ?></span>
                <span class="stat-label">📖 Total de Livros</span>
            </div>
            <div class="stat-card">
                <span class="stat-number"><?php echo $stats['total_exemplares']; ?></span>
                <span class="stat-label">📚 Total de Exemplares</span>
            </div>
            <div class="stat-card">
                <span class="stat-number"><?php echo $stats['disponiveis']; ?></span>
                <span class="stat-label">✅ Disponíveis</span>
            </div>
            <div class="stat-card">
                <span class="stat-number"><?php echo $stats['usuarios_ativos']; ?></span>
                <span class="stat-label">👥 Usuários Ativos</span>
            </div>
            <div class="stat-card">
                <span class="stat-number"><?php echo $stats['emprestimos_ativos']; ?></span>
                <span class="stat-label">📋 Empréstimos Ativos</span>
            </div>
        </div>
        <?php endif; ?>

        <div class="info">
            <h3>🚀 Funcionalidades Implementadas:</h3>
            <ul>
                <li>Consulta online do acervo completo com filtros avançados</li>
                <li>Reserva e renovação de livros via interface web</li>
                <li>Controle de empréstimos e devoluções com cálculo automático de multas</li>
                <li>Gerenciamento de usuários com diferentes perfis (Aluno, Professor, Funcionário)</li>
                <li>Relatórios gerenciais em tempo real com Views otimizadas</li>
                <li>Sistema de recomendações baseado em histórico de empréstimos</li>
                <li>Integração entre 3 unidades da biblioteca (Central, Norte, Sul)</li>
                <li>Arquitetura distribuída com replicação MySQL Master-Slave</li>
                <li>Containerização Docker para portabilidade e escalabilidade</li>
            </ul>
        </div>

        <div class="server-info">
            <h4>🖥️ Informações do Servidor</h4>
            <table>
                <tr>
                    <td>Versão do PHP:</td>
                    <td><?php echo $server_info['php_version']; ?></td>
                </tr>
                <tr>
                    <td>Servidor Web:</td>
                    <td><?php echo htmlspecialchars($server_info['server_software']); ?></td>
                </tr>
                <tr>
                    <td>Hostname do Container:</td>
                    <td><?php echo $server_info['container_hostname']; ?></td>
                </tr>
                <tr>
                    <td>Timezone:</td>
                    <td><?php echo $server_info['timezone']; ?></td>
                </tr>
            </table>
        </div>

        <div class="footer">
            <p><strong>Desenvolvido por:</strong> Rodrigo Tenorio Cavalcanti da Silva</p>
            <p><strong>Curso:</strong> DevOps | <strong>Instituição:</strong> Anhanguera</p>
            <p><strong>Projeto:</strong> Projeto Integrado 2026 | <strong>Versão:</strong> 1.0.0</p>
        </div>
    </div>
</body>
</html>
