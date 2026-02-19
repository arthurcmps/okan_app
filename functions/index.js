const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

// Forçamos a região para o Brasil (mais rápido e evita conflitos de permissão)
setGlobalOptions({ region: "southamerica-east1" }); 

exports.sendPushNotification = onDocumentCreated("users/{userId}/notifications/{notificationId}", async (event) => {
    const snapshot = event.data;
    
    // Se não houver dados (documento deletado rápido demais, etc), paramos
    if (!snapshot) return;

    const notificationData = snapshot.data();
    const userId = event.params.userId;

    console.log("Nova notificação detectada para o usuário:", userId);

    // 1. Buscar os tokens do usuário
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    
    if (!userDoc.exists || !userDoc.data().fcmTokens || userDoc.data().fcmTokens.length === 0) {
      console.log("Nenhum token encontrado para o usuário:", userId);
      return;
    }

    const tokens = userDoc.data().fcmTokens;

    // 2. Montar a mensagem no formato MulticastMessage com suporte a SOM e VIBRAÇÃO
    const message = {
      notification: {
        title: notificationData.title || "Nova Notificação",
        body: notificationData.body || "Você tem uma nova mensagem no Okan.",
      },
      // --- CONFIGURAÇÃO PARA ANDROID ---
      android: {
        notification: {
          sound: "default", // Força o som padrão
          clickAction: "FLUTTER_NOTIFICATION_CLICK"
        }
      },
      // --- CONFIGURAÇÃO PARA iOS (APPLE) ---
      apns: {
        payload: {
          aps: {
            sound: "default", // Força o som padrão
            badge: 1 // Atualiza a bolinha vermelha no ícone
          }
        }
      },
      // --- DADOS EXTRAS PARA NAVEGAÇÃO NO FLUTTER ---
      data: {
        type: String(notificationData.type || "general"), 
        actionId: String(notificationData.actionId || ""),
        click_action: "FLUTTER_NOTIFICATION_CLICK"
      },
      tokens: tokens, // Array de tokens
    };

    try {
      // 3. Enviar para todos os aparelhos do usuário
      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`${response.successCount} mensagens enviadas com sucesso.`);

      // 4. Limpeza de tokens antigos/inválidos
      const tokensToRemove = [];
      response.responses.forEach((res, index) => {
        if (!res.success) {
          const error = res.error;
          console.error(`Erro ao enviar push para o token ${index}:`, error);
          
          if (error.code === 'messaging/invalid-registration-token' ||
              error.code === 'messaging/registration-token-not-registered') {
            tokensToRemove.push(tokens[index]);
          }
        }
      });
      
      // Se achou token velho, deleta do banco para não dar erro na próxima
      if (tokensToRemove.length > 0) {
         await admin.firestore().collection("users").doc(userId).update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove)
         });
         console.log("Tokens inválidos limpos do banco com sucesso.");
      }
    } catch (error) {
      console.error("Erro fatal ao tentar enviar a mensagem de Push:", error);
    }
});