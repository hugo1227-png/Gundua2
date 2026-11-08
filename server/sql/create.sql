CREATE DATABASE IF NOT EXISTS gundua
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE gundua;

CREATE TABLE IF NOT EXISTS users (
  id CHAR(36) PRIMARY KEY,
  email VARCHAR(254) NOT NULL UNIQUE,
  password_hash CHAR(128) NOT NULL,
  password_salt CHAR(32) NOT NULL,
  name VARCHAR(100) NOT NULL,
  username VARCHAR(80) NOT NULL DEFAULT '',
  bio VARCHAR(500) NOT NULL DEFAULT 'A descobrir lugares e experiências.',
  location VARCHAR(200) NOT NULL DEFAULT '',
  interests VARCHAR(500) NOT NULL DEFAULT '',
  avatar LONGTEXT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sessions (
  token_hash CHAR(64) PRIMARY KEY,
  user_id CHAR(36) NOT NULL,
  expires_at DATETIME(3) NOT NULL,
  INDEX idx_sessions_user (user_id),
  INDEX idx_sessions_expires (expires_at),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS places (
  id VARCHAR(300) PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  category VARCHAR(150) NOT NULL DEFAULT '',
  latitude DOUBLE NULL,
  longitude DOUBLE NULL,
  data_json JSON NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  INDEX idx_places_name (name),
  INDEX idx_places_category (category)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS favorites (
  user_id CHAR(36) NOT NULL,
  place_id VARCHAR(300) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (user_id, place_id),
  CONSTRAINT fk_fav_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_fav_place FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reviews (
  user_id CHAR(36) NOT NULL,
  place_id VARCHAR(300) NOT NULL,
  rating TINYINT UNSIGNED NOT NULL,
  comment VARCHAR(600) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (user_id, place_id),
  INDEX idx_reviews_place (place_id),
  CONSTRAINT chk_reviews_rating CHECK (rating BETWEEN 1 AND 5),
  CONSTRAINT fk_reviews_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_reviews_place FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS visits (
  user_id CHAR(36) NOT NULL,
  place_id VARCHAR(300) NOT NULL,
  visited_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (user_id, place_id),
  INDEX idx_visits_time (visited_at),
  CONSTRAINT fk_visits_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_visits_place FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS page_views (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id CHAR(36) NOT NULL,
  place_id VARCHAR(300) NOT NULL,
  viewed_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX idx_views_time_place (viewed_at, place_id),
  CONSTRAINT fk_views_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_views_place FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS selected_locations (
  user_id CHAR(36) PRIMARY KEY,
  label VARCHAR(200) NOT NULL,
  latitude DOUBLE NOT NULL,
  longitude DOUBLE NOT NULL,
  is_device_location BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_location_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;


-- Experiências publicadas pelos utilizadores (imagens pequenas).
CREATE TABLE IF NOT EXISTS experiences (
  id CHAR(36) PRIMARY KEY,
  user_id CHAR(36) NOT NULL,
  place_id VARCHAR(300) NOT NULL,
  title VARCHAR(160) NOT NULL,
  description VARCHAR(2000) NOT NULL,
  place_location VARCHAR(250) NOT NULL DEFAULT '',
  image_base64 MEDIUMTEXT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX idx_experiences_user_time (user_id, created_at),
  INDEX idx_experiences_place_time (place_id, created_at),
  CONSTRAINT fk_experiences_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_experiences_place FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE CASCADE
) ENGINE=InnoDB;


CREATE OR REPLACE VIEW v_favoritos AS
SELECT u.name AS utilizador, p.name AS local, p.category AS categoria,
       f.created_at AS data_favorito
FROM favorites f
JOIN users u ON u.id = f.user_id
JOIN places p ON p.id = f.place_id;

CREATE OR REPLACE VIEW v_visitas AS
SELECT u.name AS utilizador, p.name AS local, p.category AS categoria,
       v.visited_at AS data_visita
FROM visits v
JOIN users u ON u.id = v.user_id
JOIN places p ON p.id = v.place_id;

CREATE OR REPLACE VIEW v_experiencias AS
SELECT u.name AS autor, p.name AS local, e.title AS titulo,
       e.description AS descricao, e.created_at AS data_publicacao
FROM experiences e
JOIN users u ON u.id = e.user_id
JOIN places p ON p.id = e.place_id;
