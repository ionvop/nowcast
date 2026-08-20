<?php

use App\Models\Post;
use App\Models\User;

test('store creates a post and returns 201', function (): void {
    $user = User::factory()->create(['name' => 'Ada Lovelace']);

    $this->actingAs($user, 'sanctum')
        ->postJson('/api/posts', [
            'content' => 'It is very hot today.',
            'address' => '1 Market St, San Francisco, CA',
            'latitude' => 37.7749,
            'longitude' => -122.4194,
        ])
        ->assertStatus(201)
        ->assertJson([
            'content' => 'It is very hot today.',
            'address' => '1 Market St, San Francisco, CA',
            'user' => [
                'id' => $user->id,
                'name' => 'Ada Lovelace',
            ],
        ]);

    $this->assertDatabaseHas('posts', [
        'user_id' => $user->id,
        'content' => 'It is very hot today.',
    ]);
});

test('store returns 401 when unauthenticated', function (): void {
    $this->postJson('/api/posts', ['content' => 'Hello'])
        ->assertStatus(401)
        ->assertJson(['message' => 'Unauthorized.']);
});

test('store returns 400 when content is missing', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user, 'sanctum')
        ->postJson('/api/posts', [])
        ->assertStatus(400)
        ->assertJsonStructure(['message']);
});

test('index returns posts newest first with an embedded user', function (): void {
    $user = User::factory()->create(['name' => 'Ada Lovelace', 'avatar' => 'data:image/png;base64,abc']);

    $older = $user->posts()->create(['content' => 'Older post']);
    $older->forceFill(['created_at' => now()->subMinutes(30)])->save();

    $newer = $user->posts()->create(['content' => 'Newer post']);

    $this->getJson('/api/posts')
        ->assertOk()
        ->assertJsonCount(2)
        ->assertJsonPath('0.content', 'Newer post')
        ->assertJsonPath('1.content', 'Older post')
        ->assertJsonPath('0.user.name', 'Ada Lovelace')
        ->assertJsonPath('0.user.avatar', 'data:image/png;base64,abc');
});

test('index purges posts older than 24 hours', function (): void {
    $user = User::factory()->create();

    $expired = $user->posts()->create(['content' => 'Expired post']);
    $expired->forceFill(['created_at' => now()->subHours(25)])->save();

    $user->posts()->create(['content' => 'Fresh post']);

    $this->getJson('/api/posts')
        ->assertOk()
        ->assertJsonCount(1)
        ->assertJsonFragment(['content' => 'Fresh post']);
});

test('show returns a single post with its embedded user', function (): void {
    $user = User::factory()->create(['name' => 'Ada Lovelace']);
    $post = $user->posts()->create(['content' => 'A single post']);

    $this->getJson('/api/posts/'.$post->id)
        ->assertOk()
        ->assertJson([
            'id' => $post->id,
            'content' => 'A single post',
            'user' => ['id' => $user->id, 'name' => 'Ada Lovelace'],
        ]);
});

test('show returns 404 for a missing post', function (): void {
    $this->getJson('/api/posts/9999')
        ->assertStatus(404)
        ->assertJson(['message' => 'Post not found.']);
});

test('userPosts returns a user\'s posts newest first with an embedded user', function (): void {
    $user = User::factory()->create(['name' => 'Ada Lovelace', 'avatar' => 'data:image/png;base64,abc']);
    $other = User::factory()->create(['name' => 'Grace Hopper']);

    $older = $user->posts()->create(['content' => 'Older post']);
    $older->forceFill(['created_at' => now()->subMinutes(30)])->save();

    $newer = $user->posts()->create(['content' => 'Newer post']);
    $other->posts()->create(['content' => 'Someone else\'s post']);

    $this->getJson('/api/users/'.$user->id.'/posts')
        ->assertOk()
        ->assertJsonCount(2)
        ->assertJsonPath('0.content', 'Newer post')
        ->assertJsonPath('1.content', 'Older post')
        ->assertJsonPath('0.user.name', 'Ada Lovelace')
        ->assertJsonPath('0.user.avatar', 'data:image/png;base64,abc');
});

test('userPosts returns an empty array for a user with no posts', function (): void {
    $user = User::factory()->create();

    $this->getJson('/api/users/'.$user->id.'/posts')
        ->assertOk()
        ->assertJson([]);
});

test('userPosts returns 404 for a missing user', function (): void {
    $this->getJson('/api/users/9999/posts')
        ->assertStatus(404)
        ->assertJson(['message' => 'User not found.']);
});

test('destroy deletes an owned post and returns 200', function (): void {
    $user = User::factory()->create();
    $post = $user->posts()->create(['content' => 'Delete me']);

    $this->actingAs($user, 'sanctum')
        ->deleteJson('/api/posts/'.$post->id)
        ->assertOk()
        ->assertJson(['message' => 'Post deleted.']);

    $this->assertDatabaseMissing('posts', ['id' => $post->id]);
});

test('destroy returns 401 when the caller is not the owner', function (): void {
    $owner = User::factory()->create();
    $other = User::factory()->create();
    $post = $owner->posts()->create(['content' => 'Someone else\'s post']);

    $this->actingAs($other, 'sanctum')
        ->deleteJson('/api/posts/'.$post->id)
        ->assertStatus(401)
        ->assertJson(['message' => 'Unauthorized.']);

    $this->assertDatabaseHas('posts', ['id' => $post->id]);
});

test('destroy returns 401 when unauthenticated', function (): void {
    $user = User::factory()->create();
    $post = $user->posts()->create(['content' => 'Hello']);

    $this->deleteJson('/api/posts/'.$post->id)
        ->assertStatus(401)
        ->assertJson(['message' => 'Unauthorized.']);
});

test('destroy returns 404 for a missing post', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user, 'sanctum')
        ->deleteJson('/api/posts/9999')
        ->assertStatus(404)
        ->assertJson(['message' => 'Post not found.']);
});

test('unknown api route returns 404 with Action not found', function (): void {
    $this->getJson('/api/does-not-exist')
        ->assertStatus(404)
        ->assertJson(['message' => 'Action not found.']);
});
