CREATE DATABASE memes;

-- Connect to the memes database
\c memes;

CREATE TABLE memes (
    id SERIAL PRIMARY KEY,
    file_name TEXT NOT NULL UNIQUE
);

INSERT INTO memes(file_name)
VALUES
    ('meme_1.webp'),
    ('meme_2.webp'),
    ('meme_3.webp');