<?php

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Accept");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . "/../config/database.php";

try {
    $sql = "SELECT id, barcode, product_name, brand, category, price, stock, image_url, created_at 
            FROM products 
            ORDER BY id DESC";
    $stmt = $pdo->query($sql);
    $products = $stmt->fetchAll();

    echo json_encode([
        "success" => true,
        "products" => $products
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Failed to fetch products: " . $e->getMessage()
    ]);
}
