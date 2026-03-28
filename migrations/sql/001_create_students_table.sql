-- migrations/sql/001_create_students_table.sql
--
-- Reference SQL script for the students table.
-- When using Flask-Migrate (recommended), run `make db-upgrade` instead.
-- This file is provided for direct database setup or documentation purposes.

CREATE TABLE IF NOT EXISTS students (
    id         SERIAL          PRIMARY KEY,
    name       VARCHAR(100)    NOT NULL,
    email      VARCHAR(120)    NOT NULL,
    age        INTEGER,
    grade      VARCHAR(20),
    created_at TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP       NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_students_email UNIQUE (email)
);

CREATE INDEX IF NOT EXISTS idx_students_email ON students (email);
