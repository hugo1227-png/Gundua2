USE gundua;

-- Locais de Lisboa usados como ponto de partida para testar a pesquisa e os detalhes.
-- Mantemos os IDs para que as referências nas outras tabelas continuem a funcionar.
INSERT IGNORE INTO places (id, name, category, latitude, longitude, data_json) VALUES
('place-lisbon-hidden-mae-dagua', 'Reservatório da Mãe d’Água das Amoreiras', 'Património', 38.7209, -9.1565, CAST('{"name":"Reservatório da Mãe d’Água das Amoreiras","location":"Amoreiras, Lisboa, Portugal","locality":"Amoreiras","country":"Portugal","category":"Património","latitude":38.7209,"longitude":-9.1565,"placeId":"lisbon-hidden-mae-dagua"}' AS JSON)),
('place-lisbon-hidden-marioneta', 'Museu da Marioneta', 'Museu', 38.7104, -9.1578, CAST('{"name":"Museu da Marioneta","location":"Rua da Esperança, Lisboa, Portugal","locality":"Santos","country":"Portugal","category":"Museu","latitude":38.7104,"longitude":-9.1578,"placeId":"lisbon-hidden-marioneta"}' AS JSON)),
('place-lisbon-hidden-feira-ladra', 'Feira da Ladra', 'Mercado', 38.7195, -9.1245, CAST('{"name":"Feira da Ladra","location":"Campo de Santa Clara, Lisboa, Portugal","locality":"São Vicente","country":"Portugal","category":"Mercado","latitude":38.7195,"longitude":-9.1245,"placeId":"lisbon-hidden-feira-ladra"}' AS JSON)),
('place-lisbon-hidden-bordalo', 'Museu Bordalo Pinheiro', 'Museu', 38.7591, -9.1534, CAST('{"name":"Museu Bordalo Pinheiro","location":"Campo Grande, Lisboa, Portugal","locality":"Campo Grande","country":"Portugal","category":"Museu","latitude":38.7591,"longitude":-9.1534,"placeId":"lisbon-hidden-bordalo"}' AS JSON)),
('place-lisbon-hidden-estufa-fria', 'Estufa Fria', 'Natureza', 38.7285, -9.1533, CAST('{"name":"Estufa Fria","location":"Parque Eduardo VII, Lisboa, Portugal","locality":"Parque Eduardo VII","country":"Portugal","category":"Natureza","latitude":38.7285,"longitude":-9.1533,"placeId":"lisbon-hidden-estufa-fria"}' AS JSON)),
('place-lisbon-hidden-tapada', 'Tapada das Necessidades', 'Jardim histórico', 38.7115, -9.1742, CAST('{"name":"Tapada das Necessidades","location":"Alcântara, Lisboa, Portugal","locality":"Alcântara","country":"Portugal","category":"Jardim histórico","latitude":38.7115,"longitude":-9.1742,"placeId":"lisbon-hidden-tapada"}' AS JSON)),
('place-lisbon-hidden-torel', 'Jardim do Torel', 'Jardim', 38.7208, -9.1406, CAST('{"name":"Jardim do Torel","location":"Rua Júlio de Andrade, Lisboa, Portugal","locality":"Torel","country":"Portugal","category":"Jardim","latitude":38.7208,"longitude":-9.1406,"placeId":"lisbon-hidden-torel"}' AS JSON)),
('place-lisbon-hidden-casa-alentejo', 'Casa do Alentejo', 'Cultura', 38.7161, -9.14, CAST('{"name":"Casa do Alentejo","location":"Rua das Portas de Santo Antão, Lisboa, Portugal","locality":"Baixa","country":"Portugal","category":"Cultura","latitude":38.7161,"longitude":-9.14,"placeId":"lisbon-hidden-casa-alentejo"}' AS JSON)),
('place-lisbon-hidden-jardim-tropical', 'Jardim Botânico Tropical', 'Natureza', 38.6976, -9.2045, CAST('{"name":"Jardim Botânico Tropical","location":"Belém, Lisboa, Portugal","locality":"Belém","country":"Portugal","category":"Natureza","latitude":38.6976,"longitude":-9.2045,"placeId":"lisbon-hidden-jardim-tropical"}' AS JSON)),
('place-lisbon-hidden-monte-agudo', 'Miradouro do Monte Agudo', 'Miradouro', 38.725, -9.127, CAST('{"name":"Miradouro do Monte Agudo","location":"Penha de França, Lisboa, Portugal","locality":"Penha de França","country":"Portugal","category":"Miradouro","latitude":38.725,"longitude":-9.127,"placeId":"lisbon-hidden-monte-agudo"}' AS JSON));

