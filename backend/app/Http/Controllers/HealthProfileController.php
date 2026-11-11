<?php

namespace App\Http\Controllers;

use App\Http\Requests\HealthProfileRequest;
use App\Models\HealthProfile;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Read, replace, and delete the authenticated user's health profile.
 *
 * Every action is scoped to `$request->user()`, so a user can only ever see or
 * modify their own profile. The profile is what the AI health-risk endpoint
 * reads server-side, which is why it is stored here rather than being sent up
 * from the client on every assessment.
 */
class HealthProfileController extends Controller
{
    /**
     * Return the authenticated user's profile, or `null` when they have not
     * entered one yet.
     */
    public function show(Request $request): JsonResponse
    {
        $profile = $request->user()->healthProfile;

        return response()->json([
            'profile' => $profile === null ? null : $this->present($profile),
        ]);
    }

    /**
     * Create or replace the authenticated user's profile.
     *
     * The profile is a single row per user, so this is an upsert rather than a
     * create: submitting the form again overwrites the previous values.
     */
    public function update(HealthProfileRequest $request): JsonResponse
    {
        // Go through the relationship so `user_id` is set by the association
        // rather than mass-assigned from the request.
        $profile = $request->user()->healthProfile()->updateOrCreate(
            [],
            [
                'age' => $request->age,
                'biological_sex' => $request->biologicalSex,
                'height_cm' => $request->heightCm,
                'weight_kg' => $request->weightKg,
                'activity_level' => $request->activityLevel,
                'conditions' => $request->conditions ?? [],
                'medications' => $request->medications ?? [],
                'lifestyle' => $request->lifestyle ?? [],
            ],
        );

        return response()->json(['profile' => $this->present($profile)]);
    }

    /**
     * Delete the authenticated user's profile.
     *
     * Deleting is idempotent: a user with no profile still receives a success
     * response so the client can clear its local copy unconditionally.
     */
    public function destroy(Request $request): JsonResponse
    {
        $request->user()->healthProfile()->delete();

        return response()->json(['message' => 'Health profile deleted.']);
    }

    /**
     * Shape a profile for the API response.
     *
     * The columns are snake_case in the database but camelCase on the wire, to
     * match every other endpoint the Flutter client consumes.
     *
     * @return array<string, mixed>
     */
    protected function present(HealthProfile $profile): array
    {
        return [
            'age' => $profile->age,
            'biologicalSex' => $profile->biological_sex,
            'heightCm' => $profile->height_cm,
            'weightKg' => $profile->weight_kg,
            'activityLevel' => $profile->activity_level,
            'conditions' => $profile->conditions ?? [],
            'medications' => $profile->medications ?? [],
            'lifestyle' => $profile->lifestyle ?? [],
            'updatedAt' => $profile->updated_at,
        ];
    }
}
