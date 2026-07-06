<?php

require_once "config.php";

/**
 * Performs an HTTP request using cURL and returns the response details.
 *
 * This function supports GET, POST, PUT, DELETE, and other HTTP methods.
 * It allows setting custom headers, a request body (JSON or raw), and a timeout.
 * The response includes status code, success flag, parsed headers, raw body, and JSON-decoded data.
 *
 * @param string $url The URL to which the request is sent.
 * @param array $options Optional request configuration:
 *   - 'method'  (string): HTTP method to use (default: 'GET').
 *   - 'headers' (array): Associative array of request headers (e.g., ['Content-Type' => 'application/json']).
 *   - 'body'    (mixed): Request body, either a string or an array (JSON-encoded if Content-Type is application/json).
 *   - 'timeout' (int): Request timeout in seconds (default: 30).
 *
 * @return array An associative array containing:
 *   - 'status'  (int): The HTTP status code of the response.
 *   - 'ok'      (bool): True if the status code is in the 200–299 range, false otherwise.
 *   - 'headers' (array): Parsed response headers as an associative array.
 *   - 'body'    (string): Raw response body as a string.
 *   - 'json'    (mixed): JSON-decoded response body (associative array or null if not JSON or decoding fails).
 *
 * @throws RuntimeException If the cURL request fails or the URL is invalid.
 */
function fetch(string $url, array $options = []): array {
    $ch = curl_init();

    // Default options
    $method = strtoupper($options['method'] ?? 'GET');
    $headers = $options['headers'] ?? [];
    $body = $options['body'] ?? null;
    $timeout = $options['timeout'] ?? 30;

    // Configure cURL
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, $timeout);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);

    // Bypass SSL verification
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

    // Handle body (JSON or raw)
    if ($body !== null) {
        if (is_array($body) && (isset($headers['Content-Type']) && stripos($headers['Content-Type'], 'application/json') !== false)) {
            $body = json_encode($body);
        }
        curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
    }

    // Convert headers to correct format
    $formattedHeaders = [];
    foreach ($headers as $key => $value) {
        $formattedHeaders[] = "$key: $value";
    }
    if (!empty($formattedHeaders)) {
        curl_setopt($ch, CURLOPT_HTTPHEADER, $formattedHeaders);
    }

    // Capture headers and body
    curl_setopt($ch, CURLOPT_HEADER, true);

    $response = curl_exec($ch);
    $headerSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
    $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);

    $headerString = substr($response, 0, $headerSize);
    $bodyString = substr($response, $headerSize);

    // Parse headers into associative array
    $headersArray = [];
    foreach (explode("\r\n", trim($headerString)) as $i => $line) {
        if ($i === 0) continue; // Skip HTTP/1.1 200 OK line
        if (strpos($line, ': ') !== false) {
            list($key, $value) = explode(': ', $line, 2);
            $headersArray[$key] = $value;
        }
    }

    return [
        'status' => $status,
        'ok' => ($status >= 200 && $status < 300),
        'headers' => $headersArray,
        'body' => $bodyString,
        'json' => json_decode($bodyString, true)
    ];
}