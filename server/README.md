# GUNDUA — Backend Node.js REST + MySQL (versão alfa universitária)

## O que está incluído

- `src/app.js` — servidor HTTP/REST com respostas JSON e autorização;
- `src/mysql_pool.js` e `src/db.js` — acesso MySQL com **mysql2/promise**, queries parametrizadas e identificadores estáveis;
- `src/auth.js` — registo, login, logout e sessões com tokens armazenados só como hash;
- `src/geoapify.js` — pesquisa e locais próximos, com chave Geoapify **apenas no servidor**;
- `src/google_places.js` — Google Places por HTTPS, com a chave exclusivamente no servidor;
- `sql/01_schema_mysql.sql` — 9 tabelas MySQL com chaves primárias, estrangeiras e índices, compatível com Workbench;
- `sql/02_utilizador_mysql.sql` — utilizador de BD com permissões limitadas (opcional);
- `sql/03_consultas_demonstracao.sql` — SELECTs para demonstrar a BD nas aulas;
- `seed/lisbon.json` — dez locais turísticos reais já presentes no protótipo.

A app Flutter existente é o **cliente**. Quando compilas com `GUNDUA_API_URL`, utiliza o servidor para registo, login, favoritos, avaliações, visitas e localização escolhida. As experiências também são guardadas no MySQL quando a API está configurada. As restantes interfaces (Liquid Glass, Explore, Home e mapa) mantêm-se.

## 1. MySQL e MySQL Workbench (Mac)

**O MySQL Workbench não é o servidor de base de dados**: deves ter o **MySQL Server 8.0+** instalado e em execução (podes utilizar a instalação que usas nas aulas). Abre o Workbench e liga-te ao MySQL local.

1. No Workbench, abre `server/sql/01_schema_mysql.sql` no **SQL Editor**.
2. Executa o script com o ícone do **relâmpago**. Isto cria o esquema `gundua` com nove tabelas relacionadas.
3. Opcional, mas recomendado: abre `server/sql/02_utilizador_mysql.sql`, substitui `SUBSTITUIR_POR_PASSWORD_FORTE` por uma password local forte e executa como utilizador administrador.
4. Faz **Refresh** à árvore **SCHEMAS**. Deverás ver `gundua` e as tabelas `users`, `sessions`, `places`, `favorites`, `reviews`, `visits`, `page_views`, `selected_locations` e `experiences`.

Se não tens permissões para criar utilizadores, podes usar o utilizador MySQL que já tens para a aula, indicando-o no `.env`. Não partilhes essas credenciais.

## 2. Iniciar o servidor Node.js

O projeto requer **Node.js 20 ou superior**. Numa janela do Terminal:

```bash
cd proto_2/server
cp .env.example .env
npm install
```

Edita `server/.env` para usar as tuas credenciais MySQL:

```env
PORT=3000
HOST=0.0.0.0
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=gundua_app
DB_PASSWORD=A_PASSWORD_QUE_ESCOLHESTE
DB_NAME=gundua
GEOAPIFY_API_KEY=A_TUA_CHAVE_GEOAPIFY
GOOGLE_PLACES_API_KEY=A_TUA_CHAVE_GOOGLE
ALLOWED_ORIGINS=http://localhost:5001,http://127.0.0.1:5001
FLUTTER_WEB_DIR=../build/web
```

Se o utilizador MySQL for `root` ou outro, altera `DB_USER`/`DB_PASSWORD`. **Nunca publiques o `.env`.**

Depois:

```bash
npm run seed    # insere os 10 lugares do catálogo; seguro repetir
npm start       # inicia API em http://localhost:3000
```

Noutra janela:

```bash
curl http://localhost:3000/api/v1/health
curl 'http://localhost:3000/api/v1/places?category=Museu'
```

A primeira resposta deve indicar `"status":"ok"` e `"database":"mysql"`. Se aparecer `ECONNREFUSED` ou `ER_ACCESS_DENIED_ERROR`, verifica o serviço MySQL, a porta 3306 e o `.env`.

