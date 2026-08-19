<?php

header("Content-Type: application/json");

require_once "../config/database.php";

$barcode = trim($_GET["barcode"] ?? "");

if ($barcode === "") {

    echo json_encode([
        "success" => false,
        "message" => "Barcode is required"
    ]);

    exit;
}

try {

    $sql = "
        SELECT
            id,
            barcode,
            product_name,
            brand,
            category,
            price,
            stock,
            image_url,
            created_at
        FROM products
        WHERE barcode = :barcode
        LIMIT 1
    ";

    $stmt = $pdo->prepare($sql);

    $stmt->execute([
        ":barcode" => $barcode
    ]);

    $product = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$product) {

        echo json_encode([
            "success" => false,
            "message" => "Product not found"
        ]);

        exit;
    }

    echo json_encode([
        "success" => true,
        "product" => $product
    ]);

} catch (PDOException $e) {

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "message" => "Database error"
    ]);
}