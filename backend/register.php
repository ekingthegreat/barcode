<?php

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Accept, Authorization");
header("Content-Type: application/json; charset=UTF-8");

// Handle preflight OPTIONS request
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
$password = $data["password"] ?? "";
$storeName = trim($data["store_name"] ?? "My Store");
$storeAddress = trim($data["store_address"] ?? "123 Main Street, City");
$phone = trim($data["phone"] ?? "+63 912 345 6789");
$role = trim($data["role"] ?? "Admin");

// Validation
if ($username === "" || $email === "" || $password === "") {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Username, email, and password are required"
    ]);
    exit;
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Invalid email format"
    ]);
    exit;
}

if (strlen($password) < 6) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Password must be at least 6 characters"
    ]);
    exit;
}

try {
    // Check if username or email already exists
    $checkStmt = $pdo->prepare("SELECT id, username, email FROM users WHERE username = :username OR email = :email LIMIT 1");
    $checkStmt->execute([
        ":username" => $username,
        ":email" => $email
    ]);
    $existing = $checkStmt->fetch();

    if ($existing) {
        if (strcasecmp($existing['username'], $username) === 0) {
            http_response_code(409);
            echo json_encode([
                "success" => false,
                "message" => "Username is already taken"
            ]);
            exit;
        }
        if (strcasecmp($existing['email'], $email) === 0) {
            http_response_code(409);
            echo json_encode([
                "success" => false,
                "message" => "Email is already registered"
            ]);
            exit;
        }
    }

    // Hash password
    $hashedPassword = password_hash($password, PASSWORD_BCRYPT);

    // Insert user
    $sql = "INSERT INTO users (username, email, password, store_name, store_address, phone, role) 
            VALUES (:username, :email, :password, :store_name, :store_address, :phone, :role)";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ":username" => $username,
        ":email" => $email,
        ":password" => $hashedPassword,
        ":store_name" => $storeName,
        ":store_address" => $storeAddress,
        ":phone" => $phone,
        ":role" => $role
    ]);

    $userId = $pdo->lastInsertId();

    http_response_code(201);
    echo json_encode([
        "success" => true,
        "message" => "Account registered successfully",
        "user_id" => $userId,
        "user" => [
            "id" => $userId,
            "username" => $username,
            "email" => $email,
            "store_name" => $storeName,
            "store_address" => $storeAddress,
            "phone" => $phone,
            "role" => $role
        ]
    ]);

} catch (PDOException $e) {
    if ($e->getCode() == 23000) {
        http_response_code(409);
        echo json_encode([
            "success" => false,
            "message" => "Username or email already exists"
        ]);
    } else {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Database error: " . $e->getMessage()
        ]);
    }
}
