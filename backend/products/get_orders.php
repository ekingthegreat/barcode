<?php

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Accept");
header("Content-Type: application/json; charset=UTF-8");

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . "/../config/database.php";

try {
    // Fetch all orders
    $sql = "SELECT id, customer_name, total_amount, cash_received, change_amount as `change`, order_date, created_at 
            FROM orders 
            ORDER BY id DESC";
    $stmt = $pdo->query($sql);
    $orders = $stmt->fetchAll();

    // Fetch items for each order
    foreach ($orders as &$order) {
        $itemSql = "SELECT barcode, product_name, brand, category, price, quantity, total 
                    FROM order_items 
                    WHERE order_id = :order_id";
        $itemStmt = $pdo->prepare($itemSql);
        $itemStmt->execute([":order_id" => $order['id']]);
        $order['items'] = $itemStmt->fetchAll();
    }

    echo json_encode([
        "success" => true,
        "orders" => $orders
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Failed to fetch orders: " . $e->getMessage()
    ]);
}
