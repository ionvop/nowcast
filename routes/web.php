<?php

use Illuminate\Support\Facades\Route;

Route::inertia('/', 'home')->name('home');
Route::inertia('/heat', 'heat')->name('heat');
Route::inertia('/map', 'map')->name('map');
Route::inertia('/community', 'community')->name('community');
Route::inertia('/profile', 'profile')->name('profile');
