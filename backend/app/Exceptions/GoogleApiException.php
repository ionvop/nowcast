<?php

namespace App\Exceptions;

use RuntimeException;

class GoogleApiException extends RuntimeException
{
    /**
     * Create a new Google API exception instance.
     *
     * @param  string  $message  A user-facing, non-secret message.
     * @param  int  $statusCode  The HTTP status code returned upstream (default 502).
     */
    public function __construct(string $message, public readonly int $statusCode = 502)
    {
        parent::__construct($message);
    }
}