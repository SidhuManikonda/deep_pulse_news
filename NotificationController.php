<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\FcmService;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class NotificationController extends Controller
{
    public function __construct(protected FcmService $fcm)
    {
    }

    /**
     * Save/update the FCM token for the authenticated user.
     *
     * POST /api/fcm-token
     * Body: { "fcm_token": "device_token_here" }
     */
    public function saveFcmToken(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'fcm_token' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $request->user()->update(['fcm_token' => $request->fcm_token]);

        return response()->json([
            'message' => 'FCM token saved successfully',
        ]);
    }

    /**
     * Send a test notification to the authenticated user's device.
     *
     * POST /api/send-test-notification
     */
    public function sendTestNotification(Request $request)
    {
        $user = $request->user();

        if (!$user->fcm_token) {
            return response()->json([
                'message' => 'No FCM token registered for this user. Please update your FCM token first.',
            ], 400);
        }

        $result = $this->fcm->sendToDevice(
            $user->fcm_token,
            'Test Notification',
            'Firebase push notifications are working correctly!',
            ['type' => 'test', 'user_id' => (string) $user->id]
        );

        return response()->json($result, $result['success'] ? 200 : 500);
    }

    /**
     * [Admin] Send a custom notification to one or all users.
     *
     * POST /api/send-notification
     * Body: {
     *   "title": "...",
     *   "body": "...",
     *   "user_ids": [1, 2, 3],   // optional – omit to notify ALL users with tokens
     *   "data": { "key": "val" } // optional extra payload
     * }
     */
    public function sendNotification(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:200',
            'body' => 'required|string|max:1000',
            'user_ids' => 'nullable|array',
            'user_ids.*' => 'integer|exists:users,id',
            'data' => 'nullable|array',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $query = User::whereNotNull('fcm_token');

        if ($request->filled('user_ids')) {
            $query->whereIn('id', $request->user_ids);
        }

        $tokens = $query->pluck('fcm_token')->toArray();

        if (empty($tokens)) {
            return response()->json([
                'message' => 'No users with FCM tokens found.',
            ], 404);
        }

        $result = $this->fcm->sendToMultiple(
            $tokens,
            $request->title,
            $request->body,
            $request->data ?? []
        );

        return response()->json([
            'message' => 'Notifications dispatched',
            'summary' => $result,
        ]);
    }

    /**
     * Get paginated notifications for the authenticated user.
     *
     * GET /api/notifications
     */
    public function index(Request $request)
    {
        $notifications = $request->user()->notifications()->paginate(20);
        return response()->json($notifications);
    }

    /**
     * Get unread notifications count.
     *
     * GET /api/notifications/unread-count
     */
    public function unreadCount(Request $request)
    {
        $count = $request->user()->unreadNotifications()->count();
        return response()->json(['unread_count' => $count]);
    }

    /**
     * Mark a specific notification as read.
     *
     * POST /api/notifications/{id}/mark-as-read
     */
    public function markAsRead(Request $request, $id)
    {
        $notification = $request->user()->notifications()->where('id', $id)->first();
        if ($notification) {
            $notification->markAsRead();
            return response()->json(['message' => 'Notification marked as read']);
        }
        return response()->json(['message' => 'Notification not found'], 404);
    }

    /**
     * Mark all unread notifications as read.
     *
     * POST /api/notifications/mark-all-as-read
     */
    public function markAllAsRead(Request $request)
    {
        $request->user()->unreadNotifications->markAsRead();
        return response()->json(['message' => 'All notifications marked as read']);
    }
}
