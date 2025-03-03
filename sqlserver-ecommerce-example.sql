/****************************************************************************************
  SCRIPT COMPLETO PARA ECOMMERCE EN SQL SERVER
  --------------------------------------------------------------
  Contenido:
    1) Creación de la base de datos y uso
    2) Creación de tablas (orden correcto para FK)
    3) Creación de un trigger de auditoría (ejemplo en tabla usuarios)
    4) Creación de procedimientos almacenados para inserciones
       - Manejo de transacciones y rollback
    5) Inserción de datos de prueba usando los SP
****************************************************************************************/

------------------------------------------------------------------------------------------
-- 1. CREAR BASE DE DATOS Y SELECCIONARLA
------------------------------------------------------------------------------------------
IF DB_ID('ecommerce_db') IS NOT NULL
    DROP DATABASE ecommerce_db;
GO

CREATE DATABASE ecommerce_db;
GO

USE ecommerce_db;
GO

------------------------------------------------------------------------------------------
-- 2. CREACIÓN DE TABLAS
------------------------------------------------------------------------------------------
/*
   Orden de creación para respetar las referencias:
   1) roles
   2) categorias
   3) metodos_pago
   4) usuarios
   5) productos
   6) ordenes
   7) detalle_ordenes
   8) pagos
   9) inventario
   10) bitacora
*/

-- ========================================
-- TABLA: roles
-- ========================================
CREATE TABLE roles (
    id_rol INT PRIMARY KEY IDENTITY(1,1),
    nombre VARCHAR(50) NOT NULL UNIQUE
);
GO

-- ========================================
-- TABLA: categorias
-- ========================================
CREATE TABLE categorias (
    id_categoria INT PRIMARY KEY IDENTITY(1,1),
    nombre VARCHAR(100) UNIQUE NOT NULL,
    descripcion TEXT NULL
);
GO

-- ========================================
-- TABLA: metodos_pago
-- ========================================
CREATE TABLE metodos_pago (
    id_metodo_pago INT PRIMARY KEY IDENTITY(1,1),
    nombre VARCHAR(50) UNIQUE NOT NULL
);
GO

-- ========================================
-- TABLA: usuarios
-- ========================================
CREATE TABLE usuarios (
    id_usuario INT PRIMARY KEY IDENTITY(1,1),
    nombre VARCHAR(100) NOT NULL,
    correo VARCHAR(100) UNIQUE NOT NULL,
    clave VARBINARY(256) NOT NULL,  -- Contraseña hasheada
    telefono VARCHAR(20),
    direccion VARCHAR(MAX),
    id_rol INT NOT NULL,
    fecha_creacion DATETIME DEFAULT GETDATE(),
    CONSTRAINT fk_usuarios_rol 
        FOREIGN KEY (id_rol) REFERENCES roles(id_rol) ON DELETE CASCADE
);
GO

-- ========================================
-- TABLA: productos
-- ========================================
CREATE TABLE productos (
    id_producto INT PRIMARY KEY IDENTITY(1,1),
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(MAX) NULL,
    precio DECIMAL(10,2) NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    id_categoria INT NULL,  -- Permite NULL para usar ON DELETE SET NULL
    fecha_creacion DATETIME DEFAULT GETDATE(),
    CONSTRAINT fk_productos_categoria 
        FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria) ON DELETE SET NULL
);
GO

-- ========================================
-- TABLA: ordenes
-- ========================================
CREATE TABLE ordenes (
    id_orden INT PRIMARY KEY IDENTITY(1,1),
    id_usuario INT NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    estado VARCHAR(50) DEFAULT 'Pendiente',  
    fecha_creacion DATETIME DEFAULT GETDATE(),
    CONSTRAINT fk_ordenes_usuario 
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
);
GO

-- ========================================
-- TABLA: detalle_ordenes
-- ========================================
CREATE TABLE detalle_ordenes (
    id_detalle INT PRIMARY KEY IDENTITY(1,1),
    id_orden INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10,2) NOT NULL,
    subtotal AS (cantidad * precio_unitario) PERSISTED,
    CONSTRAINT fk_detalle_orden_orden 
        FOREIGN KEY (id_orden) REFERENCES ordenes(id_orden) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_orden_producto 
        FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
);
GO

