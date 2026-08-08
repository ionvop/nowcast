<?php

use App\Http\Controllers\Api\WeatherController;
use Illuminate\Support\Facades\Route;

Route::post('/weather', [WeatherController::class, 'weather']);
Route::post('/geocode', [WeatherController::class, 'geocode']);
Route::post('/forecast', [WeatherController::class, 'forecast']);
