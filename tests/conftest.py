# tests/conftest.py

import os
import pyodbc
import pytest
from dotenv import load_dotenv

# Carga variables de entorno desde .env
load_dotenv()

@pytest.fixture(scope='session')
def db_connection():
    """
    Crea una conexión a SQL Server utilizando pyodbc.
    Se ejecuta una sola vez por sesión de pruebas.
    """
    server = os.getenv('DB_SERVER', 'localhost')
    database = os.getenv('DB_NAME', 'ecommerce_db')
    user = os.getenv('DB_USER', 'sa')
    password = os.getenv('DB_PASSWORD', '')

    conn_str = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={server};"
        f"DATABASE={database};"
        f"UID={user};"
        f"PWD={password};"
    )

    connection = pyodbc.connect(conn_str)
    yield connection
    connection.close()

@pytest.fixture
def db_cursor(db_connection):
    """
    Devuelve un cursor para cada test.
    """
    cursor = db_connection.cursor()
    yield cursor
    cursor.close()