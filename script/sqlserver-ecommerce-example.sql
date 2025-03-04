/****************************************************************************************
  SCRIPT LIMPIO PARA ECOMMERCE EN SQL SERVER
  ---------------------------------------------------------------------------------------
  Contenido:
    1) Creación de la base de datos y uso
    2) Creación de tablas (orden correcto para FKs)
    3) Creación de un trigger de auditoría (en la tabla usuarios)
    4) Creación de procedimientos almacenados para inserciones
       - Manejo de transacciones y rollback
    5) Inserción de datos de prueba usando los SP
****************************************************************************************/

------------------------------------------------------------------------------------------
-- 1. CREAR BASE DE DATOS Y SELECCIONARLA
------------------------------------------------------------------------------------------
-- Eliminar la BD si existe, en lote separado
IF DB_ID('ecommerce_db') IS NOT NULL
BEGIN
    -- Cambia la base a SINGLE_USER por si hay conexiones abiertas
    ALTER DATABASE ecommerce_db 
        SET SINGLE_USER 
        WITH ROLLBACK IMMEDIATE;
    
    DROP DATABASE ecommerce_db;
END
GO  -- Fin del lote

-- Crear la base de datos en un lote aislado
CREATE DATABASE ecommerce_db;
GO

-- Seleccionar la BD
USE ecommerce_db;
GO

------------------------------------------------------------------------------------------
-- 2. CREACIÓN DE TABLAS
------------------------------------------------------------------------------------------
/*
   Orden de creación para respetar las referencias:
   1) Roles
   2) Categorias
   3) MetodosPago
   4) Usuarios
   5) Productos
   6) Ordenes
   7) DetalleOrdenes
   8) Pagos
   9) Inventario
   10) Bitacora
*/

-- ========================================
-- TABLA: Roles
-- ========================================
CREATE TABLE Roles (
    id_rol INT PRIMARY KEY IDENTITY(1,1),
    nombre VARCHAR(50) NOT NULL UNIQUE
);
GO

-- ========================================
-- TABLA: Categorias
-- ========================================
CREATE TABLE Categorias (
    id_categoria INT PRIMARY KEY IDENTITY(1,1),
    nombre       VARCHAR(100) NOT NULL UNIQUE,
    descripcion  VARCHAR(MAX) NULL
);
GO

-- ========================================
-- TABLA: MetodosPago
-- ========================================
CREATE TABLE MetodosPago (
    id_metodo_pago INT PRIMARY KEY IDENTITY(1,1),
    nombre         VARCHAR(50) NOT NULL UNIQUE
);
GO

-- ========================================
-- TABLA: Usuarios
-- ========================================
CREATE TABLE Usuarios (
    id_usuario     INT PRIMARY KEY IDENTITY(1,1),
    nombre         VARCHAR(100) NOT NULL,
    correo         VARCHAR(100) NOT NULL UNIQUE,
    clave          VARBINARY(256) NOT NULL,  -- Contraseña hasheada
    telefono       VARCHAR(20),
    direccion      VARCHAR(MAX),
    id_rol         INT NOT NULL,
    fecha_creacion DATETIME DEFAULT GETDATE(),
    CONSTRAINT fk_usuarios_rol 
        FOREIGN KEY (id_rol) REFERENCES Roles(id_rol) ON DELETE CASCADE
);
GO

-- ========================================
-- TABLA: Productos
-- ========================================
CREATE TABLE Productos (
    id_producto    INT PRIMARY KEY IDENTITY(1,1),
    nombre         VARCHAR(100) NOT NULL,
    descripcion    VARCHAR(MAX) NULL,
    precio         DECIMAL(10,2) NOT NULL CHECK (precio >= 0),
    stock          INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    id_categoria   INT NULL,  -- Permite NULL para usar ON DELETE SET NULL
    fecha_creacion DATETIME DEFAULT GETDATE(),
    CONSTRAINT fk_productos_categoria 
        FOREIGN KEY (id_categoria) REFERENCES Categorias(id_categoria) ON DELETE SET NULL
);
GO

-- ========================================
-- TABLA: Ordenes
-- ========================================
CREATE TABLE Ordenes (
    id_orden       INT PRIMARY KEY IDENTITY(1,1),
    id_usuario     INT NOT NULL,
    total          DECIMAL(10,2) NOT NULL CHECK (total >= 0),
    estado         VARCHAR(50) DEFAULT 'Pendiente',
    fecha_creacion DATETIME DEFAULT GETDATE(),
    CONSTRAINT fk_ordenes_usuario 
        FOREIGN KEY (id_usuario) REFERENCES Usuarios(id_usuario) ON DELETE CASCADE
);
GO

