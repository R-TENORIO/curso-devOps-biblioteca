-- ============================================
-- BIBLIOTECA UNIVERSITÁRIA - PROJETO INTEGRADO DEVOPS
-- Tarefa 3: Programação e Desenvolvimento de Banco de Dados
-- Versão Final Corrigida - 30/03/2026
-- ============================================

-- ============================================
-- 0. CONFIGURAÇÃO INICIAL
-- ============================================

-- Habilitar Event Scheduler (para automação de events)
SET GLOBAL event_scheduler = ON;

-- Desabilitar verificação de FKs temporariamente para recriação limpa
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================
-- 1. LIMPEZA DE OBJETOS (IDEMPOTÊNCIA)
-- ============================================

DROP DATABASE IF EXISTS biblioteca_universitaria;

-- ============================================
-- 2. CRIAÇÃO DO BANCO DE DADOS
-- ============================================

CREATE DATABASE biblioteca_universitaria
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE biblioteca_universitaria;

-- ============================================
-- 3. LIMPEZA DE OBJETOS INTERNOS (REEXECUÇÃO SEGURA)
-- ============================================

-- Events
DROP EVENT IF EXISTS evt_verificar_reservas_expiradas;
DROP EVENT IF EXISTS evt_atualizar_atrasos;

-- Views
DROP VIEW IF EXISTS vw_multas_pendentes;
DROP VIEW IF EXISTS vw_disponibilidade_unidades;
DROP VIEW IF EXISTS vw_emprestimos_ativos;

-- Triggers (serão recriados após tabelas)
-- Tabelas serão dropadas com CASCADE via DROP DATABASE acima

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================
-- 4. TABELAS DE SUPORTE (Sem FK)
-- ============================================

