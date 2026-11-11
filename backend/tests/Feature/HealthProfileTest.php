<?php

use App\Models\HealthProfile;
use App\Models\User;

test('show returns null when the user has no profile', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user, 'sanctum')
        ->getJson('/api/profile/health')
        ->assertOk()
        ->assertJson(['profile' => null]);
});

test('update creates a profile and returns it', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user, 'sanctum')
        ->putJson('/api/profile/health', [
            'age' => 68,
            'biologicalSex' => 'female',
            'heightCm' => 162.5,
            'weightKg' => 61.0,
            'activityLevel' => 'light',
            'conditions' => ['cardiovascular', 'diabetes'],
            'medications' => ['beta_blockers'],
            'lifestyle' => ['acclimatized'],
        ])
        ->assertOk()
        ->assertJson([
            'profile' => [
                'age' => 68,
                'biologicalSex' => 'female',
                'heightCm' => 162.5,
                'weightKg' => 61.0,
                'activityLevel' => 'light',
                'conditions' => ['cardiovascular', 'diabetes'],
                'medications' => ['beta_blockers'],
                'lifestyle' => ['acclimatized'],
            ],
        ]);

    $this->assertDatabaseHas('health_profiles', [
        'user_id' => $user->id,
        'age' => 68,
        'biological_sex' => 'female',
    ]);
});

test('update accepts only the required fields', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user, 'sanctum')
        ->putJson('/api/profile/health', [
            'age' => 30,
            'biologicalSex' => 'male',
        ])
        ->assertOk()
        ->assertJson([
            'profile' => [
                'age' => 30,
                'biologicalSex' => 'male',
                'heightCm' => null,
                'weightKg' => null,
                'activityLevel' => null,
                'conditions' => [],
                'medications' => [],
                'lifestyle' => [],
            ],
        ]);
});

test('update replaces an existing profile instead of creating a second row', function (): void {
    $user = User::factory()->create();

    $user->healthProfile()->create([
        'age' => 40,
        'biological_sex' => 'male',
    ]);

    $this->actingAs($user, 'sanctum')
        ->putJson('/api/profile/health', [
            'age' => 41,
            'biologicalSex' => 'male',
        ])
        ->assertOk()
        ->assertJsonPath('profile.age', 41);

    expect(HealthProfile::query()->where('user_id', $user->id)->count())->toBe(1);
});

test('show returns the stored profile', function (): void {
    $user = User::factory()->create();

    $user->healthProfile()->create([
        'age' => 55,
        'biological_sex' => 'other',
        'conditions' => ['respiratory'],
    ]);

    $this->actingAs($user, 'sanctum')
        ->getJson('/api/profile/health')
        ->assertOk()
        ->assertJsonPath('profile.age', 55)
        ->assertJsonPath('profile.biologicalSex', 'other')
        ->assertJsonPath('profile.conditions', ['respiratory']);
});

test('destroy deletes the profile and is idempotent', function (): void {
    $user = User::factory()->create();

    $user->healthProfile()->create([
        'age' => 55,
        'biological_sex' => 'male',
    ]);

    $this->actingAs($user, 'sanctum')
        ->deleteJson('/api/profile/health')
        ->assertOk()
        ->assertJson(['message' => 'Health profile deleted.']);

    $this->assertDatabaseMissing('health_profiles', ['user_id' => $user->id]);

    // Deleting again still succeeds so the client can clear unconditionally.
    $this->actingAs($user, 'sanctum')
        ->deleteJson('/api/profile/health')
        ->assertOk();
});

test('a user cannot see another users profile', function (): void {
    $owner = User::factory()->create();
    $other = User::factory()->create();

    $owner->healthProfile()->create([
        'age' => 70,
        'biological_sex' => 'female',
    ]);

    $this->actingAs($other, 'sanctum')
        ->getJson('/api/profile/health')
        ->assertOk()
        ->assertJson(['profile' => null]);
});

test('profile endpoints return 401 when unauthenticated', function (): void {
    $this->getJson('/api/profile/health')->assertStatus(401);
    $this->putJson('/api/profile/health', ['age' => 30, 'biologicalSex' => 'male'])
        ->assertStatus(401);
    $this->deleteJson('/api/profile/health')->assertStatus(401);
});

test('update returns 400 when age is missing', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user, 'sanctum')
        ->putJson('/api/profile/health', ['biologicalSex' => 'male'])
        ->assertStatus(400)
        ->assertJsonStructure(['message']);
});

test('update returns 400 when age is out of range', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user, 'sanctum')
        ->putJson('/api/profile/health', ['age' => 0, 'biologicalSex' => 'male'])
        ->assertStatus(400);

    $this->actingAs($user, 'sanctum')
        ->putJson('/api/profile/health', ['age' => 121, 'biologicalSex' => 'male'])
        ->assertStatus(400);
});

test('update returns 400 when biologicalSex is not an allowed value', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user, 'sanctum')
        ->putJson('/api/profile/health', ['age' => 30, 'biologicalSex' => 'unknown'])
        ->assertStatus(400);
});

test('update returns 400 when a condition is not an allowed value', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user, 'sanctum')
        ->putJson('/api/profile/health', [
            'age' => 30,
            'biologicalSex' => 'male',
            'conditions' => ['made_up_condition'],
        ])
        ->assertStatus(400);
});

test('update returns 400 when height or weight is implausible', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user, 'sanctum')
        ->putJson('/api/profile/health', [
            'age' => 30,
            'biologicalSex' => 'male',
            'heightCm' => 10,
        ])
        ->assertStatus(400);

    $this->actingAs($user, 'sanctum')
        ->putJson('/api/profile/health', [
            'age' => 30,
            'biologicalSex' => 'male',
            'weightKg' => 500,
        ])
        ->assertStatus(400);
});
