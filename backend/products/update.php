<?php

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Accept");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["success" => false, "message" => "Method not allowed"]);
    exit;
}

require_once __DIR__ . "/../config/database.php";

$rawInput = file_get_contents("php://input");
$data = json_decode($rawInput, true);

if (!$data) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Invalid JSON payload"]);
    exit;
}

$barcode = trim($data["barcode"] ?? "");
$productName = trim($data["product_name"] ?? "");
$brand = trim($data["brand"] ?? "");
$category = trim($data["category"] ?? "");
$price = $data["price"] ?? 0;
$stock = $data["stock"] ?? 0;

if ($barcode === "" || $productName === "") {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Barcode and product name are required"]);
    exit;
}

try {
    $sql = "UPDATE products 
            SET product_name = :product_name, brand = :brand, category = :category, price = :price, stock = :stock 
            WHERE barcode = :barcode";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ":product_name" => $productName,
        ":brand" => $brand,
        ":category" => $category,
        ":price" => $price,
        ":stock" => $stock,
        ":barcode" => $barcode
    ]);

    echo json_encode([
        "success" => true,
        "message" => "Product updated successfully"
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Failed to update product: " . $e->getMessage()
    ]);
}