CREATE TABLE idioma (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(50) NOT NULL,
    codigo_iso VARCHAR(10) NOT NULL UNIQUE,
    INDEX idx_codigo (codigo_iso)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Idiomas dos livros';

CREATE TABLE editora (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    cidade VARCHAR(50),
    pais VARCHAR(50),
    ano_fundacao SMALLINT UNSIGNED,
    INDEX idx_nome (nome)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Editoras dos livros';

CREATE TABLE categoria (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(50) NOT NULL,
    descricao TEXT,
    categoria_pai_id INT NULL,
    FOREIGN KEY (categoria_pai_id) REFERENCES categoria(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_nome (nome)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Categorias hierárquicas';

CREATE TABLE unidade (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    codigo VARCHAR(20) NOT NULL UNIQUE,
    endereco VARCHAR(200),
    telefone VARCHAR(20),
    email VARCHAR(100),
    INDEX idx_codigo (codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Unidades físicas da biblioteca';

CREATE TABLE autor (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    nacionalidade VARCHAR(50),
    data_nascimento DATE,
    INDEX idx_nome (nome)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Autores dos livros';

-- ============================================
-- 5. TABELA: LIVRO
-- ============================================

CREATE TABLE livro (
    id INT AUTO_INCREMENT PRIMARY KEY,
    isbn VARCHAR(13) NOT NULL UNIQUE COMMENT 'ISBN-13',
    titulo VARCHAR(200) NOT NULL,
    ano_publicacao YEAR,
    num_paginas INT,
    edicao VARCHAR(20),
    editora_id INT,
    idioma_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (editora_id) REFERENCES editora(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (idioma_id) REFERENCES idioma(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    
    INDEX idx_titulo (titulo),
    INDEX idx_isbn (isbn),
    INDEX idx_ano (ano_publicacao),
    FULLTEXT INDEX idx_titulo_fulltext (titulo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Catálogo de livros';

-- ============================================
-- 6. TABELAS ASSOCIATIVAS N:M
-- ============================================

CREATE TABLE livro_autor (
    livro_id INT NOT NULL,
    autor_id INT NOT NULL,
    ordem_autoria INT DEFAULT 1,
    tipo_contribuicao VARCHAR(50) DEFAULT 'Autor',
    
    PRIMARY KEY (livro_id, autor_id),
    
    FOREIGN KEY (livro_id) REFERENCES livro(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (autor_id) REFERENCES autor(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    
    INDEX idx_autor (autor_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Relacionamento N:M Livro-Autor';

CREATE TABLE livro_categoria (
    livro_id INT NOT NULL,
    categoria_id INT NOT NULL,
    relevancia DECIMAL(3,2) DEFAULT 1.00,
    
    PRIMARY KEY (livro_id, categoria_id),
    
    FOREIGN KEY (livro_id) REFERENCES livro(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (categoria_id) REFERENCES categoria(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    
    INDEX idx_categoria (categoria_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Relacionamento N:M Livro-Categoria';

-- ============================================
-- 7. TABELA: USUARIO (Herança via tipo ENUM)
-- ============================================

CREATE TABLE usuario (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tipo ENUM('aluno', 'professor', 'funcionario') NOT NULL COMMENT 'Herança: tipos de usuário',
    matricula VARCHAR(20) NOT NULL UNIQUE,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    telefone VARCHAR(20),
    data_nascimento DATE,
    limite_emprestimos INT DEFAULT 5,
    ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_matricula (matricula),
    INDEX idx_email (email),
    INDEX idx_tipo (tipo),
    INDEX idx_ativo (ativo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Usuários do sistema (herança via tipo)';

-- ============================================
-- 8. TABELA: EXEMPLAR
-- ============================================

CREATE TABLE exemplar (
    id INT AUTO_INCREMENT PRIMARY KEY,
    numero_tombo VARCHAR(20) NOT NULL UNIQUE COMMENT 'Código único do exemplar',
    status ENUM('disponivel', 'emprestado', 'manutencao', 'perdido', 'reservado') 
        DEFAULT 'disponivel',
    data_aquisicao DATE NOT NULL,
    condicao VARCHAR(50) DEFAULT 'bom',
    livro_id INT NOT NULL,
    unidade_id INT NOT NULL,
    
    FOREIGN KEY (livro_id) REFERENCES livro(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (unidade_id) REFERENCES unidade(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    INDEX idx_tombo (numero_tombo),
    INDEX idx_status (status),
    INDEX idx_unidade (unidade_id),
    INDEX idx_livro_unidade (livro_id, unidade_id),
    INDEX idx_disponivel (unidade_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Exemplares físicos dos livros';

-- ============================================
-- 9. TABELA: EMPRESTIMO
-- ============================================

CREATE TABLE emprestimo (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data_emprestimo DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_prevista_devolucao DATE NOT NULL,
    data_devolucao DATETIME,
    status ENUM('ativo', 'devolvido', 'atrasado', 'renovado', 'perdido') 
        DEFAULT 'ativo',
    renovacoes INT DEFAULT 0,
    observacoes TEXT,
    usuario_id INT NOT NULL,
    exemplar_id INT NOT NULL,
    
    FOREIGN KEY (usuario_id) REFERENCES usuario(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (exemplar_id) REFERENCES exemplar(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    INDEX idx_usuario (usuario_id),
    INDEX idx_exemplar (exemplar_id),
    INDEX idx_status (status),
    INDEX idx_data_prevista (data_prevista_devolucao),
    INDEX idx_atrasados (status, data_prevista_devolucao),
    INDEX idx_ativo_usuario (usuario_id, status),
    INDEX idx_atraso_check (status, data_prevista_devolucao) COMMENT 'Otimização para consulta de atrasos'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Registro de empréstimos';

-- ============================================
-- 10. TABELA: MULTA
-- ============================================

CREATE TABLE multa (
    id INT AUTO_INCREMENT PRIMARY KEY,
    valor DECIMAL(10,2) NOT NULL,
    dias_atraso INT NOT NULL,
    data_geracao DATETIME DEFAULT CURRENT_TIMESTAMP,
    data_pagamento DATETIME,
    status ENUM('pendente', 'paga', 'cancelada', 'parcelada') DEFAULT 'pendente',
    forma_pagamento VARCHAR(50),
    emprestimo_id INT NOT NULL,
    
    FOREIGN KEY (emprestimo_id) REFERENCES emprestimo(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    INDEX idx_emprestimo (emprestimo_id),
    INDEX idx_status (status),
    INDEX idx_pendentes (status, data_geracao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Multas geradas automaticamente';

-- ============================================
-- 11. TABELA: RESERVA
-- ============================================

CREATE TABLE reserva (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data_reserva DATETIME DEFAULT CURRENT_TIMESTAMP,
    data_expiracao DATETIME NOT NULL,
    status ENUM('ativa', 'atendida', 'cancelada', 'expirada') DEFAULT 'ativa',
    posicao_fila INT,
    notificado BOOLEAN DEFAULT FALSE,
    usuario_id INT NOT NULL,
    livro_id INT NOT NULL,
    
    FOREIGN KEY (usuario_id) REFERENCES usuario(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (livro_id) REFERENCES livro(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    
    INDEX idx_usuario (usuario_id),
    INDEX idx_livro (livro_id),
    INDEX idx_status (status),
    INDEX idx_livro_ativa (livro_id, status),
    INDEX idx_posicao (livro_id, posicao_fila)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Reservas de livros';

-- ============================================
-- 12. VIEWS PARA RELATÓRIOS
-- ============================================

-- View: Resumo de empréstimos ativos e atrasados
CREATE VIEW vw_emprestimos_ativos AS
SELECT 
    e.id AS emprestimo_id,
    u.nome AS usuario,
    u.tipo AS tipo_usuario,
    u.matricula,
    l.titulo AS livro,
    l.isbn,
    ex.numero_tombo,
    un.nome AS unidade,
    un.codigo AS codigo_unidade,
    e.data_emprestimo,
    e.data_prevista_devolucao,
    DATEDIFF(e.data_prevista_devolucao, CURDATE()) AS dias_restantes,
    CASE 
        WHEN e.data_prevista_devolucao < CURDATE() THEN 'ATRASADO'
        WHEN DATEDIFF(e.data_prevista_devolucao, CURDATE()) <= 2 THEN 'URGENTE'
        ELSE 'NO PRAZO'
    END AS situacao,
    CASE 
        WHEN e.data_prevista_devolucao < CURDATE() 
        THEN DATEDIFF(CURDATE(), e.data_prevista_devolucao) * 2.00 
        ELSE 0.00 
    END AS valor_multa_projetado
FROM emprestimo e
JOIN usuario u ON e.usuario_id = u.id
JOIN exemplar ex ON e.exemplar_id = ex.id
JOIN livro l ON ex.livro_id = l.id
JOIN unidade un ON ex.unidade_id = un.id
WHERE e.status IN ('ativo', 'atrasado');

-- View: Disponibilidade por unidade (para consulta 1)
CREATE VIEW vw_disponibilidade_unidades AS
SELECT 
    un.id AS unidade_id,
    un.nome AS unidade,
    un.codigo AS codigo_unidade,
    l.id AS livro_id,
    l.titulo,
    l.isbn,
    COUNT(ex.id) AS total_exemplares,
    SUM(CASE WHEN ex.status = 'disponivel' THEN 1 ELSE 0 END) AS disponiveis,
    SUM(CASE WHEN ex.status = 'emprestado' THEN 1 ELSE 0 END) AS emprestados,
    SUM(CASE WHEN ex.status = 'manutencao' THEN 1 ELSE 0 END) AS em_manutencao,
    SUM(CASE WHEN ex.status = 'reservado' THEN 1 ELSE 0 END) AS reservados,
    ROUND(SUM(CASE WHEN ex.status = 'emprestado' THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(COUNT(ex.id), 0), 2) AS taxa_ocupacao_percent
FROM unidade un
LEFT JOIN exemplar ex ON un.id = ex.unidade_id
LEFT JOIN livro l ON ex.livro_id = l.id
GROUP BY un.id, un.nome, un.codigo, l.id, l.titulo, l.isbn
HAVING un.id IS NOT NULL;

-- View: Multas pendentes (para teste de trigger)
CREATE VIEW vw_multas_pendentes AS
SELECT 
    m.id AS multa_id,
    m.valor,
    m.dias_atraso,
    m.data_geracao,
    DATEDIFF(CURDATE(), DATE(m.data_geracao)) AS dias_desde_geracao,
    u.nome AS usuario,
    u.email,
    u.matricula,
    l.titulo AS livro,
    e.data_emprestimo,
    e.data_devolucao,
    e.id AS emprestimo_id
FROM multa m
JOIN emprestimo e ON m.emprestimo_id = e.id
JOIN usuario u ON e.usuario_id = u.id
JOIN exemplar ex ON e.exemplar_id = ex.id
JOIN livro l ON ex.livro_id = l.id
WHERE m.status = 'pendente';

-- ============================================
-- 13. TRIGGERS PARA AUTOMAÇÃO
-- ============================================

DELIMITER $$

-- Trigger 1: Atualizar status de empréstimo para 'atrasado' no UPDATE
-- NOTA: Só funciona quando o registro é atualizado, não no INSERT
CREATE TRIGGER trg_verificar_atraso
BEFORE UPDATE ON emprestimo
FOR EACH ROW
BEGIN
    IF NEW.status = 'ativo' AND NEW.data_prevista_devolucao < CURDATE() THEN
        SET NEW.status = 'atrasado';
    END IF;
END$$

-- Trigger 2: Gerar multa automaticamente ao devolver com atraso
CREATE TRIGGER trg_gerar_multa
AFTER UPDATE ON emprestimo
FOR EACH ROW
BEGIN
    DECLARE v_dias_atraso INT;
    DECLARE v_valor_multa DECIMAL(10,2);
    
    -- Só processa se foi devolvido com atraso (data_devolucao preenchida agora, mas não antes)
    IF NEW.data_devolucao IS NOT NULL AND 
       OLD.data_devolucao IS NULL AND
       NEW.data_devolucao > NEW.data_prevista_devolucao THEN
        
        SET v_dias_atraso = DATEDIFF(NEW.data_devolucao, NEW.data_prevista_devolucao);
        SET v_valor_multa = v_dias_atraso * 2.00; -- R$ 2,00 por dia de atraso
        
        INSERT INTO multa (emprestimo_id, valor, dias_atraso, status)
        VALUES (NEW.id, v_valor_multa, v_dias_atraso, 'pendente');
    END IF;
END$$

-- Trigger 3: Atualizar status do exemplar para 'emprestado' no INSERT de empréstimo
CREATE TRIGGER trg_atualizar_exemplar_emprestimo
AFTER INSERT ON emprestimo
FOR EACH ROW
BEGIN
    UPDATE exemplar 
    SET status = 'emprestado' 
    WHERE id = NEW.exemplar_id;
END$$

-- Trigger 4: Atualizar status do exemplar para 'disponivel' na devolução
CREATE TRIGGER trg_atualizar_exemplar_devolucao
AFTER UPDATE ON emprestimo
FOR EACH ROW
BEGIN
    IF NEW.data_devolucao IS NOT NULL AND OLD.data_devolucao IS NULL THEN
        UPDATE exemplar 
        SET status = 'disponivel' 
        WHERE id = NEW.exemplar_id;
    END IF;
END$$

DELIMITER ;

-- ============================================
-- 14. EVENTS (AUTOMATIZAÇÃO PROGRAMADA)
-- ============================================

-- Event 1: Marcar reservas expiradas diariamente
CREATE EVENT IF NOT EXISTS evt_verificar_reservas_expiradas
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
ENABLE
COMMENT 'Marca reservas expiradas automaticamente'
DO
    UPDATE reserva 
    SET status = 'expirada'
    WHERE status = 'ativa' 
    AND data_expiracao < NOW();

-- Event 2: Atualizar empréstimos atrasados diariamente
-- IMPORTANTE: Este evento compensa a limitação do trigger trg_verificar_atraso
CREATE EVENT IF NOT EXISTS evt_atualizar_atrasos
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
ENABLE
COMMENT 'Atualiza status de empréstimos para atrasado automaticamente'
DO
    UPDATE emprestimo 
    SET status = 'atrasado'
    WHERE status = 'ativo' 
    AND data_prevista_devolucao < CURDATE();

-- ============================================
-- 15. DADOS DE TESTE (DML)
-- ============================================

-- 15.1 Idiomas
INSERT INTO idioma (nome, codigo_iso) VALUES
('Português', 'pt-BR'),
('Inglês', 'en-US'),
('Espanhol', 'es-ES'),
('Francês', 'fr-FR');

-- 15.2 Editoras
INSERT INTO editora (nome, cidade, pais, ano_fundacao) VALUES
('Pearson', 'São Paulo', 'Brasil', 1935),
('Elsevier', 'Amsterdam', 'Países Baixos', 1880),
('O''Reilly Media', 'Sebastopol', 'EUA', 1978),
('Packt Publishing', 'Birmingham', 'Reino Unido', 2004),
('Novatec', 'São Paulo', 'Brasil', 2000);

-- 15.3 Categorias principais
INSERT INTO categoria (nome, descricao) VALUES
('Programação', 'Desenvolvimento de software e linguagens de programação'),
('Banco de Dados', 'Sistemas de gerenciamento de dados e modelagem'),
('Redes', 'Redes de computadores, protocolos e infraestrutura'),
('DevOps', 'Integração contínua, entrega contínua e automação'),
('Segurança', 'Segurança da informação e cibersegurança'),
('Inteligência Artificial', 'Machine learning, deep learning e IA'),
('Ciência de Dados', 'Análise, processamento e visualização de dados');

-- 15.4 Subcategorias
INSERT INTO categoria (nome, descricao, categoria_pai_id) VALUES
('MySQL', 'Banco de dados MySQL e MariaDB', 2),
('Docker', 'Containerização e orquestração', 4),
('Python', 'Linguagem Python e bibliotecas', 1),
('Kubernetes', 'Orquestração de containers', 4);

-- 15.5 Unidades (3 unidades conforme enunciado)
INSERT INTO unidade (nome, codigo, endereco, telefone, email) VALUES
('Biblioteca Central - Campus Central', 'BCC', 'Av. Principal, 1000 - Centro', '(11) 3333-4444', 'central@biblioteca.edu.br'),
('Biblioteca Norte - Campus Norte', 'BCN', 'Rua Norte, 500 - Zona Norte', '(11) 3333-5555', 'norte@biblioteca.edu.br'),
('Biblioteca Sul - Campus Sul', 'BCS', 'Av. Sul, 800 - Zona Sul', '(11) 3333-6666', 'sul@biblioteca.edu.br');

-- 15.6 Autores
INSERT INTO autor (nome, nacionalidade, data_nascimento) VALUES
('Carlos Silva', 'Brasileiro', '1975-03-15'),
('Maria Santos', 'Brasileira', '1980-07-22'),
('John Smith', 'Americano', '1968-11-10'),
('Jane Doe', 'Britânica', '1972-05-30'),
('Pedro Oliveira', 'Brasileiro', '1985-09-18'),
('Ana Costa', 'Brasileira', '1990-12-05'),
('Robert Johnson', 'Americano', '1955-08-20');

-- 15.7 Livros (8 livros obrigatórios - diferentes categorias/autores)
INSERT INTO livro (isbn, titulo, ano_publicacao, num_paginas, edicao, editora_id, idioma_id) VALUES
('9788575226896', 'MySQL: Guia do Programador', 2020, 350, '3ª Edição', 5, 1),
('9788535297669', 'Banco de Dados: Modelagem e Implementação', 2019, 420, '2ª Edição', 1, 1),
('9781491950388', 'Docker: Up & Running', 2021, 250, '3ª Edição', 3, 2),
('9781788296663', 'DevOps Handbook', 2020, 480, '1ª Edição', 4, 2),
('9788550804460', 'Redes de Computadores', 2021, 520, '5ª Edição', 1, 1),
('9788595010239', 'Kubernetes: Guia Prático', 2022, 380, '2ª Edição', 5, 1),
('9781492046530', 'Python for Data Analysis', 2022, 550, '3ª Edição', 3, 2),
('9788550806624', 'Segurança em Banco de Dados', 2021, 290, '1ª Edição', 5, 1);

-- 15.8 Relacionamentos Livro-Autor
INSERT INTO livro_autor (livro_id, autor_id, ordem_autoria, tipo_contribuicao) VALUES
(1, 1, 1, 'Autor'),           -- MySQL -> Carlos Silva
(2, 2, 1, 'Autora'),          -- Banco de Dados -> Maria Santos
(3, 3, 1, 'Autor'),           -- Docker -> John Smith
(4, 3, 1, 'Co-autor'),        -- DevOps Handbook -> John Smith
(4, 4, 2, 'Co-autora'),       -- DevOps Handbook -> Jane Doe
(5, 5, 1, 'Autor'),           -- Redes -> Pedro Oliveira
(6, 1, 1, 'Autor'),           -- Kubernetes -> Carlos Silva
(7, 3, 1, 'Autor'),           -- Python -> John Smith
(8, 2, 1, 'Autora');          -- Segurança -> Maria Santos

-- 15.9 Relacionamentos Livro-Categoria
INSERT INTO livro_categoria (livro_id, categoria_id, relevancia) VALUES
(1, 8, 1.00),   -- MySQL -> MySQL
(1, 2, 0.90),   -- MySQL -> Banco de Dados
(2, 2, 1.00),   -- Banco de Dados -> Banco de Dados
(3, 9, 1.00),   -- Docker -> Docker
(3, 4, 0.95),   -- Docker -> DevOps
(4, 4, 1.00),   -- DevOps Handbook -> DevOps
(5, 3, 1.00),   -- Redes -> Redes
(6, 4, 1.00),   -- Kubernetes -> DevOps
(6, 10, 0.90),  -- Kubernetes -> Kubernetes
(7, 11, 1.00),  -- Python -> Python
(7, 7, 0.85),   -- Python -> Ciência de Dados
(8, 2, 0.90),   -- Segurança -> Banco de Dados
(8, 5, 1.00);   -- Segurança -> Segurança

-- 15.10 Usuários (5 usuários: 2 alunos, 2 professores, 1 funcionário)
INSERT INTO usuario (tipo, matricula, nome, email, telefone, data_nascimento, limite_emprestimos, ativo) VALUES
('aluno', '2024001', 'Ana Paula Silva', 'ana.silva@university.edu.br', '(11) 99999-1111', '2000-05-15', 5, TRUE),
('aluno', '2024002', 'Bruno Costa', 'bruno.costa@university.edu.br', '(11) 99999-2222', '1999-08-22', 5, TRUE),
('professor', 'PROF001', 'Dr. Carlos Mendes', 'carlos.mendes@university.edu.br', '(11) 99999-3333', '1975-03-10', 10, TRUE),
('professor', 'PROF002', 'Dra. Fernanda Alves', 'fernanda.alves@university.edu.br', '(11) 99999-4444', '1980-11-28', 10, TRUE),
('funcionario', 'FUNC001', 'João Pedro Santos', 'joao.santos@university.edu.br', '(11) 99999-5555', '1985-07-05', 3, TRUE);

-- 15.11 Exemplares (16 exemplares distribuídos nas 3 unidades)
INSERT INTO exemplar (numero_tombo, status, data_aquisicao, condicao, livro_id, unidade_id) VALUES
('T001-001', 'disponivel', '2020-01-15', 'bom', 1, 1),      -- MySQL na BCC
('T001-002', 'disponivel', '2020-01-15', 'bom', 1, 2),      -- MySQL na BCN
('T001-003', 'emprestado', '2020-02-20', 'regular', 1, 3),  -- MySQL na BCS (emprestado)
('T002-001', 'disponivel', '2019-03-10', 'bom', 2, 1),      -- Banco de Dados na BCC
('T002-002', 'manutencao', '2019-03-10', 'danificado', 2, 2), -- Banco de Dados na BCN
('T003-001', 'disponivel', '2021-05-22', 'novo', 3, 1),     -- Docker na BCC
('T003-002', 'disponivel', '2021-05-22', 'novo', 3, 3),     -- Docker na BCS
('T004-001', 'emprestado', '2020-08-15', 'bom', 4, 1),      -- DevOps na BCC (emprestado)
('T004-002', 'disponivel', '2020-08-15', 'bom', 4, 2),      -- DevOps na BCN
('T005-001', 'disponivel', '2021-02-28', 'bom', 5, 1),      -- Redes na BCC
('T005-002', 'disponivel', '2021-02-28', 'bom', 5, 2),      -- Redes na BCN
('T005-003', 'perdido', '2021-02-28', 'desaparecido', 5, 3), -- Redes na BCS (perdido)
('T006-001', 'disponivel', '2022-01-10', 'novo', 6, 1),     -- Kubernetes na BCC
('T007-001', 'emprestado', '2022-03-15', 'bom', 7, 2),      -- Python na BCN (emprestado)
('T008-001', 'disponivel', '2021-06-20', 'bom', 8, 1),      -- Segurança na BCC
('T008-002', 'disponivel', '2021-06-20', 'bom', 8, 3);      -- Segurança na BCS

-- 15.12 Empréstimos (5 empréstimos, sendo 1 em atraso para gerar multa)
-- Data de referência: 2026-03-30 (hoje)
INSERT INTO emprestimo (data_emprestimo, data_prevista_devolucao, data_devolucao, status, renovacoes, usuario_id, exemplar_id) VALUES
('2026-03-01 10:30:00', '2026-03-15', NULL, 'ativo', 0, 1, 3),      -- Ana - em dia (vence em 15 dias)
('2026-02-20 14:15:00', '2026-03-10', NULL, 'ativo', 0, 2, 8),      -- Bruno - ATRASADO (20 dias de atraso!)
('2026-03-10 09:00:00', '2026-03-24', NULL, 'ativo', 0, 3, 1),      -- Carlos - em dia (vence em 6 dias)
('2026-03-12 16:45:00', '2026-03-26', NULL, 'ativo', 0, 4, 14),     -- Fernanda - em dia (vence em 4 dias)
('2026-03-08 11:20:00', '2026-03-22', '2026-03-20 15:30:00', 'devolvido', 0, 1, 6); -- Ana - devolvido (no prazo)

-- 15.13 Reservas (2 reservas ativas)
INSERT INTO reserva (data_reserva, data_expiracao, status, posicao_fila, notificado, usuario_id, livro_id) VALUES
('2026-03-25 10:00:00', '2026-04-01 23:59:59', 'ativa', 1, FALSE, 2, 1),   -- Bruno reserva MySQL
('2026-03-28 14:30:00', '2026-04-04 23:59:59', 'ativa', 1, FALSE, 5, 4);   -- João reserva DevOps Handbook

-- ============================================
-- 16. CORREÇÃO DE STATUS (CRÍTICO!)
-- ============================================
-- Atualiza empréstimos que já estão atrasados mas ainda marcados como 'ativo'
-- Isso garante que a Consulta 3 funcione imediatamente

UPDATE emprestimo 
SET status = 'atrasado'
WHERE status = 'ativo' 
AND data_prevista_devolucao < CURDATE();

-- ============================================
-- 17. CONSULTAS OBRIGATÓRIAS (5 CONSULTAS)
-- ============================================

-- ============================================
-- CONSULTA 1: Exemplares disponíveis de uma unidade específica
-- (título, autor, ISBN, localização)
-- ============================================
SELECT 
    l.titulo,
    GROUP_CONCAT(DISTINCT a.nome SEPARATOR ', ') AS autores,
    l.isbn,
    un.nome AS unidade,
    ex.numero_tombo AS localizacao
FROM exemplar ex
JOIN livro l ON ex.livro_id = l.id
JOIN livro_autor la ON l.id = la.livro_id
JOIN autor a ON la.autor_id = a.id
JOIN unidade un ON ex.unidade_id = un.id
WHERE ex.status = 'disponivel'
AND un.codigo = 'BCC'  -- Biblioteca Central
GROUP BY l.id, l.titulo, l.isbn, un.nome, ex.numero_tombo
ORDER BY l.titulo;

-- ============================================
-- CONSULTA 2: 5 livros mais emprestados nos últimos 6 meses
-- (título, autor, quantidade total)
-- ============================================
SELECT 
    l.titulo,
    GROUP_CONCAT(DISTINCT a.nome SEPARATOR ', ') AS autores,
    COUNT(e.id) AS total_emprestimos
FROM livro l
JOIN exemplar ex ON l.id = ex.livro_id
JOIN emprestimo e ON ex.id = e.exemplar_id
JOIN livro_autor la ON l.id = la.livro_id
JOIN autor a ON la.autor_id = a.id
WHERE e.data_emprestimo >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY l.id, l.titulo
ORDER BY total_emprestimos DESC
LIMIT 5;

-- ============================================
-- CONSULTA 3: Usuários com empréstimos em atraso
-- (calcular dias de atraso e valor da multa - R$ 2,00/dia)
-- ============================================
SELECT 
    u.nome AS usuario,
    u.matricula,
    u.tipo,
    u.email,
    l.titulo AS livro,
    e.data_prevista_devolucao,
    DATEDIFF(CURDATE(), e.data_prevista_devolucao) AS dias_atraso,
    DATEDIFF(CURDATE(), e.data_prevista_devolucao) * 2.00 AS valor_multa,
    un.nome AS unidade
FROM emprestimo e
JOIN usuario u ON e.usuario_id = u.id
JOIN exemplar ex ON e.exemplar_id = ex.id
JOIN livro l ON ex.livro_id = l.id
JOIN unidade un ON ex.unidade_id = un.id
WHERE e.status = 'atrasado'
ORDER BY dias_atraso DESC, valor_multa DESC;

-- ============================================
-- CONSULTA 4: Histórico completo de empréstimos de um usuário específico
-- (título, datas, status: devolvido/em atraso/ativo)
-- ============================================
SELECT 
    l.titulo AS livro,
    GROUP_CONCAT(DISTINCT a.nome SEPARATOR ', ') AS autor,
    e.data_emprestimo,
    e.data_prevista_devolucao,
    e.data_devolucao,
    CASE 
        WHEN e.data_devolucao IS NULL AND e.data_prevista_devolucao < CURDATE() 
            THEN 'EM ATRASO'
        WHEN e.data_devolucao IS NULL 
            THEN 'ATIVO'
        WHEN e.data_devolucao > e.data_prevista_devolucao 
            THEN 'DEVOLVIDO COM ATRASO'
        ELSE 'DEVOLVIDO'
    END AS status,
    un.nome AS unidade,
    m.valor AS multa_paga
FROM emprestimo e
JOIN usuario u ON e.usuario_id = u.id
JOIN exemplar ex ON e.exemplar_id = ex.id
JOIN livro l ON ex.livro_id = l.id
JOIN livro_autor la ON l.id = la.livro_id
JOIN autor a ON la.autor_id = a.id
JOIN unidade un ON ex.unidade_id = un.id
LEFT JOIN multa m ON e.id = m.emprestimo_id AND m.status = 'paga'
WHERE u.matricula = '2024001'  -- Ana Paula Silva
GROUP BY e.id, l.titulo, e.data_emprestimo, e.data_prevista_devolucao, 
         e.data_devolucao, un.nome, m.valor
ORDER BY e.data_emprestimo DESC;

-- ============================================
-- CONSULTA 5: Livros que nunca foram emprestados (SUBCONSULTA)
-- ============================================
SELECT 
    l.titulo,
    l.isbn,
    l.ano_publicacao,
    GROUP_CONCAT(DISTINCT a.nome SEPARATOR ', ') AS autores,
    GROUP_CONCAT(DISTINCT c.nome SEPARATOR ', ') AS categorias,
    COUNT(ex.id) AS total_exemplares,
    un.nome AS unidade_disponivel
FROM livro l
LEFT JOIN livro_autor la ON l.id = la.livro_id
LEFT JOIN autor a ON la.autor_id = a.id
LEFT JOIN livro_categoria lc ON l.id = lc.livro_id
LEFT JOIN categoria c ON lc.categoria_id = c.id
LEFT JOIN exemplar ex ON l.id = ex.livro_id
LEFT JOIN unidade un ON ex.unidade_id = un.id
WHERE l.id NOT IN (
    SELECT DISTINCT ex2.livro_id 
    FROM emprestimo e2
    JOIN exemplar ex2 ON e2.exemplar_id = ex2.id
)
GROUP BY l.id, l.titulo, l.isbn, l.ano_publicacao, un.nome
ORDER BY l.titulo;

-- ============================================
-- 18. CONSULTAS ADICIONAIS (DIFERENCIAIS)
-- ============================================

-- Consulta 6: Ranking de usuários por atividade
SELECT 
    u.nome,
    u.tipo,
    u.matricula,
    COUNT(e.id) AS total_emprestimos,
    SUM(CASE WHEN e.status = 'devolvido' THEN 1 ELSE 0 END) AS devolvidos,
    SUM(CASE WHEN e.status IN ('ativo', 'atrasado') THEN 1 ELSE 0 END) AS ativos,
    SUM(CASE WHEN e.status = 'atrasado' THEN 1 ELSE 0 END) AS atrasos,
    ROUND(AVG(DATEDIFF(COALESCE(e.data_devolucao, CURDATE()), e.data_emprestimo)), 1) AS media_dias
FROM usuario u
LEFT JOIN emprestimo e ON u.id = e.usuario_id
GROUP BY u.id, u.nome, u.tipo, u.matricula
HAVING total_emprestimos > 0
ORDER BY total_emprestimos DESC;

-- Consulta 7: Taxa de ocupação por unidade (resumo)
SELECT 
    un.nome AS unidade,
    un.codigo,
    COUNT(ex.id) AS total_exemplares,
    SUM(CASE WHEN ex.status = 'disponivel' THEN 1 ELSE 0 END) AS disponiveis,
    SUM(CASE WHEN ex.status = 'emprestado' THEN 1 ELSE 0 END) AS emprestados,
    SUM(CASE WHEN ex.status = 'manutencao' THEN 1 ELSE 0 END) AS manutencao,
    ROUND(SUM(CASE WHEN ex.status = 'emprestado' THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(COUNT(ex.id), 0), 2) AS taxa_ocupacao_percent
FROM unidade un
LEFT JOIN exemplar ex ON un.id = ex.unidade_id
GROUP BY un.id, un.nome, un.codigo
ORDER BY taxa_ocupacao_percent DESC;

-- Consulta 8: Alertas de vencimento (próximos 3 dias)
SELECT 
    u.nome AS usuario,
    u.email,
    l.titulo AS livro,
    e.data_prevista_devolucao,
    DATEDIFF(e.data_prevista_devolucao, CURDATE()) AS dias_restantes,
    CASE 
        WHEN DATEDIFF(e.data_prevista_devolucao, CURDATE()) = 0 THEN 'VENCE HOJE!'
        WHEN DATEDIFF(e.data_prevista_devolucao, CURDATE()) = 1 THEN 'VENCE AMANHÃ'
        ELSE CONCAT('Vence em ', DATEDIFF(e.data_prevista_devolucao, CURDATE()), ' dias')
    END AS alerta,
    un.nome AS unidade
FROM emprestimo e
JOIN usuario u ON e.usuario_id = u.id
JOIN exemplar ex ON e.exemplar_id = ex.id
JOIN livro l ON ex.livro_id = l.id
JOIN unidade un ON ex.unidade_id = un.id
WHERE e.status IN ('ativo', 'atrasado')
AND e.data_prevista_devolucao BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 3 DAY)
ORDER BY dias_restantes;

-- ============================================
-- 19. TESTE DO SISTEMA DE MULTAS (OPCIONAL)
-- ============================================

-- Verificar empréstimos ativos e atrasados via view
SELECT '=== EMPRÉSTIMOS ATIVOS E ATRASADOS ===' AS teste;
SELECT * FROM vw_emprestimos_ativos;

-- Verificar multas pendentes (inicialmente vazio)
SELECT '=== MULTAS PENDENTES (ANTES DA DEVOLUÇÃO) ===' AS teste;
SELECT * FROM vw_multas_pendentes;

-- ============================================
-- 20. SIMULAÇÃO DE DEVOLUÇÃO COM ATRASO (TESTE DO TRIGGER)
-- ============================================
-- DESCOMENTE E EXECUTE PARA TESTAR A GERAÇÃO AUTOMÁTICA DE MULTA:

/*
-- 1. Identificar empréstimo atrasado
SELECT id, usuario_id, exemplar_id, status 
FROM emprestimo 
WHERE status = 'atrasado';

-- 2. Simular devolução (substituir X pelo ID real)
UPDATE emprestimo 
SET 
    data_devolucao = NOW(),
    status = 'devolvido'
WHERE id = X;  -- <-- USE O ID DO EMPRÉSTIMO ATRASADO

-- 3. Verificar se multa foi gerada automaticamente
SELECT * FROM multa WHERE emprestimo_id = X;
SELECT * FROM vw_multas_pendentes;
*/

-- ============================================
-- 21. VERIFICAÇÃO FINAL DO SISTEMA
-- ============================================

SELECT '=== VERIFICAÇÃO DO SISTEMA ===' AS info;

SELECT 'Total de livros' AS metrica, COUNT(*) AS valor FROM livro
UNION ALL
SELECT 'Total de exemplares', COUNT(*) FROM exemplar
UNION ALL
SELECT 'Total de usuários', COUNT(*) FROM usuario
UNION ALL
SELECT 'Empréstimos ativos', COUNT(*) FROM emprestimo WHERE status IN ('ativo', 'atrasado')
UNION ALL
SELECT 'Empréstimos atrasados', COUNT(*) FROM emprestimo WHERE status = 'atrasado'
UNION ALL
SELECT 'Reservas ativas', COUNT(*) FROM reserva WHERE status = 'ativa'
UNION ALL
SELECT 'Multas pendentes', COUNT(*) FROM multa WHERE status = 'pendente';

-- ============================================
-- FIM DO ARQUIVO
-- ============================================
-- Documentação técnica:
-- - 13 tabelas (4 de suporte, 6 principais, 3 associativas)
-- - 3 views para relatórios
-- - 4 triggers para automação
-- - 2 events para manutenção periódica
-- - 8 consultas (5 obrigatórias + 3 diferenciais)
-- - Dados de teste completos conforme enunciado
-- ============================================



-- Verificar triggers criadas
SHOW TRIGGERS;

-- Verificar events criados
SHOW EVENTS FROM biblioteca_universitaria;

-- Verificar views criadas
SHOW FULL TABLES WHERE TABLE_TYPE = 'VIEW';

-- Testar as 5 consultas obrigatórias do roteiro
-- (Consultas 1-5 da seção 14 do seu script)

-- CONSULTAR: Exemplares disponíveis da Biblioteca Central
SELECT 
    l.titulo,
    GROUP_CONCAT(DISTINCT a.nome SEPARATOR ', ') AS autores,
    l.isbn,
    un.nome AS unidade,
    ex.numero_tombo AS localizacao
FROM exemplar ex
JOIN livro l ON ex.livro_id = l.id
JOIN livro_autor la ON l.id = la.livro_id
JOIN autor a ON la.autor_id = a.id
JOIN unidade un ON ex.unidade_id = un.id
WHERE ex.status = 'disponivel'
AND un.codigo = 'BCC'
GROUP BY l.id, l.titulo, l.isbn, un.nome, ex.numero_tombo
ORDER BY l.titulo;


-- CONSULTAR: O Ranking dos 5 livros mais emprestados
SELECT 
    l.titulo,
    GROUP_CONCAT(DISTINCT a.nome SEPARATOR ', ') AS autores,
    COUNT(e.id) AS total_emprestimos
FROM livro l
JOIN exemplar ex ON l.id = ex.livro_id
JOIN emprestimo e ON ex.id = e.exemplar_id
JOIN livro_autor la ON l.id = la.livro_id
JOIN autor a ON la.autor_id = a.id
WHERE e.data_emprestimo >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY l.id, l.titulo
ORDER BY total_emprestimos DESC
LIMIT 5;


-- CONSULTANDO: Os empréstimos em atraso com cálculo de multa
SELECT 
    u.nome AS usuario,
    u.matricula,
    u.tipo,
    u.email,
    l.titulo AS livro,
    e.data_prevista_devolucao,
    DATEDIFF(CURDATE(), e.data_prevista_devolucao) AS dias_atraso,
    DATEDIFF(CURDATE(), e.data_prevista_devolucao) * 2.00 AS valor_multa,
    un.nome AS unidade
FROM emprestimo e
JOIN usuario u ON e.usuario_id = u.id
JOIN exemplar ex ON e.exemplar_id = ex.id
JOIN livro l ON ex.livro_id = l.id
JOIN unidade un ON ex.unidade_id = un.id
WHERE e.status = 'atrasado'
OR (e.status = 'ativo' AND e.data_prevista_devolucao < CURDATE())
ORDER BY dias_atraso DESC, valor_multa DESC;


-- CONSULTA : AO Histórico da Ana Paula Silva (matrícula 2024001)
SELECT 
    l.titulo AS livro,
    GROUP_CONCAT(DISTINCT a.nome SEPARATOR ', ') AS autor,
    e.data_emprestimo,
    e.data_prevista_devolucao,
    e.data_devolucao,
    CASE 
        WHEN e.data_devolucao IS NULL AND e.data_prevista_devolucao < CURDATE() 
            THEN 'EM ATRASO'
        WHEN e.data_devolucao IS NULL 
            THEN 'ATIVO'
        WHEN e.data_devolucao > e.data_prevista_devolucao 
            THEN 'DEVOLVIDO COM ATRASO'
        ELSE 'DEVOLVIDO'
    END AS status,
    un.nome AS unidade,
    m.valor AS multa_paga
FROM emprestimo e
JOIN usuario u ON e.usuario_id = u.id
JOIN exemplar ex ON e.exemplar_id = ex.id
JOIN livro l ON ex.livro_id = l.id
JOIN livro_autor la ON l.id = la.livro_id
JOIN autor a ON la.autor_id = a.id
JOIN unidade un ON ex.unidade_id = un.id
LEFT JOIN multa m ON e.id = m.emprestimo_id AND m.status = 'paga'
WHERE u.matricula = '2024001'
GROUP BY e.id, l.titulo, e.data_emprestimo, e.data_prevista_devolucao, 
         e.data_devolucao, un.nome, m.valor
ORDER BY e.data_emprestimo DESC;

-- CONSULTAR : Livros que nunca foram emprestados
SELECT 
    l.titulo,
    l.isbn,
    l.ano_publicacao,
    GROUP_CONCAT(DISTINCT a.nome SEPARATOR ', ') AS autores,
    GROUP_CONCAT(DISTINCT c.nome SEPARATOR ', ') AS categorias,
    COUNT(ex.id) AS total_exemplares,
    un.nome AS unidade_disponivel
FROM livro l
LEFT JOIN livro_autor la ON l.id = la.livro_id
LEFT JOIN autor a ON la.autor_id = a.id
LEFT JOIN livro_categoria lc ON l.id = lc.livro_id
LEFT JOIN categoria c ON lc.categoria_id = c.id
LEFT JOIN exemplar ex ON l.id = ex.livro_id
LEFT JOIN unidade un ON ex.unidade_id = un.id
WHERE l.id NOT IN (
    SELECT DISTINCT ex2.livro_id 
    FROM emprestimo e2
    JOIN exemplar ex2 ON e2.exemplar_id = ex2.id
)
GROUP BY l.id, l.titulo, l.isbn, l.ano_publicacao, un.nome
ORDER BY l.titulo;


-- Views de relatório
SELECT * FROM vw_multas_pendentes;


-- 1. Verificar se existem multas no sistema
SELECT COUNT(*) AS total_multas FROM multa;

-- 2. Verificar status das multas existentes
SELECT status, COUNT(*) AS quantidade 
FROM multa 
GROUP BY status;

-- 3. Verificar empréstimos em atraso
SELECT 
    e.id,
    u.nome AS usuario,
    l.titulo AS livro,
    e.data_prevista_devolucao,
    DATEDIFF(CURDATE(), e.data_prevista_devolucao) AS dias_atraso
FROM emprestimo e
JOIN usuario u ON e.usuario_id = u.id
JOIN exemplar ex ON e.exemplar_id = ex.id
JOIN livro l ON ex.livro_id = l.id
WHERE e.status IN ('ativo', 'atrasado')
AND e.data_prevista_devolucao < CURDATE();

-- 4. Verificar estrutura da view
SHOW CREATE VIEW vw_multas_pendentes;

-- 1. Verificar se existem multas no sistema
SELECT COUNT(*) AS total_multas FROM multa;

-- 2. Verificar status das multas existentes
SELECT status, COUNT(*) AS quantidade 
FROM multa 
GROUP BY status;

-- 3. Verificar empréstimos em atraso
SELECT 
    e.id,
    u.nome AS usuario,
    l.titulo AS livro,
    e.data_prevista_devolucao,
    DATEDIFF(CURDATE(), e.data_prevista_devolucao) AS dias_atraso
FROM emprestimo e
JOIN usuario u ON e.usuario_id = u.id
JOIN exemplar ex ON e.exemplar_id = ex.id
JOIN livro l ON ex.livro_id = l.id
WHERE e.status IN ('ativo', 'atrasado')
AND e.data_prevista_devolucao < CURDATE();

-- 4. Verificar estrutura da view
SHOW CREATE VIEW vw_multas_pendentes;