<?php

use App\Models\Post;
use App\Models\User;

test('store creates a comment and returns 201', function (): void {
    $user = User::factory()->create(['name' => 'Ada Lovelace']);
    $post = $user->posts()->create(['content' => 'It is very hot today.']);

    $this->actingAs($user, 'sanctum')
        ->postJson('/api/posts/'.$post->id.'/comments', [
            'content' => 'Stay hydrated!',
        ])
        ->assertStatus(201)
        ->assertJson([
            'content' => 'Stay hydrated!',
            'user' => [
                'id' => $user->id,
                'name' => 'Ada Lovelace',
            ],
        ]);

    $this->assertDatabaseHas('comments', [
        'post_id' => $post->id,
        'user_id' => $user->id,
        'content' => 'Stay hydrated!',
    ]);
});

test('store returns 401 when unauthenticated', function (): void {
    $user = User::factory()->create();
    $post = $user->posts()->create(['content' => 'Hello']);

    $this->postJson('/api/posts/'.$post->id.'/comments', ['content' => 'Hi'])
        ->assertStatus(401)
        ->assertJson(['message' => 'Unauthorized.']);
});

test('store returns 400 when content is missing', function (): void {
    $user = User::factory()->create();
    $post = $user->posts()->create(['content' => 'Hello']);

    $this->actingAs($user, 'sanctum')
        ->postJson('/api/posts/'.$post->id.'/comments', [])
        ->assertStatus(400)
        ->assertJsonStructure(['message']);
});

test('store returns 404 for a missing post', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user, 'sanctum')
        ->postJson('/api/posts/9999/comments', ['content' => 'Hi'])
        ->assertStatus(404)
        ->assertJson(['message' => 'Post not found.']);
});

test('index returns comments newest first with an embedded user', function (): void {
    $user = User::factory()->create(['name' => 'Ada Lovelace', 'avatar' => 'data:image/png;base64,abc']);
    $post = $user->posts()->create(['content' => 'A post']);

    $older = $post->comments()->create(['user_id' => $user->id, 'content' => 'Older comment']);
    $older->forceFill(['created_at' => now()->subMinutes(30)])->save();

    $post->comments()->create(['user_id' => $user->id, 'content' => 'Newer comment']);

    $this->getJson('/api/posts/'.$post->id.'/comments')
        ->assertOk()
        ->assertJsonCount(2)
        ->assertJsonPath('0.content', 'Newer comment')
        ->assertJsonPath('1.content', 'Older comment')
        ->assertJsonPath('0.user.name', 'Ada Lovelace')
        ->assertJsonPath('0.user.avatar', 'data:image/png;base64,abc');
});

test('index returns an empty array for a post with no comments', function (): void {
    $user = User::factory()->create();
    $post = $user->posts()->create(['content' => 'A post']);

    $this->getJson('/api/posts/'.$post->id.'/comments')
        ->assertOk()
        ->assertJson([]);
});

test('index returns 404 for a missing post', function (): void {
    $this->getJson('/api/posts/9999/comments')
        ->assertStatus(404)
        ->assertJson(['message' => 'Post not found.']);
});

test('destroy deletes an owned comment and returns 200', function (): void {
    $user = User::factory()->create();
    $post = $user->posts()->create(['content' => 'A post']);
    $comment = $post->comments()->create(['user_id' => $user->id, 'content' => 'Delete me']);

    $this->actingAs($user, 'sanctum')
        ->deleteJson('/api/comments/'.$comment->id)
        ->assertOk()
        ->assertJson(['message' => 'Comment deleted.']);

    $this->assertDatabaseMissing('comments', ['id' => $comment->id]);
});

test('destroy returns 401 when the caller is not the owner', function (): void {
    $owner = User::factory()->create();
    $other = User::factory()->create();
    $post = $owner->posts()->create(['content' => 'A post']);
    $comment = $post->comments()->create(['user_id' => $owner->id, 'content' => 'Someone else\'s comment']);

    $this->actingAs($other, 'sanctum')
        ->deleteJson('/api/comments/'.$comment->id)
        ->assertStatus(401)
        ->assertJson(['message' => 'Unauthorized.']);

    $this->assertDatabaseHas('comments', ['id' => $comment->id]);
});

test('destroy returns 401 when unauthenticated', function (): void {
    $user = User::factory()->create();
    $post = $user->posts()->create(['content' => 'A post']);
    $comment = $post->comments()->create(['user_id' => $user->id, 'content' => 'Hello']);

    $this->deleteJson('/api/comments/'.$comment->id)
        ->assertStatus(401)
        ->assertJson(['message' => 'Unauthorized.']);
});

test('destroy returns 404 for a missing comment', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user, 'sanctum')
        ->deleteJson('/api/comments/9999')
        ->assertStatus(404)
        ->assertJson(['message' => 'Comment not found.']);
});