-- ========================================
-- TABLA: pagos
-- ========================================
CREATE TABLE pagos (
    id_pago INT PRIMARY KEY IDENTITY(1,1),
    id_orden INT NOT NULL,
    id_metodo_pago INT NULL, -- Permite NULL para usar ON DELETE SET NULL
    monto DECIMAL(10,2) NOT NULL,
    fecha_pago DATETIME DEFAULT GETDATE(),
    CONSTRAINT fk_pagos_orden 
        FOREIGN KEY (id_orden) REFERENCES ordenes(id_orden) ON DELETE CASCADE,
    CONSTRAINT fk_pagos_metodo 
        FOREIGN KEY (id_metodo_pago) REFERENCES metodos_pago(id_metodo_pago) ON DELETE SET NULL
);
GO

-- ========================================
-- TABLA: inventario
-- ========================================
CREATE TABLE inventario (
    id_inventario INT PRIMARY KEY IDENTITY(1,1),
    id_producto INT NOT NULL,
    cantidad_cambiada INT NOT NULL,
    fecha DATETIME DEFAULT GETDATE(),
    descripcion VARCHAR(MAX) NULL,
    CONSTRAINT fk_inventario_producto 
        FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
);
GO

-- ========================================
-- TABLA: bitacora (Auditoría)
-- ========================================
CREATE TABLE bitacora (
    id_bitacora INT PRIMARY KEY IDENTITY(1,1),
    tabla_afectada VARCHAR(100) NOT NULL,
    id_registro_afectado INT NOT NULL,
    accion VARCHAR(50) NOT NULL,   -- 'INSERT', 'UPDATE', 'DELETE'
    usuario VARCHAR(100) NOT NULL,
    fecha DATETIME DEFAULT GETDATE(),
    detalle VARCHAR(MAX) NULL
);
GO

------------------------------------------------------------------------------------------
-- 3. CREACIÓN DE TRIGGERS PARA AUDITORÍA (EJEMPLO EN USUARIOS)
------------------------------------------------------------------------------------------
GO  -- Asegura que CREATE TRIGGER sea la primera instrucción de su lote

CREATE TRIGGER trg_auditoria_usuarios
ON usuarios
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
    */
    INSERT INTO bitacora (tabla_afectada, id_registro_afectado, accion, usuario, detalle)
    SELECT 'usuarios', id_usuario, @accion, SUSER_NAME(), 'Cambio en la tabla usuarios'
    FROM inserted
    UNION
    SELECT 'usuarios', id_usuario, @accion, SUSER_NAME(), 'Cambio en la tabla usuarios'
    FROM deleted;
END;
GO

------------------------------------------------------------------------------------------
-- 4. CREACIÓN DE PROCEDIMIENTOS ALMACENADOS (INSERCIÓN CON TRANSACCIONES)
------------------------------------------------------------------------------------------

