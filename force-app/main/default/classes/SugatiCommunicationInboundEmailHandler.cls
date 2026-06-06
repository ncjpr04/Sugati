global class SugatiCommunicationInboundEmailHandler implements Messaging.InboundEmailHandler {
    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        return SugatiCommunicationInboundService.processInboundEmail(email, envelope);
    }
}
