const {onDocumentDeleted} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");

initializeApp();

// Runs automatically whenever a document in users/{userId} is deleted
// (e.g. when an admin taps the X button in User Management). The
// Firestore document ID IS the Firebase Auth UID (see AuthService /
// signUp flow), so we can delete the matching Auth account directly.
exports.deleteAuthUserOnFirestoreDelete = onDocumentDeleted(
    "users/{userId}",
    async (event) => {
      const userId = event.params.userId;

      try {
        await getAuth().deleteUser(userId);
        console.log(`Deleted Auth account for uid: ${userId}`);
      } catch (error) {
        // Common case: account was already deleted manually before —
        // not a real failure, so just log it instead of throwing.
        console.error(`Could not delete Auth account ${userId}:`, error.message);
      }
    },
);