## 3. Ligar o Flutter à API (Chrome no Mac)

Num segundo Terminal na pasta `proto_2`:

```bash
flutter pub get
flutter run -d chrome --web-port 5001 \
  --dart-define=GUNDUA_API_URL=http://localhost:3000/api/v1 \
  --dart-define=GUNDUA_PLACES_PROXY_URL=http://localhost:3000/api/v1/places/google/nearby
```

**Cria uma nova conta na app**, abre Explore, escolhe Lisboa, marca um lugar como favorito, escreve uma avaliação e consulta o MySQL Workbench. Os dados são persistidos na base de dados, não apenas no dispositivo.

A API Geoapify está no Node: **não precisas de passar a chave Geoapify ao Flutter** neste modo. Os lugares que o utilizador guarda/avalia/visita ficam gravados em `places`. O catálogo inicial funciona mesmo sem Geoapify, mas a pesquisa externa exige a chave.

## 4. Demonstração Web no iPhone — um só servidor

A melhor opção para a apresentação universitária é servir **Flutter Web e Node REST no mesmo endereço**:

```bash
cd proto_2
flutter build web --dart-define=GUNDUA_API_URL=/api/v1 \
  --dart-define=GUNDUA_PLACES_PROXY_URL=/api/v1/places/google/nearby
cd server
npm start
```

O Node serve `build/web` graças a `FLUTTER_WEB_DIR=../build/web`. No Mac, abre `http://localhost:3000`.

No **Safari do iPhone**, `http://IP_DO_MAC:3000` permite abrir a aplicação, mas não concede GPS em condições normais por não ser HTTPS. Para a demonstração de GPS, com `cloudflared` instalado:

```bash
cloudflared tunnel --url http://localhost:3000
```

Abre o URL `https://...trycloudflare.com` que aparecer no Terminal. Esse túnel é temporário e não deve ser tratado como produção. A opção de **localização manual** funciona sem GPS.

## 5. API REST — endpoints

Prefixo: `/api/v1`. Pedidos com corpo JSON usam `Content-Type: application/json`. Os endpoints protegidos exigem `Authorization: Bearer <token>` obtido no login.

| Método | Caminho | Função | Token |
|---|---|---|---|
| GET | `/health` | Estado do Node e MySQL | Não |
| POST | `/auth/register` | Criar conta: `name`, `email`, `password` | Não |
| POST | `/auth/login` | Autenticar conta | Não |
| POST | `/auth/logout` | Revogar token | Sim |
| GET/PATCH | `/me` | Ler/editar perfil | Sim |
| GET/PUT/DELETE | `/me/location` | Local escolhido / GPS | Sim |
| GET | `/places?q=&category=&limit=` | Consultar catálogo da BD | Não |
| GET/POST | `/places` | Consultar/criar local | POST: sim |
| GET | `/places/:id` | Ver local guardado | Não |
| POST | `/places/google/nearby` | Classificações Google Places (chave no servidor, HTTPS externamente) | Sim |
| GET | `/places/:id/reviews` | Ver avaliações GUNDUA do local | Não |
| GET | `/geo/search?q=Lisboa` | Geocoding (Geoapify) | Não |
| GET | `/geo/nearby?lat=38.72&lon=-9.14&radius=5000` | Locais próximos (Geoapify ou catálogo local) | Não |
| GET/POST | `/me/favorites` | Listar/guardar favoritos | Sim |
| DELETE | `/me/favorites/:id` | Retirar favorito | Sim |
| GET/POST | `/me/visits` | Listar/marcar visitas | Sim |
| DELETE | `/me/visits/:id` | Retirar marcação de visita | Sim |
| POST | `/me/views` | Registar abertura de um local | Sim |
| GET/PUT/DELETE | `/me/reviews/:id` | Consultar/criar/apagar avaliação | Sim |
| GET | `/me/reviews` | As minhas avaliações | Sim |
| GET/POST | `/me/experiences` | Listar/criar experiências | Sim |
| DELETE | `/me/experiences/:id` | Eliminar apenas as próprias experiências | Sim |
| GET | `/places/:id/experiences` | Experiências públicas de um local | Não |
| GET | `/analytics/weekly?metric=visits` | Lugar mais marcado como visitado nos últimos 7 dias | Não |
| GET | `/analytics/weekly?metric=views` | Lugar com mais aberturas de detalhes | Não |

