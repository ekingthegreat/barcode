<?php

$host = "localhost";
$dbname = "barcode_db";
$username = "root";
$password = "";

try {
    $pdo = new PDO(
        "mysql:host=$host;dbname=$dbname;charset=utf8mb4",
        $username,
        $password,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]
    );

    // Auto-create products table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS products (
            id INT AUTO_INCREMENT PRIMARY KEY,
            barcode VARCHAR(100) NOT NULL UNIQUE,
            product_name VARCHAR(255) NOT NULL,
            brand VARCHAR(100) DEFAULT '',
            category VARCHAR(100) DEFAULT '',
            price DECIMAL(10,2) DEFAULT 0.00,
            stock INT DEFAULT 0,
            image_url VARCHAR(255) DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    // Auto-create orders table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS orders (
            id INT AUTO_INCREMENT PRIMARY KEY,
            customer_name VARCHAR(150) DEFAULT 'Walk-in Customer',
            total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
            cash_received DECIMAL(10,2) NOT NULL DEFAULT 0.00,
            change_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
            order_date VARCHAR(50) DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    // Auto-create order_items table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS order_items (
            id INT AUTO_INCREMENT PRIMARY KEY,
            order_id INT NOT NULL,
            barcode VARCHAR(100) DEFAULT '',
            product_name VARCHAR(255) NOT NULL,
            brand VARCHAR(100) DEFAULT '',
            category VARCHAR(100) DEFAULT '',
            price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
            quantity INT NOT NULL DEFAULT 1,
            total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
            INDEX (order_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    // Auto-create users table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(100) NOT NULL UNIQUE,
            email VARCHAR(150) NOT NULL UNIQUE,
            password VARCHAR(255) NOT NULL,
            store_name VARCHAR(150) DEFAULT 'My Store',
            store_address VARCHAR(255) DEFAULT '123 Main Street, City',
            phone VARCHAR(50) DEFAULT '+63 912 345 6789',
            role VARCHAR(50) DEFAULT 'Admin',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Database connection failed: " . $e->getMessage()
    ]);
    exit;
}