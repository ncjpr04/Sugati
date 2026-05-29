String raw = '{"opportunityId":"006d3000005oJpNAAU","templateId":"a2kd3000001SB81AAG","recipientIds":[],"recipientEmails":[],"recipientNames":[],"subjectTemplate":"Subject {{Opportunity.Name}}","bodyTemplate":"Body {{Opportunity.Name}}"}';
SugatiCommunicationHubController.PreviewRequest req = (SugatiCommunicationHubController.PreviewRequest) JSON.deserialize(raw, SugatiCommunicationHubController.PreviewRequest.class);
System.debug('REQ OPP: ' + req.opportunityId);
System.debug('REQ TEMPLATE: ' + req.templateId);
SugatiCommunicationHubController.PreviewResponse res = SugatiCommunicationHubController.previewMessage(req);
System.debug(JSON.serializePretty(res));
