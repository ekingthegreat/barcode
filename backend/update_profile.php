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
        "message" => "Method not allowed. Only POST is accepted."
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

$username = trim($data["username"] ?? "");
$email = trim($data["email"] ?? "");
$storeName = trim($data["store_name"] ?? "My Store");
$storeAddress = trim($data["store_address"] ?? "123 Main Street, City");
$phone = trim($data["phone"] ?? "+63 912 345 6789");
$originalEmail = trim($data["original_email"] ?? $email);
$originalUsername = trim($data["original_username"] ?? $username);
$userId = !empty($data["id"]) ? (int)$data["id"] : null;

if ($username === "" || $email === "") {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Username and email cannot be empty"
    ]);
    exit;
}

try {
    // Check if target username or email conflicts with ANOTHER user
    $conflictStmt = $pdo->prepare("
        SELECT id FROM users 
        WHERE (username = :username OR email = :email) 
        AND NOT (email = :original_email OR username = :original_username)
        LIMIT 1
    ");
    $conflictStmt->execute([
        ":username" => $username,
        ":email" => $email,
        ":original_email" => $originalEmail,
        ":original_username" => $originalUsername
    ]);
    if ($conflictStmt->fetch()) {
        http_response_code(409);
        echo json_encode([
            "success" => false,
            "message" => "Username or email is already in use by another account"
        ]);
        exit;
    }

    // Update the user
    if ($userId !== null && $userId > 0) {
        $updateSql = "UPDATE users SET username = :username, email = :email, store_name = :store_name, store_address = :store_address, phone = :phone WHERE id = :id";
        $updateStmt = $pdo->prepare($updateSql);
        $updateStmt->execute([
            ":username" => $username,
            ":email" => $email,
            ":store_name" => $storeName,
            ":store_address" => $storeAddress,
            ":phone" => $phone,
            ":id" => $userId
        ]);
    } else {
        $updateSql = "UPDATE users SET username = :username, email = :email, store_name = :store_name, store_address = :store_address, phone = :phone WHERE email = :original_email OR username = :original_username LIMIT 1";
        $updateStmt = $pdo->prepare($updateSql);
        $updateStmt->execute([
            ":username" => $username,
            ":email" => $email,
            ":store_name" => $storeName,
            ":store_address" => $storeAddress,
            ":phone" => $phone,
            ":original_email" => $originalEmail,
            ":original_username" => $originalUsername
        ]);
    }

    echo json_encode([
        "success" => true,
        "message" => "Profile updated successfully in database",
        "user" => [
            "username" => $username,
            "email" => $email,
            "store_name" => $storeName,
            "store_address" => $storeAddress,
            "phone" => $phone
        ]
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Database error: " . $e->getMessage()
    ]);
}