-- ===============================
-- SP: Insertar Rol
-- ===============================
CREATE OR ALTER PROCEDURE sp_insert_rol
    @nombre VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN
    BEGIN TRY
        INSERT INTO roles (nombre)
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
-- SP: Insertar Usuario
-- ===============================
CREATE OR ALTER PROCEDURE sp_insert_usuario
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
        INSERT INTO usuarios (
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
-- SP: Insertar Categoría
-- ===============================
CREATE OR ALTER PROCEDURE sp_insert_categoria
    @nombre      VARCHAR(100),
    @descripcion VARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN
    BEGIN TRY
        INSERT INTO categorias (nombre, descripcion)
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
-- SP: Insertar Producto
-- ===============================
CREATE OR ALTER PROCEDURE sp_insert_producto
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
        INSERT INTO productos (
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
-- SP: Insertar Orden
-- ===============================
CREATE OR ALTER PROCEDURE sp_insert_orden
    @id_usuario INT,
    @total      DECIMAL(10,2),
    @estado     VARCHAR(50) = 'Pendiente'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN
    BEGIN TRY
        INSERT INTO ordenes (
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
-- SP: Insertar Detalle de Orden
-- ===============================
CREATE OR ALTER PROCEDURE sp_insert_detalle_orden
    @id_orden       INT,
    @id_producto    INT,
    @cantidad       INT,
    @precio_unitario DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN
    BEGIN TRY
        INSERT INTO detalle_ordenes (
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
-- SP: Insertar Pago
-- ===============================
CREATE OR ALTER PROCEDURE sp_insert_pago
    @id_orden       INT,
    @id_metodo_pago INT,
    @monto          DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN
    BEGIN TRY
        INSERT INTO pagos (
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
-- SP: Insertar Movimiento de Inventario
-- ===============================
CREATE OR ALTER PROCEDURE sp_insert_inventario
    @id_producto       INT,
    @cantidad_cambiada INT,
    @descripcion       VARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN
    BEGIN TRY
        INSERT INTO inventario (
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
EXEC sp_insert_rol @nombre = 'Administrador';
EXEC sp_insert_rol @nombre = 'Cliente';
EXEC sp_insert_rol @nombre = 'Vendedor';

-- ========================================
-- CATEGORÍAS
-- ========================================
EXEC sp_insert_categoria 
    @nombre = 'Electrónica', 
    @descripcion = 'Smartphones, laptops, etc.';
EXEC sp_insert_categoria 
    @nombre = 'Ropa', 
    @descripcion = 'Prendas de vestir';
EXEC sp_insert_categoria 
    @nombre = 'Hogar', 
    @descripcion = 'Muebles y electrodomésticos';

-- ========================================
-- MÉTODOS DE PAGO
-- ========================================
INSERT INTO metodos_pago (nombre)
VALUES ('Tarjeta de Crédito'),
       ('PayPal'),
       ('Transferencia Bancaria'),
       ('Efectivo');

-- ========================================
-- USUARIOS
-- ========================================
EXEC sp_insert_usuario 
    @nombre = 'Juan Pérez',
    @correo = 'juan@example.com',
    @clave = 0x123456,       
    @telefono = '999-888-777',
    @direccion = 'Calle Falsa 123',
    @id_rol = 2;             -- Cliente

EXEC sp_insert_usuario 
    @nombre = 'Ana Gómez',
    @correo = 'ana@example.com',
    @clave = 0x654321,
    @telefono = '111-222-333',
    @direccion = 'Av. Principal 456',
    @id_rol = 1;             -- Administrador

-- ========================================
-- PRODUCTOS
-- ========================================
EXEC sp_insert_producto
    @nombre = 'Laptop HP',
    @descripcion = 'Laptop de alto rendimiento',
    @precio = 1200.00,
    @stock = 10,
    @id_categoria = 1;  -- Electrónica

EXEC sp_insert_producto
    @nombre = 'Camiseta Negra',
    @descripcion = 'Camiseta de algodón',
    @precio = 20.00,
    @stock = 50,
    @id_categoria = 2;  -- Ropa

-- ========================================
-- CREAR UNA ORDEN (Usuario "Juan Pérez" -> id_usuario = 1)
-- ========================================
EXEC sp_insert_orden 
    @id_usuario = 1,
    @total = 1240.00,
    @estado = 'Pendiente';

-- ========================================
-- DETALLES DE LA ORDEN (Asumiendo la orden recién creada es id_orden = 1)
-- ========================================
EXEC sp_insert_detalle_orden
    @id_orden = 1,
    @id_producto = 1,      -- Laptop HP
    @cantidad = 1,
    @precio_unitario = 1200.00;

EXEC sp_insert_detalle_orden
    @id_orden = 1,
    @id_producto = 2,      -- Camiseta Negra
    @cantidad = 2,
    @precio_unitario = 20.00;

-- ========================================
-- PAGO DE LA ORDEN (Método de pago #1 = 'Tarjeta de Crédito')
-- ========================================
EXEC sp_insert_pago
    @id_orden = 1,
    @id_metodo_pago = 1,
    @monto = 1240.00;

-- ========================================
-- INVENTARIO (Descuenta 1 laptop y 2 camisetas)
-- ========================================
EXEC sp_insert_inventario
    @id_producto = 1,
    @cantidad_cambiada = -1,
    @descripcion = 'Venta Laptop HP';

EXEC sp_insert_inventario
    @id_producto = 2,
    @cantidad_cambiada = -2,
    @descripcion = 'Venta Camiseta Negra';

------------------------------------------------------------------------------------------
-- FIN DEL SCRIPT
------------------------------------------------------------------------------------------

/****************************************************************************************
  Instrucciones:
  1) Ejecuta este script completo en SQL Server Management Studio o similar.
  2) Revisa la base de datos "ecommerce_db" con sus tablas, triggers, SP y datos insertados.
  3) Puedes personalizar o ampliar según tus necesidades.
****************************************************************************************/