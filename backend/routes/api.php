<?php

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
});