Exemplo — registo:

```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"Estudante","email":"aluno@example.com","password":"password-forte-123"}'
```

O JSON devolve `user` e `token`. Testa o endpoint protegido:

```bash
curl http://localhost:3000/api/v1/me \
  -H 'Authorization: Bearer COLOCA_O_TOKEN_AQUI'
```

## 6. Consultar os dados no Workbench

Executa `server/sql/03_consultas_demonstracao.sql` e mostra as tabelas e relações. Para gerar o diagrama EER usa **Database → Reverse Engineer**; vê `docs/er_diagram.md`.

## 7. Testes e segurança

```bash
cd proto_2/server
npm test
```

Os testes locais verificam validação dos locais, funcionamento HTTP, respostas JSON, autenticação obrigatória e CORS. **Não substituem um teste contra o teu MySQL real.** Confirma também os endpoints com o MySQL ativo e os dados no Workbench.

- Password derivada no servidor com `scrypt` + salt; sessões com token aleatório e hash na BD.
- SQL parametrizado com `mysql2`; FK e índices no esquema.
- Chaves e password no `.env` e não no cliente Flutter.
- `SharedPreferences` guarda temporariamente o token no protótipo Flutter; para produção usar armazenamento de credenciais seguro e HTTPS obrigatório.
- A contagem semanal de visitas é baseada em **marcações feitas pelos utilizadores**, não rastreio GPS de presenças físicas.
- Serviço destinado a uma alfa de demonstração académica; antes de publicar precisarás de limites de pedidos, monitorização, backups e endurecimento de segurança.

**Nota:** o pacote foi revisto quanto à sintaxe JavaScript e as rotas básicas foram testadas sem MySQL. O ambiente de preparação não tinha um serviço MySQL nem Flutter SDK disponíveis, pelo que a instalação `npm install`, a execução de SQL real e `flutter analyze` têm de ser confirmadas no teu Mac.

## Google Places no servidor principal

Em `server/.env` preenche `GOOGLE_PLACES_API_KEY`. O endpoint `POST /api/v1/places/google/nearby` usa a mesma sessão do GUNDUA (Authorization Bearer), filtra tipos permitidos e limita o ritmo de pedidos. A app deve apontar `GUNDUA_PLACES_PROXY_URL` para a rota deste backend; pode usar URL relativo quando Flutter e Node estiverem no mesmo domínio. Usa HTTPS para o iPhone e para produção. Não precisas de arrancar um servidor proxy separado.


## Atualizar uma base de dados existente — EXPERIÊNCIAS

No **MySQL Workbench**, executa **`server/sql/04_experiences_alpha.sql`**.
O script cria apenas a nova tabela `experiences`, não elimina os teus dados.
Depois reinicia o Node.js com `npm start` e cria uma experiência na app.
No Workbench podes verificar com:

```sql
USE gundua;
SELECT id, user_id, place_id, title, created_at FROM experiences
ORDER BY created_at DESC;
```

**Atenção:** experiências anteriores guardadas apenas em `SharedPreferences` **não são
migradas automaticamente**. Continuam no armazenamento antigo do dispositivo; as
novas experiências passam a ser guardadas na BD quando iniciares a app com
`GUNDUA_API_URL`. Não confundas ausência de migração com perda de dados da BD.

### Verificação real no Mac

Depois de `npm start`, abre outro Terminal e executa `npm run smoke:db` no
servidor. Esse teste cria uma conta de demonstração identificada com o prefixo
`alpha-check-`, faz login, adiciona um favorito e uma experiência, confirma a
persistência e termina a sessão. Mantém a conta/registos de demonstração na BD
para poderes vê-los no Workbench; não altera contas existentes.
