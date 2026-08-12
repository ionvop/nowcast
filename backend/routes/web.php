<?php

use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Route;

// Route::get('/', function () {
//     return view('welcome');
// });

Route::any('/app/{any}', function () {
    return File::get(public_path('app/index.html'));
})->where('any', '.*');