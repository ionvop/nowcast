<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    /**
     * Return the currently authenticated user's profile.
     *
     * Requires a valid Sanctum Bearer token; otherwise the auth middleware
     * responds with 401 and {"message": "Unauthorized."}.
     */
    public function profile(Request $request): JsonResponse
    {
        return response()->json($request->user());
    }

    /**
     * Revoke the current Sanctum token and sign the user out.
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out.']);
    }
}
