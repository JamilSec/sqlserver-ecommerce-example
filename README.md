# Ejemplo de Base de Datos eCommerce en SQL Server (Script Limpio)

Este repositorio contiene un **script** que implementa una base de datos de comercio electrónico en **SQL Server**, siguiendo un enfoque más limpio de nombres y convenciones. El script se compone de cinco secciones principales:

1. **Creación de la base de datos**  
2. **Creación de tablas** en orden lógico  
3. **Trigger de auditoría** (ejemplo en la tabla `Usuarios`)  
4. **Procedimientos almacenados** para inserciones con transacciones  
5. **Inserción de datos de prueba**

---

## Tabla de Contenidos

1. [Características Principales](#características-principales)  
2. [Requisitos](#requisitos)  
3. [Estructura del Proyecto](#estructura-del-proyecto)  
4. [Contenido del Script](#contenido-del-script)  
5. [Cómo Ejecutar el Script](#cómo-ejecutar-el-script)  
6. [Personalización](#personalización)  
7. [Pruebas Automatizadas (Opcional)](#pruebas-automatizadas-opcional)  
8. [Notas Finales](#notas-finales)  
9. [Referencias](#referencias)

---

## Características Principales

- **Orden lógico de creación** de objetos (tablas, llaves foráneas, trigger, SPs).  
- **Nomenclatura clara**: Se evita el uso de prefijos numéricos, se emplean nombres sencillos para tablas (`Usuarios`, `Productos`, etc.) y el formato `usp_{Entidad}{Acción}` para procedimientos (p. ej. `usp_UsuarioInsertar`).  
- **Trigger de auditoría** (`trg_auditoria_usuarios`): registra operaciones `INSERT`, `UPDATE` y `DELETE` en la tabla `Usuarios` hacia la tabla `Bitacora`.  
- **Stored Procedures** con **transacciones** y **manejo de errores** (`TRY/CATCH` + `ROLLBACK` en caso de fallo).  
- **Inserción de datos de prueba** para roles, categorías, usuarios, productos, etc.

---

## Requisitos

- **SQL Server** (versión 2016 SP1 o superior para `CREATE OR ALTER PROCEDURE`).  
- Herramienta para ejecutar scripts T-SQL (por ejemplo: **SQL Server Management Studio**).  
- (Opcional) **Python** y **pytest** si deseas automatizar pruebas en la carpeta `tests` (si existe en tu proyecto).

---

## Estructura del Proyecto

```plaintext
sqlserver-ecommerce-example
├── script
│   └── sqlserver-ecommerce-example.sql    # <--- Script principal (versión limpia)
├── tests
│   └── ... (archivos de prueba con pytest)
├── images
│   └── diagrama.png
└── README.md
```

1. **images/**
    - Carpeta para almacenar imágenes de soporte, como diagramas de la base de datos (`diagrama.png`).
2. **script/**
    - Contiene el script principal (`sqlserver-ecommerce-example.sql`) que crea la base de datos `ecommerce_db`, sus tablas, procedimientos almacenados, triggers y datos de prueba.
3. **tests/**
    - Directorio reservado para archivos de prueba (por ejemplo, test de conexión a la base de datos, validaciones de inserción, etc.).
    - Incluye un `README.md` donde se describe cómo instalar dependencias, configurar el entorno y ejecutar **pytest**.

## Contenido del Script

El script principal (`sqlserver-ecommerce-example.sql`) contiene:

1. **Creación de la base de datos**
    - Elimina la base `ecommerce_db` si existe (forzando `SINGLE_USER`) y luego la recrea.
2. **Creación de Tablas**
    - Roles, Categorias, MetodosPago, Usuarios, Productos, Ordenes, DetalleOrdenes, Pagos, Inventario, Bitacora.
3. **Trigger de Auditoría**
    - `trg_auditoria_usuarios`: Se ejecuta tras `INSERT`, `UPDATE` o `DELETE` en Usuarios, registrando en `Bitacora`.
4. **Procedimientos Almacenados**
    - Convención `usp_{Entidad}{Accion}` (ej. `usp_UsuarioInsertar`).
    - Usa transacciones (`BEGIN TRAN` / `COMMIT TRAN`, `ROLLBACK`en caso de error).
5. **Inserción de Datos de Prueba**
    - Roles, Categorías, Métodos de pago, Usuarios, Productos, una Orden con Detalles, Pago y movimientos de Inventario.

## Cómo Ejecutar el Script

1. **Clona** o **descarga** este repositorio.
2. **Abre** el archivo `sqlserver-ecommerce-example.sql` en SQL Server Management Studio (o tu cliente SQL favorito).
3. **Ejecuta** el script completo. Este script:
    - Crea la base de datos `ecommerce_db`.
    - Configura todas las tablas y sus relaciones.
    - Define un trigger de auditoría para la tabla `Usuarios`.
    - Crea procedimientos almacenados (Stored Procedures) para insertar datos con transacciones.
    - Inserta datos de prueba (Roles, Categorías, Métodos de pago, Usuarios, Productos, etc.).

Después de ejecutarlo, podrás **verificar** las tablas creadas y los registros insertados.

## Personalización

- **Nombres de tablas**: Cambia a singular si lo prefieres (`Rol`, `Usuario`, etc.) manteniendo coherencia.
- **Trigger**: Amplíalo a otras tablas siguiendo el patrón de `trg_auditoria_usuarios`.
- **SPs**: Agrega procedimientos para *UPDATE*, *DELETE*, validaciones extra, etc.
- **Índices**: Crea índices adicionales si esperas muchas consultas por ciertos campos (p. ej. `correo` en `Usuarios`).
- **Validaciones**: Antes de insertar una Orden, podrías verificar stock disponible o requerir login de usuario.

## Pruebas Automatizadas (Opcional)

En `tests/` puedes colocar scripts de prueba (por ejemplo `test_database.py`) usando pytest y librerías como `pyodbc`:

1. Instala Python 3.7+ y pytest:

    ```bash
    pip install pytest
    ```

2. Configura variables de entorno (o un archivo .env) con tu conexión SQL Server:

    ```env
    DB_SERVER=localhost
    DB_NAME=ecommerce_db
    DB_USER=sa
    DB_PASSWORD=MyPassword123
    ```

3. Ejecuta pytest (desde la raíz del proyecto o dentro de tests):

    ```bash
    pytest
    ```

Así automatizas la verificación de inserciones, auditorías y cualquier lógica de negocio.

## Notas Finales

- Si no deseas recrear la base cada vez, comenta la parte que hace `DROP DATABASE`.
- Verifica que tengas permisos suficientes en tu servidor para crear y eliminar la base de datos.
- Personaliza mensajes, validaciones y catálogos de tablas según tu necesidad.

## Detalles de las Tablas

1. **Roles**
    - Maneja los diferentes roles del sistema (`Administrador`, `Cliente`, `Vendedor`).
2. **Usuarios**
    - Datos de los usuarios, su rol, correo electrónico, contraseña (hasheada), etc.
3. **Categorias**
    - Guarda la información de las categorías de productos (p. ej. `Electrónica`, `Ropa`, `Hogar`).
4. **Productos**
    - Lista de productos con su precio, stock, categoría y fecha de creación.
5. **Ordenes**
    - Cabecera de cada pedido, que indica qué usuario lo generó, el total y estado (`Pendiente`, `Pagado`, etc.).
6. **DetalleOrdenes**
    - Contiene los productos que pertenecen a cada orden, su cantidad y el subtotal calculado.
7. **MetodosPago**
    - Catálogo de métodos de pago (`Tarjeta de Crédito`, `PayPal`, etc.).
8. **Pagos**
    - Información de los pagos realizados (enlazados a `ordenes` y `metodos_pago`).
9. **Inventario**
    - Registra movimientos de stock, como entradas y salidas de productos.
10. **Bitacora**
    - Tabla donde se guarda la auditoría de cambios (basada en triggers).

## Procedimientos Almacenados

Cada *Stored Procedure* inicia con `BEGIN TRAN` y finaliza con `COMMIT TRAN`. En caso de error, se ejecuta `ROLLBACK TRAN`. Ejemplos:

- **usp_RolInsertar**: Inserta un rol nuevo en la tabla `Roles`.
- **usp_UsuarioInsertar**: Crea un nuevo usuario en la tabla `Usuarios`.
- **usp_CategoriaInsertar**: Inserta una nueva categoría en la tabla `Categorias`.
- **usp_ProductoInsertar**: Inserta un producto en la tabla `Productos`.
- **usp_OrdenInsertar**: Crea una nueva orden en la tabla `Ordenes`.
- **usp_DetalleOrdenInsertar**: Inserta un detalle específico en una orden dada.
- **usp_PagoInsertar**: Registra un pago relacionado a una Orden.
- **usp_InventarioInsertar**: Registra un movimiento de Inventario.

Si algo falla dentro del *Stored Procedure*, se realiza **ROLLBACK** para evitar datos inconsistentes.

## Auditoría

- **Trigger**: `trg_auditoria_usuarios`.
- Se dispara en **INSERT**, **UPDATE**, **DELETE** sobre la tabla usuarios.
- Registra los cambios en la tabla `Bitacora`, guardando información como la tabla afectada, el registro afectado, la acción (`INSERT`, `UPDATE`, `DELETE`), el usuario que realizó el cambio y la fecha.
- Puedes replicar o adaptar el mismo patrón de trigger para las demás tablas (`Productos`, `Ordenes`, etc.), si deseas auditoría completa.

## Instrucciones para Insertar Datos de Prueba

El script final incluye ejemplos de inserción de datos básicos:

- **Roles**: `Administrador`, `Cliente`, `Vendedor`.
- **Categorías**: `Electrónica`, `Ropa`, `Hogar`.
- **Métodos de Pago**: `Tarjeta de Crédito`, `PayPal`, `Transferencia Bancaria`, `Efectivo`.
- **Usuarios**: `Juan Pérez` (Cliente) y `Ana Gómez` (Admin).
- **Productos**: `Laptop HP`, `Camiseta Negra`.
- **Orden y Detalles**: Orden de prueba para el usuario Juan con un par de productos.
- **Pago**: Registro de pago para la orden.
- **Inventario**: Descuento de stock al realizar el pago.

Puedes **personalizar** estos datos a tu gusto o crear tus propios *Stored Procedures* para la inserción masiva de datos.

## Referencias

- **Documentación de SQL Server**:
  - [Transacciones en SQL Server](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/transactions-transact-sql?view=sql-server-ver16)
  - [Triggers en SQL Server](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-trigger-transact-sql?view=sql-server-ver16)
  - [CREATE OR ALTER PROCEDURE (SQL Server)](https://learn.microsoft.com/es-es/sql/t-sql/statements/create-procedure-transact-sql?view=sql-server-ver16#create-or-alter-procedure)
  - [pytest (Testing en Python)](https://docs.pytest.org/en/stable/)
