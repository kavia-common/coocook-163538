-- Convert schema 'share/ddl/_source/deploy/26/001-auto.yml' to 'share/ddl/_source/deploy/27/001-auto.yml':;

;
BEGIN;

DROP INDEX recipes_idx_project_id;
DROP INDEX recipes_project_id_name;

-- need to create the new column with future default value
-- because SQLite doesn't support changing column defaults
CREATE TABLE recipes_new (
  id INTEGER PRIMARY KEY NOT NULL,
  project_id integer NOT NULL,
  name text NOT NULL,
  preparation text NOT NULL,
  description text NOT NULL,
  servings integer NOT NULL,
  created timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);
CREATE INDEX recipes_idx_project_id ON recipes (project_id);
CREATE UNIQUE INDEX recipes_project_id_name ON recipes (project_id, name);

INSERT INTO recipes_new
SELECT
    id,
    project_id,
    name,
    preparation,
    description,
    servings,
    NULL
FROM recipes;

DROP TABLE recipes;

ALTER TABLE recipes_new RENAME TO recipes;

COMMIT;

