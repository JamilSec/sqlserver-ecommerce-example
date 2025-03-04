# tests/roles/test_roles.py

def test_insert_rol(db_cursor):
    # Llamamos al SP que inserta un rol
    db_cursor.execute("EXEC usp_RolInsertar @nombre = ?", ("RolPrueba",))
    db_cursor.connection.commit()

    # Verificamos que se insertó
    db_cursor.execute("SELECT nombre FROM Roles WHERE nombre = ?", ("RolPrueba",))
    row = db_cursor.fetchone()
    assert row is not None, "No se insertó el rol 'RolPrueba'"