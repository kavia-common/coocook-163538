-- Convert schema '/home/daniel/workspace/coocook/share/ddl/_source/deploy/27/001-auto.yml' to '/home/daniel/workspace/coocook/share/ddl/_source/deploy/28/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE projects_new (
  id INTEGER PRIMARY KEY NOT NULL,
  name text NOT NULL,
  url_name text NOT NULL,
  url_name_fc text NOT NULL,
  description text NOT NULL,
  is_public boolean NOT NULL DEFAULT 1,
  owner_id integer NOT NULL,
  created timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  archived timestamp without time zone,
  default_purchase_list_id integer,
  FOREIGN KEY (default_purchase_list_id) REFERENCES purchase_lists(id),
  FOREIGN KEY (owner_id) REFERENCES users(id)
);

INSERT INTO projects_new( id, name, url_name, url_name_fc, description, is_public, owner_id, created, archived) SELECT id, name, url_name, url_name_fc, description, is_public, owner_id, created, archived FROM projects;

DROP TABLE projects;

ALTER TABLE projects_new RENAME TO projects;

;
CREATE INDEX projects_idx_default_purchase_list_id ON projects (default_purchase_list_id);

;
CREATE INDEX projects_idx_owner_id ON projects (owner_id);

;
CREATE UNIQUE INDEX projects_name ON projects (name);

;
CREATE UNIQUE INDEX projects_url_name ON projects (url_name);

;
CREATE UNIQUE INDEX projects_url_name_fc ON projects (url_name_fc);

;

COMMIT;

