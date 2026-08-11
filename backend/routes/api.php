<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\GoogleOAuthController;
use App\Http\Controllers\HeatLocationController;
use App\Http\Controllers\WeatherController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| is assigned the "api" middleware group. Enjoy building your API!
|
*/

Route::middleware('throttle:api')->group(function (): void {
    Route::post('/weather', [WeatherController::class, 'currentConditions']);
    Route::post('/forecast', [WeatherController::class, 'forecast']);
    Route::post('/geocode', [WeatherController::class, 'geocode']);

    Route::post('/analyze-heat-location', [HeatLocationController::class, 'analyze']);
    Route::post('/heat-locations', [HeatLocationController::class, 'index']);

    Route::get('/auth/google/redirect', [GoogleOAuthController::class, 'redirect']);
    Route::get('/auth/google/callback', [GoogleOAuthController::class, 'callback']);

    Route::middleware('auth:sanctum')->group(function (): void {
        Route::get('/profile', [AuthController::class, 'profile']);
        Route::post('/logout', [AuthController::class, 'logout']);
    });
});