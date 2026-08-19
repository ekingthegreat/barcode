<?php

header("Content-Type: application/json");

require_once "../config/database.php";

$data = json_decode(
    file_get_contents("php://input"),
    true
);

if (!$data) {

    echo json_encode([
        "success" => false,
        "message" => "Invalid request"
    ]);

    exit;
}

$barcode = trim($data["barcode"] ?? "");
$productName = trim($data["product_name"] ?? "");
$brand = trim($data["brand"] ?? "");
$category = trim($data["category"] ?? "");
$price = $data["price"] ?? 0;
$stock = $data["stock"] ?? 0;

if ($barcode === "" || $productName === "") {

    echo json_encode([
        "success" => false,
        "message" => "Barcode and product name are required"
    ]);

    exit;
}

try {

    $sql = "
        INSERT INTO products
        (
            barcode,
            product_name,
            brand,
            category,
            price,
            stock
        )
        VALUES
        (
            :barcode,
            :product_name,
            :brand,
            :category,
            :price,
            :stock
        )
    ";

    $stmt = $pdo->prepare($sql);

    $stmt->execute([
        ":barcode" => $barcode,
        ":product_name" => $productName,
        ":brand" => $brand,
        ":category" => $category,
        ":price" => $price,
        ":stock" => $stock
    ]);

    echo json_encode([
        "success" => true,
        "message" => "Product registered successfully",
        "id" => $pdo->lastInsertId()
    ]);

} catch (PDOException $e) {

    if ($e->getCode() == 23000) {

        echo json_encode([
            "success" => false,
            "message" => "Barcode already exists"
        ]);

    } else {

        http_response_code(500);

        echo json_encode([
            "success" => false,
            "message" => "Failed to register product"
        ]);
    }
}