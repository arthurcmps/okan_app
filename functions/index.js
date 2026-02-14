/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
admin.initializeApp();

setGlobalOptions({ region: "southamerica-east1" });

// Gatilho V2: Quando um documento é criado em users/{userId}/notifications/{notificationId}
exports.sendPushNotification = onDocumentCreated("users/{userId}/notifications/{notificationId}", async (event) => {
    // Na V2, o 'snap' agora é 'event.data'
    const snapshot = event.data;
    
    // Se não houver dados (ex: documento deletado logo em seguida), paramos
    if (!snapshot) {
        return;
    }

    const notificationData = snapshot.data();
    const userId = event.params.userId; // 'context.params' agora é 'event.params'

    console.log("Nova notificação detectada para o usuário:", userId);

    // 1. Buscar os tokens do usuário
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    
    // Se o usuário não tiver tokens salvos, paramos
    if (!userDoc.exists || !userDoc.data().fcmTokens || userDoc.data().fcmTokens.length === 0) {
      console.log("Nenhum token encontrado para o usuário:", userId);
      return;
    }

    const tokens = userDoc.data().fcmTokens;

    // 2. Montar a mensagem
    const payload = {
      notification: {
        title: notificationData.title || "Nova Notificação",
        body: notificationData.body || "Você tem uma nova mensagem no Okan.",
      },
      data: {
        // Dados extras para navegação
        type: notificationData.type || "general", 
        actionId: notificationData.actionId || "",
        click_action: "FLUTTER_NOTIFICATION_CLICK"
      }
    };

    // 3. Enviar para todos os dispositivos do usuário
    // sendToDevice é legado, mas ainda funciona. Se der erro, avise que mudamos para sendEachForMulticast
    const response = await admin.messaging().sendToDevice(tokens, payload);
    
    // 4. Limpeza de tokens inválidos
    const tokensToRemove = [];
    response.results.forEach((result, index) => {
      const error = result.error;
      if (error) {
        console.error("Erro ao enviar push:", error);
        // Códigos de erro que indicam token inválido
        if (error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered') {
          tokensToRemove.push(tokens[index]);
        }
      }
    });
    
    if (tokensToRemove.length > 0) {
       await admin.firestore().collection("users").doc(userId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove)
       });
       console.log("Tokens inválidos removidos:", tokensToRemove);
    }
});