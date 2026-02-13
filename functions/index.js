const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Gatilho: Quando um documento é criado em users/{uid}/notifications/{notifId}
exports.sendPushNotification = functions.firestore
    .document("users/{userId}/notifications/{notificationId}")
    .onCreate(async (snap, context) => {
      const notificationData = snap.data();
      const userId = context.params.userId;

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
          // Opcional: Adicionar ícone ou som
        },
        data: {
          // Dados extras para navegação (ex: abrir chat específico)
          type: notificationData.type || "general", 
          actionId: notificationData.actionId || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        }
      };

      // 3. Enviar para todos os dispositivos do usuário
      const response = await admin.messaging().sendToDevice(tokens, payload);
      
      // 4. Limpeza de tokens inválidos (opcional, mas recomendado)
      // Se um token falhar (app desinstalado), devemos removê-lo do banco.
      const tokensToRemove = [];
      response.results.forEach((result, index) => {
        const error = result.error;
        if (error) {
          console.error("Erro ao enviar push:", error);
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
      }
    });