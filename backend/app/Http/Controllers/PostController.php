<?php

namespace App\Http\Controllers;

use App\Http\Requests\StorePostRequest;
use App\Models\Post;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class PostController extends Controller
{
    /**
     * The number of hours a post remains visible before it expires.
     */
    protected const POST_TTL_HOURS = 24;

    /**
     * Create a new post for the authenticated user.
     *
     * Requires a valid Sanctum Bearer token; otherwise the auth middleware
     * responds with 401 and {"message": "Unauthorized."}.
     */
    public function store(StorePostRequest $request): JsonResponse
    {
        $post = $request->user()->posts()->create([
            'content' => $request->content,
            'address' => $request->address,
            'latitude' => $request->latitude,
            'longitude' => $request->longitude,
        ]);

        return response()->json($post->load('user:id,name,avatar'), 201);
    }

    /**
     * Return all current posts, newest first, each with its embedded author.
     *
     * Posts older than 24 hours are purged first.
     */
    public function index(): JsonResponse
    {
        $this->purgeExpired();

        return response()->json(
            Post::with('user:id,name,avatar')->latest()->get(),
        );
    }

    /**
     * Return a single post with its embedded author.
     */
    public function show(int $id): JsonResponse
    {
        $post = Post::with('user:id,name,avatar')->find($id);

        if ($post === null) {
            return response()->json(['message' => 'Post not found.'], 404);
        }

        return response()->json($post);
    }

    /**
     * Return all current posts by a given user, newest first, each with its
     * embedded author.
     *
     * Returns 404 if the user does not exist.
     */
    public function userPosts(int $id): JsonResponse
    {
        if (User::find($id) === null) {
            return response()->json(['message' => 'User not found.'], 404);
        }

        $this->purgeExpired();

        return response()->json(
            Post::with('user:id,name,avatar')
                ->where('user_id', $id)
                ->latest()
                ->get(),
        );
    }

    /**
     * Delete a post owned by the authenticated user.
     *
     * Returns 404 if the post does not exist, 401 if the caller is not the
     * owner, and 200 on success.
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $post = Post::find($id);

        if ($post === null) {
            return response()->json(['message' => 'Post not found.'], 404);
        }

        if ($post->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized.'], 401);
        }

        $post->delete();

        return response()->json(['message' => 'Post deleted.']);
    }

    /**
     * Delete posts older than 24 hours.
     */
    protected function purgeExpired(): void
    {
        Post::query()
            ->where('created_at', '<', Carbon::now()->subHours(self::POST_TTL_HOURS))
            ->delete();
    }
}
