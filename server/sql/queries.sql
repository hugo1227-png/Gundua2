-- Consultas para explorar os dados da aplicação e demonstrar o funcionamento da base de dados.

USE gundua;

-- 1. Quantos locais existem em cada categoria?
-- Ajuda-nos a perceber que tipos de espaços estão mais representados na aplicação.
SELECT
    p.category AS categoria,
    COUNT(*) AS total_locais
FROM places AS p
GROUP BY p.category
ORDER BY total_locais DESC, categoria;

-- 2. Favoritos guardados pelos utilizadores.
-- Mostra os nomes das pessoas e dos locais, em vez de apenas os seus identificadores.
SELECT
    u.name AS utilizador,
    p.name AS local,
    p.category AS categoria,
    f.created_at AS data_favorito
FROM favorites AS f
JOIN users AS u ON u.id = f.user_id
JOIN places AS p ON p.id = f.place_id
ORDER BY f.created_at DESC;

-- 3. Lugares mais bem avaliados pelos utilizadores da GUNDUA.
-- Calcula a média das classificações e indica quantas avaliações recebeu cada local.
SELECT
    p.name AS local,
    p.category AS categoria,
    ROUND(AVG(r.rating), 2) AS media_gundua,
    COUNT(*) AS total_avaliacoes
FROM reviews AS r
JOIN places AS p ON p.id = r.place_id
GROUP BY p.id, p.name, p.category
HAVING COUNT(*) >= 1
ORDER BY media_gundua DESC, total_avaliacoes DESC, p.name;

-- 4. Locais cujos detalhes foram mais consultados nos últimos sete dias.
-- Conta aberturas de páginas, não visitas físicas aos locais.
SELECT
    p.name AS local,
    COUNT(*) AS aberturas_detalhes
FROM page_views AS pv
JOIN places AS p ON p.id = pv.place_id
WHERE pv.viewed_at >= UTC_TIMESTAMP(3) - INTERVAL 7 DAY
GROUP BY p.id, p.name
ORDER BY aberturas_detalhes DESC, p.name;

-- 5. Experiências partilhadas na aplicação.
-- Apresenta quem publicou, o local associado e um pequeno excerto do texto.
SELECT
    u.name AS autor,
    p.name AS local,
    e.title AS experiencia,
    LEFT(e.description, 120) AS resumo,
    e.created_at AS publicacao
FROM experiences AS e
JOIN users AS u ON u.id = e.user_id
JOIN places AS p ON p.id = e.place_id
ORDER BY e.created_at DESC;

-- 6. Utilizadores que guardaram pelo menos dois favoritos.
-- Permite identificar contas que já estão a utilizar esta funcionalidade.
SELECT
    u.name AS utilizador,
    COUNT(*) AS favoritos
FROM users AS u
JOIN favorites AS f ON f.user_id = u.id
GROUP BY u.id, u.name
HAVING COUNT(*) >= 2
ORDER BY favoritos DESC;

-- 7. Locais que ainda não foram marcados como visitados.
-- Pode ser útil para sugerir espaços menos explorados.
SELECT
    p.name,
    p.category
FROM places AS p
WHERE NOT EXISTS (
    SELECT 1
    FROM visits AS v
    WHERE v.place_id = p.id
)
ORDER BY p.name;

-- 8. Categorias mais guardadas nos favoritos.
-- Além do número de favoritos, mostra quantos utilizadores diferentes os guardaram.
SELECT
    p.category AS categoria,
    COUNT(*) AS total_favoritos,
    COUNT(DISTINCT f.user_id) AS utilizadores_distintos
FROM favorites AS f
JOIN places AS p ON p.id = f.place_id