-- ========================================
-- TABLA: DetalleOrdenes
-- ========================================
CREATE TABLE DetalleOrdenes (
    id_detalle      INT PRIMARY KEY IDENTITY(1,1),
    id_orden        INT NOT NULL,
    id_producto     INT NOT NULL,
    cantidad        INT NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10,2) NOT NULL CHECK (precio_unitario >= 0),
    subtotal        AS (cantidad * precio_unitario) PERSISTED,
    CONSTRAINT fk_detalleorden_orden 
        FOREIGN KEY (id_orden) REFERENCES Ordenes(id_orden) ON DELETE CASCADE,
    CONSTRAINT fk_detalleorden_producto 
        FOREIGN KEY (id_producto) REFERENCES Productos(id_producto) ON DELETE CASCADE
);
GO

-- ========================================
-- TABLA: Pagos
-- ========================================
CREATE TABLE Pagos (
    id_pago        INT PRIMARY KEY IDENTITY(1,1),
    id_orden       INT NOT NULL,
    id_metodo_pago INT NULL, -- Permite NULL para usar ON DELETE SET NULL
    monto          DECIMAL(10,2) NOT NULL CHECK (monto >= 0),
    fecha_pago     DATETIME DEFAULT GETDATE(),
    CONSTRAINT fk_pagos_orden 
        FOREIGN KEY (id_orden) REFERENCES Ordenes(id_orden) ON DELETE CASCADE,
    CONSTRAINT fk_pagos_metodo 
        FOREIGN KEY (id_metodo_pago) REFERENCES MetodosPago(id_metodo_pago) ON DELETE SET NULL
);
GO

-- ========================================
-- TABLA: Inventario
-- ========================================
CREATE TABLE Inventario (
    id_inventario     INT PRIMARY KEY IDENTITY(1,1),
    id_producto       INT NOT NULL,
    cantidad_cambiada INT NOT NULL,
    fecha             DATETIME DEFAULT GETDATE(),
    descripcion       VARCHAR(MAX) NULL,
    CONSTRAINT fk_inventario_producto 
        FOREIGN KEY (id_producto) REFERENCES Productos(id_producto) ON DELETE CASCADE
);
GO

-- ========================================
-- TABLA: Bitacora (Auditoría)
-- ========================================
CREATE TABLE Bitacora (
    id_bitacora          INT PRIMARY KEY IDENTITY(1,1),
    tabla_afectada       VARCHAR(100) NOT NULL,
    id_registro_afectado INT NOT NULL,
    accion               VARCHAR(50) NOT NULL,   -- 'INSERT', 'UPDATE', 'DELETE'
    usuario              VARCHAR(100) NOT NULL,
    fecha                DATETIME DEFAULT GETDATE(),
    detalle              VARCHAR(MAX) NULL
);
GO

------------------------------------------------------------------------------------------
-- 3. CREACIÓN DE TRIGGER PARA AUDITORÍA (Ejemplo en Usuarios)
------------------------------------------------------------------------------------------
GO  -- Asegura que CREATE TRIGGER sea la primera instrucción de su lote

CREATE TRIGGER trg_auditoria_usuarios
ON Usuarios
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @accion VARCHAR(50);

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @accion = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @accion = 'INSERT';
    ELSE
        SET @accion = 'DELETE';

    /*
      Inserta en la bitácora tanto los registros 'inserted' como 'deleted'.
      - 'inserted' contiene las filas nuevas o actualizadas.
      - 'deleted' contiene las filas que fueron borradas o antes de la actualización.
      - Si sólo quisieras almacenar un único registro por UPDATE, podrías filtrar.
    */
    INSERT INTO Bitacora (tabla_afectada, id_registro_afectado, accion, usuario, detalle)
    SELECT 'Usuarios', id_usuario, @accion, SUSER_NAME(), 'Cambio en la tabla usuarios'
    FROM inserted
    UNION
    SELECT 'Usuarios', id_usuario, @accion, SUSER_NAME(), 'Cambio en la tabla usuarios'
    FROM deleted;
END;
GO

