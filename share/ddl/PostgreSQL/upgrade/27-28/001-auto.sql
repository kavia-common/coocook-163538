-- Convert schema '/home/daniel/workspace/coocook/share/ddl/_source/deploy/27/001-auto.yml' to '/home/daniel/workspace/coocook/share/ddl/_source/deploy/28/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE projects ADD COLUMN default_purchase_list_id integer;

;
CREATE INDEX projects_idx_default_purchase_list_id on projects (default_purchase_list_id);

;
ALTER TABLE projects ADD CONSTRAINT projects_fk_default_purchase_list_id FOREIGN KEY (default_purchase_list_id)
  REFERENCES purchase_lists (id) DEFERRABLE;

;

COMMIT;

