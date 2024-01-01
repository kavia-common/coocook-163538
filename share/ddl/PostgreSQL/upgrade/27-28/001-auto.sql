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

-- assign default purchase lists:
-- 1. list with most items
-- 2. list with earliest date
UPDATE projects
SET default_purchase_list_id = (
    SELECT id FROM purchase_lists
    WHERE project_id = projects.id
    ORDER BY
        (SELECT COUNT(*) FROM items WHERE purchase_list_id = purchase_lists.id) DESC,
        date ASC
    LIMIT 1
);

;

COMMIT;