------------------------------------------------------------------------------------------
-- 4. CREACIÓN DE PROCEDIMIENTOS ALMACENADOS (INSERCIÓN CON TRANSACCIONES)
------------------------------------------------------------------------------------------
/*
   Uso convención "usp_{Entidad}{Acción}":
   - usp_RolInsertar
   - usp_UsuarioInsertar
   - ...
*/

-- ===============================
-- usp_RolInsertar
-- ===============================
CREATE OR ALTER PROCEDURE usp_RolInsertar
    @nombre VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN
    BEGIN TRY
        INSERT INTO Roles (nombre)
        VALUES (@nombre);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

-- ===============================
-- usp_UsuarioInsertar
-- ===============================
CREATE OR ALTER PROCEDURE usp_UsuarioInsertar
    @nombre     VARCHAR(100),
    @correo     VARCHAR(100),
    @clave      VARBINARY(256),
    @telefono   VARCHAR(20)    = NULL,
    @direccion  VARCHAR(MAX)   = NULL,
    @id_rol     INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN
    BEGIN TRY
        INSERT INTO Usuarios (
            nombre,
            correo,
            clave,
            telefono,
            direccion,
            id_rol
        )
        VALUES (
            @nombre,
            @correo,
            @clave,
            @telefono,
            @direccion,
            @id_rol
        );

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

-- ===============================
-- usp_CategoriaInsertar
-- ===============================
CREATE OR ALTER PROCEDURE usp_CategoriaInsertar
    @nombre      VARCHAR(100),
    @descripcion VARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN
    BEGIN TRY
        INSERT INTO Categorias (nombre, descripcion)
        VALUES (@nombre, @descripcion);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

-- ===============================
-- usp_ProductoInsertar
-- ===============================
CREATE OR ALTER PROCEDURE usp_ProductoInsertar
    @nombre        VARCHAR(100),
    @descripcion   VARCHAR(MAX) = NULL,
    @precio        DECIMAL(10,2),
    @stock         INT,
    @id_categoria  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN
    BEGIN TRY
        INSERT INTO Productos (
            nombre,
            descripcion,
            precio,
            stock,
            id_categoria
        )
        VALUES (
            @nombre,
            @descripcion,
            @precio,
            @stock,
            @id_categoria
        );

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

-- ===============================
-- usp_OrdenInsertar
-- ===============================
CREATE OR ALTER PROCEDURE usp_OrdenInsertar
    @id_usuario INT,
    @total      DECIMAL(10,2),
    @estado     VARCHAR(50) = 'Pendiente'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN
    BEGIN TRY
        INSERT INTO Ordenes (
            id_usuario,
            total,
            estado
        )
        VALUES (
            @id_usuario,
            @total,
            @estado
        );

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

-- ===============================
-- usp_DetalleOrdenInsertar
-- ===============================
CREATE OR ALTER PROCEDURE usp_DetalleOrdenInsertar
    @id_orden       INT,
    @id_producto    INT,
    @cantidad       INT,
    @precio_unitario DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN
    BEGIN TRY
        INSERT INTO DetalleOrdenes (
            id_orden,
            id_producto,
            cantidad,
            precio_unitario
        )
        VALUES (
            @id_orden,
            @id_producto,
            @cantidad,
            @precio_unitario
        );

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

-- ===============================
-- usp_PagoInsertar
-- ===============================
CREATE OR ALTER PROCEDURE usp_PagoInsertar
    @id_orden       INT,
    @id_metodo_pago INT,
    @monto          DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN
    BEGIN TRY
        INSERT INTO Pagos (
            id_orden,
            id_metodo_pago,
            monto
        )
        VALUES (
            @id_orden,
            @id_metodo_pago,
            @monto
        );

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

-- ===============================
-- usp_InventarioInsertar
-- ===============================
CREATE OR ALTER PROCEDURE usp_InventarioInsertar
    @id_producto       INT,
    @cantidad_cambiada INT,
    @descripcion       VARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN
    BEGIN TRY
        INSERT INTO Inventario (
            id_producto,
            cantidad_cambiada,
            descripcion
        )
        VALUES (
            @id_producto,
            @cantidad_cambiada,
            @descripcion
        );

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

------------------------------------------------------------------------------------------
-- 5. INSERCIÓN DE DATOS DE PRUEBA USANDO LOS PROCEDIMIENTOS
------------------------------------------------------------------------------------------

/*
   Insertaremos datos básicos:
     - Roles
     - Categorías
     - Métodos de pago
     - Usuarios
     - Productos
     - Orden y detalle de orden
     - Pagos
     - Movimientos de inventario
*/

