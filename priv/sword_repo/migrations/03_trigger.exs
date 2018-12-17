defmodule Jx3App.Sword.SwordRepo.Migrations.CreateDocumentTriger do
  use Ecto.Migration

  def change do
    role = ~s[jx3spark_writer]
    trigger_name = ~s[document_trigger]
    trigger_func_name = "#{trigger_name}_func"

    execute ~s|CREATE VIEW v_documents AS SELECT tag, CAST (content AS text[]) FROM documents|,
            ~s|DROP VIEW v_documents|
    execute ~s|GRANT ALL PRIVILEGES ON TABLE v_documents TO #{role}|,
            ~s|REVOKE ALL PRIVILEGES ON TABLE v_documents FROM #{role}|

    execute """
            CREATE FUNCTION public.#{trigger_func_name} () RETURNS trigger AS $document_trigger$
            BEGIN
              INSERT INTO documents (tag, content, inserted_at, updated_at) values(NEW.tag, NEW.content::jsonb[], now(), now());
              RETURN NEW;
            END
            $document_trigger$ LANGUAGE plpgsql;
            """,
            ~s|DROP FUNCTION public.#{trigger_func_name}|

    execute """
            CREATE TRIGGER #{trigger_name}
              INSTEAD OF INSERT ON v_documents FOR EACH ROW
              EXECUTE PROCEDURE #{trigger_func_name}()
            """,
            ~s|DROP TRIGGER #{trigger_name} ON v_documents|
  end
end
