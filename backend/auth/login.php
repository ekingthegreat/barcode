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

$usernameOrEmail = trim($data["username_or_email"] ?? $data["username"] ?? $data["email"] ?? "");
$password = $data["password"] ?? "";

if ($usernameOrEmail === "" || $password === "") {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Username/email and password are required"
    ]);
    exit;
}

try {
    $sql = "SELECT id, username, email, password, store_name, store_address, phone, role 
            FROM users 
            WHERE username = :term OR email = :term 
            LIMIT 1";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([":term" => $usernameOrEmail]);
    $user = $stmt->fetch();

    if (!$user) {
        http_response_code(401);
        echo json_encode([
            "success" => false,
            "message" => "Invalid username/email or password"
        ]);
        exit;
    }

    // Verify password (supports hashed passwords with fallback for legacy plain text)
    $passwordValid = false;
    if (password_verify($password, $user["password"])) {
        $passwordValid = true;
    } elseif ($password === $user["password"]) {
        // Upgrade legacy plain-text password to hash
        $passwordValid = true;
        $newHash = password_hash($password, PASSWORD_BCRYPT);
        $updateStmt = $pdo->prepare("UPDATE users SET password = :password WHERE id = :id");
        $updateStmt->execute([":password" => $newHash, ":id" => $user["id"]]);
    }

    if (!$passwordValid) {
        http_response_code(401);
        echo json_encode([
            "success" => false,
            "message" => "Invalid username/email or password"
        ]);
        exit;
    }

    // Remove password from returned data
    unset($user["password"]);

    echo json_encode([
        "success" => true,
        "message" => "Login successful",
        "user" => $user
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Database error: " . $e->getMessage()
    ]);
}
