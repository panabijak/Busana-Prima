/**
 * Busana Prima — Cloud Functions for Chat Notifications
 *
 * Triggers:
 * 1. onNewMessage — When a new message is created in a conversation
 * 2. onMissedCall — When a call log status changes to 'missed'
 *
 * These functions send FCM push notifications to the recipient.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ─── Send Notification on New Message ─────────────────────────────────────────

/**
 * Triggered when a new message is added to any conversation.
 * Sends a push notification to the OTHER participant (not the sender).
 *
 * Path: conversations/{conversationId}/messages/{messageId}
 */
export const onNewMessage = functions.firestore
  .document("conversations/{conversationId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const { conversationId } = context.params;
    const messageData = snap.data();

    // Skip system messages
    if (messageData.senderRole === "system") {
      return null;
    }

    const senderId: string = messageData.senderId;
    const messageType: string = messageData.type || "text";
    const content: string = messageData.content || "";

    // Get the conversation document to find participants
    const conversationDoc = await db
      .collection("conversations")
      .doc(conversationId)
      .get();

    if (!conversationDoc.exists) {
      console.log(`Conversation ${conversationId} not found`);
      return null;
    }

    const conversation = conversationDoc.data()!;
    const customerId: string = conversation.customerId;
    const tailorId: string = conversation.tailorId;
    const orderNumber: string = conversation.orderNumber || "";
    const orderId: string = conversation.orderId || "";

    // Determine the recipient (the OTHER participant)
    const recipientId = senderId === customerId ? tailorId : customerId;

    // Get recipient's FCM tokens
    const tokens = await getTokensForUser(recipientId);
    if (tokens.length === 0) {
      console.log(`No FCM tokens found for user ${recipientId}`);
      return null;
    }

    // Build notification content
    const senderName = senderId === customerId
      ? conversation.customerName || "Customer"
      : conversation.tailorName || "Busana Prima Tailor";

    let notificationBody: string;
    let notificationType: string;

    switch (messageType) {
    case "image":
      notificationBody = `${senderName} sent a photo`;
      notificationType = "new_attachment";
      break;
    case "video":
      notificationBody = `${senderName} sent a video`;
      notificationType = "new_attachment";
      break;
    case "file":
      notificationBody = `${senderName} shared a document`;
      notificationType = "new_attachment";
      break;
    default:
      // Text message — show preview (max 100 chars)
      notificationBody = content.length > 100
        ? `${senderName}: ${content.substring(0, 100)}...`
        : `${senderName}: ${content}`;
      notificationType = "new_message";
    }

    const notificationTitle = orderNumber
      ? `Order ${orderNumber}`
      : "New Message";

    // Send FCM notification
    const payload: admin.messaging.MulticastMessage = {
      tokens: tokens,
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: {
        type: notificationType,
        orderId: orderId,
        conversationId: conversationId,
        orderNumber: orderNumber,
        senderId: senderId,
        senderName: senderName,
        message: content.substring(0, 200),
      },
      android: {
        priority: "high",
        notification: {
          channelId: "busana_prima_chat",
          priority: "high",
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: notificationTitle,
              body: notificationBody,
            },
            badge: 1,
            sound: "default",
          },
        },
      },
    };

    try {
      const response = await messaging.sendEachForMulticast(payload);
      console.log(
        `Notification sent: ${response.successCount} success, ` +
        `${response.failureCount} failures`
      );

      // Remove invalid tokens
      await cleanupInvalidTokens(recipientId, tokens, response);
    } catch (error) {
      console.error("Error sending notification:", error);
    }

    return null;
  });

// ─── Send Notification on Missed Call ─────────────────────────────────────────

/**
 * Triggered when a call_log document is updated.
 * Sends a missed call notification if status changed to 'missed'.
 *
 * Path: call_logs/{callId}
 */
export const onCallStatusUpdate = functions.firestore
  .document("call_logs/{callId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only trigger when status changes to 'missed'
    if (before.status === after.status || after.status !== "missed") {
      return null;
    }

    const receiverId: string = after.receiverId;
    const callerName: string = after.callerName || "Unknown";
    const callType: string = after.callType || "voice";
    const orderId: string = after.orderId || "";

    // Get order number from conversation
    let orderNumber = "";
    if (after.conversationId) {
      const convoDoc = await db
        .collection("conversations")
        .doc(after.conversationId)
        .get();
      if (convoDoc.exists) {
        orderNumber = convoDoc.data()?.orderNumber || "";
      }
    }

    // Get recipient tokens
    const tokens = await getTokensForUser(receiverId);
    if (tokens.length === 0) {
      return null;
    }

    const title = "Missed Call";
    const body = orderNumber
      ? `Missed ${callType} call from ${callerName} — Order ${orderNumber}`
      : `Missed ${callType} call from ${callerName}`;

    const payload: admin.messaging.MulticastMessage = {
      tokens: tokens,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: "missed_call",
        orderId: orderId,
        conversationId: after.conversationId || "",
        orderNumber: orderNumber,
        callType: callType,
        callerName: callerName,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "busana_prima_chat",
          priority: "high",
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: { title, body },
            badge: 1,
            sound: "default",
          },
        },
      },
    };

    try {
      const response = await messaging.sendEachForMulticast(payload);
      console.log(
        `Missed call notification: ${response.successCount} success`
      );
      await cleanupInvalidTokens(receiverId, tokens, response);
    } catch (error) {
      console.error("Error sending missed call notification:", error);
    }

    return null;
  });

// ─── Helper Functions ─────────────────────────────────────────────────────────

/**
 * Get all FCM tokens for a specific user.
 * Tokens are stored in: users/{userId}/fcmTokens/{deviceId}
 */
async function getTokensForUser(userId: string): Promise<string[]> {
  const tokensSnap = await db
    .collection("users")
    .doc(userId)
    .collection("fcmTokens")
    .get();

  const tokens: string[] = [];
  tokensSnap.docs.forEach((doc) => {
    const token = doc.data().token;
    if (token) {
      tokens.push(token);
    }
  });

  return tokens;
}

/**
 * Remove invalid/expired FCM tokens from Firestore.
 */
async function cleanupInvalidTokens(
  userId: string,
  tokens: string[],
  response: admin.messaging.BatchResponse
): Promise<void> {
  const tokensToRemove: string[] = [];

  response.responses.forEach((result, index) => {
    if (result.error) {
      const errorCode = result.error.code;
      // Remove tokens that are no longer valid
      if (
        errorCode === "messaging/invalid-registration-token" ||
        errorCode === "messaging/registration-token-not-registered"
      ) {
        tokensToRemove.push(tokens[index]);
      }
    }
  });

  if (tokensToRemove.length === 0) return;

  // Find and delete the token documents
  const tokensSnap = await db
    .collection("users")
    .doc(userId)
    .collection("fcmTokens")
    .get();

  const batch = db.batch();
  tokensSnap.docs.forEach((doc) => {
    if (tokensToRemove.includes(doc.data().token)) {
      batch.delete(doc.ref);
      console.log(`Removing invalid token for user ${userId}`);
    }
  });

  await batch.commit();
}
