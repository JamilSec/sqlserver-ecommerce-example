# Ejemplo de Base de Datos eCommerce en SQL Server

## Descripción breve:
Base de datos de ejemplo para un eCommerce en SQL Server, que incluye:
- Estructura con tablas principales (usuarios, productos, órdenes, etc.).
- Manejo de auditoría mediante triggers (bitácora).
- Procedimientos almacenados con transacciones y rollback.
- Ejemplos de inserción de datos de prueba.

## Tabla de Contenidos
1. [Características Principales](#características-principales)
2. [Requisitos](#requisitos)
3. [Estructura del Proyecto](#estructura-del-proyecto)
4. [Cómo Usar el Script](#cómo-usar-el-script)
5. [Detalles de las Tablas](#detalles-de-las-tablas)
6. [Procedimientos Almacenados](#procedimientos-almacenados)
7. [Auditoría](#auditoría)
8. [Instrucciones para Insertar Datos de Prueba](#instrucciones-para-insertar-datos-de-prueba)
9. [Referencias](#referencias)

## Características Principales

- **Convención de Nombres**: Se usa `snake_case` en nombres de tablas y columnas para mayor compatibilidad entre SQL Server y otros motores de base de datos.
- **Auditoría Integrada**: Mediante un **trigger** de ejemplo en la tabla `usuarios`, que registra inserciones, actualizaciones y eliminaciones en la tabla `bitacora`.
- **Transacciones y Rollback**: Cada *Stored Procedure* inicia y finaliza una transacción, permitiendo **rollback** en caso de errores.
- **Enfoque eCommerce**: Incluye tablas típicas de un comercio electrónico, como `usuarios`, `productos`, `ordenes`, `detalle_ordenes`, `pagos`, etc.
- **Inserciones de Datos de Prueba**: Ejemplo de *Seed Data* para roles, categorías, usuarios, productos y órdenes de compra.

## Requisitos
- **SQL Server** (versión 2016 SP1 o superior recomendado, debido a `CREATE OR ALTER PROCEDURE`).
- Herramienta de administración SQL (ejemplo: **SQL Server Management Studio**).
> **Si tu SQL Server no admite** `CREATE OR ALTER`**, reemplaza la sentencia por** `CREATE PROCEDURE` **en los procedimientos.**

## Estructura del Proyecto
```scss
.
├── sqlserver-ecommerce-example.sql   # Script principal (crea la BD, tablas, triggers, SPs y datos de prueba)
└── README.md                    # Este archivo
```
- **sqlserver-ecommerce-example.sql**:Contiene todo el contenido para crear y poblar la base de datos.

## Cómo Usar el Script
1. **Clona** o **descarga** este repositorio.
2. **Abre** el archivo `sqlserver-ecommerce-example.sql` en SQL Server Management Studio (o tu cliente SQL favorito).
3. **Ejecuta** el script completo. Este script:
    - Crea la base de datos `ecommerce_db`.
    - Configura todas las tablas y sus relaciones.
    - Define un trigger de auditoría para la tabla `usuarios`.
    - Crea procedimientos almacenados (Stored Procedures) para insertar datos con transacciones.
    - Inserta datos de prueba (roles, categorías, métodos de pago, usuarios, productos, etc.).

Después de ejecutarlo, podrás **verificar** las tablas creadas y los registros insertados.

## Detalles de las Tablas

1. **roles**
    - Maneja los diferentes roles del sistema (`Administrador`, `Cliente`, `Vendedor`).
2. **usuarios**
    - Datos de los usuarios, su rol, correo electrónico, contraseña (hasheada), etc.
3. **categorias**
    - Guarda la información de las categorías de productos (p. ej. `Electrónica`, `Ropa`, `Hogar`).
4. **productos**
    - Lista de productos con su precio, stock, categoría y fecha de creación.
5. **ordenes**
    - Cabecera de cada pedido, que indica qué usuario lo generó, el total y estado (`Pendiente`, `Pagado`, etc.).
6. **detalle_ordenes**
    - Contiene los productos que pertenecen a cada orden, su cantidad y el subtotal calculado.
7. **metodos_pago**
    - Catálogo de métodos de pago (`Tarjeta de Crédito`, `PayPal`, etc.).
8. **pagos**
    - Información de los pagos realizados (enlazados a `ordenes` y `metodos_pago`).
9. **inventario**
    - Registra movimientos de stock, como entradas y salidas de productos.
10. **bitacora**
    - Tabla donde se guarda la auditoría de cambios (basada en triggers).

## Procedimientos Almacenados
Cada *Stored Procedure* inicia con `BEGIN TRAN` y finaliza con `COMMIT TRAN`. En caso de error, se ejecuta `ROLLBACK TRAN`. Ejemplos:
- **sp_insert_rol**: Inserta un rol nuevo en la tabla `roles`.
- **sp_insert_usuario**: Crea un nuevo usuario en la tabla `usuarios`.
- **sp_insert_categoria**: Inserta una nueva categoría en la tabla `categorias`.
- **sp_insert_producto**: Inserta un producto en la tabla `productos`.
- **sp_insert_orden**: Crea una nueva orden en la tabla `ordenes`.
- **sp_insert_detalle_orden**: Inserta un detalle específico en una orden dada.
- **sp_insert_pago**: Registra un pago relacionado a una orden.
- **sp_insert_inventario**: Registra un movimiento de inventario.

Si algo falla dentro del *Stored Procedure*, se realiza **ROLLBACK** para evitar datos inconsistentes.

## Auditoría
- **Trigger**: `trg_auditoria_usuarios`.
- Se dispara en **INSERT**, **UPDATE**, **DELETE** sobre la tabla usuarios.
- Registra los cambios en la tabla `bitacora`, guardando información como la tabla afectada, el registro afectado, la acción (`INSERT`, `UPDATE`, `DELETE`), el usuario que realizó el cambio y la fecha.
- Puedes replicar o adaptar el mismo patrón de trigger para las demás tablas (`productos`, `ordenes`, etc.), si deseas auditoría completa.

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