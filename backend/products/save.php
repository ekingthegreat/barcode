<?php

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Accept, Authorization");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Method not allowed. Only POST accepted."
    ]);
    exit;
}

require_once __DIR__ . "/../config/database.php";

$rawInput = file_get_contents("php://input");
$data = json_decode($rawInput, true);

if (!$data) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Invalid JSON payload"
    ]);
    exit;
}

$customerName = trim($data['customer_name'] ?? 'Walk-in Customer');
if ($customerName === '') {
    $customerName = 'Walk-in Customer';
}

$totalAmount = floatval($data['total_amount'] ?? 0);
$cashReceived = floatval($data['cash_received'] ?? $totalAmount);
$changeAmount = floatval($data['change'] ?? $data['change_amount'] ?? 0);
$orderDate = $data['order_date'] ?? date('Y-m-d H:i:s');
$items = $data['items'] ?? [];

if (empty($items)) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "No items in order"
    ]);
    exit;
}

try {
    $pdo->beginTransaction();

    // 1. Insert order record
    $orderSql = "INSERT INTO orders (customer_name, total_amount, cash_received, change_amount, order_date) 
                 VALUES (:customer_name, :total_amount, :cash_received, :change_amount, :order_date)";
    $orderStmt = $pdo->prepare($orderSql);
    $orderStmt->execute([
        ":customer_name" => $customerName,
        ":total_amount" => $totalAmount,
        ":cash_received" => $cashReceived,
        ":change_amount" => $changeAmount,
        ":order_date" => $orderDate
    ]);

    $orderId = $pdo->lastInsertId();

    // 2. Insert order items & deduct product stock
    $itemSql = "INSERT INTO order_items (order_id, barcode, product_name, brand, category, price, quantity, total) 
                VALUES (:order_id, :barcode, :product_name, :brand, :category, :price, :quantity, :total)";
    $itemStmt = $pdo->prepare($itemSql);

    $stockSql = "UPDATE products SET stock = GREATEST(0, stock - :quantity) WHERE barcode = :barcode";
    $stockStmt = $pdo->prepare($stockSql);

    foreach ($items as $item) {
        $barcode = trim($item['barcode'] ?? '');
        $productName = trim($item['product_name'] ?? 'Product');
        $brand = trim($item['brand'] ?? '');
        $category = trim($item['category'] ?? '');
        $price = floatval($item['price'] ?? 0);
        $quantity = intval($item['quantity'] ?? 1);
        $total = floatval($item['total'] ?? ($price * $quantity));

        $itemStmt->execute([
            ":order_id" => $orderId,
            ":barcode" => $barcode,
            ":product_name" => $productName,
            ":brand" => $brand,
            ":category" => $category,
            ":price" => $price,
            ":quantity" => $quantity,
            ":total" => $total
        ]);

        if ($barcode !== '') {
            $stockStmt->execute([
                ":quantity" => $quantity,
                ":barcode" => $barcode
            ]);
        }
    }

    $pdo->commit();

    echo json_encode([
        "success" => true,
        "message" => "Order saved successfully",
        "order_id" => $orderId
    ]);

} catch (Exception $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Failed to save order: " . $e->getMessage()
    ]);
}