-- Duas contas fictícias para podermos testar a aplicação com utilizadores diferentes.
-- Apenas para demonstração local: a palavra-passe das duas contas é GunduaDemo2026!.
INSERT IGNORE INTO users
(id, email, password_hash, password_salt, name, username, bio, location, interests) VALUES
('11111111-1111-4111-8111-111111111111', 'rita.demo@example.invalid', 'b835d17f96a49c73b51e2e8c31b51b8be6cbd8593f21e2d540ea63159abc226c65847d14bd99d9a1300ddf8b29b04222635f5b408b35762d2a42cfe9960603df', '00000000000000000000000000000001', 'Rita Martins', 'rita_demo', 'Gosto de descobrir museus, exposições e espaços culturais.', 'Lisboa', 'Museus, História'),
('22222222-2222-4222-8222-222222222222', 'miguel.demo@example.invalid', 'b9a08e044f1fc69072475a6dfb5b4b8bada6d9f73cd806ca5e8a8d4a1866a7ffe5d4e2182bb28446b03d6315dde3601616f8aceb41839881feb93a92d23898d0', '00000000000000000000000000000002', 'Miguel Rocha', 'miguel_demo', 'Prefiro passeios ao ar livre e lugares menos conhecidos.', 'Lisboa', 'Jardins, Natureza');

-- Cada pessoa guarda alguns lugares que gostava de visitar novamente.
INSERT IGNORE INTO favorites (user_id, place_id) VALUES
('11111111-1111-4111-8111-111111111111', 'place-lisbon-hidden-marioneta'),
('11111111-1111-4111-8111-111111111111', 'place-lisbon-hidden-bordalo'),
('11111111-1111-4111-8111-111111111111', 'place-lisbon-hidden-casa-alentejo'),
('22222222-2222-4222-8222-222222222222', 'place-lisbon-hidden-estufa-fria'),
('22222222-2222-4222-8222-222222222222', 'place-lisbon-hidden-tapada'),
('22222222-2222-4222-8222-222222222222', 'place-lisbon-hidden-torel');

-- Para testar o histórico, marcamos alguns desses lugares como visitados.
INSERT IGNORE INTO visits (user_id, place_id) VALUES
('11111111-1111-4111-8111-111111111111', 'place-lisbon-hidden-marioneta'),
('11111111-1111-4111-8111-111111111111', 'place-lisbon-hidden-bordalo'),
('22222222-2222-4222-8222-222222222222', 'place-lisbon-hidden-estufa-fria'),
('22222222-2222-4222-8222-222222222222', 'place-lisbon-hidden-tapada');

-- Avaliações inventadas apenas para ilustrar como funciona a funcionalidade.
-- Não são avaliações recolhidas de visitantes reais.
INSERT IGNORE INTO reviews (user_id, place_id, rating, comment) VALUES
('11111111-1111-4111-8111-111111111111', 'place-lisbon-hidden-marioneta', 5, 'Gostei bastante da visita. Tem peças muito diferentes daquilo que esperava encontrar.'),
('11111111-1111-4111-8111-111111111111', 'place-lisbon-hidden-bordalo', 4, 'É um museu pequeno, mas vale a pena passar por lá. Achei a coleção muito interessante.'),
('22222222-2222-4222-8222-222222222222', 'place-lisbon-hidden-estufa-fria', 5, 'Um sítio ótimo para passear e desligar um pouco da confusão da cidade.'),
('22222222-2222-4222-8222-222222222222', 'place-lisbon-hidden-tapada', 4, 'Não conhecia este jardim. É calmo e tem espaço para uma boa caminhada.');

-- Duas experiências de exemplo, ligadas aos respetivos autores e lugares.
INSERT IGNORE INTO experiences
(id, user_id, place_id, title, description, place_location) VALUES
('33333333-3333-4333-8333-333333333333', '11111111-1111-4111-8111-111111111111', 'place-lisbon-hidden-marioneta', 'Uma tarde no Museu da Marioneta', 'Fui conhecer o museu sem grandes expectativas e acabei por ficar mais tempo do que pensava. Gostei especialmente das marionetas de diferentes países.', 'Lisboa'),
('44444444-4444-4444-8444-444444444444', '22222222-2222-4222-8222-222222222222', 'place-lisbon-hidden-estufa-fria', 'Passeio pela Estufa Fria', 'Passei a manhã na Estufa Fria. Mesmo estando perto do centro, é um lugar sossegado, com caminhos agradáveis e muita vegetação.', 'Lisboa');

-- Ambos escolheram Lisboa manualmente como localização na aplicação.
INSERT IGNORE INTO selected_locations
(user_id, label, latitude, longitude, is_device_location) VALUES
('11111111-1111-4111-8111-111111111111', 'Lisboa, Portugal', 38.7223, -9.1393, FALSE),
('22222222-2222-4222-8222-222222222222', 'Lisboa, Portugal', 38.7223, -9.1393, FALSE);

-- Cada registo abaixo representa uma abertura da página de detalhes.
-- Repetimos alguns lugares para podermos testar os destaques por visualizações.
INSERT INTO page_views (user_id, place_id) VALUES
('11111111-1111-4111-8111-111111111111', 'place-lisbon-hidden-marioneta'),
('11111111-1111-4111-8111-111111111111', 'place-lisbon-hidden-marioneta'),
('11111111-1111-4111-8111-111111111111', 'place-lisbon-hidden-bordalo'),
('22222222-2222-4222-8222-222222222222', 'place-lisbon-hidden-estufa-fria'),
('22222222-2222-4222-8222-222222222222', 'place-lisbon-hidden-estufa-fria'),
('22222222-2222-4222-8222-222222222222', 'place-lisbon-hidden-tapada');