-- ========================================
-- ROLES
-- ========================================
EXEC usp_RolInsertar @nombre = 'Administrador';
EXEC usp_RolInsertar @nombre = 'Cliente';
EXEC usp_RolInsertar @nombre = 'Vendedor';

-- ========================================
-- CATEGORÍAS
-- ========================================
EXEC usp_CategoriaInsertar 
    @nombre = 'Electrónica', 
    @descripcion = 'Smartphones, laptops, etc.';
EXEC usp_CategoriaInsertar 
    @nombre = 'Ropa', 
    @descripcion = 'Prendas de vestir';
EXEC usp_CategoriaInsertar 
    @nombre = 'Hogar', 
    @descripcion = 'Muebles y electrodomésticos';

-- ========================================
-- MÉTODOS DE PAGO (ejemplo de inserción directa)
-- ========================================
INSERT INTO MetodosPago (nombre)
VALUES ('Tarjeta de Crédito'),
       ('PayPal'),
       ('Transferencia Bancaria'),
       ('Efectivo');

-- ========================================
-- USUARIOS
-- ========================================
EXEC usp_UsuarioInsertar 
    @nombre = 'Juan Pérez',
    @correo = 'juan@example.com',
    @clave = 0x123456,   -- Hash simulado
    @telefono = '999-888-777',
    @direccion = 'Calle Falsa 123',
    @id_rol = 2;         -- Cliente

EXEC usp_UsuarioInsertar
    @nombre = 'Ana Gómez',
    @correo = 'ana@example.com',
    @clave = 0x654321,   -- Hash simulado
    @telefono = '111-222-333',
    @direccion = 'Av. Principal 456',
    @id_rol = 1;         -- Administrador

-- ========================================
-- PRODUCTOS
-- ========================================
EXEC usp_ProductoInsertar
    @nombre = 'Laptop HP',
    @descripcion = 'Laptop de alto rendimiento',
    @precio = 1200.00,
    @stock = 10,
    @id_categoria = 1;  -- Electrónica

EXEC usp_ProductoInsertar
    @nombre = 'Camiseta Negra',
    @descripcion = 'Camiseta de algodón',
    @precio = 20.00,
    @stock = 50,
    @id_categoria = 2;  -- Ropa

-- ========================================
-- CREAR UNA ORDEN (Usuario "Juan Pérez" -> id_usuario = 1)
-- ========================================
EXEC usp_OrdenInsertar 
    @id_usuario = 1,
    @total = 1240.00,
    @estado = 'Pendiente';

-- ========================================
-- DETALLES DE LA ORDEN (asumiendo la orden creada es id_orden = 1)
-- ========================================
EXEC usp_DetalleOrdenInsertar
    @id_orden = 1,
    @id_producto = 1,      -- Laptop HP
    @cantidad = 1,
    @precio_unitario = 1200.00;

EXEC usp_DetalleOrdenInsertar
    @id_orden = 1,
    @id_producto = 2,      -- Camiseta Negra
    @cantidad = 2,
    @precio_unitario = 20.00;

-- ========================================
-- PAGO DE LA ORDEN (Método de pago #1 = 'Tarjeta de Crédito')
-- ========================================
EXEC usp_PagoInsertar
    @id_orden = 1,
    @id_metodo_pago = 1,
    @monto = 1240.00;

-- ========================================
-- INVENTARIO (Descuenta 1 laptop y 2 camisetas)
-- ========================================
EXEC usp_InventarioInsertar
    @id_producto = 1,
    @cantidad_cambiada = -1,
    @descripcion = 'Venta Laptop HP';

EXEC usp_InventarioInsertar
    @id_producto = 2,
    @cantidad_cambiada = -2,
    @descripcion = 'Venta Camiseta Negra';

------------------------------------------------------------------------------------------
-- FIN DEL SCRIPT
------------------------------------------------------------------------------------------

/****************************************************************************************
  Instrucciones:
  1) Ejecuta este script completo en SQL Server Management Studio o similar.
  2) Revisa la base de datos "ecommerce_db", con sus tablas sin prefijos innecesarios.
  3) Verás el trigger "trg_auditoria_usuarios" y procedimientos "usp_*" para las inserciones.
  4) Confirma que los datos de prueba se hayan insertado correctamente.
  5) Personaliza nombres, validaciones y descripciones a conveniencia.
****************************************************************************************/