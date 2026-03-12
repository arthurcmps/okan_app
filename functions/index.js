const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// Esta função fica "olhando" a coleção de notificações do seu app 24h por dia
exports.enviarPushNotificationGenerica = onDocumentCreated(
    "users/{userId}/notifications/{notificationId}",
    async (event) => {
        
        // Se o documento não existir, ignora
        if (!event.data) return;

        const novaNotificacao = event.data.data();
        const userId = event.params.userId;

        // 1. Pega os dados do usuário para encontrar o "Token" (O CPF do aparelho)
        const userDoc = await admin.firestore().collection("users").doc(userId).get();
        if (!userDoc.exists) return;

        const userData = userDoc.data();
        const tokens = userData.fcmTokens; // A lista de tokens que o Flutter salvou

        // Se o usuário não tem token (nunca abriu o app), cancela o envio
        if (!tokens || tokens.length === 0) {
            console.log("Usuário sem token FCM:", userId);
            return;
        }

        // 2. Monta a mensagem Push que vai fazer o celular vibrar
        const payload = {
            notification: {
                title: novaNotificacao.title || "Nova Notificação",
                body: novaNotificacao.body || "Você tem uma nova mensagem no Okan.",
            },
            data: {
                // IMPORTANTE: Os campos de 'data' precisam ser String
                type: String(novaNotificacao.type || "geral"),
                actionId: String(novaNotificacao.actionId || ""),
            },
            android: {
                notification: {
                    channelId: "high_importance_channel", // O canal que força o som e vibração!
                    sound: "default"
                }
            },
            tokens: tokens // Envia para todos os aparelhos do usuário de uma vez
        };

        // 3. Dispara a notificação via Firebase Cloud Messaging
        try {
            const response = await admin.messaging().sendEachForMulticast(payload);
            console.log("Notificações enviadas com sucesso:", response.successCount);
        } catch (error) {
            console.error("Erro ao enviar Push:", error);
        }
    }
);