<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreCommentRequest;
use App\Models\Comment;
use App\Models\Post;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CommentController extends Controller
{
    /**
     * Create a new comment on a post for the authenticated user.
     *
     * Requires a valid Sanctum Bearer token; otherwise the auth middleware
     * responds with 401 and {"message": "Unauthorized."}.
     *
     * Returns 404 if the post does not exist.
     */
    public function store(StoreCommentRequest $request, int $postId): JsonResponse
    {
        if (Post::find($postId) === null) {
            return response()->json(['message' => 'Post not found.'], 404);
        }

        $comment = $request->user()->comments()->create([
            'post_id' => $postId,
            'content' => $request->content,
        ]);

        return response()->json($comment->load('user:id,name,avatar'), 201);
    }

    /**
     * Return all comments on a post, newest first, each with its embedded
     * author.
     *
     * Returns 404 if the post does not exist.
     */
    public function index(int $postId): JsonResponse
    {
        if (Post::find($postId) === null) {
            return response()->json(['message' => 'Post not found.'], 404);
        }

        return response()->json(
            Comment::with('user:id,name,avatar')
                ->where('post_id', $postId)
                ->latest()
                ->get(),
        );
    }

    /**
     * Delete a comment owned by the authenticated user.
     *
     * Returns 404 if the comment does not exist, 401 if the caller is not the
     * owner, and 200 on success.
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $comment = Comment::find($id);

        if ($comment === null) {
            return response()->json(['message' => 'Comment not found.'], 404);
        }

        if ($comment->user_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized.'], 401);
        }

        $comment->delete();

        return response()->json(['message' => 'Comment deleted.']);
    }
}