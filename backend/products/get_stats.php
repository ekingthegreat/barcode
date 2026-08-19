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
    // 1. Total products count
    $productCountStmt = $pdo->query("SELECT COUNT(*) FROM products");
    $totalProducts = (int)$productCountStmt->fetchColumn();

    // 2. Total orders / transactions count
    $orderCountStmt = $pdo->query("SELECT COUNT(*) FROM orders");
    $totalOrders = (int)$orderCountStmt->fetchColumn();

    // 3. Total sales amount
    $totalSalesStmt = $pdo->query("SELECT COALESCE(SUM(total_amount), 0) FROM orders");
    $totalSales = (float)$totalSalesStmt->fetchColumn();

    // 4. Today's sales amount and today's orders
    $todaySalesStmt = $pdo->query("SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE DATE(created_at) = CURDATE() OR DATE(order_date) = CURDATE()");
    $todaySales = (float)$todaySalesStmt->fetchColumn();

    $todayOrdersStmt = $pdo->query("SELECT COUNT(*) FROM orders WHERE DATE(created_at) = CURDATE() OR DATE(order_date) = CURDATE()");
    $todayOrders = (int)$todayOrdersStmt->fetchColumn();

    // 5. Unique customers count
    $customersStmt = $pdo->query("SELECT COUNT(DISTINCT customer_name) FROM orders WHERE customer_name IS NOT NULL AND customer_name != ''");
    $uniqueCustomers = (int)$customersStmt->fetchColumn();

    // 6. Recent activities (combine recent orders and recently added products)
    $recentOrdersStmt = $pdo->query("SELECT id, customer_name, total_amount, order_date, created_at FROM orders ORDER BY id DESC LIMIT 5");
    $recentOrders = $recentOrdersStmt->fetchAll();

    $recentProductsStmt = $pdo->query("SELECT id, barcode, product_name, brand, category, price, stock, created_at FROM products ORDER BY id DESC LIMIT 5");
    $recentProducts = $recentProductsStmt->fetchAll();

    $activities = [];

    foreach ($recentOrders as $order) {
        $date = !empty($order['order_date']) ? $order['order_date'] : $order['created_at'];
        $cust = !empty($order['customer_name']) ? $order['customer_name'] : 'Walk-in Customer';
        $amount = number_format((float)$order['total_amount'], 2, '.', ',');
        $activities[] = [
            'id' => 'order_' . $order['id'],
            'type' => 'transaction',
            'title' => 'Transaction Completed',
            'subtitle' => 'Order #' . $order['id'] . ' • ' . $cust . ' (₱' . $amount . ')',
            'timestamp' => $date,
            'color' => 'orange',
            'icon' => 'receipt'
        ];
    }

    foreach ($recentProducts as $prod) {
        $date = !empty($prod['created_at']) ? $prod['created_at'] : date('Y-m-d H:i:s');
        $subtitle = $prod['product_name'];
        if (!empty($prod['brand'])) {
            $subtitle .= ' (' . $prod['brand'] . ')';
        }
        $subtitle .= ' • ₱' . number_format((float)$prod['price'], 2, '.', ',');
        $activities[] = [
            'id' => 'product_' . $prod['id'],
            'type' => 'product',
            'title' => 'Product Added',
            'subtitle' => $subtitle,
            'timestamp' => $date,
            'color' => 'green',
            'icon' => 'inventory'
        ];
    }

    // Sort combined activities by timestamp descending
    usort($activities, function($a, $b) {
        $tA = strtotime($a['timestamp']);
        $tB = strtotime($b['timestamp']);
        return $tB - $tA;
    });

    // Take latest 6 activities
    $activities = array_slice($activities, 0, 6);

    echo json_encode([
        "success" => true,
        "stats" => [
            "total_products" => $totalProducts,
            "total_orders" => $totalOrders,
            "total_sales" => $totalSales,
            "today_sales" => $todaySales,
            "today_orders" => $todayOrders,
            "unique_customers" => $uniqueCustomers
        ],
        "recent_activities" => $activities
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Failed to fetch statistics: " . $e->getMessage()
    ]);
}

